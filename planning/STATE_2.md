# State 2 — Phase 2: Correct Public API, Documentation, and Package Metadata

Resume from this file. The user approved this plan on 2026-10-15. Approval covers Phase 2 planning-task orchestration only — no Rust changes, live-network verification, CRAN submission, or release publication.

## Baseline checklist (observed 2026-10-15)

- [x] Repository instructions read: `AGENTS.md` (build: `R CMD INSTALL .`, `cargo check`; tests: `devtools::test()`).
- [x] Master input read: `planning/MASTER_PLAN.md` (Phase 2 mandate and exit gate).
- [x] Prior phase read: `planning/EXECUTION_PLAN_1.md`, `planning/STATE_1.md`.
- [x] No repository `docs/decisions/` ADRs found.
- [x] `R CMD build .` succeeded (Phase 1 check log, `rxet.Rcheck/00check.log`).
- [x] Linux `R CMD INSTALL .` succeeded; `cargo check` succeeded (Phase 1).
- [ ] Green test baseline: **not established** — no `tests/testthat.R`; prior `devtools::test()` had 3 failures (missing `uuid`) + 8 skips. Task `2.1.4` adds the runner and skips; substantive correctness is Phase 5.
- [ ] Clean check baseline: **not established** — 1 WARNING (`rprojroot` undeclared in `tests/hf_test_setup.R`) + 1 NOTE (`LICENSE` not mentioned in `DESCRIPTION`). Forced-suggests check stopped for missing `arrow`, `uuid`, `covr`. Task `2.2.1` verifies the fixes.
- [x] Local toolchain: R 4.6.1; `roxygen2` 8.1.0, `devtools` 2.5.2, `knitr`, `rmarkdown`, `testthat`, `rprojroot`, `future`, `jsonlite`, `terra`, `sf`, `httr2` present; **missing** `uuid`, `arrow`, `covr`.
- [x] Workspace artifacts preserved: `rxet.Rcheck/` and `rxet_0.1.0.tar.gz` are untracked and must not be overwritten or removed.

## Decisions / user answers (2026-10-15)

- D1: Keep `read_xet_parquet_stream()` exported; document it honestly; remains experimental pending evidence.
- D2: `DESCRIPTION` license → `Apache License (>= 2) + file LICENSE`.
- D3: Truthful wording **and** explicit experimental labels for the provisional APIs (10 after D1: Phase 1's 9 + `read_xet_parquet_stream`).
- D4: Add `tests/testthat.R` in Phase 2, with clean skips when `uuid`/`arrow`/`future.apply` are absent.
- D5: Wave 1 = 4 file-disjoint parallel tasks; Wave 2 = verification. (Docs + DESCRIPTION metadata merged into `2.1.1` because roxygen writes `DESCRIPTION`.)
- Keep all 13 exports; no removal or rename.

## Wave board

| Wave | Tasks | Status | Depends on |
|---|---|---|---|
| 1 | `2.1.1.pkg-docs-metadata` | pending | none |
| 1 | `2.1.2.readme` | pending | none |
| 1 | `2.1.3.agents-doc` | pending | none |
| 1 | `2.1.4.test-harness` | pending | none |
| 2 | `2.2.1.release-check` | pending | `2.1.1`, `2.1.2`, `2.1.3`, `2.1.4` |

## Task reports

<!-- Orchestrator and workers append reports below. One section per task id, <=15 lines each. -->

### 2.1.1.pkg-docs-metadata

(pending)

### 2.1.2.readme

(pending)

### 2.1.3.agents-doc

(pending)

### 2.1.4.test-harness

(pending)

### 2.2.1.release-check

(pending)
