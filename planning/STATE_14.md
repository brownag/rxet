# STATE 14: resolve PR #3 review comments (Copilot and CodeRabbit)

Plan: `planning/EXECUTION_PLAN_14.md`. Goal: resolve F1-F17 from https://github.com/brownag/rxet/pull/3. Status: APPROVED by user 2026-11-11. Not yet executed. Base: `v040` HEAD `afb6274`.

## Baseline (pre-wave, run before wave 1)

- [x] P0. Install the local CAS server (D5): `cargo install xet-client --version 1.7.0 --features simulation --bin local_cas_server --locked`. Already present at `/home/andrew/.cargo/bin/local_cas_server`.
- [x] P1. `R CMD INSTALL .` exits 0 on `afb6274`. Done (0).
- [x] P2. `cd src/rust && cargo test`: record passed/failed counts. Result: 34 passed, 0 failed.
- [x] P3. `cd src/rust && cargo check --tests 2>&1 | grep -c '^warning'`: record count. Result: 0.
- [x] P4. `RXET_LOCAL_CAS_SERVER=$HOME/.cargo/bin/local_cas_server Rscript -e 'devtools::test()'`: record PASS, FAIL, SKIP, ERROR. Result: [ FAIL 0 | WARN 0 | SKIP 17 | PASS 333 ].
- [x] P5. Record anchor counts for the wave-end gate:
  - `grep -rn "never transferred" R/ README.Rmd README.md`: 2 lines (R/arrow.R:5, README.Rmd:90).
  - `grep -n "terra::wrap" R/spatial.R`: 1 line (R/spatial.R:64).
  - `grep -n "eight are Experimental" README.Rmd README.md`: 1 line (README.md:143).

## Finding board

| # | Source | Task | Status | Resolved in |
|---|---|---|---|---|
| F1 | Copilot high, Rust reader shutdown race | 14.1.1 | resolved | adb09e5 |
| F2 | Copilot, C partial item at EOF | 14.1.2 | resolved | 0c2cfcc |
| F3 | Copilot + CodeRabbit, "never transferred" overclaim | 14.2.1, 14.2.2 | resolved | c21025e, 3c12c8b |
| F4 | Copilot, README.Rmd close before examples | 14.2.2 | resolved | 3c12c8b |
| F5 | Copilot, README.md close before examples | 14.2.2 | resolved | 3c12c8b |
| F6 | Copilot, README.md "col_select applies after download" | 14.2.2 | resolved | 3c12c8b |
| F7 | Copilot, README.md "all three read the whole file" | 14.2.2 | resolved | 3c12c8b |
| F8 | Copilot, README API table and experimental count | 14.2.2 | resolved | 3c12c8b |
| F9 | Copilot, tools/README.md benchmark-extended | 14.1.4 | resolved | 81ab3e4 |
| F10 | CodeRabbit, duplicate of F3 | 14.2.1 | resolved | c21025e |
| F11 | CodeRabbit, rawConnection peak memory | 14.2.1, 14.3.1 | resolved | c21025e, 061865a |
| F12 | CodeRabbit, regenerate README.md | 14.2.2 | resolved | 3c12c8b |
| F13 | CodeRabbit, duplicate of F4 | 14.2.2 | resolved | 3c12c8b |
| F14 | CodeRabbit major, PROTECT in rxet_conn_read | 14.1.2 | resolved | 0c2cfcc |
| F15 | CodeRabbit, seek returns destination | 14.1.2 | resolved | 0c2cfcc |
| F16 | CodeRabbit major, outside diff, raster temp file deleted | 14.1.3, 14.3.1 | resolved | ca900e7, 061865a |
| F17 | CodeRabbit nitpick, whole-download test mock | 14.1.3 | resolved | ca900e7 |

## Wave board

| Task | Wave | Model | Status |
|---|---|---|---|
| 14.1.1 Rust: serialize reader shutdown with reads | 1 | flash | done (adb09e5) |
| 14.1.2 C: EOF whole items, PROTECT, seek previous position | 1 | flash | done (0c2cfcc) |
| 14.1.3 R: raster lifetime, dest_path, whole-download mock | 1 | flash | done (ca900e7) |
| 14.1.4 Docs: benchmark wording | 1 | flash | done (81ab3e4) |
| 14.2.1 R roxygen: qualify claims, rawConnection memory | 2 | flash | done (c21025e) |
| 14.2.2 README and NEWS | 2 | flash | done (3c12c8b) |
| 14.3.1 Regenerate man pages | 3 | flash | done (061865a) |

