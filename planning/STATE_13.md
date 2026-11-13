# STATE 13: stream connection owns reader lifetime and size

Plan: `planning/EXECUTION_PLAN_13.md`. Goal: GOALS.md G2 (+ G4 range check). Status: APPROVED by user 2026-11-07. Execution started 2026-11-07 from `v030` HEAD `456e601`.

## Baseline (pre-wave, run 2026-11-07 on 456e601)

- [x] P1. `R CMD INSTALL .` exits 0.
- [x] P2. `cargo test`: 30 passed, 0 failed. `cargo check --tests` warnings: 0.
- [x] P3. `RXET_LOCAL_CAS_SERVER=$HOME/.cargo/bin/local_cas_server Rscript -e 'devtools::test()'`: PASS 312, FAIL 0, SKIP 16, ERROR 0. (Orchestration 12 reference was PASS 328; not comparable, re-baselined.)
- [x] P4. Duplication sites before: `R/stream_connection.R:49,54,63` (`file_size` in check, `.xet_open_reader`, `.xet_stream_connection`). `src/connection.c` stores `size` (C copy, see J1).
- [x] P5. GOALS.md G2 reworded per D7 (uncommitted working-tree change to `planning/GOALS.md`).

## Wave board

| Task | Wave | Model | Status |
|---|---|---|---|
| 13.1.1 Rust: reader owns size; reader-id constructor; reader probe | 1 | sonnet | done (`ffebca3`) |
| 13.1.3 G4 empty-range check | 1 | haiku | done (`e5de3ee`), R rule kept by user decision |
| 13.1.2 Rust: registry holds any RangeSource; memory-backed reader; regenerate wrappers | 2 | sonnet | done (`892ef3a`), with deviations below |
| 13.2.1 C: close releases reader; R constructor takes reader id | 3 | sonnet | done (`f98b732`) |
| 13.2.2 Offline connection tests | 4 | haiku | done (`37279bf`) |
| 13.3.1 ADR 0007 and 0006 amendment | 4 | haiku | done (`8a10f3b`) |

## Wave-end gate (after wave 4, run serially on `v030` at `065a283`+, final HEAD recorded below)

- `cargo test`: 34 passed, 0 failed, 0 warnings from `cargo check --tests`.
- `R CMD INSTALL .`: exit 0.
- Full suite with `RXET_LOCAL_CAS_SERVER`: PASS 333, FAIL 0, SKIP 17, ERROR 0. Baseline was PASS 312, SKIP 16. Delta: +20 offline connection tests, +1 R-layer pin from 13.1.3, +1 expected SKIP from the D5 Rust-side skip.
- Offline connection suite without CAS: PASS 20, FAIL 0, SKIP 0, ERROR 0.
- `grep -n "size #1\|size #2" R/stream_connection.R src/connection.c`: no matches.
- GOALS.md G2 reworded per D7 (uncommitted planning change).

### Fix found in the gate: stale `is.loaded` probe (commit after `37279bf`)

- `tests/testthat/test-config.R:29` checked `is.loaded("wrap__xet_init_client")`, which the `rxet_` rename removed. The test silently skipped. My earlier repo-wide grep was truncated by `head`, so it missed this. Fixed to `wrap__rxet_init_client`. No other stale `wrap__xet_` references remain outside planning history.

### Correction

- Earlier notes said `NAMESPACE` uses `exportPattern("^xet_")`. It uses explicit `export()` lines. The rename rationale is the four name collisions with public R wrappers only. `AGENTS.md` still says `exportPattern`; it is stale and outside plan 13.

### Open items (not in plan 13)

- `planning/GOALS.md` G2 reword and the `planning/*13*` files are uncommitted, as the plan intends.
- Generated wrappers carry roxygen `#'` blocks on the `rxet_*` functions. `devtools::document()` has not been run, so its effect on `man/` is unverified.
- Live suites (`RXET_LIVE_TESTS`) were not run.


Wave-end gate after wave 4 (orchestrator, serial): see EXECUTION_PLAN_13.md.

## Task reports

## 13.1.1

