# Execution Plan 4 — Phase 4: Harden Core Rust/R Operations and Failure Semantics

Orchestration 4 of the rxet release plan. Source of truth: `planning/MASTER_PLAN.md`,
Phase 4. Prior phases: `EXECUTION_PLAN_1.md`/`STATE_1.md` (scope),
`EXECUTION_PLAN_2.md`/`STATE_2.md` (docs/metadata), `EXECUTION_PLAN_3.md`/`STATE_3.md`
(build/packaging). Governing ADRs: `docs/decisions/0001` (13-export API, experimental
labels), `0003` (tests under `R CMD check`).

## Goal & Scope

**Goal.** Included core operations get a predictable client-handle lifecycle, checked
size/offset validation in R and Rust, a registry lock that is not held across blocking
network I/O, atomic disk downloads that never leave a corrupt destination, safe FFI
error propagation, and early readable errors that do not leak credentials. Each
behavior is backed by deterministic tests that run offline and need no credentials.

**In scope**
- R input validation: endpoint scheme rule, finite whole-byte sizes, 2 GiB in-memory cap (`R/client.R`, `R/stream.R`, `R/connection.R`).
- Rust registry lock release before blocking I/O; removal of the Tokio/`Drop` placeholders (`src/rust/src/lib.rs`).
- Rust checked size conversion, fallible allocation, and the upload report check (`src/rust/src/lib.rs`).
- Atomic disk download via temp file + rename (`R/download.R`).
- Offline failure-path tests (closed port, blackhole listener) and token redaction (`tests/testthat/`).
- Rust unit tests for the registry lock contract (`src/rust/src/registry.rs`, `src/rust/src/tests.rs`).
- Roxygen/Rd and README sentences that describe the new behavior.

**Out of scope (deferred, do not implement)**
- Success-path byte-integrity tests against a live or protocol-compatible Xet endpoint. Owned by Phase 5.
- Any change to the public export set (13 functions per ADR 0001) or to experimental labels.
- Upload hash verification (`Sha256Policy` stays `Skip`). Upload stays experimental.
- Vendoring, CRAN submission, Windows execution (CI-gated per Phase 3 D9).
- Memory-efficient streaming or range-backed connections. Phase 6 scope.
- Cancellation of in-flight operations. Not supported by hf-xet in this phase.
- Tokio runtime replacement. `tokio` stays in `Cargo.toml`; only the unused placeholder code is removed.

