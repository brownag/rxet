# EXECUTION PLAN 11: validation module and whole-download reader module

Source: `planning/ARCHITECTURE_REVIEW.md` candidates #1 and #2 (and the Rust converter merge from #2). Prompt: `planning/PROMPT_TEMPLATE_11.md`. State: `planning/STATE_11.md`.

## Goal & Scope

Give request validation one home, and give the three whole-download readers one shared module. Validation rules (handle, hash, whole-number size, byte range, the 2 GiB in-memory cap) currently live in about 7 copies that have drifted. The three readers (`read_xet_parquet`, `read_xet_raster`, `read_xet_vector`) each repeat the optional-package check, argument validation and connection or temp-file lifecycle.

**In scope**
- New internal `R/validate.R` (validation module) and `R/whole_download.R` (whole-download module).
- Migrate `xet_download_file`, `xet_stream_raw`, `xet_stream_range`, `xet_open_connection`, `xet_upload_file` and the three readers onto them.
- Merge the Rust converters `to_whole_bytes` and `whole_u64` into one.
- Tests, NEWS, AGENTS.md architecture notes.

**Out of scope (deferred)**
- Rust transfer-module split (review candidate #3).
- Classed client handle (review candidate #4).
- `xet_client_new()` argument validation (`R/client.R`): endpoint and token rules are not request validation and have their own tests.
- Any change to exported function names, arguments or return values.
- Live suite.

**Verbatim user constraints**
- "we will start with the whole-download reader module"
- "a wave-orchestration plan that resolves request validation issues"

## Decision log (dated)

| # | Decision | Source |
|---|---|---|
| D1 | Shared validation uses `file_size >= 0` everywhere. An empty file fails inside the format reader, not at the argument check. This relaxes the readers (previously `> 0`); download, stream and connection are unchanged. | User, 2026-10-22 |
| D2 | Include a Rust task merging `to_whole_bytes` and `whole_u64`, in its own wave-1 slot. | User, 2026-10-22 |
| D3 | Two files: `R/validate.R` and `R/whole_download.R`. | User, 2026-10-22 |
| D4 | Validation raises clear custom messages (no `stopifnot` text). Tests matching `nchar.*handle` are updated. | User, 2026-10-22 |
| D5 | At most 2 concurrent workers. Small model for workers; escalate to a frontier model after two failures on a task. Suites run serially; each wave ends with `devtools::test()`. | User, 2026-10-22 |
| D6 | ADR check: no accepted ADR is contradicted. ADR 0001 (13-function API) and 0004 are untouched because the exported interface does not change. The D1 relaxation for readers is recorded in NEWS. | Orchestrator |

## Interface of the new modules (fixed by this plan; workers must not invent others)

`R/validate.R` (internal, not exported, no `@export`; use `@noRd`):
- `check_handle(handle)`: non-empty length-1 character, else `stop("`handle` must be a non-empty string", call. = FALSE)`.
- `check_hash(file_hash, arg = "file_hash")`: same rule; `arg` names the argument (`hash` for `xet_download_file`).
- `check_file_size(file_size, in_memory = FALSE)`: numeric length 1, finite whole number, `>= 0`. If `in_memory`, also error above `.Machine$integer.max` with the single 2 GiB message: `"in-memory read of %.0f bytes exceeds the 2 GiB limit (2147483647 bytes); use xet_download_file() for larger files"`.
- `check_range(start_byte, end_byte, file_size)`: numeric length 1 each, `start_byte >= 0`, `end_byte > start_byte`, `end_byte <= file_size`, and `end_byte - start_byte <= .Machine$integer.max` with the range message `"in-memory requested range of %.0f bytes exceeds the 2 GiB limit (2147483647 bytes); use xet_download_file() for larger files"`.
- `check_string(x, arg)`: non-NA length-1 character (used for `dest_path`, `src_path`).
- `require_pkg(pkg, fn)`: `requireNamespace(pkg, quietly = TRUE)` or `stop("The '<pkg>' package is required for <fn>(). Install it with: install.packages('<pkg>')", call. = FALSE)`.

`R/whole_download.R` (internal):
- `whole_download(handle, file_hash, file_size, reader, ext = NULL, via = c("connection", "file"))`. `"connection"`: open via `xet_open_connection()`, call `reader(conn)`, and close the connection if `reader` errors (arrow's `read_parquet` closes it on success; closing an already-closed rawConnection must not error, wrap in `tryCatch`). `"file"`: open, `readBin`, write bytes to `tempfile(fileext = ...)` (extension from `ext`), call `reader(path)`, always `unlink` the temp file and close the connection via `on.exit`.

## Waves

| Wave | Tasks | Files (pairwise disjoint within the wave) | Notes |
|---|---|---|---|
| 1 | T1, T2 | T1: `R/validate.R`, `tests/testthat/test-validate.R`. T2: `src/rust/src/lib.rs`, `src/rust/src/tests.rs` | T1 R-only, T2 Rust-only. Separate worktrees if both run at once. |
| 2 | T3, T4 | T3: `R/download.R`, `R/stream.R`, `R/connection.R`, `R/upload.R`, `tests/testthat/test-input-validation.R`. T4: `R/whole_download.R`, `tests/testthat/test-whole-download.R` | Depends on T1. |
| 3 | T5 | `R/arrow.R`, `R/spatial.R`, `tests/testthat/test-arrow-spatial.R` | Depends on T3, T4. |
| 4 | T6 | `NEWS.md`, `AGENTS.md`, `README.Rmd` (only if it names a changed rule) | Depends on T5. Orchestrator then regenerates docs and runs the full gate. |

Hazards (recon):
- `tests/testthat/test-input-validation.R` matches message text in many places (`nchar.*handle`, `file_size`, `2 GiB limit`). Only T3 edits it; T5 must not.
- `tests/testthat/test-token-canary.R` checks tokens never appear in errors on every offline public path. Validation messages must never include argument values for `handle`. Run it in every R task.
- Both R and Rust tests share `src/rust/target`. Never run two builds at once; run T1 and T2 in separate worktrees, with Rust tests only in T2 and no `devtools::test` there.
- `devtools::test()` loads the compiled extension. R tasks that touch no Rust may use the already built `.so`.
- `R/extendr-wrappers.R` and `NAMESPACE` are untouched (new functions are internal; `exportPattern("^xet_")` must not match them, hence names without the `xet_` prefix).

## Task specs

### T1: validation module
- **id** T1. **repo** rxet. **depends-on** none.
- **Files in scope:** `R/validate.R` (new), `tests/testthat/test-validate.R` (new).
- **Spec:** implement exactly the interface above. Accept `file_size = 0`. Messages never echo `handle` or token-like values; `file_hash` and sizes may be echoed. Tests call the functions through `rxet:::`, covering: empty/NA/non-character/length-2 handle and hash; size `0` ok, `-1`, `1.5`, `Inf`, `NaN`, `"big"`, `2^31` with `in_memory = TRUE` (error) and `FALSE` (ok); range with `end <= start`, `end > file_size`, over-2-GiB range; `require_pkg("definitelynotapkg", "f")` error text; `check_string`.
- **Constraints:** do not touch any other file. Do not call `.Call`.
- **Grep anchors:** `R/stream.R:40-55` and `R/download.R:31-36` for current rules; `R/spatial.R:72` for the pkg check.
- **Acceptance:** `Rscript -e 'devtools::test(filter = "validate")'` passes. Commit: `refactor(validate): add internal request validation module`.

### T2: merge the Rust converters
- **id** T2. **repo** rxet. **depends-on** none.
- **Files in scope:** `src/rust/src/lib.rs`, `src/rust/src/tests.rs`.
- **Spec:** replace `to_whole_bytes` (line 22) and `whole_u64` (line 66) by one `whole_bytes(field, v)` returning `u64`, rejecting non-finite, negative, fractional and `>= 2^64`, with one message: `"{field} must be a finite non-negative whole number"`. Update all call sites (`lib.rs` 90, 96, 159, 218-220, 324). Keep `tests.rs` coverage: adapt existing converter tests to the new name and message; add a case for `2^64` and `-1`. Check no R test matches the old message (`grep -rn "whole number of bytes" tests R`); if one does, STOP and report.
- **Constraints:** no behavior change other than the message text. Do not touch `R/`.
- **Grep anchors:** `fn to_whole_bytes`, `fn whole_u64`, `to_whole_bytes(`, `whole_u64(`.
- **Acceptance:** `cd src/rust && cargo check --tests && cargo test --lib`. Commit: `refactor(rust): merge duplicate whole-number converters`.

### T3: migrate the transfer functions
- **id** T3. **repo** rxet. **depends-on** T1.
- **Files in scope:** `R/download.R`, `R/stream.R`, `R/connection.R`, `R/upload.R`, `tests/testthat/test-input-validation.R`.
- **Spec:** replace every `stopifnot` / hand-written size and range check with the T1 functions. `xet_download_file`: `check_handle`, `check_hash(hash, "hash")`, `check_file_size`, `check_string(dest_path, "dest_path")`; keep the directory and parent-directory checks and the `.part` logic unchanged. `xet_stream_raw`: `check_file_size(file_size, in_memory = TRUE)`. `xet_stream_range`: `check_file_size` plus `check_range`. `xet_open_connection`: `check_file_size(file_size, in_memory = TRUE)` (it calls `xet_stream_raw`; keep one check, not two, if redundant, but the error must still arrive before any network call). `xet_upload_file`: `check_handle`, `check_string`. Update the tests whose regexes matched `stopifnot` text (`nchar.*handle` -> `handle`) and any size-message expectations. Keep the roxygen comments untouched.
- **Constraints:** no signature, return value or roxygen change. Do not edit `R/arrow.R`, `R/spatial.R`.
- **Grep anchors:** `stopifnot(`, `integer.max`, `2147483647`, `nchar.*handle`.
- **Acceptance:** `Rscript -e 'devtools::test(filter = "input-validation|token-canary|connection|streaming")'` passes. Commit: `refactor(validate): use shared validation in transfer functions`.

### T4: whole-download module
- **id** T4. **repo** rxet. **depends-on** T1.
- **Files in scope:** `R/whole_download.R` (new), `tests/testthat/test-whole-download.R` (new).
- **Spec:** implement `whole_download()` as specified above. It validates with the T1 functions (`check_handle`, `check_hash`, `check_file_size(in_memory = TRUE)`). Tests use a stub: temporarily replace `xet_open_connection` with `testthat::local_mocked_bindings(xet_open_connection = function(...) rawConnection(as.raw(1:5), "r"), .package = "rxet")` and assert: reader receives the connection (mode `"connection"`); reader error closes the connection and re-raises; `"file"` mode passes a path whose file exists during the call, has the bytes, honors `ext`, and is gone afterward both on success and on reader error; invalid arguments error before the stub is called.
- **Constraints:** do not edit `R/connection.R`. Never write a temp file outside `tempfile()`.
- **Grep anchors:** `R/spatial.R:80-95` and `R/arrow.R:80-90` for the current lifecycle.
- **Acceptance:** `Rscript -e 'devtools::test(filter = "whole-download")'` passes. Commit: `refactor(reader): add internal whole-download module`.

### T5: migrate the three readers
- **id** T5. **repo** rxet. **depends-on** T3, T4.
- **Files in scope:** `R/arrow.R`, `R/spatial.R`, `tests/testthat/test-arrow-spatial.R`.
- **Spec:** each reader becomes `require_pkg(...)` plus one `whole_download()` call. `read_xet_parquet`: `via = "connection"`, `reader = function(conn) arrow::read_parquet(conn, ...)`. `read_xet_raster`: `via = "file"`, reader keeps `terra::unwrap(terra::wrap(terra::rast(path, ...)))`. `read_xet_vector`: `via = "file"`, `ext = ext`, `reader = function(path) sf::st_read(path, ...)`; keep the existing `ext` argument check (`grepl("^[A-Za-z0-9]+$")`) via `check_string`-style custom message. File size `0` now reaches the reader (D1): add one test per reader that `file_size = 0` against a stubbed empty stream yields the reader's own error, not an argument error. Keep all roxygen unchanged.
- **Constraints:** no change to function signatures, `...` handling or return values. Do not edit `test-input-validation.R`.
- **Grep anchors:** `requireNamespace`, `stopifnot(`, `tempfile(`, `on.exit`.
- **Acceptance:** `Rscript -e 'devtools::test(filter = "arrow-spatial|token-canary")'` passes (arrow, terra, sf installed). Commit: `refactor(reader): route readers through whole-download module`.

### T6: docs
- **id** T6. **repo** rxet. **depends-on** T5.
- **Files in scope:** `NEWS.md`, `AGENTS.md`, `README.Rmd` (only if it states `file_size > 0` for readers; check with grep).
- **Spec:** NEWS: add an entry under the development version noting the readers now accept `file_size = 0` at the argument check (they fail in the reader instead) and that rust converter error messages changed. AGENTS.md: in "Codebase Layout" list `R/validate.R` and `R/whole_download.R` with one line each; in "Optional integrations" nothing else changes. Do not hand-edit `man/` or `NAMESPACE`.
- **Acceptance:** `git diff --stat` shows only the files in scope. Commit: `docs: record validation and whole-download modules`.

## Wave gates (orchestrator)

After every wave: `R CMD INSTALL .`, then `RXET_LOCAL_CAS_SERVER=$HOME/.cargo/bin/local_cas_server Rscript -e 'devtools::test()'`. Compare against the STATE_11 baseline. After wave 4 also `Rscript -e 'devtools::document()'` and confirm `git diff NAMESPACE` is empty.

## Review notes (plan self-review)

- Spec axis: both user lines map to T1-T6; D1-D5 honored; deferrals explicit.
- Standards axis: T1/T2 and T3/T4 file sets are pairwise disjoint; T3 and T4 both call into T1 only. Judgment call: T3 touches four R files, which is the upper size for one small-model task; split if the worker plan exceeds 12 steps.