- Status: done, commit `ffebca3` on v030.
- Files: `src/rust/src/lib.rs`, `src/rust/src/reader.rs` (`file_size()`), `src/rust/src/tests.rs`.
- Tests: `cargo test` 32 passed, 0 failed; `cargo check --tests` 0 warnings.
- Deviations: none in code. `R CMD INSTALL` does not link until 13.2.1 updates the C arity; expected.

## 13.1.3

- Status: done, commit `e5de3ee` on v030.
- Empty-range rules: R `R/validate.R:46` rejects `end_byte <= start_byte`. Rust `src/rust/src/lib.rs` `xet_stream_range` rejects only `end < start`, so `end == start` is accepted. The layers disagree.
- User decision (2026-11-07): keep the R rule. No Rust change in this plan. Rust gap is recorded as a skip citing D5.
- Files: `tests/testthat/test-validate.R` (+9 lines).
- Tests: `devtools::test(filter = "validate")` FAIL 0, SKIP 1 (the D5 skip), PASS 32.

## 13.1.2

- Status: done, commit `892ef3a` on v030.
- Tests: `cargo test` 34 passed, 0 failed; `cargo check --tests` 0 warnings; offline `input-validation` PASS 34, FAIL 0, ERROR 0, SKIP 7.
- Deviation 1 (user-approved): all 11 Rust binding functions renamed to an `rxet_` prefix. The extendr generator emits each Rust name verbatim as the R name, so `xet_*` names collided with public R wrappers (`xet_stream_raw`, `xet_stream_range`, `xet_download_file`, `xet_upload_file`), which would silently override them. (Correction: an earlier note said `exportPattern("^xet_")` would export the rest. `NAMESPACE` uses explicit `export()` lines, so that claim was wrong. The rename is still correct for the collisions.) Call sites in `R/client.R`, `R/download.R`, `R/stream.R`, `R/stream_connection.R`, `R/upload.R` updated. Public `xet_*` wrappers unchanged.
- Deviation 2 (user-approved): `R/extendr-wrappers.R` regenerated with the locked generator (`rextendr:::make_wrappers`). Rextendr 0.5.0 and 0.3.1 gave the same output. The generated names are `rxet_*`, no leading dot. No hand edits.
- Name map for downstream tasks: `.xet_stream_connection` -> `rxet_stream_connection`; `.xet_reader_read` -> `rxet_reader_read`; `.xet_close_reader` -> `rxet_close_reader`; `.xet_open_reader` -> `rxet_open_reader`; `.xet_reader_is_open` -> `rxet_reader_is_open`; `.rxet_memory_reader_open` -> `rxet_memory_reader_open`.
- Gotcha: `R/stream_connection.R` still passes the old two-argument shape until 13.2.1. Runtime connection calls are not valid at this commit.

## Fix: compiled-extension probe (commit `065a283`, outside 13.2.1 scope)

- `tests/testthat/helper-local-cas.R` `is_compiled()` still called `wrap__xet_init_client`, which my rename removed. The probe returned FALSE, so every compiled test skipped silently. Found when 13.2.1 reported "Rust extension not available" on all 5 stream-connection tests.
- Fixed to `wrap__rxet_init_client` / `wrap__rxet_close_client`. `git grep` shows no other live `wrap__xet_` reference outside planning history.
- Lesson: the 13.1.2 test run (offline input-validation) passed partly because it skips, so it did not catch this. Compiled-test counts after any rename must be checked for SKIP.

## 13.2.1

- Status: done, commit `f98b732` on v030.
- Files: `src/connection.c` (close_fun preserved and released; `rxet_conn_close` sets `closed` then calls `close_fun`; destroy makes no R calls; R < 4.3 stub updated), `R/stream_connection.R` (`close_fun` built, `rxet_stream_connection(reader, close_fun, id)`, guard comment corrected).
- Tests: `devtools::test(filter = "stream-connection")` with `RXET_LOCAL_CAS_SERVER`: PASS 21, FAIL 0, ERROR 0, SKIP 0 (after the probe fix).
- Grep: `file_size` in `R/stream_connection.R` is limited to the roxygen param, the signature, the argument check, and the `rxet_open_reader` call.
- Deviation: the first worker run reported SKIP 5 because of the probe bug above. Counts above are from the re-run.
