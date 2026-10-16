# EXECUTION PLAN 8: Phase 7 — release validation, release notes, and publication gate

Status: DRAFT for approval (2026-10-15). Orchestration 8 implements master plan Phase 7 items 1–7 for v0.1.0 as a GitHub release. It ends at a release candidate with release notes. Tagging and publishing are not in this plan.

## Goal & Scope

**Goal.** Produce a clean, auditable v0.1.0 release candidate: a source tarball that installs and passes `R CMD check` from a clean archive, the offline and live test evidence, complete user-facing release materials (NEWS.md, README install and auth sections, DESCRIPTION links), and an independent review of the release diff. The release is a GitHub release only.

**In scope**
- Master plan Phase 7 items 1–7 (clean-checkout validation, check findings in scope, API and metadata verification, dependency and tarball contents review, release notes, final independent review, and a publication gate that waits for the user).
- The two known gaps from plan 7 that the user chose to fix: the connection-close gap in the raster and vector helpers.
- Release metadata: DESCRIPTION `URL` and `BugReports` fields, pointing at the `origin` remote (`https://github.com/soilschema/rxet`).
- Live integration evidence, run with `HF_TOKEN` exported in the session by the user.
- Pushing `main` to `origin` for CI validation, as one gated step the user approves at run time.

**Out of scope (explicit deferrals)**
- Tagging `v0.1.0`, creating a GitHub release, and any upload. These need separate user authorization (master plan Phase 7 item 7).
- CRAN submission material (`cran-comments.md`) and CRAN policy checks. The destination is GitHub only (user decision, 2026-10-15).
- Shapefile and other multi-file vector formats. Single-file temp writes cannot serve them. They are documented as a known limitation, not implemented (user decision, 2026-10-15).
- A range-backed or seekable connection (master plan Phase 6 item 4; deferred in plan 7).
- Any change to the 13 exports, to ADR 0001, or to the experimental labels, beyond what the release audit proves wrong.
- Reporting the upstream xet-core race ("Data sender was dropped"). Filing it is outward-facing and needs the user's go-ahead, which is not yet given.

**Verbatim constraints (carried)**
- User, 2026-10-15: "Token in this session" for the live run. The token is exported in the session by the user. Workers and the orchestrator never print, log, or write it, and never read `.env`.
- User, 2026-10-15: "GitHub release only (Recommended)". No CRAN material.
- User, 2026-10-15: "Push at a gated step (Recommended)". Pushing waits for explicit approval at run time.
- User, 2026-10-15: "Fix the close gap, document shapefiles (Recommended)".
- Master plan Phase 7 item 7: "Obtain explicit user release approval before tagging/publishing; publishing is not implicit in a passing validation task."
- Master plan Phase 7 item 4: "ensure published source contains no credentials, local artifacts, untracked generated outputs, or unintended vendor material."

## Decision log (dated 2026-10-15)

| # | Decision | Source |
|---|---|---|
| D1 | Plan 8 = master plan Phase 7 items 1–7. Publication excluded. | User: "Yes, Phase 7 only (Recommended)" |
| D2 | Live integration tests run by the user with `HF_TOKEN` exported in this session; the orchestrator records pass/fail counts only. | User: "Token in this session" |
| D3 | Push `main` to `origin` only as a gated step the user approves at run time; then review the CI run. | User: "Push at a gated step (Recommended)" |
| D4 | Fix the connection-close gap in `read_xet_raster`/`read_xet_vector`. Document the shapefile limitation; do not implement multi-file support. | User: "Fix the close gap, document shapefiles (Recommended)" |
| D5 | Destination is a GitHub release. No `cran-comments.md`, no CRAN checks. | User: "GitHub release only (Recommended)" |
| D6 | Release notes go in `NEWS.md` (new). README gets an install section and an auth section. | Default (not asked): standard R package convention; flagged for review |
| D7 | DESCRIPTION gets `URL: https://github.com/soilschema/rxet` and `BugReports: https://github.com/soilschema/rxet/issues`. | Default from `git remote`; flagged for review |
| D8 | Workers: Haiku, two in parallel per wave, file scopes disjoint. Orchestrator runs `roxygen2::roxygenise()` and every serial gate. | Carried from orchestrations 4 and 7 |
| D9 | Acceptance bar: routine suite green per wave (targeted tests only in workers); full suite, live suite and clean-archive check serial at the final gate. | Default, carried from plan 7; flagged for review |
| D10 | ADR alignment: this plan complies with ADR 0001 (public API support contract) and ADR 0003 (tests run under `R CMD check` with optional-dependency skips). It supersedes neither. | Codebase fact: both ADRs are `Accepted` and no scope item contradicts them |

