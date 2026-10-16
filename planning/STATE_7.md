# STATE 7: Phase 6 — optional integrations and memory behaviour

Plan: `planning/EXECUTION_PLAN_7.md` (draft, awaiting approval). Prompt: `planning/PROMPT_TEMPLATE_7.md`.

## Baseline (2026-10-16)

- [x] Routine suite with `RXET_LOCAL_CAS_SERVER` (orchestration 6 gate, 02cd962): pass 224, fail 0, skip 17. arrow was absent then; arrow 25.0.1, terra 1.9.51, sf 1.1.2 are installed now.
- [x] Clean-archive `R CMD check` (orchestration 6 gate): Status OK.
- [ ] Routine suite re-run with arrow, terra and sf installed: not yet recorded.
- [x] CI: macOS and Windows pass on 88a146d; Ubuntu failed on one streaming token check, fixed in 3f0b447 (not yet pushed).

## Wave board

| Task | Wave | Status |
|---|---|---|
| 7.1.1.spike-helper-paths | 1 | pending |
| 7.1.2.fixtures | 1 | pending |
| 7.2.1.arrow-tests | 2 | pending |
| 7.2.2.spatial-tests | 3 | pending |
| 7.3.1.helper-docs | 4 | pending |

## Task reports

(Empty. Workers append reports here.)
