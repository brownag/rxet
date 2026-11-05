# STATE 12: reader window policy behind a fetch seam

Plan: `planning/EXECUTION_PLAN_12.md`. Status: APPROVED by user 2026-11-05 (D8 kept). Wave 1 done; wave 2 next.

## Baseline (pre-wave)

- [x] P1. Commit the planning files (plan 12 set): 36d3e5b.
- [x] P2. `R CMD INSTALL .` exit 0. Routine suite with `RXET_LOCAL_CAS_SERVER=$HOME/.cargo/bin/local_cas_server`: PASS 328, FAIL 0, SKIP 16, ERROR 0 (2026-11-05, commit 4d66b13). Skips: live opt-in, local token enforcement, upload 401.
- [x] P3. `cd src/rust && cargo test`: 18 passed, 0 failed. `cargo check --tests 2>&1 | grep -c '^warning'`: 0 (2026-11-05, commit 4d66b13).
- [x] P4. `grep -rn "runs past\|stream returned\|reader cache" tests R`: no matches, so no R test depends on the reader's error text.
- [x] P5. `grep -Pzo "at least\s*(#'\s*)?16 MiB" R/stream_connection.R R/arrow.R`: matches in both files (the 12.1.2 acceptance check starts red).

## Wave board

| Task | Wave | Model | Status |
|---|---|---|---|
| 12.1.1 Extract the reader window policy into reader.rs | 1 | sonnet | done (8e3c3ba) |
| 12.1.2 Correct the window-size wording in the docs | 1 | haiku | done (3c50efb) |
| 12.2.1 Offline reader tests through MemorySource | 2 | haiku | pending |
| 12.2.2 Record reader.rs in AGENTS.md | 2 | haiku | pending |

## Task reports

## 12.1.1
- Status: done, committed 8e3c3ba. Sonnet, first attempt; the plan was approved without changes.
- Files: `src/rust/src/reader.rs` (new, ~130 lines: constants, `RangeSource`, `WindowedReader` new/source/read_at, private `WindowCache`/`ReaderWindow`). `src/rust/src/lib.rs`: `XetStreamSource` + `impl RangeSource` replaces `XetReader`; `READERS` is retyped; open/read/close are rewired; `Mutex` import dropped.
- Tests: `cargo check --tests` gives 0 warnings; `cargo test` gives 18 passed. Acceptance greps are clean.
- Deviations: none. The orchestrator removed a "(D4)" plan reference from the `read_at` doc comment.
- Gotchas: the wrong-length check is in `read_at`, so `MemorySource` Short/Long both hit "stream returned N bytes, expected M". The `READ_*` constants are `pub(crate)`.
- Incident: the first worker's worktree was created from `main` (a74b46e) rather than the `v030` HEAD and lacked the reader code. It was re-run in a manual worktree at 36d3e5b. Wave 2 worktrees must be created manually from the current HEAD.

## 12.1.2
- Status: done, committed 3c50efb along with the regenerated `man/read_xet_parquet.Rd` and `man/xet_open_stream_connection.Rd`. Haiku, first attempt; Q1 (rewrapping the paragraph) was approved.
- Files: `R/stream_connection.R` 16-19 and `R/arrow.R` 23-25 now say "at least 1 MiB … up to 16 MiB".
- Checks: the multi-line grep exits 1; "1 MiB" appears once per file.
- Deviations: none. `devtools::document()` also rewrote `man/rxet-package.Rd` (ORCID from DESCRIPTION). That is out of scope, so it was left uncommitted and restored.

## Wave 1 gate
- `R CMD INSTALL .` exit 0. The local-CAS routine suite gives PASS 328, FAIL 0, SKIP 16, ERR 0, matching the baseline.
