# AGENTS.md

This file provides guidance to AI agents and developers when working with code in this repository.

## Quick Start

**Build and install the package:**
```bash
R CMD INSTALL .
```

**Test the API (quick smoke test):**
```bash
R --quiet --no-save -e "
  library(rxet)
  h <- xet_client_new('https://example.com', 'token')
  xet_client_close(h)
  cat('✓ Basic API works\n')
"
```

**Iterate on Rust code only (faster):**
```bash
cd src/rust && cargo check
```

---

## Architecture

### Overview
`rxet` is an R package providing native bindings to Hugging Face's Xet content-addressed storage engine. The architecture uses **extendr** to bridge R and Rust.

**Design pattern:**
```
R functions (R/)
    ↓ [.Call() dispatch]
Rust extendr bindings (src/rust/src/lib.rs)
    ↓ [async_blocking API]
hf-xet crate (git dependency)
    ↓
XetSession + AuthGroupBuilder
    ↓
CAS protocol + Tokio runtime (internal to hf-xet)
```

### Key Components

**Handle-Based Session Management** (`src/rust/src/lib.rs`)
- Character UUID handles (v4 strings) map to `XetClient` structs
- Each `XetClient` owns: `XetSession` + auth credentials (endpoint, token)
- Stored in lazy_static `Mutex<HashMap<String, Arc<XetClient>>>` keyed by that UUID
- Avoids passing credentials on every operation

**R Wrapper Layer** (`R/`)
- `xet_client_new(endpoint, token)` → character UUID handle
- `xet_client_close(handle)` → cleanup
- `xet_download_file(handle, hash, file_size, dest)` → file
- `xet_upload_file(handle, src_path)` → list(hash, file_size)
- Each wrapper validates inputs and calls corresponding Rust function via `.Call()`

**FFI Bridge** (`src/entrypoint.c`)
- **Critical for linking.** Registers extendr panic hook and forwards `R_init_<pkg>()` to Rust's `R_init_<pkg>_extendr()`.
- Without this file, the `.so` cannot be created.

**Build System** (`src/Makevars.in`, `configure`, `tools/`)
- Generates platform-specific `src/Makevars` from template
- Detects Rust toolchain via `tools/msrv.R`
- Builds static Rust lib (`librxet.a`), links into R shared object (`rxet.so`)
- Supports offline/CRAN builds via vendored crates

---

## Module Import Paths (Important!)

**Correct import in Rust:**
```rust
use xet::xet_session::{XetSession, XetSessionBuilder, XetFileInfo, Sha256Policy};
```

**NOT:**
```rust
use hf_xet::{...};  // Wrong: crate name is hf-xet, lib name is xet
use xet::{...};     // Wrong: types are nested in ::xet_session module
```

The hf-xet crate publishes lib name `xet`, and public types live in `xet::xet_session::*`.

---

## Common Tasks

### Modify Rust Bindings
1. Edit `src/rust/src/lib.rs`
2. Check syntax: `cd src/rust && cargo check`
3. Rebuild package: `R CMD INSTALL .`
4. Test in R: `R --no-save -e 'library(rxet); xet_client_new("url", "token")'`

### Modify R Wrappers
1. Edit `R/*.R` files
2. Rebuild: `R CMD INSTALL .` (relinks `.so` if Rust unchanged)
3. Test: `R --no-save -e 'library(rxet); ...'`

### Add a New Rust Function
1. Add `#[extendr]` fn in `src/rust/src/lib.rs`
2. Add to `extendr_module!` macro at end of file
3. Create R wrapper in appropriate `R/*.R` file
4. Rebuild and test

### First Build (Slow)
- First `R CMD INSTALL .` downloads hf-xet and 300+ transitive deps from git
- Compiles ~40 proc-macro crates (slow)
- Subsequent builds cache in `src/rust/target/`, much faster
- ~5-10 minutes first time, ~30 seconds for Rust-only changes

### Dependency Issues
- Dependencies stored in `src/rust/Cargo.lock` (commit if stable)
- Git dep (hf-xet) is specified by commit hash in lock file
- To update: `cd src/rust && cargo update`

