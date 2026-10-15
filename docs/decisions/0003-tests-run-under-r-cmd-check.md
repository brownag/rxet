---
id: "0003"
title: "Run the testthat Suite Under R CMD check with Optional-Dependency Skips"
status: "Accepted"
date: 2026-10-15
authors:
  - "Andrew G. Brown"
supersedes: null
superseded_by: null
source_context: "EXECUTION_PLAN_2"
---

# 3. Run the testthat Suite Under R CMD check with Optional-Dependency Skips

## Context and Problem Statement

The repository had a substantial `tests/testthat/` suite but no
`tests/testthat.R` runner, so `R CMD check` never executed it — only
`tests/hf_test_setup.R`, which merely defines a function. Running the suite
directly failed when optional packages were absent, because helpers such as
`create_test_fixtures()` call `uuid::UUIDgenerate()` unconditionally and are
invoked from `setup()` blocks (which run before any `test_that()`). Tests also
use `arrow`, `future.apply`, `sf`, and `terra`, and live-network tests require
credentials.

## Decision Drivers

* `R CMD check` must actually run the testthat suite.
* Tests must stay offline and secret-free by default; optional packages must
  produce clean skips rather than errors.
* Test logic and assertions must not be modified just to make the suite run.

## Considered Options

1. Leave the suite unrun by `R CMD check`.
2. Add `tests/testthat.R` and guard each affected `test_that()` with
   `skip_if_not_installed()`.
3. Add `tests/testthat.R`; guard `setup()` blocks (which need optional packages)
   with `skip_if_not_installed()` at the top, and guard individual tests
   elsewhere (chosen).

## Decision Outcome

Chosen option: **Add the standard `tests/testthat.R` runner and place
`skip_if_not_installed()` guards where optional packages are actually needed.**
A skip raised inside `setup()` skips the whole file, which is required for files
whose fixture creation runs in `setup()`; files without a `setup()` use a
per-test guard. No assertion or test logic was changed, and internal helpers
stay unexported.

### Consequences

* **Positive:** `R CMD check` now runs the suite
  (`FAIL 0 | WARN 0 | SKIP 11 | PASS 111`); a package-complete environment
  exercises the skipped tests; missing optional packages never fail the build.
* **Negative:** In environments lacking `uuid`/`arrow`/`future.apply` or
  credentials, some tests are skipped rather than executed.

## Validation & Compliance

* `R CMD check --no-manual` reports `checking tests ... OK` (runs
  `tests/testthat.R`).
* `devtools::test(stop_on_failure = TRUE)` reports 0 failures.
* `DESCRIPTION` declares `rprojroot` (used by `tests/hf_test_setup.R`); `withr`
  and `future` were removed as unused.