## Judgment calls (flagged for review)

- **J1.** The close-gap fix uses an exit handler registered before `readBin`, so the connection closes on every path. Terra and sf now read from a file, so nothing else closes the connection.
- **J2.** The close-gap test forces the failure with `testthat::local_mocked_bindings()` on `xet_open_connection`, returning an already-closed connection. This is the only practical way to reach the error path without a broken server.
- **J3.** `NEWS.md` test evidence is filled at the final gate from the counts recorded in STATE_8, not written by workers, so the release notes never claim numbers that were not observed.
- **J4.** The release audit (8.1.1) treats the 13 exports, ADR 0001, and the README "v0.1 status" list as the contract. Any mismatch becomes a fix task in a later wave, not an in-place edit by the auditor.

## Hazards

- **H1.** `HF_TOKEN` is in the environment during the live run. The live helper exchanges it in memory. Any worker log that prints environment variables would leak it. Live runs are orchestrator-only.
- **H2.** The repository root contains `rxet_0.1.0.tar.gz` and `rxet.Rcheck/`. Both are git-ignored. The clean-archive build uses `git archive HEAD` in a scratch directory so they cannot leak in.
- **H3.** `.Rbuildignore` already excludes `TODO.md`, `models.json`, `xet-sync.*`, `check-updates.sh`, `planning`, `docs`, `AGENTS.md`, `.development` and `README.Rmd`. These files are tracked in git but are not in the built tarball. The tarball inspection (8.3.3) verifies this rather than assuming it.
- **H4.** `src/Makevars` and `src/entrypoint.o` are restored before every commit and never staged (carried from plan 7).
- **H5.** Pushing (8.4.1) is outward-facing. The wave stops and asks the user before running it.
- **H6.** CI has not run on the plan 7 commits. A failing CI run is a finding to triage, not a reason to rewrite history.

## Wave table

| Wave | Task | Files (disjoint within wave) | Depends on | Notes |
|---|---|---|---|---|
| 1 | `8.1.1.release-audit` | `planning/STATE_8.md` (report only) | — | Read-only audit of the contract (see spec). |
| 1 | `8.1.2.metadata` | `DESCRIPTION` | — | Adds `URL` and `BugReports` only. |
| 1 | `8.1.3.close-gap` | `R/spatial.R` (function bodies only), `tests/testthat/test-arrow-spatial.R` (new test at the end of the terra/sf section) | — | Exit-handler close and a failure-path test. |
| 2 | `8.2.1.release-notes` | `NEWS.md` (new) | 8.1.1, 8.1.3 | Content from the audit; test evidence left as a marked placeholder, filled at the gate (J3). |
| 2 | `8.2.2.readme` | `README.Rmd`, `README.md` | 8.1.1, 8.1.2 | Install and auth sections; "v0.1 status" list matches the audit. |
| 3 | `8.3.1.final-review` | `planning/STATE_8.md` (report only) | 8.2.1, 8.2.2 | Independent review of the complete release diff, read-only. |
| 4 | `8.4.1.fix-review-findings` | only the files named by any critical or high finding | 8.3.1 | Created only if 8.3.1 reports critical or high findings. Otherwise skipped. |

Within each wave, file scopes are disjoint. `8.2.1` and `8.2.2` both read the audit but write different files.

**Report handling (serial).** Workers never append to `STATE_8.md` directly. Each worker writes its report to `planning/tasks/{{id}}.report.md`, and the orchestrator appends each report to STATE_8 one at a time. This avoids concurrent writes to the shared state file, which plan 7 did in wave 1 without incident but which the plan should not rely on.

