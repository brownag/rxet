# EXECUTION PLAN 14: resolve PR #3 review comments (Copilot and CodeRabbit)

Source: review threads on https://github.com/brownag/rxet/pull/3 (branch `v040`, base `main`). Drafted 2026-11-11 by plan-wave. Status: APPROVED by user 2026-11-11 (J1-J7 accepted as drafted). Not yet executed. Start with wave 1.

## Goal & Scope

**Goal:** resolve every review finding on PR #3 that the current code confirms, as local commits on `v040`. Nothing is pushed and no GitHub thread is touched.

**In scope (all 17 findings, mapped in the table below)**
- Rust: `WindowedReader` shutdown is synchronized with in-flight reads (Copilot, high).
- C: `src/connection.c` read path returns whole items at EOF, protects its R call arguments, and `seek()` returns the previous position.
- R raster lifetime: `read_xet_raster()` no longer returns an object whose file was deleted. Adds an optional `dest_path` argument (see J1).
- R docs: qualify the "unselected columns are never transferred" claims; document `rawConnection()` peak memory.
- README (`README.Rmd` and `README.md`): close placement, Parquet wording, API table, experimental count, and the stale "whole file" claims.
- `tools/README.md`: describe the extended benchmark as synthetic.
- Regenerate `man/*.Rd` from the roxygen changes.

**Out of scope**
- Pushing `v040`, replying to or resolving PR threads, and any change to PR metadata (decision D4).
- CodeRabbit pre-merge check "Docstring Coverage" (deferred; it is a repo-wide coverage threshold, not a review comment).
- CodeRabbit's "Fix comments" checkbox (a prompt to the bot, not a finding).
- Rewriting `tools/benchmark-extended.R` to time a real sync (D3 chose docs).
- Any change to ADRs 0005-0008, `NAMESPACE` exports, or `R/extendr-wrappers.R`.
- A finalizer that deletes the no-path raster temp file (dropped, see D2).

