# STATE 10: rxet 0.2.0 breaking changes

Plan: `planning/EXECUTION_PLAN_10.md`. Branch `v0.2.0`. Status: approved by the user; pre-wave baseline recorded 2026-10-18; wave 1 next.

## Baseline (pre-wave, recorded 2026-10-18)

- [x] P1. Plan already committed in `b6d9ab9` (`docs(planning): add 0.2.0 execution plan, worker prompt and state`). No new commit.
- [x] P2. `R CMD INSTALL .` exit 0. Routine suite with `RXET_LOCAL_CAS_SERVER=$HOME/.cargo/bin/local_cas_server`: pass 305, fail 0, error 0, skip 16. Failing tests: none. `test-parallel-downloads.R` test 1 passes: yes. Bullet lines `^- \`` in README.Rmd 29, README.md 26. The counts differ because README.md is hard-wrapped; T9's count check is replaced by a name-set check (see J5).
- [x] P3. `cd src/rust && cargo check --tests` exit 0. `cargo test --lib` exit 0, 11 passed. Test binary links: yes. T7 runs `cargo test build_config`.
- [x] P4. pkgbuild 1.4.8 never references `CARGO_TARGET_DIR`. Cargo reads the variable from the environment itself, but this is untested. Worktree builds are cold (5-10 min each); accepted.
- [x] P5. `git status` clean on `v0.2.0`.

Note: `command -v local_cas_server` returns nothing in the orchestrator shell. The binary is at `~/.cargo/bin/local_cas_server`; export the full path.

Reference baseline from plan 9 (recorded, not re-verified): 305 passed, 0 failed, 16 skipped on `main`.

## Wave board

| Wave | Task | Model | Status | Commit |
|---|---|---|---|---|
| 1 | T1 remove read_xet_parquet_stream | Haiku | pending | - |
| 1 | T2 remove xet_close_connection | Haiku | pending | - |
| 1 | T3 remove ext from read_xet_raster | Haiku | pending | - |
| 1 | T4 remove dead helpers | Haiku | pending | - |
| 1 | T5 cargo cleanup and version | Sonnet | pending | - |
| 1 | T6 remove root model-sync files | Haiku | pending | - |
| 2 | T7 per-client configuration | Sonnet | pending | - |
| 2 | T8 read_xet_vector ext | Haiku | pending | - |
| 3 | T9 docs and surface | Sonnet | pending | - |
| 3 | T10 NEWS | Haiku | pending | - |
| Gate | G1-G4, G6 | orchestrator | pending | - |

Serial wave-end suite: wave 1 ___, wave 2 ___, wave 3 ___.

## Task reports

(Workers append here under `## {{id}}`.)

## Gate reports

(Orchestrator appends here.)