---

## Auth Design

**Static Bearer Token:**
```rust
.with_endpoint("https://cas.example.com")
.with_token_info("bearer-token-here", u64::MAX)  // u64::MAX = no expiry
```

**Per-Client Storage:**
- Credentials stored in `XetClient` struct when client created
- Passed to `AuthGroupBuilder` for each operation (download/upload)
- No global state; each client is independent

---

## Testing

**No formal test suite yet.** Smoke tests are manual:
```bash
R --quiet --no-save << 'EOF'
library(rxet)
client <- xet_client_new("https://example.com", "token")
xet_client_close(client)
cat("✓ API works\n")
EOF
```

Integration testing requires:
- Live Xet CAS endpoint
- Valid bearer token
- XetFileInfo (hash + file_size) from HuggingFace Hub

---

## Codebase Layout

```
rxet/
├── R/                          # R wrapper functions
│   ├── client.R                # xet_client_new/close + docs
│   ├── download.R              # xet_download_file
│   ├── upload.R                # xet_upload_file
│   ├── extendr-wrappers.R      # .Call() dispatch stubs
│   └── rxet-package.R          # Package metadata
├── src/
│   ├── entrypoint.c            # ⚠️ CRITICAL: R/Rust FFI bridge
│   ├── Makevars.in             # Build rules template
│   └── rust/
│       ├── Cargo.toml          # Rust deps + extendr-api
│       └── src/lib.rs          # 4 core Rust bindings + handle map
├── configure{,.win}            # Calls tools/config.R
├── DESCRIPTION                 # Package metadata
├── NAMESPACE                   # Exports (patterns: ^xet_)
└── tools/
    ├── config.R                # Generate src/Makevars
    └── msrv.R                  # Validate Rust version >= 1.70
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `configure: command not found` | `chmod +x configure configure.win` |
| `shared object 'rxet.so' not found` | Missing `src/entrypoint.c` or linker error. Check build log for `undefined reference` |
| `unresolved import xet::...` | Use `xet::xet_session::*` not `xet::*` or `hf_xet::*` |
| Build hangs on first compile | Normal. Git deps + 300+ crates = 5-10 min. Check `ps aux \| grep cargo` |
| Rust compile errors | `cd src/rust && cargo check` gives clearer error messages than `R CMD INSTALL` |
| Module not found in R | Verify `NAMESPACE` has `exportPattern("^xet_")` and `useDynLib(rxet, ...)` |

---

## Key Constraints

- **Zero Python.** No `reticulate`, no Python bindings. Pure Rust ↔ R via extendr.
- **extendr-api 0.9.0.** Locked version; update carefully (may change macro syntax).
- **Synchronous API only.** Rust code blocks; no async callbacks to R (not supported by R).
- **Static lib linking.** `crate-type = ['rlib', 'staticlib']` in Cargo.toml; R links the `.a` into `.so`.
- **Handle opaqueness.** Handles are random character UUID strings; opaque and no type safety. R must not invent handles.

---

## Design Rationale

**Why character UUID handles instead of ExternalPtr?**
- Simpler R API (user just passes strings)
- Matches roxigdal pattern (local reference)
- Avoids serialization issues with R's external pointer format

**Why lazy_static + Mutex + Arc?**
- Thread-safe: R may load package in concurrent context
- Arc: ref-counted; no memory leaks when handle dropped
- Mutex: serialized access; xet-core's XetSession may not be Send

**Why not async callbacks?**
- R has no event loop; blocking calls are standard
- hf-xet's `_blocking()` API designed for this use case
- Keeps R code simple (no futures, no await syntax)

**Why per-client auth storage?**
- xet-core's AuthGroupBuilder takes credentials per operation
- Avoids passing 2 strings on every download/upload call
- Enables multiple clients with different tokens in same session

---

## References

- **extendr-api docs:** https://docs.rs/extendr-api/0.9.0/
- **hf-xet source:** https://github.com/huggingface/xet-core/tree/main/xet_pkg
- **roxigdal (local reference):** `/home/andrew/workspace/roxigdal/` (similar rextendr structure)