## Final phase gate (orchestrator, serial, after wave 3)

1. `devtools::roxygenise()` (D8). Confirm `NAMESPACE` is unchanged and `man/` changes are only the expected helper pages.
2. Routine suite with `RXET_LOCAL_CAS_SERVER` and arrow, terra, sf installed: `devtools::test()`. Record counts. FAILED must be 0.
3. Live suite, with the user's `HF_TOKEN` already exported: `RXET_LIVE_TESTS=1 Rscript -e 'devtools::test(filter = "live-hf")'`. Record pass, fail and skip counts. Never print the token. If the live run cannot start, record why and stop the gate.
4. Clean-archive `git archive HEAD` → `R CMD build --no-manual` → `R CMD check --no-manual` with `_R_CHECK_FORCE_SUGGESTS_=false` and no server or live variables. Status OK.
5. Tarball contents: list the built tarball. Confirm no `.env`, no `local_cas_data/`, no `planning/`, no `docs/`, no credentials (grep for `hf_` token prefixes and `Bearer `), and no `src/Makevars` or `*.o` beyond what the build needs.
6. Fill the test-evidence placeholder in `NEWS.md` (J3) from steps 2–4 counts.
7. Confirm every task has a todo in `planning/tasks/` and a STATE_8 report.
8. Record residual gaps in STATE_8: CI unvalidated until pushed (or its result if pushed), shapefile limitation, range-backed connection deferred, tag and publication awaiting user approval.

## Gated step (requires explicit user approval at run time)

- **8.5.1.push-and-ci** (H5, D3): push `main` to `origin` and review the GitHub Actions run for the pushed commit. The orchestrator stops before the push and asks the user to approve. Record the CI result in STATE_8. A failing job is triaged as a finding.
- Tagging `v0.1.0` and publishing are not in this plan. They are the user's decision after the gate and CI result (master plan Phase 7 item 7).

## Task specs

### 8.1.1.release-audit

- **Files:** `planning/tasks/8.1.1.audit.md` (new; the orchestrator copies its summary into STATE_8). Read-only otherwise.
- **Depends on:** none.
- **Known discrepancy to resolve:** AGENTS.md says `tools/msrv.R` validates Rust `>= 1.70`; DESCRIPTION `SystemRequirements` says `rustc >= 1.85.0`; `tools/msrv.R` checks only that Cargo and rustc are declared. Record the actual enforced minimum and state which value the release notes should use.
- **Spec:** Audit the release contract. (a) Confirm the 13 exports in `NAMESPACE` match `docs/decisions/0001-public-api-support-contract.md` and the README "v0.1 status" list (`README.Rmd`). (b) Confirm each exported function's man page exists in `man/` and its `\examples` do not call the network without `\dontrun`. (c) Confirm `DESCRIPTION` fields: Version, License, Authors@R, Suggests (arrow, digest, and the others actually used), SystemRequirements. (d) List each `\dontrun`/`\donttest` example and confirm none needs a credential that is not documented in the README. (e) Record the minimum Rust version claim in `DESCRIPTION` SystemRequirements (`rustc >= 1.85.0`) against `tools/msrv.R`. For each mismatch, record the file:line and the exact text. Do not fix anything.
- **Anchors:** `NAMESPACE` (export lines), `docs/decisions/0001-public-api-support-contract.md` lines 50 and 65, `README.Rmd` "v0.1 status" section, `DESCRIPTION` (SystemRequirements), `tools/msrv.R`.
- **Constraints:** Do not edit any file except `planning/STATE_8.md`. Do not run `devtools::document()`.
- **Acceptance:** `planning/tasks/8.1.1.audit.md` lists all 13 exports (`grep -c '^export(' NAMESPACE` returns 13) with a match or mismatch for each of (a)–(e), and states the enforced Rust minimum from (e). Its summary is copied into STATE_8 section `8.1.1` by the orchestrator.

### 8.1.2.metadata