## Wave-end gate (orchestrator, serial, after wave 3)

- [x] G1. `cargo test`: expect 35 passed, 0 failed. Passed (35 passed, 0 failed in 0.75s).
- [x] G2. `R CMD INSTALL .` exits 0. Passed (exit code 0).
- [x] G3. Full suite with `RXET_LOCAL_CAS_SERVER`: no new failures against P4; new tests pass. Passed: [ FAIL 0 | WARN 0 | SKIP 17 | PASS 364 ] (compared to pre-wave P4: PASS 333, net +31 tests passed).
- [x] G4. Anchor grep from P5 now shows no stale claims. Passed: `grep -rn "never transferred\|col_select and filters apply after\|All three read the whole file\|terra::wrap" R/ README.Rmd README.md` returned 0 matches.
- [x] G5. `git log --oneline afb6274..HEAD`: one commit per task, no phase or wave numbers. Passed (7 conventional commits: `adb09e5`, `0c2cfcc`, `ca900e7`, `81ab3e4`, `c21025e`, `3c12c8b`, `061865a`).

## Task reports

### 14.1.1 Rust: serialize reader shutdown with reads (F1)
- **Status:** Complete in commit `adb09e5`.
- **Files changed:** `src/rust/src/reader.rs` (+11, -0), `src/rust/src/lib.rs` (+1, -1), `src/rust/src/tests.rs` (+56, -1).
- **Exact test commands:** `cd src/rust && cargo test` (35 passed, 0 failed); `cargo check --tests` (0 warnings).
- **Deviations:** Added `#[allow(dead_code)]` to `WindowedReader::source()`.
- **Gotchas for dependent tasks:** None.

### 14.1.2 C: EOF whole items, PROTECT, seek previous position (F2, F14, F15)
- **Status:** Complete in commit `0c2cfcc`.
- **Files changed:** `src/connection.c` (+10, -4), `tests/testthat/test-connection-offline.R` (+23, -5), `tests/testthat/test-stream-connection.R` (+10, -4).
- **Exact test commands:** `env -u RXET_LOCAL_CAS_SERVER Rscript -e 'devtools::test(filter = "connection-offline")'` (30 passed); `RXET_LOCAL_CAS_SERVER=$HOME/.cargo/bin/local_cas_server Rscript -e 'devtools::test(filter = "stream-connection")'` (27 passed).
- **Deviations:** None.
- **Gotchas for dependent tasks:** `seek()` on custom connection now returns previous position before move.

### 14.1.3 R: raster lifetime, dest_path, whole-download mock (F16, F17)
- **Status:** Complete in commit `ca900e7`.
- **Files changed:** `R/spatial.R` (+34, -6), `R/whole_download.R` (+9, -2), `tests/testthat/test-arrow-spatial.R` (+54, -8), `tests/testthat/test-whole-download.R` (+47, -2).
- **Exact test commands:** `RXET_LOCAL_CAS_SERVER=$HOME/.cargo/bin/local_cas_server Rscript -e 'devtools::test(filter = "arrow-spatial|whole-download")'` (59 passed).
- **Deviations:** None.
- **Gotchas for dependent tasks:** `read_xet_raster` now takes `dest_path = NULL` as fourth argument; 14.2.2 and 14.3.1 document this.

### 14.2.1 R roxygen: qualify claims, rawConnection memory (F3, F10, F11)
- **Status:** Complete in commit `c21025e`.
- **Files changed:** `R/arrow.R` (+8, -2), `R/connection.R` (+3, -3).
- **Exact test commands:** `grep -rn "never transferred" R/` (0 matches); `grep -n "roughly twice" R/connection.R` (line 23); `parse()` check passed.
- **Deviations:** None.
- **Gotchas for dependent tasks:** Feeds 14.2.2 and 14.3.1.

