# STATE 10: rxet 0.2.0 breaking changes

Plan: `planning/EXECUTION_PLAN_10.md`. Branch `v0.2.0`. Status: plan drafted, awaiting approval. No pre-wave step has run.

## Baseline (pre-wave, to be recorded)

- [ ] P1. Plan committed: `docs(planning): add 0.2.0 orchestration plan 10`.
- [ ] P2. `R CMD INSTALL .` exit 0. Routine suite with `RXET_LOCAL_CAS_SERVER`: pass ___ fail ___ error ___ skip ___. Failing test names: ___. `test-parallel-downloads.R` test 1 passes: yes / no. Line count of `^- \`` in README.Rmd ___ and README.md ___.
- [ ] P3. `cd src/rust && cargo check --tests` exit ___. `cargo test --lib` links: yes / no.
- [ ] P4. `pkgbuild` honors `CARGO_TARGET_DIR`: yes / no. Effect on worktrees: ___.
- [ ] P5. `git status` clean on `v0.2.0` except planning files from P1.

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