**Verbatim constraints** (quoted from `planning/MASTER_PLAN.md` and the user's answers):
- Phase 4 exit gate: "Focused tests demonstrate checked inputs, lock not held over blocking I/O, no failed-download artifact corruption, and safe FFI error propagation; Rust and package builds pass."
- Master rule: "Do not claim a phase complete solely because code compiles."
- Master rule: "Preserve user changes and keep generated build/check artifacts out of commits unless explicitly intended."
- Cross-phase risk: "Partial destination on failure — Users may consume corrupt or empty output as valid."
- Cross-phase risk: "Mutex across network waits — One slow request can block unrelated clients."

**Recon coverage vs. master items** (every master Phase 4 item maps to a task or a deferral):

| Master item | Disposition |
|---|---|
| 1 inspect R/Rust sources | done in recon (see Recon log) |
| 2 release registry lock before blocking I/O | 4.1.2 (lock), 4.3.2 (test) |
| 3 finite/whole-byte/representable validation, checked conversion, alloc limits | 4.1.1 (R), 4.2.1 (Rust) |
| 4 atomic disk download | 4.2.2 (R), 4.3.1 (test) |
| 5 upload commit review | 4.2.1 (report check); Sha256 policy kept (D5) |
| 6 remove Tokio/Drop placeholders; panic/error FFI review | 4.1.2 (removal); FFI review at 4.2.1 and final gate |
| 7 endpoint/hash/token preconditions, no credential leak | 4.1.1 (endpoint), 4.3.1 (redaction test) |
| 8 deterministic tests for wrapper validation, lifecycle, lock, cleanup | 4.1.1, 4.3.1, 4.3.2 |

## Decision log (dated 2026-10-15, user answers)

- **D1 — Untracked artifacts.** `rxet.Rcheck/` and `rxet_0.1.0.tar.gz` are ignored via `.gitignore` (`rxet.Rcheck/`, `rxet_*.tar.gz`). Nothing is deleted or moved. Applied as a planning-commit step, not a task.
- **D2 — In-memory size policy.** Fixed cap of **2^31 − 1 bytes** (`.Machine$integer.max`, `i32::MAX`). Applies to `xet_stream_raw` (`file_size`), `xet_stream_range` (`end_byte − start_byte`), and `xet_open_connection` (via `xet_stream_raw`). Exceeding it errors before any handle lookup or network work. Fallible allocation (`try_reserve_exact`) is the second guard. The error text points to `xet_download_file()`. No new public option.
- **D3 — Atomic disk download.** Download to a temp file in the destination's directory, then rename over `dest_path` only on full success. On failure the temp file is removed and a pre-existing `dest_path` is untouched. The existing "destination is a directory" and "parent missing" errors remain.
- **D4 — Close during an operation.** `xet_client_close()` removes the handle from the registry immediately; new calls on that handle error with "invalid or closed client handle". An in-flight operation keeps its owned `Arc` and completes normally. Documented in `xet_client_close` help (4.4.1).
- **D5 — Upload semantics.** Keep single-file behavior and `Sha256Policy::Skip`. Fix lifecycle only: registry lock released, and an explicit error when the report holds more than one upload. Upload stays experimental.
- **D6 — Endpoint rule.** `https://` accepted for any host. `http://` accepted only when the host is exactly `localhost` or `127.0.0.1` (case-insensitive). Everything else errors with "endpoint must use https:// (http:// is allowed only for localhost or 127.0.0.1)". Keeps bearer tokens off cleartext remote links and leaves a loopback seam for Phase 5.
- **D7 — Test seam.** Deterministic offline tests use a closed loopback port (fast failure) and a blackhole listener (`serverSocket()` on 127.0.0.1 that never accepts or replies; read timeout shortened with `HF_XET_CLIENT_READ_TIMEOUT`). No live credentials.
- **D8 — Parallelism and models.** Max 2 concurrent workers per wave, file-disjoint. Rust tasks touching `src/rust/src/lib.rs` run in separate waves. Workers run on Haiku. Escalation per wave-orchestration's ladder (mid-tier re-run, never a third small-model attempt).

**Judgment calls made by the planner (not asked; flagged for review):**
- J1. **Lock test lives in Rust, not R.** R is single-threaded; while `.Call` blocks, no R code can contend the registry. The lock-release proof is a Rust unit test on a generic `Registry<T>` (4.3.2). Call-site correctness is verified by grep and review, not by that test.
- J2. **Panic/FFI proof is review-level.** No deterministic panic trigger exists without a new test hook; the exit gate's "safe FFI error propagation" is evidenced by `safe_exec` retention, the removed `Drop` placeholder, and error-path tests in 4.3.1. Residual gap is recorded in STATE_4.md.
- J3. **`callr` not used.** The lifecycle tests need no subprocess under D7. `callr` is not added.
- J4. **Read timeout tests may be slow.** hf-xet may retry before surfacing a timeout. Workers must measure; if one test exceeds 60 s wall clock, STOP and report (do not raise timeouts silently).

## Recon log (facts from the repository, 2026-10-15)

- `src/rust/src/lib.rs` — 335 lines. Single file holds all Rust bindings. Global `CLIENTS: Mutex<HashMap<String, Arc<XetClient>>>` (line 48 `lazy_static!`). Each of `xet_stream_raw` (116), `xet_stream_range` (168), `xet_download_file` (238), `xet_upload_file` (285) takes `CLIENTS.lock()` and keeps the guard through the blocking network call — the master plan's "mutex across network waits" risk, confirmed.
- `impl Drop for XetClient` (line 15) spawns a no-op task on the runtime; its only user is `get_rt()` (line 57). Both are placeholders with no effect.
- Unchecked size casts: `file_size.round() as u64` (136, 208, 259), `start_offset.round() as u64` (203), `end_offset.round() as u64` (204), `Vec::with_capacity(size_bytes as usize)` (155) and `Vec::with_capacity(size as usize)` (226). A huge `file_size` aborts on allocation instead of erroring.
- `xet_download_file` writes straight to `dest` via `download_file_to_path_blocking` (line ~272), then `finish_blocking()` (~276). A failure leaves a partial file.
- `xet_upload_file` (285): `Sha256Policy::Skip`; takes `report.uploads.values().next()` without checking how many uploads exist.
- R: `xet_client_new` (`R/client.R`) accepts any `^https?://`. `xet_stream_raw` (`R/stream.R`) checks `file_size >= 0` but not finiteness, so `Inf` reaches Rust (Rust rejects it; R should too for a consistent error). `xet_download_file` (`R/download.R`) already rejects non-finite sizes via `file_size <= .Machine$double.xmax`.
- Existing tests to keep passing: `test-input-validation.R:9` (ftp rejected), `:36` (`"nchar.*handle"`), `:103` and `:115` (`"file_size"`), `:89` (`"end_byte"`-family); `test-streaming.R:30` (`"file_size"`), `:48` (`"end_byte.*file_size"`); `test-client.R:33` and `:41` (`"invalid"` in close error). Error wording for these patterns must not change.
- Test infrastructure: `devtools` 2.x, `testthat`, `roxygen2`, `processx`, `callr`, `future` installed. `uuid` and `arrow` absent (their tests skip). Suite under `R CMD check`: `FAIL 0 | WARN 0 | SKIP 11 | PASS 111` (Phase 3 evidence).
- Toolchain: `cargo 1.96.0-nightly`; MSRV `1.85` (Phase 3). `try_reserve_exact` is stable.
- `R/download.R` and `R/stream.R` contain roxygen blocks that generate `man/*.Rd`. Regeneration happens once, in 4.4.1.
- Conventions: `AGENTS.md` (build `R CMD INSTALL .`; `cd src/rust && cargo check`; tests `devtools::test()`).

## Hazards

- **H1** Registry lock is held over network I/O today; fixing it must not change `xet_close_client` error text ("invalid or already-closed client handle" — `test-client.R:33` expects "invalid").
- **H2** `Vec::with_capacity` on an attacker/typo-sized input aborts the process; the cap must run before any allocation.
- **H3** Temp file must be created in the destination directory (same filesystem for atomic rename). `tempfile(tmpdir = dest_dir)`.
- **H4** `file.rename()` overwrite-on-existing behavior differs by platform. Linux verified in-task; Windows behavior is an unverified hazard (CI matrix is the gate, D9 of Phase 3). Worker must not claim Windows atomic overwrite.
- **H5** After removing the `Drop` placeholder and `get_rt`, `tokio` may have no remaining `use`. Leave `Cargo.toml`/`Cargo.lock` untouched; note any `unused` warning in the report.
- **H6** `cargo test` may fail to link because the crate depends on extendr/R symbols. If it does, the 4.3.2 worker STOPs and reports the exact linker error; do not add R-linking workarounds, feature flags, or new dependencies without orchestrator approval.
- **H7** The `R/` roxygen changes in 4.2.2 and 4.1.1 do not regenerate `man/`. Rd drift is cleared only in 4.4.1; do not run `roxygen2` in earlier tasks.
- **H8** Tests must never read or write real user caches. Use `tempfile()` directories and `withr::local_envvar()` or `on.exit()` to restore `HF_XET_*` variables.

## Wave table

| Wave | Task | Repo | Files (must edit) | Depends on | Parallel with |
|---|---|---|---|---|---|
| 1 | `4.1.1.r-input-validation` | rxet | `R/client.R`, `R/stream.R`, `R/connection.R`, `tests/testthat/test-input-validation.R` | none | `4.1.2` |
| 1 | `4.1.2.rust-registry-lock` | rxet | `src/rust/src/lib.rs` | none | `4.1.1` |
| 2 | `4.2.1.rust-size-and-upload` | rxet | `src/rust/src/lib.rs` | `4.1.2` | `4.2.2` |
| 2 | `4.2.2.r-atomic-download` | rxet | `R/download.R` | `4.1.1` | `4.2.1` |
| 3 | `4.3.1.lifecycle-failure-tests` | rxet | creates `tests/testthat/test-phase4-lifecycle.R` | `4.2.2`, `4.2.1` | `4.3.2` |
| 3 | `4.3.2.rust-registry-tests` | rxet | `src/rust/src/lib.rs`, `src/rust/src/registry.rs` (new), `src/rust/src/tests.rs` (new) | `4.2.1` | `4.3.1` |
| 4 | `4.4.1.docs-rd-sync` | rxet | `man/*.Rd` (regenerated), `README.Rmd`, `README.md`, `DESCRIPTION` (RoxygenNote only if changed) | `4.3.1`, `4.3.2` | none |

Disjointness check: wave 1 — `4.1.1` (R/client.R, R/stream.R, R/connection.R, test-input-validation.R) and `4.1.2` (lib.rs) share no file. Wave 2 — `4.2.1` (lib.rs) and `4.2.2` (download.R) share no file. Wave 3 — `4.3.1` (new R test file) and `4.3.2` (Rust files) share no file. Wave 4 is serial.

Note on `4.2.1` vs `4.1.2`: both edit `lib.rs`, so they are in different waves (sequential by wave dependency).

Note on `4.4.1`: roxygen regeneration rewrites every `man/*.Rd`; it must run after all R roxygen edits (4.1.1 touches client/stream/connection roxygen; 4.2.2 touches download roxygen).

## Task specs

Common acceptance rules for every task:
- Targeted command must exit 0 and be reported verbatim with pass/fail counts.
- Worker must not run the full suite; the orchestrator runs it serially at wave end.
- Every file outside "Files in scope" is untouchable. Discovered work goes in `## Discovered` and waits.

---

### 4.1.1.r-input-validation

- **Repo:** rxet
- **Files in scope (must edit):** `R/client.R`, `R/stream.R`, `R/connection.R`, `tests/testthat/test-input-validation.R`
- **Files in scope (can create):** none
- **Depends on:** none
- **Reference implementation:** the existing `stopifnot(...)` chains in `R/stream.R` (`xet_stream_raw`, `xet_stream_range`) and `R/client.R` (`xet_client_new`) — extend in place; do not add a validation helper file.

**Spec**
1. `xet_client_new()` (`R/client.R`, anchor `grepl("^https?://"`): accept `https://` for any host. Accept `http://` only when the host (text after `http://`, up to the first `/`, `:`, or end) equals `localhost` or `127.0.0.1` case-insensitively. All other inputs error with exactly: `endpoint must use https:// (http:// is allowed only for localhost or 127.0.0.1)`. Keep the existing `ftp://` rejection path (it hits the same message, which is acceptable).
2. Add a shared finite-whole-byte check in each of `xet_stream_raw`, `xet_stream_range`, and `xet_open_connection` (`R/stream.R`, `R/connection.R`). A size is valid if `is.finite(x)` and `x == floor(x)`. Message when invalid: `file_size must be a finite whole number of bytes`. Keep the existing `stopifnot` messages that tests match on ("file_size", "end_byte.*file_size", "nchar.*handle").
3. Add the 2 GiB cap (decision D2). Constant in-function: `max_in_memory <- .Machine$integer.max` (2^31 − 1). `xet_stream_raw`: if `file_size > max_in_memory`, error: `in-memory read of <N> bytes exceeds the 2 GiB limit (2147483647 bytes); use xet_download_file() for larger files`. `xet_stream_range`: apply the same check to `end_byte - start_byte` with the same message wording ("requested range"). The cap check runs **before** any `.Call`, so it works with an unknown handle.
4. Keep check order: handle → hash → size type/finite/whole → cap → existing range checks. Do not reorder checks in a way that changes which error a currently-tested input produces.
5. Update roxygen `@param`/`@details` in these three files only to mention the cap and the finite-whole-byte rule. Do **not** run roxygen2 (H7).
6. Tests (`tests/testthat/test-input-validation.R`, extend existing `describe`/`it` blocks in the same style):
   - `Inf` and `NaN` `file_size` rejected by `xet_stream_raw` and `xet_open_connection`.
   - Fractional `file_size` (`1.5`) rejected.
   - `file_size = 2^31` rejected with message matching `"2 GiB limit"`, using handle `"handle"` (proves no network/handle lookup).
   - `xet_stream_range` with `start_byte = 0`, `end_byte = 2^31` and `file_size = 2^32` rejected with `"2 GiB limit"`.
   - `xet_client_new("http://example.com", "token")` errors matching `"https://"`.
   - `xet_client_new("http://localhost:8080", "token")` succeeds; close it.
   - `xet_client_new("http://127.0.0.1:9", "token")` succeeds; close it.
   - `xet_client_new("HTTP://LOCALHOST", "token")` succeeds (case-insensitive); close it.

**Anchors**
- `R/client.R` `xet_client_new <- function` and the `grepl("^https?://"` line.
- `R/stream.R` `xet_stream_raw <- function`, `xet_stream_range <- function`.
- `R/connection.R` `xet_open_connection <- function`.
- `tests/testthat/test-input-validation.R` `describe(` blocks for "xet_stream_raw", "xet_stream_range", "xet_open_connection", "xet_client_new".

**Constraints (do not touch)**
- `R/download.R`, `R/upload.R`, `src/**`, `R/utils.R`, `tests/testthat/helper-*.R`, `man/**`, `NAMESPACE`, `DESCRIPTION`.
- No new dependencies. No `roxygen2` run.

**Acceptance**
```bash
Rscript -e 'devtools::test(filter = "input-validation|streaming", reporter = "summary", stop_on_failure = TRUE)'
```
Exit 0; 0 failures. Skips permitted only for the existing uuid/arrow/credential guards.

---

### 4.1.2.rust-registry-lock

- **Repo:** rxet
- **Files in scope (must edit):** `src/rust/src/lib.rs`
- **Files in scope (can create):** none
- **Depends on:** none
- **Reference implementation:** `xet_init_client` / `xet_close_client` already take the lock only for the insert/remove — mirror that pattern.

**Spec**
1. Add a private helper in `lib.rs`:
   `fn acquire_client(handle: &str) -> extendr_api::Result<Arc<XetClient>>` — lock `CLIENTS`, clone the `Arc` for `handle` (error `invalid or closed client handle` if absent, same text as today), and return; the guard drops at return.
2. In `xet_stream_raw`, `xet_stream_range`, `xet_download_file`, `xet_upload_file`: replace the `let clients = CLIENTS.lock()…; let client = clients.get(handle)…` block with `let client = acquire_client(handle)?;`. The guard must not outlive the helper. Blocking calls then run on the owned `Arc`.
3. Remove the `impl Drop for XetClient` block (anchor `impl Drop for XetClient`) and `fn get_rt` plus `TOKIO_RUNTIME` `static`, and their `use tokio::runtime::…` / `OnceLock` imports if unused after removal. Do **not** edit `Cargo.toml` or `Cargo.lock` (H5). Note in the report whether `tokio` is now unused in code.
4. Keep `safe_exec` and its `catch_unwind` wrapping unchanged on every extendr function.
5. Keep `xet_close_client` and `xet_init_client` behavior unchanged (error text included).

**Anchors** (lines are from 2026-10-15 recon; verify with grep)
- `impl Drop for XetClient` (≈15), `lazy_static!` `CLIENTS` (≈48), `TOKIO_RUNTIME`/`get_rt` (≈55–66), `CLIENTS.lock()` in `xet_stream_raw` (≈129), `xet_stream_range` (≈196), `xet_download_file` (≈252), `xet_upload_file` (≈287).

**Constraints (do not touch)**
- `src/rust/Cargo.toml`, `src/rust/Cargo.lock`, `R/**`, `tests/**`, `src/entrypoint.c`, `src/Makevars*`.
- Do not change extendr signatures or the `extendr_module!` list.

**Acceptance**
```bash
cd src/rust && cargo check 2>&1 | tail -3 && cd ../.. && ! grep -n "impl Drop for XetClient\|fn get_rt\|TOKIO_RUNTIME" src/rust/src/lib.rs && Rscript -e 'devtools::test(filter = "client", reporter = "summary", stop_on_failure = TRUE)'
```
Exit 0. `cargo check` must report `Finished` with no new warnings beyond pre-existing ones (list any new warning in the report).

---

### 4.2.1.rust-size-and-upload

- **Repo:** rxet
- **Files in scope (must edit):** `src/rust/src/lib.rs`
- **Files in scope (can create):** none
- **Depends on:** `4.1.2`
- **Reference implementation:** the existing `safe_exec` error style (`Error::Other(format!(…))`) and the R messages from 4.1.1 — keep wording identical so R and Rust errors read the same.

**Spec**
1. Add `const MAX_IN_MEMORY_BYTES: u64 = i32::MAX as u64;` (2^31 − 1, decision D2).
2. Add `fn to_whole_bytes(value: f64, what: &str) -> extendr_api::Result<u64>`: error if `!value.is_finite()` or `value < 0.0` or `value.fract() != 0.0` or `value >= 18446744073709551616.0` (2^64). Otherwise `Ok(value as u64)`. Messages: `"{what} must be a finite whole number of bytes, got {value}"`.
3. Replace every `.round() as u64` in `xet_stream_raw`, `xet_stream_range`, `xet_download_file` with `to_whole_bytes(…, "file_size")` (or `"start_offset"`/`"end_offset"`/`"total_size"` as appropriate). Remove the now-redundant `is_nan`/`is_infinite` checks only where `to_whole_bytes` covers them.
4. `xet_stream_range`: compute `size = end.checked_sub(start)` and error `"invalid byte range: end {end} is before start {start}"` on `None`. Keep the existing offset-order errors.
5. In `xet_stream_raw`: if `size_bytes > MAX_IN_MEMORY_BYTES` → error `in-memory read of {size_bytes} bytes exceeds the 2 GiB limit (2147483647 bytes); use xet_download_file() for larger files`. In `xet_stream_range`: same check on `size`, wording `in-memory requested range of {size} bytes exceeds the 2 GiB limit (2147483647 bytes); use xet_download_file() for larger files` (identical to the R text approved in 4.1.1). Run both checks **before** `acquire_client` so they fire without a handle.
6. Replace `Vec::with_capacity(…)` (both in stream functions) with `let mut buf = Vec::new(); buf.try_reserve_exact(n).map_err(|e| Error::Other(format!("cannot allocate {n} bytes for in-memory read: {e}")))?;` where `n` is the checked size.
7. `xet_upload_file`: after `report.uploads`, if `report.uploads.len() != 1` → error `expected exactly one uploaded file, got {len}`. Keep the existing `no upload metadata in report` error for the zero case. Keep `Sha256Policy::Skip` (D5).
8. No token or endpoint may appear in any new error message.

**Anchors**
- `fn xet_stream_raw` (`file_size.round() as u64`, `Vec::with_capacity(size_bytes as usize)`), `fn xet_stream_range` (`start_offset.round()`, `end_offset.round()`, `Vec::with_capacity(size as usize)`), `fn xet_download_file` (`file_size.round() as u64`), `fn xet_upload_file` (`report.uploads.values().next()`).

**Constraints (do not touch)**
- `src/rust/Cargo.toml`, `src/rust/Cargo.lock`, `R/**`, `tests/**`, `src/rust/src/registry.rs` (does not exist yet; created in 4.3.2 — do not create it here).
- No new crates. No change to extendr signatures or the module list.

**Acceptance**
```bash
cd src/rust && cargo check 2>&1 | tail -3 && cd ../.. && grep -c "with_capacity" src/rust/src/lib.rs | grep -qx 0 && Rscript -e 'devtools::test(filter = "input-validation|streaming|stream-range", reporter = "summary", stop_on_failure = TRUE)'
```
Exit 0. `grep -c with_capacity` must be `0`. Tests skipped for credentials are acceptable; any failure is not.

---

### 4.2.2.r-atomic-download

- **Repo:** rxet
- **Files in scope (must edit):** `R/download.R`
- **Files in scope (can create):** none
- **Depends on:** `4.1.1` (finite whole-byte rule already defined there)
- **Reference implementation:** `on.exit()` cleanup pattern used in the package's existing R wrappers; `tempfile(tmpdir = …)` for same-directory temp files.

**Spec**
1. Add a finite whole-byte check to `xet_download_file`: `stopifnot(is.finite(file_size), file_size == floor(file_size))` after the existing `file_size` checks, with message `file_size must be a finite whole number of bytes`.
2. Create the temp path in the destination directory: `tmp <- tempfile(pattern = paste0(".", basename(dest_path), "-"), tmpdir = dest_dir, fileext = ".part")`.
3. Register cleanup before the native call: `on.exit(if (file.exists(tmp)) unlink(tmp), add = TRUE)`.
4. Call `.Call("wrap__xet_download_file", handle, hash, as.double(file_size), tmp, PACKAGE = "rxet")`.
5. On success: `if (!file.rename(tmp, dest_path)) stop(sprintf("could not move download into place: %s", dest_path))`. The `on.exit` then finds no temp file and does nothing.
6. Return `invisible(dest_path)` as today.
7. Update the roxygen block for `xet_download_file`: one sentence stating the file is written to a temporary file in the destination directory and moved into place only after the download succeeds; a failed download leaves no partial file and does not modify an existing `dest_path`. Do **not** run roxygen2 (H7).
8. Do not change the directory/parent checks.

**Anchors**
- `xet_download_file <- function(handle, hash, file_size, dest_path)`, `.Call("wrap__xet_download_file"`, roxygen block above it (`#' Download a file from Xet storage`).

**Constraints (do not touch)**
- `src/**`, `R/client.R`, `R/stream.R`, `R/connection.R`, `R/upload.R`, `tests/**`, `man/**`, `NAMESPACE`, `DESCRIPTION`.
- Do not change the function signature or return value.

**Hazard (H4):** `file.rename()` overwrite behavior on Windows is unverified. Do not add Windows-specific code. Note the risk in the report; CI (Phase 3 D9) is the gate.

**Acceptance**
```bash
grep -n "tempfile(" R/download.R && grep -n "file.rename" R/download.R && Rscript -e 'devtools::test(filter = "input-validation", reporter = "summary", stop_on_failure = TRUE)'
```
Exit 0. Behavioral proof of the failure path is in `4.3.1`; this task must not claim it.

---

### 4.3.1.lifecycle-failure-tests

- **Repo:** rxet
- **Files in scope (must edit):** none
- **Files in scope (can create):** `tests/testthat/test-phase4-lifecycle.R`
- **Depends on:** `4.2.2`, `4.2.1`
- **Reference implementation:** `tests/testthat/test-input-validation.R` style (`describe`/`it`) and `tests/testthat/test-client.R` for handle handling.

**Spec** (offline; loopback only; no credentials)

Helper functions defined at the top of the new file (file-local, not exported):
- `closed_port()`: return an unused port on 127.0.0.1 (use `serverSocket(0)`-free approach: pick from 20000–40000 and verify with `tryCatch(socketConnection(…), error = ...)` that nothing listens; if something listens, retry).
- `blackhole()`: `srv <- serverSocket(port)`; return list(port, srv); test calls `close(srv)` in `on.exit`. The socket is listening but never accepted, so connects complete and requests hang until the read timeout.
- `with_short_timeout(expr)`: `withr::local_envvar(HF_XET_CLIENT_READ_TIMEOUT = "2")` (or `Sys.setenv` + `on.exit` restore if `withr` is absent — prefer `withr` only if already in `Suggests`; otherwise restore manually). Set **before** `xet_client_new`, because the config is read at client creation (`src/rust/src/lib.rs` `XetConfig::new()`).

Tests (each uses `tempfile()` directories, cleaned up on exit; never a real cache):
1. **Failed download to closed port leaves no destination:** `xet_download_file` errors; `file.exists(dest)` is FALSE; `list.files(dir, all.files = TRUE)` contains no entry matching `^\\.` + dest basename + `-` and ending `.part`.
2. **Failed download preserves an existing destination:** write `"original"` to `dest`; the failing download errors; `readChar(dest, nchars = 8)` is `"original"`; no `.part` leftovers.
3. **Failed download to blackhole errors within bound:** `xet_download_file` against `blackhole()`; `expect_error`; elapsed wall clock `< 60` seconds (J4 bound); `dest` absent; no `.part` leftovers.
4. **Token is not leaked:** client with token `"rxet-secret-token-XYZ"` against closed port; `tryCatch(xet_download_file(...), error = function(e) conditionMessage(e))` does not contain the token string (`grepl(…, fixed = TRUE)` is FALSE).
5. **Stream to blackhole errors without partial return:** `xet_stream_raw(client, "abc", 1024)` against `blackhole()` errors (no `raw` returned); bounded by the same 60 s guard.
6. **Closed handle after close:** `xet_client_close(h)` then `xet_download_file(h, …)` errors matching `"invalid or closed"`.
7. **Double close errors:** already in `test-client.R`; do not duplicate.

**Anchors**
- `R/download.R` `xet_download_file` (temp-file logic from 4.2.2), `R/stream.R` `xet_stream_raw`, `src/rust/src/lib.rs` `safe_exec` (error text shape `Error::Other`).

**Constraints (do not touch)**
- `R/**`, `src/**`, `tests/testthat/helper-*.R`, `tests/testthat/test-input-validation.R`, `tests/testthat/test-client.R`, `man/**`.
- Do not add `callr` or any new dependency (J3).
- Do not use the real `HF_TOKEN` or any real endpoint (`huggingface.co`). Use `127.0.0.1` only.

**Acceptance**
```bash
Rscript -e 'devtools::test(filter = "phase4-lifecycle", reporter = "summary", stop_on_failure = TRUE)'
```
Exit 0. Report per-test elapsed time (`reporter = "timing"` if available) and any test over 30 s (J4).

---

### 4.3.2.rust-registry-tests

- **Repo:** rxet
- **Files in scope (must edit):** `src/rust/src/lib.rs`
- **Files in scope (can create):** `src/rust/src/registry.rs`, `src/rust/src/tests.rs`
- **Depends on:** `4.2.1` (lib.rs stable)
- **Reference implementation:** `lazy_static` `CLIENTS` pattern in `lib.rs` — the new `Registry<T>` is the same contract, generic over the stored type.

**Spec**
1. Create `src/rust/src/registry.rs` with no R or extendr dependency:
   - `pub struct Registry<T> { inner: std::sync::Mutex<std::collections::HashMap<String, std::sync::Arc<T>>> }`
   - `pub fn new() -> Self`, `pub fn insert(&self, key: String, value: T)`, `pub fn acquire(&self, key: &str) -> Option<std::sync::Arc<T>>` (lock, clone the `Arc`, return; guard drops before return), `pub fn remove(&self, key: &str) -> Option<std::sync::Arc<T>>`.
   - Poisoned-lock handling: never map a poisoned lock to `None` (that would look like "unknown handle"). `Registry` methods call `.lock().expect("client registry poisoned")`; the panic is caught by `safe_exec` at the FFI boundary and surfaces as `Rust Panic: client registry poisoned`. Document this in one comment line.
2. In `lib.rs`, replace `CLIENTS: Mutex<HashMap<…>>` with `static CLIENTS: Lazy<Registry<XetClient>>` (or `lazy_static!` retaining its current form) holding `Registry<XetClient>`. Update `acquire_client` (from 4.1.2) to use `Registry::acquire`, and `xet_init_client`/`xet_close_client` to use `insert`/`remove`. Keep every error string unchanged.
3. Add `#[cfg(test)] mod tests;` near the top of `lib.rs`. `src/rust/src/tests.rs` holds the tests, which exercise `Registry<u32>` (not `XetClient`, which needs a live session):
   - `acquire_returns_clone_and_releases_lock`: insert key→7; `acquire` returns `Some(Arc<7>)`; then, in a spawned thread that holds an `Arc` clone, `remove(key)` completes within 1 second (`recv_timeout`), proving the registry lock is not held while an `Arc` is in use.
   - `acquire_unknown_key_is_none`.
   - `remove_twice_second_is_none`.
   - `insert_then_remove_then_acquire_none`.
4. Run `cargo test` (see Acceptance). If the test binary fails to link against R/extendr symbols (H6), STOP: report the exact linker error and the output of `cargo test --lib tests::` and do not work around it.

**Anchors**
- `lib.rs` `lazy_static!` (`CLIENTS`), `fn acquire_client` (from 4.1.2), `fn xet_init_client` insert site, `fn xet_close_client` remove site.

**Constraints (do not touch)**
- `src/rust/Cargo.toml`, `src/rust/Cargo.lock`, `R/**`, `tests/**`, `man/**`.
- No new crates (not even `parking_lot`). No `#[cfg(feature)]` gates.
- Do not change extendr signatures or the module list.

**Acceptance**
```bash
cd src/rust && cargo check 2>&1 | tail -3 && cargo test --lib tests:: 2>&1 | tail -15
```
`cargo check` exit 0. `cargo test` exit 0 with the four named tests passing (report `N passed`). If link fails, the task is reported as BLOCKED with the linker output, not as done.

---

### 4.4.1.docs-rd-sync

- **Repo:** rxet
- **Files in scope (must edit):** `man/*.Rd` (regenerated), `README.Rmd`, `README.md` (only sentences that describe endpoint rules, size limits, download behavior, or close semantics)
- **Files in scope (can create):** none
- **Depends on:** `4.3.1`, `4.3.2`
- **Reference implementation:** the Phase 2 roxygen/README pattern (`planning/EXECUTION_PLAN_2.md`, task `2.1.1`).

**Spec**
1. Run `Rscript -e 'roxygen2::roxygenise()'` once. Expect `man/*.Rd` changes for the roxygen text added in 4.1.1 and 4.2.2. Expect `NAMESPACE` unchanged. If `DESCRIPTION` changes beyond `RoxygenNote`, revert the extra lines with `git checkout -p` or `git diff` review (do not commit unrelated drift).
2. Add the D4 close-semantics sentence to `xet_client_close` help (`R/client.R` roxygen) — this is a roxygen edit in a file not owned by 4.1.1; allowed here because 4.1.1 is complete. Then re-run `roxygen2::roxygenise()`.
3. `README.Rmd`: find any sentence stating an endpoint rule, a size limit, download behavior, or close behavior (`grep -n "http\|size\|download\|close" README.Rmd`). Update only those sentences to match D2, D3, D4, D6. Mirror the same change into `README.md` by hand (do not re-render: Phase 3 kept `.md` edits minimal). Do not change the 13-function list or experimental labels (ADR 0001).
4. Do not change examples' function names or signatures.

**Anchors**
- `README.Rmd` section "v0.1 status" / install / usage (grep for `http`, `size`, `close`, `download`).
- `man/xet_download_file.Rd`, `man/xet_stream_raw.Rd`, `man/xet_client_new.Rd`, `man/xet_client_close.Rd`.

**Constraints (do not touch)**
- `src/**`, `tests/**`, `R/**` except the one roxygen block in `R/client.R` for `xet_client_close` (step 2).
- No README claim about Windows atomic behavior (H4).

**Acceptance**
```bash
Rscript -e 'roxygen2::roxygenise()' && git diff --quiet -- NAMESPACE && grep -q "temporary" man/xet_download_file.Rd && grep -q "2 GiB\|2147483647" man/xet_stream_raw.Rd && grep -q "https://" man/xet_client_new.Rd && Rscript -e 'devtools::test(filter = "input-validation|phase4-lifecycle", reporter = "summary", stop_on_failure = TRUE)'
```
Exit 0.

## Final phase gate (orchestrator, serial, after wave 4)

Not a task; the orchestrator runs this and records it in `STATE_4.md`.

1. `cd src/rust && cargo check` and `cargo test --lib tests::` → exit 0.
2. `R CMD INSTALL .` → exit 0.
3. Full suite serially: `Rscript -e 'devtools::test(reporter = "summary", stop_on_failure = TRUE)'` → exit 0, `FAIL 0`.
4. From a clean archive (`git archive HEAD | tar -x -C <scratch>`, where `<scratch>` is an empty directory outside the repo, such as the session scratchpad): `R CMD build .` then `_R_CHECK_FORCE_SUGGESTS_=false R CMD check --no-manual rxet_0.1.0.tar.gz` → `Status: OK` with no new ERROR/WARNING/NOTE vs. the Phase 3 baseline.
5. Grep the source tree: no `CLIENTS.lock()` held across a `.Call`/blocking call (manual review of each extendr function; record the result), no `Vec::with_capacity` on user sizes, no `.part` leftovers in tests.
6. Record residual gaps: J1 (lock call sites by review), J2 (panic/FFI review-only), Windows `file.rename` (H4), success-path network behavior (Phase 5).

## Cross-task notes

- The R cap (4.1.1, D2) and the Rust cap (4.2.1, D2) must use the same literal `2147483647`. Workers verify by grep at the end of 4.2.1.
- Error wording: the new R and Rust messages for the cap and finiteness rules are intentionally identical. Do not reword one side.
- Existing test patterns in `test-input-validation.R` (`"nchar.*handle"`, `"file_size"`) must survive 4.1.1; 4.2.1 must not change messages that R tests match.