### 14.2.2 README and NEWS (F4-F8, F12, F13; J1, J7)
- **Status:** Complete in commit `3c12c8b`.
- **Files changed:** `README.Rmd` (+18, -18), `README.md` (+54, -27), `NEWS.md` (+2, -0).
- **Exact test commands:** `grep -n "eight are Experimental\|col_select and filters apply after\|All three read the whole file" README.Rmd README.md` (0 matches); `grep -n "xet_open_stream_connection" README.Rmd README.md` (10 matches).
- **Deviations:** None.
- **Gotchas for dependent tasks:** None.

### 14.3.1 Regenerate man pages (F11, F16, F3 rendered)
- **Status:** Complete in commit `061865a`.
- **Files changed:** `man/read_xet_parquet.Rd` (+3, -1), `man/read_xet_raster.Rd` (+18, -4), `man/xet_open_connection.Rd` (+3, -0).
- **Exact test commands:** `git diff --stat -- NAMESPACE R/extendr-wrappers.R` (empty); `grep -n "dest_path" man/read_xet_raster.Rd` (5 matches); `grep -n "roughly twice\|copies" man/xet_open_connection.Rd` (2 matches); package installs cleanly into local library.
- **Deviations:** None.
- **Gotchas for dependent tasks:** None.

### 14.1.1 Rust: serialize reader shutdown with reads (F1)
- **Status:** Complete.
- **Files changed:**
  - `src/rust/src/reader.rs` (lines 114, 119-127)
  - `src/rust/src/lib.rs` (line 137)
  - `src/rust/src/tests.rs` (lines 3-4, 434-486)
- **Exact test commands:**
  - `cd src/rust && cargo test`: 35 passed; 0 failed.
  - `cd src/rust && cargo check --tests 2>&1 | grep -c '^warning'`: 0.
  - `git diff --stat -- R/extendr-wrappers.R`: empty (0 lines).
- **Deviations:** Added `#[allow(dead_code)]` to `WindowedReader::source` so library builds remain warning-free now that `lib.rs` delegates to `WindowedReader::finish`.
- **Gotchas for dependent tasks:** None.
- **Unresolved findings:** None (F1 resolved).

### 14.1.4 Docs: benchmark wording (F9)
- **Status:** Complete.
- **Files changed:** `tools/README.md` (lines 21, 29, 39).
- **Exact test commands:**
  - `git diff --stat`: 1 file changed, 3 insertions(+), 3 deletions(-) (`tools/README.md`).
  - `grep -n -i "synthetic" tools/README.md`: 1 match (line 29).
  - `grep -n "same run" tools/README.md`: 0 matches (exit 1).
- **Deviations:** None.
- **Gotchas for dependent tasks:** None.
- **Unresolved findings:** None (F9 resolved).

### 14.1.2 C: EOF whole items, PROTECT, seek previous position (F2, F14, F15)
- **Status:** Complete.
- **Files changed:**
  - `src/connection.c` (lines 36-51, 65-78)
  - `tests/testthat/test-connection-offline.R` (lines 34-43, 53-70, 77-79, 88-89)
  - `tests/testthat/test-stream-connection.R` (lines 27-40, 53-55)
- **Exact test commands:**
  - `R CMD INSTALL -l .development/lib .`: exited 0.
  - `env -u RXET_LOCAL_CAS_SERVER Rscript -e 'devtools::test(filter = "connection-offline")'`: [ FAIL 0 | WARN 0 | SKIP 0 | PASS 30 ].
  - `RXET_LOCAL_CAS_SERVER=$HOME/.cargo/bin/local_cas_server Rscript -e 'devtools::test(filter = "stream-connection")'`: [ FAIL 0 | WARN 0 | SKIP 0 | PASS 27 ].
  - `git diff --stat`: 3 files changed, 43 insertions(+), 13 deletions(-).
  - `git diff --stat -- R/extendr-wrappers.R`: empty (0 lines).
- **Deviations:** None.
- **Gotchas for dependent tasks:** None.
- **Unresolved findings:** None (F2, F14, F15 resolved).

### 14.1.3 R: raster lifetime, dest_path, whole-download test mock (F16, F17)
- **Status:** Complete.
- **Files changed:**
  - `R/spatial.R` (lines 10-12, 20-24, 56-62, 71-97)
  - `R/whole_download.R` (lines 5-7, 27-33)
  - `tests/testthat/test-arrow-spatial.R` (lines 67-124, 198-212)
  - `tests/testthat/test-whole-download.R` (lines 66-70, 78-124)