- **Files:** `DESCRIPTION` only.
- **Depends on:** none.
- **Spec:** Add two fields after `License:`: `URL: https://github.com/soilschema/rxet` and `BugReports: https://github.com/soilschema/rxet/issues`. Change nothing else. The repository location comes from `git remote get-url origin`.
- **Anchors:** the `License:` line in `DESCRIPTION`.
- **Constraints:** Do not change `Version`, `Authors@R`, `Suggests`, `SystemRequirements`. Do not touch any other file.
- **Acceptance:** `Rscript -e 'd <- read.dcf("DESCRIPTION"); stopifnot(!is.na(d[, "URL"]), !is.na(d[, "BugReports"])); cat("DCF_OK\n")'` prints `DCF_OK`. `git diff -- DESCRIPTION` shows only the two added lines.

### 8.1.3.close-gap

- **Files:** `R/spatial.R` (function bodies of `read_xet_raster` and `read_xet_vector` only), `tests/testthat/test-arrow-spatial.R` (one new test, placed at the end of the terra/sf section).
- **Depends on:** none.
- **Spec:** In both helpers, replace the `close(conn)` after `readBin` with an exit handler registered immediately after `xet_open_connection`: `on.exit(close(conn), add = TRUE)`. This closes the connection on the error path as well. Keep the temp-file `on.exit(unlink(path))` and the `readBin`/`writeBin` logic unchanged. Add one test with two assertions, one per helper: with `testthat::local_mocked_bindings(xet_open_connection = function(...) { cc <- rawConnection(raw(0)); close(cc); cc }, .package = "rxet")`, each helper errors, and `nrow(showConnections(all = TRUE))` is the same before and after. Use the arrow tests' helper pattern (`skip_without_local_cas()`, `skip_if_not_installed("terra")` and `"sf"`, `start_fixture_client()`, `serve_fixture()`).
- **Anchors:** `R/spatial.R` `read_xet_raster` (the `xet_open_connection`/`readBin`/`close` block, around lines 67-70) and `read_xet_vector` (around lines 135-140). `tests/testthat/helper-fixtures.R` for `start_fixture_client()` and `serve_fixture()`.
- **Constraints:** No change to roxygen, signatures, or the `ext` crop. No new files. Use `tempfile()` only. Do not touch the arrow section of the test file.
- **Acceptance:** `RXET_LOCAL_CAS_SERVER=$HOME/.cargo/bin/local_cas_server Rscript -e 'devtools::test(filter="arrow-spatial")'` shows FAILED 0, and the new test passes. Previous counts were PASSED 14, SKIPPED 3.

### 8.2.1.release-notes

