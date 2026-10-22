# STATE 11: validation module and whole-download reader module

Plan: `planning/EXECUTION_PLAN_11.md`. Status: drafted, awaiting user approval; pre-wave baseline not yet recorded.

## Baseline (pre-wave)

- [ ] P1. Commit the planning files (`ARCHITECTURE_REVIEW.md`, plan 11 files).
- [ ] P2. `R CMD INSTALL .` exit 0. Routine suite with `RXET_LOCAL_CAS_SERVER=$HOME/.cargo/bin/local_cas_server`: record pass/fail/skip counts.
- [ ] P3. `cd src/rust && cargo check --tests && cargo test --lib`: record counts.
- [ ] P4. `grep -rn "whole number of bytes" R tests src` to list message coupling for T2.

## Wave board

| Task | Wave | Status |
|---|---|---|
| T1 validation module | 1 | pending |
| T2 Rust converter merge | 1 | pending |
| T3 migrate transfer functions | 2 | pending |
| T4 whole-download module | 2 | pending |
| T5 migrate readers | 3 | pending |
| T6 docs | 4 | pending |

## Task reports
