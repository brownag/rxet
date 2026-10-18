---
id: "0004"
title: "Remove three public functions, move client configuration onto the client, and drop an unused raster argument for v0.2.0"
status: "Accepted"
date: 2026-10-17
authors:
  - "Andrew G. Brown"
supersedes: null
superseded_by: null
partially_supersedes: "0001"
source_context: "EXECUTION_PLAN_10"
---

# 4. Remove Three Public Functions, Move Client Configuration onto the Client, and Drop an Unused Raster Argument for v0.2.0

## Context and Problem Statement

ADR 0001 kept all 13 exports at v0.1 because removing public functions is a
breaking change and the functions were only provisional. v0.2.0 is the first
release where breaking changes are allowed. A review of the 0.1.1 surface found
four places where the API is misleading, redundant, or fights the package's own
design rules:

- `read_xet_parquet_stream()` says "stream", but it downloads the whole file,
  writes a temporary `.parquet` file, and reads that. It duplicates
  `read_xet_parquet()`, which reads from memory without a temporary file.
- `xet_close_connection()` wraps base `close()`. Its only added behavior is a
  no-op on an already-closed connection.
- `xet_config_environment()` sets process-wide `HF_XET_*` environment variables.
  AGENTS.md states "No global state; each client is independent", and the
  client reads that environment only when it is created.
- `read_xet_raster(ext = )` crops after the whole raster is loaded. The
  documentation already shows `terra::crop()`, and the argument sits before
  `...`, so positional calls break in any case.

Two related facts were checked before deciding:

- hf-xet 1.7.0 accepts per-session configuration. `XetConfig::new()` applies
  the `HF_XET_*` environment, `XetConfig::with_config(path, value)` sets a field
  by dotted path (for example `client.read_timeout`, `chunk_cache.size_bytes`),
  `XetConfig::with_high_performance()` applies the high-performance preset, and
  `XetSessionBuilder::new_with_config()` takes the result.
- The existing R help for `high_perf` says the mode "disables chunk cache".
  hf-xet's `with_high_performance()` does not change `chunk_cache`. It raises
  concurrency and download buffer sizes. The R help is wrong, and this ADR
  corrects it.

## Decision Drivers

* Remove misleading names before the 0.2.0 release, not after.
* Keep configuration scoped to a client, as AGENTS.md requires.
* Keep the existing `HF_XET_*` environment working for users who set it
  directly, because hf-xet still reads it.
* Do not change anything that is not on this list.

## Considered Options

1. Keep all 13 exports and deprecate the three functions for one release.
2. Remove the three functions in 0.2.0 without a deprecation period.
3. Keep `xet_config_environment()` and add per-client arguments beside it.

## Decision Outcome

Chosen option: **2, remove the three functions in 0.2.0**, because this release
is already declared breaking, the functions are Experimental, and a deprecation
cycle would carry three misleading names into a second release. Option 3 keeps
the global-state design that AGENTS.md rules out.

### Public API changes

| Change | Replacement |
|---|---|
| Remove `read_xet_parquet_stream()` | `read_xet_parquet()` |
| Remove `xet_close_connection()` | base `close()` |
| Remove `xet_config_environment()` | Arguments on `xet_client_new()` (below) |
| Remove the `ext` argument of `read_xet_raster()` | `terra::crop()` on the result |
| Add `xet_client_new(endpoint, token, timeout_sec = NULL, cache_bytes = NULL, high_perf = FALSE)` | Optional, so existing calls still work |
| Add `ext = NULL` to `read_xet_vector()` | Sets the temporary file's extension |

Export count: 13 becomes 10.

### Configuration rules

- The client starts from `XetConfig::new()`, so `HF_XET_*` environment values
  still apply as hf-xet defines them.
- `timeout_sec` sets `client.read_timeout` (seconds).
- `cache_bytes` sets `chunk_cache.size_bytes`. `0` disables the cache.
- `high_perf = TRUE` applies `with_high_performance()`. This preset is applied
  after the environment, so for the fields it sets, it overrides an
  `HF_XET_*` value. This ordering must be stated in the help text.
- `NULL` for `timeout_sec` or `cache_bytes` means "leave hf-xet's value
  alone", so the environment or hf-xet's default applies.
- Explicit R arguments override the environment for the fields they set.

### Documentation correction

The `high_perf` help text drops "disabling chunk cache". It describes what the
preset changes: concurrency and download buffer sizes.

### Other changes in this release

- `read_xet_vector(ext = NULL)` names the temporary file with the extension.
  Earlier planning called this a "format" argument. The name changes to `ext`
  because the value is a file extension, not a GDAL driver name.
- `DESCRIPTION` and `src/rust/Cargo.toml` both state `0.2.0`.
- Remove the six unused helpers in `R/utils.R` and their tests.
- Remove the Rust crates that nothing references: `tokio`, `byteorder`, `lru`,
  `crossbeam-channel`, `futures-util`.

### Consequences

* **Positive:** Each public name says what it does. Configuration is per client.
  The Rust side has fewer dependencies.
* **Negative:** Code that calls the three removed functions breaks. Each one
  has a stated replacement, listed in `NEWS.md`.
* **Neutral:** `high_perf = TRUE` can override an explicit `HF_XET_*` setting
  for the fields the preset sets. This is hf-xet's own precedence, and the help
  text says so.

### Not decided here

Range-backed connections, multi-file vector formats, vendored crates, promoting
any Experimental API to Supported, and a client finalizer are out of this ADR.
Each needs its own decision and evidence.

## Validation & Compliance

* `NAMESPACE` exports exactly the 10 functions listed above, with no others.
* `xet_client_new()` with no optional arguments produces the same client as
  0.1.1 (test: no `XetConfig` field changes from its environment value).
* `high_perf` help text contains no claim that the cache is disabled.
* Each removed function has a line in `NEWS.md` under "Breaking changes".
* ADR 0001 is updated to point here, because its "exactly 13 exports" rule no
  longer holds.
