# STATE 12: reader window policy behind a fetch seam

Plan: `planning/EXECUTION_PLAN_12.md`. Status: APPROVED by user 2026-11-05 (D8 kept). Wave 1 next, after P1.

## Baseline (pre-wave)

- [ ] P1. Commit the planning files (plan 12 set).
- [x] P2. `R CMD INSTALL .` exit 0. Routine suite with `RXET_LOCAL_CAS_SERVER=$HOME/.cargo/bin/local_cas_server`: PASS 328, FAIL 0, SKIP 16, ERROR 0 (2026-11-05, commit 4d66b13). Skips: live opt-in, local token enforcement, upload 401.
- [x] P3. `cd src/rust && cargo test`: 18 passed, 0 failed. `cargo check --tests 2>&1 | grep -c '^warning'`: 0 (2026-11-05, commit 4d66b13).
- [x] P4. `grep -rn "runs past\|stream returned\|reader cache" tests R`: no matches, so no R test depends on the reader's error text.
- [x] P5. `grep -Pzo "at least\s*(#'\s*)?16 MiB" R/stream_connection.R R/arrow.R`: matches in both files (the 12.1.2 acceptance check starts red).

## Wave board

| Task | Wave | Model | Status |
|---|---|---|---|
| 12.1.1 Extract the reader window policy into reader.rs | 1 | sonnet | pending |
| 12.1.2 Correct the window-size wording in the docs | 1 | haiku | pending |
| 12.2.1 Offline reader tests through MemorySource | 2 | haiku | pending |
| 12.2.2 Record reader.rs in AGENTS.md | 2 | haiku | pending |

## Task reports
