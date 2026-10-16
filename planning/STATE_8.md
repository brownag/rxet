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
| 8.1.1.release-audit | 1 | done |
| 8.1.2.metadata | 1 | done |
| 8.1.3.close-gap | 1 | done |
| 8.2.1.release-notes | 2 | pending |
| 8.2.2.readme | 2 | pending |
| 8.3.1.final-review | 3 | pending |
| 8.4.1.fix-review-findings | 4 | conditional (only if 8.3.1 reports critical or high findings) |
| Final phase gate (orchestrator, serial) | after wave 3 or 4 | pending |
| 8.5.1.push-and-ci | gated | pending (requires user approval at run time) |

## Task reports

(Empty. Workers append reports here.)

## 8.1.1 (release audit)

- Status: done (read-only; audit at `planning/tasks/8.1.1.audit.md`).
- Exports: 13 in NAMESPACE; match ADR 0001 (3 supported, 10 experimental) and both README "v0.1 status" lists.
- Man pages: all 13 exist; all examples are `\dontrun{}` with placeholder `"token"`; only documented credential is `HF_TOKEN`.
- Enforced Rust minimum: **1.85.0**. `tools/msrv.R` reads DESCRIPTION SystemRequirements and does not hard-code a version. Release notes say Rust >= 1.85.
- Mismatch: `AGENTS.md:208` says `>= 1.70` (stale). Not fixed here.
- Finding: `uuid` is in Suggests (DESCRIPTION:30) and used in `tests/testthat/test-edge-cases.R:110-115`, but CI (`.github/workflows/R-CMD-check.yaml`) does not install it, so those tests skip silently. Residual gap; decide at 8.4.1 whether it is in scope.
- Unused Suggests: `jsonlite`, `rprojroot`, `covr`. Reported only.

## 8.1.2 (metadata)

- Status: done. DESCRIPTION lines 11-12 add `URL` and `BugReports`. DCF_OK. Diff is two added lines only. Report: `planning/tasks/8.1.2.report.md`.

## 8.1.3 (close gap)

- Status: done. `R/spatial.R` 81-83 and 169-171: `on.exit(close(conn), add = TRUE)` after `xet_open_connection`, replaces `close(conn)`. New test at `test-arrow-spatial.R` 124-137 with write-only mock (amended from spec, approved; spec's pre-closed mock would not discriminate).
- Validation (orchestrator re-run): `devtools::test(filter="arrow-spatial")` with local server: FAIL 0, WARN 0, SKIP 3, PASS 17 (baseline PASS 14, SKIP 3).
- Not verified: the new test was not run against pre-fix code (no checkout allowed). Reasoning only.
- Report: `planning/tasks/8.1.3.report.md`.
