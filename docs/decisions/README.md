# Architecture Decision Records

Living catalog of enduring decisions for `rxet`. Source context refers to the
`planning/` orchestration that produced the record.

| ID | Title | Status | Date | Supersedes | Superseded By | Context |
|---|---|---|---|---|---|---|
| [0001](0001-public-api-support-contract.md) | Preserve the 13-function public API and label unverified functions experimental | Accepted (partially superseded by 0004) | 2026-10-15 | - | - (partly: 0004) | EXECUTION_PLAN_2 |
| [0002](0002-license-apache-2-0-license-md.md) | License Apache-2.0 with the full text in LICENSE.md | Accepted | 2026-10-15 | - | - | EXECUTION_PLAN_2 |
| [0003](0003-tests-run-under-r-cmd-check.md) | Run the testthat suite under R CMD check with optional-dependency skips | Accepted | 2026-10-15 | - | - | EXECUTION_PLAN_2 |
| [0004](0004-v0-2-0-breaking-api-changes.md) | Remove three public functions, move client configuration onto the client, and drop an unused raster argument for v0.2.0 | Accepted | 2026-10-17 | 0001 (in part) | - | EXECUTION_PLAN_10 |
| [0005](0005-remove-in-memory-cap.md) | Remove the 2 GiB in-memory cap and hold in-memory reads to one copy of the file | Accepted | 2026-11-01 | D2 in EXECUTION_PLAN_4 (cap only) | - | ad hoc |
