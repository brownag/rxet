# State 1 — Phase 1: Freeze v0.1 Scope, Support Policy, and Acceptance Contract

Resume from this file. The user approved this plan on 2026-10-15. Approval covers Phase 1 planning-task orchestration only, not product implementation or release publication.

## Baseline checklist (observed 2026-10-15)

- [x] Repository instructions read: `AGENTS.md`.
- [x] Master input read: `planning/MASTER_PLAN.md`.
- [x] No existing orchestration plans/states or repository ADRs found.
- [x] Inventory anchors found: 13 NAMESPACE exports; R wrappers and Rust binding locations recorded in `EXECUTION_PLAN_1.md`.
- [x] `R CMD build .` succeeded in initial release-readiness review.
- [x] `R CMD INSTALL .` succeeded on current Linux environment in initial release-readiness review.
- [x] `cargo check` succeeded in initial release-readiness review (Cargo resolved dependencies online; no tracked lockfile).
- [ ] Green test baseline: **not established**. `devtools::test(reporter="summary")` on the observed installed build had 3 failures due to missing `uuid`, 8 skips from optional packages/credentials/environment, remaining tests passed. Resolve/re-run in an implementation phase; this planning phase does not modify test setup.
- [ ] Clean CRAN-style check baseline: **not established**. Earlier `_R_CHECK_FORCE_SUGGESTS_=false R CMD check --no-manual` completed with 1 WARNING (`rprojroot` undeclared for tests) and 1 NOTE (LICENSE metadata); standard forced-suggests run stopped for unavailable suggested packages.
- [x] Existing workspace artifacts preserved: `rxet.Rcheck/` and `rxet_0.1.0.tar.gz` are untracked and must not be removed by this phase.

## Decisions / user answers

- macOS is in scope alongside Linux and minimal Windows.
- Use `brownag/rxet-test-data` for opt-in manual live integration testing; routine tests remain offline/secret-free, credentials are environment-only, and public CI must not require them.
- CRAN is the intended eventual target if feasible; vendorization belongs in the later packaging phase, not this policy phase.
- Preserve implemented APIs provisionally. Mark an API supported only after its success behavior is demonstrated through actual package behavior; otherwise retain provisionally as experimental or defer the support claim rather than remove it by default.
- Rust MSRV/toolchain and exact R minimum remain technical validation items for Phase 3, not unresolved user-policy decisions.
- User approved the Phase 1 plan on 2026-10-15; approval covers planning-task orchestration only.

## Wave board

| Wave | Tasks | Status | Depends on |
|---|---|---|---|
| 1 | `1.1.1.api-inventory` | done | none |
| 2 | `1.2.1.support-policy` | done | Wave 1 |
| 3 | `1.3.1.phase-contract` | done | Wave 2 |

## Task reports

### 1.1.1.api-inventory

Status: done (2026-10-15). Appended `## Appendix A — API inventory (Task 1.1.1)` to `EXECUTION_PLAN_1.md` (lines 146–207): 13-row export table, non-exported/stale-claims table, read-only `brownag/rxet-test-data` inventory. No runtime/test/doc/metadata files changed.
Classification: 4 `candidate supported` (`xet_client_new`, `xet_client_close`, `xet_config_environment`, `xet_close_connection`), 8 `experimental pending evidence` (all network/Arrow/spatial helpers), 1 `defer/remove claim as stub` (`read_xet_parquet_stream`).
Validation: `git diff --check -- planning/EXECUTION_PLAN_1.md` clean; targeted grep found 13 export rows + stale-claims section; `git status --short` shows no source changes. `rg` unavailable — used `grep -E` (deviation: tool only).
Key facts for later waves: no test performs a real successful Xet transfer; `test-stream-range.R` never calls `xet_stream_range`; `read_xet_parquet_stream` is `@keywords internal` yet exported (NAMESPACE:4); live repo has only 3 tiny fixtures (one Xet-stored), no large/GeoTIFF/write fixture. Phase 4 hazards: mutex held across blocking I/O, whole-file buffering, non-atomic download to final path, placeholder `Drop`. README is generated from `README.Rmd`; both carry the same stale claims.