- **Exact test commands:**
  - `mkdir -p .development/lib && R CMD INSTALL -l .development/lib . > /dev/null`: exited 0.
  - `RXET_LOCAL_CAS_SERVER=$HOME/.cargo/bin/local_cas_server Rscript -e 'devtools::test(filter = "arrow-spatial|whole-download")'`: [ FAIL 0 | WARN 0 | SKIP 3 | PASS 59 ].
  - `grep -n "terra::wrap\|terra::unwrap" R/spatial.R`: 0 matches (exit 1).
  - `git diff --stat -- R/extendr-wrappers.R NAMESPACE`: empty (0 lines).
- **Deviations:** None.
- **Gotchas for dependent tasks:** `read_xet_raster` now takes `dest_path = NULL` as fourth argument; 14.2.2 and 14.3.1 document this.
- **Unresolved findings:** None (F16, F17 resolved).

### 14.2.1 R roxygen: qualify claims, rawConnection memory (F3, F10, F11)
- **Status:** Complete.
- **Files changed:** `R/arrow.R` (lines 5-6, 25-29), `R/connection.R` (lines 22-26).
- **Exact test commands:**
  - `grep -rn "never transferred" R/`: 0 matches (exit code 1).
  - `grep -n "roughly twice" R/connection.R`: 1 match (line 23).
  - `Rscript -e 'parse("R/arrow.R"); parse("R/connection.R")'`: exit 0 (both parsed successfully).
  - `git diff --stat`: 2 files changed, 11 insertions(+), 5 deletions(-) (`R/arrow.R`, `R/connection.R`).
- **Deviations:** None.
- **Gotchas for dependent tasks:** 14.2.2 can now adopt the qualified wording for `README.Rmd`/`README.md`; 14.3.1 will regenerate `man/*.Rd`.
- **Unresolved findings:** None (F3 R roxygen part, F10, F11 R roxygen part resolved).

### 14.2.2 README and NEWS (F4-F8, F12, F13; J1, J7)
- **Status:** Complete.
- **Files changed:** `NEWS.md` (lines 6-7), `README.Rmd` (lines 53-56, 76-104, 137), `README.md` (lines 54-57, 80-114, 147-185, 221-227).
- **Exact test commands:**
  - `grep -n "eight are Experimental\|col_select and filters apply after\|All three read the whole file" README.Rmd README.md`: 0 matches (exit 1).
  - `grep -n "xet_open_stream_connection" README.Rmd README.md`: 10 matches (5 in README.Rmd, 5 in README.md).
  - `grep -rn "never transferred" README.Rmd README.md`: 0 matches (exit 1).
  - `git diff --stat`: 3 files changed, 64 insertions(+), 37 deletions(-) (`NEWS.md`, `README.Rmd`, `README.md`).
- **Deviations:** None.
- **Gotchas for dependent tasks:** None; `dest_path` on `read_xet_raster()` and `xet_open_stream_connection()` are documented.
- **Unresolved findings:** None (F4, F5, F6, F7, F8, F12, F13 resolved).


### 14.3.1 Regenerate man pages (F11, F16, F3 rendered)
- **Status:** Complete.
- **Files changed:** `man/read_xet_parquet.Rd` (lines 25-26, 40-43), `man/read_xet_raster.Rd` (lines 7, 16-19, 33-37, 70-77), `man/xet_open_connection.Rd` (lines 35-39).
- **Exact test commands:**
  - `git diff --stat -- NAMESPACE R/extendr-wrappers.R`: empty (0 lines).
  - `grep -n "dest_path" man/read_xet_raster.Rd`: 5 matches.
  - `grep -n "roughly twice\|copies" man/xet_open_connection.Rd`: 2 matches.
  - `mkdir -p .development/lib && R CMD INSTALL -l .development/lib . > /dev/null`: exited 0.
  - `git diff --stat`: 3 files changed, 29 insertions(+), 10 deletions(-) (`man/read_xet_parquet.Rd`, `man/read_xet_raster.Rd`, `man/xet_open_connection.Rd`).
- **Deviations:** None.
- **Gotchas for dependent tasks:** None; wave 14 documentation generation is complete.
- **Unresolved findings:** None (F3, F11, F16 rendered).