**Verbatim constraints (from the user's request and PR review text)**
- "resolutions for https://github.com/brownag/rxet/pull/3 code review comments from copilot and coderabbit"
- User answer on the raster: "i'd like to have the user be able to specify a path and return a lazy referenbce, in which case it would not be deleted. otherwise we would (try) to materilize values but that could be inefficient or impossible for some rasters on some machines, so it seems necessary to keep file alive in some form"
- User answer on cleanup: "the finalizer sounds like an interesting idea but i worry it would be brittle or unexpected for R users"
- User answer on GitHub: "Nothing on GitHub (Recommended)"

## Finding map (all 17 verified against current code on 2026-11-11)

| # | Source | Location at HEAD `afb6274` | Verified | Task |
|---|---|---|---|---|
| F1 | Copilot, high | `src/rust/src/lib.rs` `rxet_close_reader` calls `reader.source().finish()` with no cache lock; `WindowedReader::read_at` holds `cache` across `fetch` | yes (`Registry::acquire` returns an `Arc` clone) | 14.1.1 |
| F2 | Copilot, medium | `src/connection.c:35` clamps `total` to the remaining bytes, returns `total / size`, and advances `pos` by the unreturned partial item | yes | 14.1.2 |
| F3 | Copilot + CodeRabbit | `R/arrow.R:5` "unselected columns are never transferred" (also `R/arrow.R:25-26` and `README.Rmd:60`) | yes: readahead is at least 1 MiB | 14.2.1, 14.2.2 |
| F4 | Copilot | `README.Rmd` quick start closes `client` before the stream and file-reader examples | yes | 14.2.2 |
| F5 | Copilot | `README.md` same close-order issue | yes | 14.2.2 |
| F6 | Copilot | `README.md` "col_select and filters apply after the download" | yes | 14.2.2 |
| F7 | Copilot | `README.md` "read_xet_parquet() … all three read the whole file" | yes | 14.2.2 |
| F8 | Copilot | `README.md` API table omits `xet_open_stream_connection()`; "eight are Experimental" should be nine | yes (support table `README.md:200-202` also omits it) | 14.2.2 |
| F9 | Copilot | `tools/README.md` describes `benchmark-extended.R` as timing "the same run"; the script uses `rnorm()` | yes | 14.1.4 |
| F10 | CodeRabbit | duplicate of F3 (`R/arrow.R` line 5) | yes | 14.2.1 |
| F11 | CodeRabbit | `R/connection.R:21-22`: `rawConnection()` copies the input vector, so peak RAM is about twice the file size | yes: R help for `rawConnection`: "the raw vector is copied at the time the connection object is created" | 14.2.1 |
| F12 | CodeRabbit | `README.md` must be regenerated from `README.Rmd` | yes | 14.2.2 |
| F13 | CodeRabbit | duplicate of F4 (`README.Rmd` line 55) | yes | 14.2.2 |
| F14 | CodeRabbit, major | `src/connection.c:37`: `Rf_ScalarReal` results are unprotected while `Rf_lang3` allocates | yes | 14.1.2 |
| F15 | CodeRabbit | `src/connection.c:72`: `rxet_conn_seek` returns the destination; R's `seek()` returns the position before the move. Offline assertions at `test-connection-offline.R:34,37,40,50,61-62,71` and stream assertions at `test-stream-connection.R:27,28,32,36,48-49` encode the wrong value | yes | 14.1.2 |
| F16 | CodeRabbit, major, outside diff | `R/spatial.R:64` `terra::wrap()` keeps a file reference, and `R/whole_download.R` deletes the temp file on exit | yes (see J1, J5) | 14.1.3 |
| F17 | CodeRabbit, nitpick | `tests/testthat/test-whole-download.R:66-70` mocks `xet_open_connection` but `.rxet_whole_download()` defaults to `via = "stream"`, which calls `xet_open_stream_connection` | yes | 14.1.3 |

## Wave table

Max 4 concurrent workers. Each worker runs in its own git worktree created from `v040` HEAD (hazard H1). Tasks within a wave touch disjoint files. Waves run in order.

| Wave | Task | Repo | Depends on | Files (must edit) | Model |
|---|---|---|---|---|---|
| 1 | 14.1.1 Rust: serialize reader shutdown with reads | rxet | none | `src/rust/src/reader.rs`, `src/rust/src/lib.rs`, `src/rust/src/tests.rs` | sonnet |
| 1 | 14.1.2 C: EOF whole items, PROTECT, seek previous position | rxet | none | `src/connection.c`, `tests/testthat/test-connection-offline.R`, `tests/testthat/test-stream-connection.R` | sonnet |
| 1 | 14.1.3 R: raster lifetime, `dest_path`, whole-download test mock | rxet | none | `R/spatial.R`, `R/whole_download.R`, `tests/testthat/test-arrow-spatial.R`, `tests/testthat/test-whole-download.R` | sonnet |
| 1 | 14.1.4 Docs: benchmark wording | rxet | none | `tools/README.md` | haiku |
| 2 | 14.2.1 R roxygen: qualify claims, `rawConnection` memory | rxet | none (wording feeds 14.2.2) | `R/arrow.R`, `R/connection.R` | haiku |
| 2 | 14.2.2 README and NEWS | rxet | 14.1.3, 14.2.1 | `README.Rmd`, `README.md`, `NEWS.md` | haiku |
| 3 | 14.3.1 Regenerate man pages | rxet | 14.1.3, 14.2.1 | `man/read_xet_raster.Rd`, `man/read_xet_parquet.Rd`, `man/xet_open_connection.Rd` (generated) | haiku |

**Disjointness check (grep-verified):** `R/whole_download.R` is read by `R/arrow.R` at runtime, but only 14.1.3 edits it. `R/arrow.R` is edited only by 14.2.1. `test-whole-download.R` and `test-arrow-spatial.R` are edited only by 14.1.3. `README.md` and `README.Rmd` are edited only by 14.2.2. `man/*.Rd` are edited only by 14.3.1. No helper file under `tests/testthat/helper-*.R` is edited.

**Wave-end gate (orchestrator, serial, after wave 3):** see the Acceptance section.

## Decision log

- **D1 (2026-11-11), raster lifetime:** `read_xet_raster()` does not materialize values. With `dest_path` given, the file is written there and the returned `SpatRaster` references it lazily, and the file is never deleted. Without `dest_path`, the temp file is kept alive. *Why:* the user says materializing can be inefficient or impossible on some machines.
- **D2 (2026-11-11), no-path cleanup (judgment, see J2):** the no-path temp file stays in R's `tempdir()` and is not deleted by the package. The finalizer option is dropped. *Why:* the user worries a finalizer would be "brittle or unexpected for R users". The user did not pick between the two cleanup options; this is plan-wave's reading of that concern. Approval confirms it.
- **D3 (2026-11-11), benchmark:** docs-only. `tools/README.md` says the extended benchmark produces a synthetic estimate. The script is unchanged. *Why:* user answer "Fix the docs (Recommended)".
- **D4 (2026-11-11), GitHub:** no outward action. Commits stay local on `v040`. Replying to or resolving threads is the user's call. *Why:* user answer "Nothing on GitHub (Recommended)".
- **D5 (2026-11-11), CAS server:** install `local_cas_server` as pre-wave step P0 so the local-CAS seek and stream tests run. *Why:* user answer "Install it (Recommended)". Command: `cargo install xet-client --version 1.7.0 --features simulation --bin local_cas_server --locked`.
- **D6 (2026-11-11), workers:** haiku for docs and tests, sonnet for Rust, C and the raster lifetime change, with escalation per the wave-orchestration ladder. Max 4 concurrent. Worktrees come from `v040` HEAD. *Why:* user answer "Haiku workers, Sonnet escalation (Recommended)".
- **D7 (2026-11-11), scope:** all 17 findings are in scope. Every one was verified against the code (see the finding map). None was found invalid.
- **D8 (2026-11-11), commits:** one local commit per task on `v040`, conventional format, no push. The orchestrator makes the commits. *Why:* wave-orchestration's commit rule and `git-workflow-standards`.
- **D9 (2026-11-11), seek semantics:** `seek()` returns the position before the move (matches R's `seek` help: "returns the current position (before any move)"). The nine assertions that expected the destination are updated.

## Judgment calls for approval (J)

- **J1 (new argument name):** `read_xet_raster(handle, file_hash, file_size, dest_path = NULL, ...)`. The name matches `xet_download_file(dest_path = )`. This adds public API surface, so `NEWS.md` gets a line. Alternative: `path`.
- **J2 (no-path cleanup):** the no-path temp file is left in `tempdir()`. It is never deleted by the package. Disk use grows with each call until the session ends. Alternative: a finalizer (dropped on your concern). Approve or switch.
- **J3 (partial item at EOF):** round the clamped count down to whole items and advance `pos` only by bytes returned. An unaligned tail is not returned, so `readBin()` sees end of file. Alternative: raise an error on an unaligned EOF read. Rounding matches how R's file connections behave.
- **J4 (finish under lock):** `WindowedReader::finish()` takes the cache lock before `source.finish()`. Close blocks until an in-flight fetch returns. Alternative: a closed flag checked by `read_at`. The lock is simpler and matches the existing "lock held across fetch" design.
- **J5 (drop wrap and unwrap):** `read_xet_raster()` drops the `terra::wrap()`/`terra::unwrap()` round trip and returns `terra::rast(path)`. Keeping them would still reference the file. Approve or keep them.
- **J6 (seek test update):** nine assertions change from destination to previous position. Destination is checked with a following `seek(conn, 0, "current")`, matching CodeRabbit's suggestion.
- **J7 (README.md):** hand-mirror the `README.Rmd` edits into `README.md`. Do not re-knit the whole file, so unrelated rendering noise stays out of the diff. The worker reports if a knit would be cleaner.

## Hazard notes (from recon)

- **H1 worktrees:** create each worktree manually from `v040` HEAD (`afb6274`). Not from `main` (`34b8742`) and not from `v030` (plan 13's base). Plan 12 lost work to a `main` base.
- **H2 extendr wrappers:** no task changes an `#[extendr]` signature. `R/extendr-wrappers.R` must be unchanged after wave 1. Check with `git diff --stat -- R/extendr-wrappers.R`.
- **H3 `src/connection.c` is guarded by `R >= 4.3.0`.** Keep the stub consistent if one exists. Use only `R_new_custom_connection` and the documented `Rconnection` fields (R_ext/Connections.h is not stable, ADR 0006).
- **H4 `src/connection.c` `destroy` runs at GC:** do not call R code from `destroy`. Release only in `close` (ADR 0007).
- **H5 `src/rust/src/lib.rs` is 588 lines.** Use anchors: `fn rxet_close_reader`, `fn rxet_reader_read`, `static ref READERS` / `READERS.insert`. Do not read the whole file.
- **H6 test helper:** `stub_conn` is defined at the top of `tests/testthat/test-whole-download.R` and is local to that file.
- **H7 offline tests** (`test-connection-offline.R`, `test-whole-download.R`) must run with `RXET_LOCAL_CAS_SERVER` unset. Local-CAS tests (`test-stream-connection.R`, `test-arrow-spatial.R` raster round trips) need it set.
- **H8 `read_xet_raster` now has a `dest_path` argument.** The `...` pass-through to `terra::rast()` is unchanged.
- **H9 README support table:** `README.md:200-202` lists Experimental functions. `xet_open_stream_connection` is not in it. Add it, and it counts toward "nine".
- **H10 roxygen regeneration:** `devtools::document()` regenerates all of `man/`. Keep only the three `.Rd` files in scope. Revert any other `man/` diff and report it.
- **H11 concurrent installs:** wave 1 runs up to 4 workers, and two of them run local-CAS tests. Local-CAS ports are random with bind-retry, so those tests can overlap safely. `R CMD INSTALL .` into the shared site library is not safe: two workers overwrite each other. Workers install to a worktree-local library, `R CMD INSTALL -l .development/lib .`. Only the orchestrator's wave-end gate does the shared install.

## Task specs

### 14.1.1 Rust: serialize reader shutdown with reads (F1)

- **Repo:** rxet
- **Files in scope:** must edit `src/rust/src/reader.rs`, `src/rust/src/lib.rs`, `src/rust/src/tests.rs`. Can create nothing. Temp scratch goes in `.development/`.
- **Depends on:** none.
- **Spec:** add `pub(crate) fn finish(&self) -> Result<(), String>` to `impl<S: RangeSource> WindowedReader<S>` in `reader.rs`. It locks `self.cache`, then calls `self.source.finish()`, and returns its result. Map a poisoned-lock error to `Err` the same way `read_at` does. Change `rxet_close_reader` in `lib.rs` to call `reader.finish()` instead of `reader.source().finish()`. Leave `source()` in place for other callers. Add one test in `tests.rs`: a `RangeSource` whose `fetch` blocks on a barrier and whose `finish` records a flag. Start a thread that calls `read_at`, then call `finish()` from the main thread. Assert the flag is set only after the fetch returns, so `finish` waited for the read.
- **Constraints:** do not change window policy, constants, or `READERS`'s type. Do not change any `#[extendr]` signature (H2).
- **Anchors:** `reader.rs` `fn read_at`, `fn source`; `lib.rs` `fn rxet_close_reader`.
- **Reference implementation:** `reader.rs` `read_at` (the lock pattern).
- **Acceptance:** `cd src/rust && cargo test` passes with 35 tests (34 existing plus 1 new). `cd src/rust && cargo check --tests 2>&1 | grep -c '^warning'` prints `0`. `git diff --stat -- R/extendr-wrappers.R` is empty.

### 14.1.2 C: EOF whole items, PROTECT, seek previous position (F2, F14, F15)

- **Repo:** rxet
- **Files in scope:** must edit `src/connection.c`, `tests/testthat/test-connection-offline.R`, `tests/testthat/test-stream-connection.R`. Can create nothing.
- **Depends on:** none.
- **Spec:**
  1. `rxet_conn_read`: after clamping `total` to the remaining bytes, round it down to a multiple of `size` (`total -= total % size`). If the result is 0, return 0 without calling R. Otherwise protect each `Rf_ScalarReal` result before building the next argument or the call, then `Rf_lang3`, then the call. Balance `UNPROTECT` after evaluation so the existing order and cleanup stay the same. Return `total / size`. Only advance `pos` by the bytes returned.
  2. `rxet_conn_seek`: capture `double previous = st->pos;` before changing `pos`, and return `previous` for a non-NA `where`. `ISNA(where)` still returns `st->pos`.
  3. `test-connection-offline.R`: update the seek assertions at lines 34, 37, 40, 50, 61-62 and 71 to the previous position. After each seek, assert the destination with `seek(conn, 0, "current")`. Add one test: a 3-byte file read with 4-byte items returns 0 items and consumes no bytes.
  4. `test-stream-connection.R`: update the assertions at lines 27, 28, 32, 36, 48-49 the same way.
- **Constraints:** no R code in `destroy` (H4). Do not change `rxet_connection_new`'s signature. Stay inside `R_ext/Connections.h` (H5).
- **Anchors:** `src/connection.c` `rxet_conn_read` (`Rf_lang3`), `rxet_conn_seek` (`return st->pos;` after `st->pos = target;`).
- **Reference implementation:** the existing `rxet_conn_read` PROTECT/UNPROTECT block, kept in order.
- **Acceptance:** `R CMD INSTALL -l .development/lib . > /dev/null` exits 0. `env -u RXET_LOCAL_CAS_SERVER Rscript -e 'devtools::test(filter = "connection-offline")'` has 0 failures. `RXET_LOCAL_CAS_SERVER=$HOME/.cargo/bin/local_cas_server Rscript -e 'devtools::test(filter = "stream-connection")'` has 0 failures and 0 skips.

### 14.1.3 R: raster lifetime, `dest_path`, whole-download test mock (F16, F17)

- **Repo:** rxet
- **Files in scope:** must edit `R/spatial.R`, `R/whole_download.R`, `tests/testthat/test-arrow-spatial.R`, `tests/testthat/test-whole-download.R`. Can create nothing.
- **Depends on:** none.
- **Spec:**
  1. `R/whole_download.R`: add `dest_path = NULL` to `.rxet_whole_download()`. For `via = "file"`: when `dest_path` is NULL, use a `tempfile(fileext = ...)` and do not `unlink` it on exit; when given, download to `dest_path` and do not unlink it. `read_xet_vector` keeps its unlink-on-exit behavior, so pass a flag (for example `keep = TRUE` for raster only). The `via = "stream"` path is unchanged.
  2. `R/spatial.R` `read_xet_raster()`: signature becomes `read_xet_raster(handle, file_hash, file_size, dest_path = NULL, ...)`. Validate `dest_path` as a single non-empty string when given, with the same error style as `xet_download_file`. Reader becomes `function(path) terra::rast(path, ...)`. Drop `terra::wrap()` and `terra::unwrap()` (J5). Update the roxygen: no temp deletion; with `dest_path` the raster references that file lazily; without it the file is left in `tempdir()` (J2). Keep the "Experimental" status line.
  3. `test-arrow-spatial.R`: raster tests (guard with local CAS) assert (a) with `dest_path`, the file exists after the call and the raster reads values; (b) without `dest_path`, the returned raster reads values after the call returns; (c) `terra::crop()` of the returned raster, computed after `gc()`, still reads.
  4. `test-whole-download.R` lines 66-70 (the "invalid arguments" test): mock `xet_open_stream_connection` instead of `xet_open_connection`, so `expect_false(called)` checks the default stream path (F17).
- **Constraints:** do not change `read_xet_vector`'s behavior. Do not change `R/extendr-wrappers.R` or `NAMESPACE`. Do not change the stream path.
- **Anchors:** `R/spatial.R` `read_xet_raster <- function`, `terra::wrap`; `R/whole_download.R` `on.exit(unlink(path)`; `test-whole-download.R` `xet_open_connection = function`.
- **Reference implementation:** `R/download.R` `xet_download_file` for `dest_path` validation and error style.
- **Acceptance:** `R CMD INSTALL -l .development/lib . > /dev/null` exits 0. `RXET_LOCAL_CAS_SERVER=$HOME/.cargo/bin/local_cas_server Rscript -e 'devtools::test(filter = "arrow-spatial|whole-download")'` has 0 failures. `grep -n "terra::wrap\|terra::unwrap" R/spatial.R` prints nothing.

### 14.1.4 Docs: benchmark wording (F9)

- **Repo:** rxet
- **Files in scope:** must edit `tools/README.md`. Can create nothing.
- **Depends on:** none.
- **Spec:** the `benchmark-extended.R` paragraph (anchor: "`benchmark-extended.R` breaks the same run into phases") says the script produces a synthetic estimate of phase latencies from simulated values, not a measurement of `models.json`. Keep the `benchmark.R` paragraph and the command examples. Say that `benchmark.R` is the real timing.
- **Constraints:** do not edit `tools/benchmark-extended.R`.
- **Acceptance:** `git diff --stat` lists only `tools/README.md`. `grep -n -i "synthetic" tools/README.md` prints at least one line. `grep -n "same run" tools/README.md` prints nothing.

### 14.2.1 R roxygen: qualify claims, `rawConnection` memory (F3, F10, F11)

- **Repo:** rxet
- **Files in scope:** must edit `R/arrow.R`, `R/connection.R`. Can create nothing.
- **Depends on:** none (its wording feeds 14.2.2).
- **Spec:**
  1. `R/arrow.R`: replace "so unread columns are never transferred" (line 5) with wording that says unselected columns are not logically read, and that aligned readahead can transfer some bytes of them. Qualify the "Partial download" paragraph (lines 23-26) the same way. Say that the download is reduced, not that it is never transferred.
  2. `R/connection.R` `xet_open_connection` `@details`: after "The whole file becomes one in-memory `raw()` vector" add that `rawConnection()` copies that vector when the connection is created, so peak RAM is roughly twice the file size during construction, and the copy is released on close. This matches R's `rawConnection` help.
- **Constraints:** roxygen comments only, no code change. Do not edit `man/*.Rd` (14.3.1 does that).
- **Anchors:** `R/arrow.R` "never transferred" and "Partial download"; `R/connection.R` "The whole file becomes one in-memory".
- **Acceptance:** `grep -rn "never transferred" R/ README.Rmd` prints nothing. `grep -n "roughly twice" R/connection.R` prints one line. `Rscript -e 'parse("R/arrow.R"); parse("R/connection.R")'` exits 0.

### 14.2.2 README and NEWS (F4-F8, F12, F13; J1, J7)

- **Repo:** rxet
- **Files in scope:** must edit `README.Rmd`, `README.md`, `NEWS.md`. Can create nothing.
- **Depends on:** 14.1.3 (for `dest_path`), 14.2.1 (for wording).
- **Spec (apply to `README.Rmd` first, then mirror into `README.md`, J7):**
  1. Quick start: move `xet_client_close(client)` (with its sentence "Call `xet_client_close()` when you finish") to after the last example, or create a new client per block. Fix both files (F4, F5, F13).
  2. Parquet paragraph: replace "col_select and filters apply after the download" with wording that they drive Arrow's selective range reads (F6). Keep the sentence "`read_xet_parquet()` reads through `xet_open_stream_connection()`" and state that unselected columns are not logically read, with readahead possibly transferring some bytes (F3).
  3. "All three read the whole file before they return. They are not streaming helpers." becomes: `read_xet_parquet()` streams; the raster and vector helpers download the whole file. Mention `read_xet_raster(dest_path = )` (F7, J1).
  4. Streaming connection paragraph: "transfers roughly the footer plus those 3 columns" becomes "transfers roughly the footer plus the chunks for those 3 columns, plus readahead" (F3).
  5. API table: add a row for `xet_open_stream_connection(handle, file_hash, file_size)`, and show `read_xet_raster(handle, file_hash, file_size, dest_path = NULL)`. Change "The other eight are Experimental" to "nine" (F8). Add `xet_open_stream_connection` to the support table at `README.md:200-202` (H9).
  6. `NEWS.md`: one line under the 0.4.0 entry for the `dest_path` argument on `read_xet_raster()` and for the corrected lifetime. Do not renumber entries.
  7. `README.md` is rendered: mirror each `README.Rmd` change by hand (J7). Do not re-knit the whole file.
- **Constraints:** no new claims beyond what 14.1.3 and 14.2.1 document. Do not edit `README.Rmd` sections not named above.
- **Anchors:** `README.Rmd` "xet_client_close(client)" (first occurrence, quick start); "col_select and filters"; "All three read the whole file"; "eight are Experimental"; `README.md` support table `xet_stream_raw`, `xet_stream_range`, `xet_open_connection` row.
- **Acceptance:** `grep -n "eight are Experimental\|col_select and filters apply after\|All three read the whole file" README.Rmd README.md` prints nothing. `grep -n "xet_open_stream_connection" README.Rmd README.md` prints at least 2 lines per file. `git diff --stat` lists only `README.Rmd`, `README.md`, `NEWS.md`.

### 14.3.1 Regenerate man pages (F11, F16, F3 rendered)

- **Repo:** rxet
- **Files in scope:** must edit `man/read_xet_raster.Rd`, `man/read_xet_parquet.Rd`, `man/xet_open_connection.Rd` (all generated by roxygen2). Can create nothing.
- **Depends on:** 14.1.3, 14.2.1.
- **Spec:** run `Rscript -e 'devtools::document()'`. Keep only the diffs in the three in-scope `.Rd` files. If roxygen changes any other `man/` file or `NAMESPACE`, revert that file with `git checkout -- <file>` and report it (H10).
- **Constraints:** `R/extendr-wrappers.R` and `NAMESPACE` must be unchanged (H2).
- **Acceptance:** `git diff --stat -- NAMESPACE R/extendr-wrappers.R` is empty. `grep -n "dest_path" man/read_xet_raster.Rd` prints at least one line. `grep -n "roughly twice\|copies" man/xet_open_connection.Rd` prints at least one line. `R CMD INSTALL -l .development/lib . > /dev/null` exits 0.

## Wave-end gate (orchestrator, serial, after wave 3)

Run in this order on `v040` after all wave 3 commits:

1. `cd src/rust && cargo test` expects 35 passed, 0 failed.
2. `R CMD INSTALL .` exits 0.
3. `RXET_LOCAL_CAS_SERVER=$HOME/.cargo/bin/local_cas_server Rscript -e 'devtools::test()'`. Compare with the pre-wave baseline. Expect no new failures and the new tests passing.
4. `grep -rn "never transferred\|col_select and filters apply after\|All three read the whole file\|terra::wrap" R/ README.Rmd README.md` prints nothing.
5. `git log --oneline afb6274..HEAD` shows one commit per task, with no phase or wave numbers in subjects.

## Acceptance (plan level)

Every F1-F17 row in the finding map is marked resolved in `planning/STATE_14.md` with the commit that resolved it. J1-J7 are answered in the approval reply.