### 1.2.1.support-policy

Status: done (2026-10-15). Added `## Support policy decisions — v0.1 API disposition (Task 1.2.1)` (13-row table + stale-claim disposition table), `## Phase handoff (Task 1.2.1)`, and policy decision rows; reframed the `Pending` MSRV row as `Phase 3 (technical)`. Edited `EXECUTION_PLAN_1.md` only.
Dispositions: `supported` = `xet_client_new`, `xet_client_close`, `xet_config_environment` (3). `experimental pending evidence` = `xet_download_file`, `xet_upload_file`, `xet_stream_raw`, `xet_stream_range`, `xet_open_connection`, `xet_close_connection`, `read_xet_parquet`, `read_xet_raster`, `read_xet_vector` (9). `deferred support claim` = `read_xet_parquet_stream` (1). No export removed; labels bound the supported claim only.
Correction during review: `xet_close_connection` moved from `supported` to `experimental` — its only test (`test-connection.R:14–25`) is HF_TOKEN-gated and asserts an error from `xet_open_connection`, so it has `none` success evidence.
Validation: `git diff --check` clean; grep shows all policy concepts present; 13 disposition rows confirmed; no source/test/metadata changes. `rg` unavailable — used `grep -E`.
Handoff: Phase 2 docs/claims, Phase 3 pin/MSRV/platforms/env-vars, Phase 4 hardening, Phase 5 live tests (needs larger fixture), Phase 6 optional integrations, Phase 7 release validation. MSRV/R-version remain the only open technical items (Phase 3).

### 1.3.1.phase-contract

Status: done (2026-10-15). Consistency review of the approved Phase 1 contract; no implementation performed and no code defect claimed resolved.
Files changed: `EXECUTION_PLAN_1.md` (line 183 — corrected the three stale Task 1.3.1 TODO filenames to the `{WAVE}.{TASKID}` form `1.1.1.*`, `1.2.1.*`, `1.3.1.*`; no other plan edits); `STATE_1.md` (Wave-board row 3 → done; this report). Created `planning/tasks/1.3.1.phase-contract.todo.md`.
Agreement verified: Goal & Scope ↔ Verbatim user constraints ↔ inline decisions ↔ `## Decisions recorded` ↔ disposition tables ↔ `## Phase handoff` ↔ wave/task specs all agree; the `xet_close_connection` Appendix-A `candidate supported` → final `experimental` shift is an already-documented correction, not a live contradiction. No contradictory platform (Linux + macOS + minimal Windows), release (GitHub/source, no prebuilt binaries), credential (offline/secret-free routine; opt-in env-token live; no live creds in public CI), API-removal (all 13 exports retained), or vendor-timing (vendoring deferred to Phase 3) statement remains. Phase 2–6 handoff facts map 1:1 to master-plan Phases 2–6 (and Phase 7 release validation).
Acceptance: master-plan Phase 1 exit gate met — scope/platform/release policy is user-approved (approval gate, 2026-10-15) and all 13 exports are classified (3 supported, 9 experimental pending evidence, 1 deferred support claim); no key v0.1 API unclassified.
Validation: `git diff --check -- planning/EXECUTION_PLAN_1.md planning/STATE_1.md planning/PROMPT_TEMPLATE_1.md planning/tasks` clean (no whitespace errors); targeted `grep -E` over the three plan/state/template files returned all expected matches; `git status --short` confirms only `planning/` artifacts changed and no implementation/test/README/man/DESCRIPTION/NAMESPACE/`MASTER_PLAN.md` edits.
Deviations: `rg` unavailable — used `grep -E` (same as predecessors). None other.
Deferrals/risks: MSRV/exact R minimum, hf-xet pin, platform builds, vendor archive, hardening, live-test success evidence, and optional-integration proof remain explicitly deferred to Phases 3, 4, 5, and 6; live repo lacks a large/multi-chunk, GeoTIFF, or write-target fixture; test baseline is not green (missing `uuid`).
