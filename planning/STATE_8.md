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

## 8.2.1 (release notes)

- Status: done. `NEWS.md` created with `# rxet 0.1.0`, 13 exports with ADR 0001 tiers, limitations, prerequisites (Rust >= 1.85), auth, and `TEST_EVIDENCE_PENDING` placeholder (filled at gate, J3). No test counts. Report: `planning/tasks/8.2.1.report.md`.
- Orchestrator fix: auth wording changed from "never prints or stores" to "does not write the token into its error output" to match the README and the audit (not verified beyond the fault test).

## 8.2.2 (readme)

- Status: done. `README.Rmd` and `README.md` (hand-synced) add Installation (prereqs, `R CMD INSTALL .`, devtools alternative) and Authentication sections; v0.1 status lists all 13 exports once each. Acceptance `README_OK`. Report: `planning/tasks/8.2.2.report.md`.

## Wave 2 board

- 8.2.1: done. 8.2.2: done.

## 8.3.1 (final review, static, read-only)

- Result: 0 critical, 1 high, 2 medium, 7 low (10 findings). Review: `planning/tasks/8.3.1.review.md`. Nothing run (static only).
- High: `NEWS.md` placeholder `TEST_EVIDENCE_PENDING`. Expected; filled at gate step 6 (J3). Not a product defect.
- Medium: token claim is broader than the fault test (401 path only) — static reading, no token found in error formats. Memory-copy claims in `R/arrow.R` and `R/spatial.R` are not measured.
- Low: extensionless temp file in `read_xet_vector` (`R/spatial.R:173`) with the "80+ formats" claim at `R/spatial.R:118`; `read_xet_parquet` relies on arrow closing the connection; `xet_close_connection` errors on a closed connection; dead `make_hf_api_request` in `R/utils.R:165`; `uuid` not installed in CI; AGENTS.md 1.70 stale; STATE_7 close-gap residual is stale (fixed by 47f3c5d).
- Decision: 8.4.1 not created. No critical or high product finding; the high item is the planned gate placeholder. Medium and low items are residual gaps (recorded below), not fixed in this plan.

## Final phase gate (orchestrator, serial, 2026-10-15)

- [x] Step 1 roxygenise: NAMESPACE unchanged; `man/rxet-package.Rd` gained the DESCRIPTION links (committed).
- [x] Step 2 routine suite, local server, arrow/terra/sf installed: 242 passed, 0 failed, 0 errors, 15 skipped (baseline 239/15; +3 from the 8.1.3 test).
- [ ] Step 3 live suite: NOT RUN. `HF_TOKEN` is not set in the orchestrator session. Needs the user to export it and approve the run.
- [x] Step 4 clean-archive `git archive HEAD` → `R CMD build` → `R CMD check --no-manual`: Status OK.
- [x] Step 5 tarball (94 entries): no `.env`, `local_cas_data/`, `planning/`, `docs/`, `.o`, `Makevars`. Credential scan: only "Bearer token" doc text.
- [x] Step 6 NEWS.md placeholder filled from steps 2 and 4. Live line says "not yet recorded".
- [x] Step 7 every task has a todo and report under `planning/tasks/` (8.1.1 to 8.3.1).
- [ ] Step 8 residual gaps (below). Tag and publication await user approval.

## Residual gaps (recorded, not fixed in plan 8)

- CI unvalidated until pushed (8.5.1 is gated). Last CI result on record: plan 6.
- Live suite not yet run under plan 8 (step 3).
- Shapefile and other multi-file vector formats: documented as a limitation (D4).
- Range-backed or seekable connection deferred (plan 7).
- Upstream xet-core "Data sender was dropped" race: not reported; needs user go-ahead.
- Token claim (NEWS, README) covers the 401 path only in the fault test; static review found no token in error formats.
- Memory-copy claims in `R/arrow.R` and `R/spatial.R` are unmeasured.
- `read_xet_vector` temp file has no extension (`R/spatial.R:173`); the "80+ formats" wording at `R/spatial.R:118` is overstated.
- `uuid` is in Suggests but not installed in CI, so the uuid tests skip silently.
- `AGENTS.md:208` says Rust >= 1.70; enforced minimum is 1.85.0.
- `make_hf_api_request` (`R/utils.R:165`) is dead code.
- Tag `v0.1.0`, GitHub release, and push: awaiting user approval (master plan Phase 7 item 7; H5).
