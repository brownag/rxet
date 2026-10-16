# STATE 8: Phase 7 — release validation, release notes, and publication gate

Plan: `planning/EXECUTION_PLAN_8.md` (DRAFT for approval, 2026-10-15). Prompt: `planning/PROMPT_TEMPLATE_8.md`.

## Baseline (recorded at the plan 7 final gate, HEAD adb5d06)

- [x] Routine suite with `RXET_LOCAL_CAS_SERVER`, arrow, terra and sf installed: FAILED 0, ERR 0, PASSED 239, SKIPPED 15.
- [x] Clean-archive `R CMD build` and `R CMD check --no-manual` with `_R_CHECK_FORCE_SUGGESTS_=false` and no server or live variables: Status OK.
- [x] Fixtures under 100 KB; hashes match `tests/testthat/fixtures/PROVENANCE.md`.
- [x] `roxygen2::roxygenise()` clean after plan 7; NAMESPACE unchanged.
- [ ] Live suite with `HF_TOKEN` exported in the session: not yet run under plan 8 (gate step 3).
- [ ] CI for the pushed commits: not yet run (gated step 8.5.1). Last CI result on record is from plan 6 (macOS and Windows passed on 88a146d; Ubuntu fixed in 3f0b447).
- [x] Git: `origin` is `https://github.com/soilschema/rxet.git`. No tags yet. Local `main` is ahead of `origin` by the plan 7 commits (not pushed).

## Wave board

| Task | Wave | Status |
|---|---|---|
| 8.1.1.release-audit | 1 | pending |
| 8.1.2.metadata | 1 | pending |
| 8.1.3.close-gap | 1 | pending |
| 8.2.1.release-notes | 2 | pending |
| 8.2.2.readme | 2 | pending |
| 8.3.1.final-review | 3 | pending |
| 8.4.1.fix-review-findings | 4 | conditional (only if 8.3.1 reports critical or high findings) |
| Final phase gate (orchestrator, serial) | after wave 3 or 4 | pending |
| 8.5.1.push-and-ci | gated | pending (requires user approval at run time) |

## Task reports

(Empty. Workers append reports here.)