- **Files:** `NEWS.md` (new file only).
- **Depends on:** 8.1.1 (audit), 8.1.3 (close-gap fix).
- **Spec:** Write `NEWS.md` in the standard R format, with a `# rxet 0.1.0` heading. Sections: **Features** (the 13 exports, grouped by client, download, upload, and optional helpers, taken from the audit, not invented), **Limitations** (no multi-file vector formats; optional helpers read whole files into memory with a 2 GiB cap; `read_xet_parquet_stream` is a whole-download helper, not a streaming one; experimental labels on the optional helpers), **Installation prerequisites** (R, Cargo, and the Rust version the audit confirms as enforced, from 8.1.1's known discrepancy), **Authentication** (set `HF_TOKEN`; the token is never printed or stored by rxet), and **Test evidence** containing exactly the placeholder line `TEST_EVIDENCE_PENDING` for the orchestrator to fill at the gate (J3). Do not write any test count.
- **Anchors:** `planning/STATE_7.md` sections 7.2.1, 7.2.2, 7.3.1 (behaviour notes), `R/arrow.R` and `R/spatial.R` roxygen (`@details` and `**Status:**` lines).
- **Constraints:** Create only `NEWS.md`. Do not edit any other file. Do not claim streaming behaviour for `read_xet_parquet_stream`.
- **Acceptance:** `grep -c 'TEST_EVIDENCE_PENDING' NEWS.md` prints `1`. `grep -c '^# rxet 0.1.0' NEWS.md` prints `1`. No file except `NEWS.md` changes.

### 8.2.2.readme

- **Files:** `README.Rmd`, `README.md` (both edited by hand, kept in sync; do not re-knit).
- **Depends on:** 8.1.1 (audit), 8.1.2 (URL, for any link).
- **Spec:** Add an **Installation** section with the prerequisites (R, Rust `>= 1.85.0`, Cargo), the install command (`R CMD INSTALL .` from a source checkout), and an **Authentication** section (`HF_TOKEN`, never printed). Make the "v0.1 status" list match the 13 exports from the audit, with the optional helpers marked experimental and noting the in-memory and whole-download limits. Link `NEWS.md`.
- **Anchors:** `README.Rmd` "v0.1 status" section; `planning/STATE_8.md` section `8.1.1`.
- **Constraints:** Do not change the examples' network behaviour. Do not add claims the audit did not confirm. Keep `README.Rmd` and `README.md` consistent.
- **Acceptance:** Every export name in the NAMESPACE appears in the README "v0.1 status" list exactly once: `Rscript -e 'ns <- sub("^export\\((.*)\\)$", "\\1", grep("^export\\(", readLines("NAMESPACE"), value = TRUE)); r <- readLines("README.md"); stopifnot(all(vapply(ns, function(n) sum(grepl(paste0("`", n, "`"), r, fixed = TRUE)) >= 1, logical(1)))); cat("README_OK\n")'` prints `README_OK`.

### 8.3.1.final-review

- **Files:** `planning/tasks/8.3.1.review.md` (new; the orchestrator copies its summary into STATE_8). Read-only otherwise.
- **Depends on:** 8.2.1, 8.2.2.
- **Spec:** Independent review of the complete release diff, from commit `17f615f` (the start of plan 7) to `HEAD`, on two axes. (a) **Spec axis:** does each release claim in `NEWS.md` and `README.Rmd` match the code and tests? Does each export still satisfy ADR 0001? (b) **Correctness and standards axis:** the plan 7 and plan 8 product changes (`R/arrow.R`, `R/spatial.R`, `R/connection.R`, `R/stream.R`) for connection handling, temp-file cleanup, error paths, and memory claims. Report findings as: severity (critical, high, medium, low), file:line, the failing scenario, and the fix. Do not fix anything.
- **Anchors:** `git diff 17f615f..HEAD -- R/ NEWS.md README.Rmd`; `docs/decisions/0001-public-api-support-contract.md`; `planning/STATE_7.md` sections 7.1.1 to 7.3.1.
- **Constraints:** Read-only. Do not run the live suite or touch `.env`.
- **Acceptance:** `planning/tasks/8.3.1.review.md` lists each finding with severity, file:line, and scenario, or states "no critical or high findings". Mechanical check: `grep -c '^- severity:' planning/tasks/8.3.1.review.md` equals the number of findings listed.

### 8.4.1.fix-review-findings (conditional)

- **Files:** only the files named in a critical or high finding from 8.3.1.
- **Depends on:** 8.3.1.
- **Spec:** Created only if 8.3.1 reports one or more critical or high findings. Fix each one with its own TODO and the targeted test. Medium and low findings are recorded in STATE_8 as residual gaps, not fixed here.
- **Constraints:** Each fix stays within its named file list. No new scope.
- **Acceptance:** The targeted test for each finding passes; the routine suite is re-run at the final gate.

## Cross-task notes

- The 2 GiB cap message is the existing text from `R/stream.R`; do not change its wording.
- No product code changes beyond 8.1.3 (close gap) and any finding fixed in 8.4.1. The roxygen text is not changed in this plan.
- A product defect found by a test is a stop-and-report. The orchestrator decides the fix, as in plans 5 to 7.

## Questions (for approval)

- **Q1.** Confirm D7: the DESCRIPTION URL and BugReports point at `https://github.com/soilschema/rxet`, taken from `git remote`. Is that the public repository location?
- **Q2.** Confirm D9 (acceptance bar) and D8 (two workers per wave, Haiku). These are defaults carried from earlier plans.
