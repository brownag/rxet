# STATE 11: validation module and whole-download reader module

Plan: `planning/EXECUTION_PLAN_11.md`. Status: approved by user 2026-10-22 ("run plan 11"); baseline recorded; wave 1 next.

## Baseline (pre-wave)

- [x] P1. Commit the planning files (`ARCHITECTURE_REVIEW.md`, plan 11 files).
- [x] P2. `R CMD INSTALL .` exit 0. Routine suite with `RXET_LOCAL_CAS_SERVER=$HOME/.cargo/bin/local_cas_server`: record pass/fail/skip counts.
- [x] P3. `cd src/rust && cargo check --tests && cargo test --lib`: record counts.
- [x] P4. `grep -rn "whole number of bytes" R tests src` to list message coupling for T2.

Baseline results: P1 planning files committed (79208ad). P2 install exit 0; `devtools::test()` no failures, 16 skips (live opt-in, token enforcement, upload 401). P3 cargo check ok; `cargo test --lib` 16 passed. P4 old message sites: R/connection.R:55, R/stream.R:44,110, R/download.R:35, lib.rs:25. No R test needs `whole number of bytes` text from Rust; T2 may proceed.

## Wave board

| Task | Wave | Status |
|---|---|---|
| T1 validation module | 1 | done |
| T2 Rust converter merge | 1 | done |
| T3 migrate transfer functions | 2 | pending |
| T4 whole-download module | 2 | pending |
| T5 migrate readers | 3 | pending |
| T6 docs | 4 | pending |

## Task reports

## T2 (done by orchestrator after worker quota error, per user choice)
- Status: done. Commit `refactor(rust): merge duplicate whole-number converters`.
- `src/rust/src/lib.rs`: removed `to_whole_bytes`/`whole_u64`, added `whole_bytes(field, v)` (~L57); 7 call sites updated.
- `src/rust/src/tests.rs`: added 2^64 case to `build_config_rejects_bad_numbers`, two `whole_bytes` tests.
- `cargo check --tests` ok; `cargo test --lib` 18 passed, 0 failed (baseline 16).
- Deviation: none (note old `whole_u64` wrongly accepted exactly 2^64; now rejected).
- Gotcha: R-side messages unchanged; extension needs rebuild at wave gate.

## T1 (done by orchestrator after worker quota error)
- Status: done. Commit `refactor(validate): add internal request validation module`.
- Files: `R/validate.R` (new), `tests/testthat/test-validate.R` (new).
- `devtools::test(filter = "validate")`: 32 pass, 0 fail.
- Deviation: none. Gotcha: messages use backticked arg names (`` `handle` ``, `` `file_size` ``); T3 must update test regexes accordingly.

## Wave 1 gate
Install exit 0; full suite no failures, same skips as baseline.
