# EXECUTION PLAN 10: rxet 0.2.0 breaking changes

Status: DRAFT for approval (2026-10-18). Branch `v0.2.0`. Not started. No tag, push, or publication in this plan. Each needs separate user approval.

Orchestration 10 follows `planning/PROMPT_TEMPLATE_10.md` and `planning/STATE_10.md`. Executed by wave-orchestration.

## Goal & Scope

**Goal.** Ship rxet 0.2.0 with the breaking API changes in ADR 0004: remove three misleading or redundant public functions, move client configuration onto the client, and drop one unused argument. Add the `ext` argument to `read_xet_vector()`. Clean up dead code, dependencies, and root files.

**In scope**
- Remove `read_xet_parquet_stream()`, `xet_close_connection()`, `xet_config_environment()`.
- Remove the `ext` argument of `read_xet_raster()`.
- Add `timeout_sec`, `cache_bytes`, `high_perf` to `xet_client_new()`, mapped to hf-xet config (ADR 0004, "Configuration rules").
- Correct the `high_perf` help text. It does not disable the chunk cache.
- Add `ext = NULL` to `read_xet_vector()`.
- Remove the six unused helpers in `R/utils.R` and their tests.
- Remove unused Rust crates: `tokio`, `byteorder`, `lru`, `crossbeam-channel`, `futures-util`.
- Set crate version 0.2.0 in `src/rust/Cargo.toml` (task T5) and `DESCRIPTION` (gate).
- Delete root files: `TODO.md`, `models.json`, `xet-sync.R`, `xet-sync.sh`, `check-updates.sh` (user agreed 2026-10-17). Each is tracked and listed in `.Rbuildignore`. They reference each other and look like a GGUF model-sync tool, not rxet. T6 checks for outside references first.
- Docs: `README.Rmd`, `README.md`, `AGENTS.md` describe the 10-export surface (T9). `NEWS.md` gets a 0.2.0 section with a "Breaking changes" heading (T10).
- Final gate: roxygen, routine suite, clean-archive `R CMD check`, live suite (user-run), grep gate, release commit.

**Out of scope (ADR 0004, "Not decided here")**
- Range-backed or seekable connections. Gate: live and local range tests and a documented range contract (`planning/POST_0.1_PLAN.md`).
- Multi-file vector formats. Gate: multi-file temp directory design with cleanup tests.
- Vendored crates for offline builds.
- Promoting any Experimental API to Supported. ADR 0001 requires live evidence.
- Client finalizer (stale TODO.md item 3.3). Non-breaking; a later patch.
- Any change to support tiers or experimental labels.
- An exact-export `NAMESPACE` test. User decided 2026-10-18 it is brittle and unnecessary.

**Verbatim constraints**
- User, 2026-10-17: agreed to the five breaking-change recommendations, the 0.2.0 scope, and root cleanup. Per-client config was conditional on hf-xet support. Verified: `XetConfig::with_config`, `XetConfig::with_high_performance`, `XetSessionBuilder::new_with_config` in hf-xet 1.7.0.
- User, 2026-10-18: branch `v0.2.0`; worker models as listed in D8 below; default concurrency of at most 2 workers per wave; acceptance as in the Gate section; no exact-export test; plan 9 committed as its own commit.
- User, 2026-10-18: ADR 0004 committed as its own commit (`a78d552`).

## Recon facts (2026-10-18)

- Orchestration number: 10. Highest existing plan is 9.
- Repo: `main` at `009cd24`; `v0.2.0` branch at `a78d552`. Plan 9 committed at `d5cea07`. Installed package is 0.1.0 and must not be trusted for testing.
- Sizes (`wc -l`): `R/arrow.R` 164, `R/spatial.R` 185, `R/client.R` 122, `R/connection.R` 90, `R/utils.R` 149, `R/stream.R` 133, `src/rust/src/lib.rs` 374, `tests/testthat/test-token-canary.R` 363, `tests/testthat/test-input-validation.R` 195.
- Test infrastructure: testthat via `devtools::test(filter = ...)`. Local CAS tests need `RXET_LOCAL_CAS_SERVER` (available at `~/.cargo/bin/local_cas_server`). Local server ports are random loopback ports (`helper-local-cas.R:45-52`), so tests do not collide when run concurrently. Live tests skip without `RXET_LIVE_TESTS=1`.
- Tools present: devtools, testthat, roxygen2, processx, arrow, terra, sf, uuid, digest, future.apply, rprojroot. `cargo` at `/usr/bin/cargo`.
- Removed-function references, by file:
  - `read_xet_parquet_stream`: `R/arrow.R:135,144`, `R/stream.R:17`, `tests/testthat/test-arrow-spatial.R:51-58`, `tests/testthat/test-token-canary.R:261-267,339-343`, `README.Rmd:207,280`, `README.md:219,337`, `AGENTS.md:176,181,182`.
  - `xet_close_connection`: `R/connection.R:81`, `tests/testthat/test-connection.R:14-29,54`, `tests/testthat/test-live-hf.R:118`, `tests/testthat/test-local-download.R:98`, `README.Rmd:202,278`, `README.md:214,334`.
  - `xet_config_environment`: `R/client.R:108-122` (and roxygen above it), `tests/testthat/test-config.R` (whole file), `tests/testthat/test-input-validation.R:183-194`, `README.Rmd:147-153,190,269`, `README.md:151-157,197,322`.
  - `ext` on `read_xet_raster`: `R/spatial.R:10,21-22,73,92-93`, `README.Rmd:208`, `README.md:221`. No test calls `read_xet_raster` with `ext`.
  - `R/utils.R` helpers: `make_result` 25, `format_action` 43, `determine_action` 61, `evict_old_cache` 83, `evict_excess_cache` 113, `maintain_cache` 145. No caller outside `R/utils.R` in `R/`.
  - Their tests: `tests/testthat/test-utils.R` (159 lines); `tests/testthat/test-parallel-downloads.R` (4 tests at 3, 22, 45, 59); `tests/testthat/test-edge-cases.R` (dead-helper tests at 3-64 and 80-108; live-code tests at 65-79 and 109-118 stay).
- `process_file_batch` is called in `test-parallel-downloads.R:3` but defined nowhere in `R/` or `tests/`. Baseline P2 records whether that test passes today.
- Root file references: `xet-sync.sh` references `xet-sync.R` and `models.json`. No other references found in `R/`, `tests/`, `.github/`, or docs. `planning/3.1.2.archive-hygiene.todo.md:18` mentions `TODO.md` as history only (not edited).
- `src/rust/src/lib.rs`: `xet_init_client` at line 70, `XetConfig::new()` at line 73, `new_with_config` at line 75. `extendr_module!` at line 368.
- Cargo deps with zero references in `src/rust/src`: `tokio`, `byteorder`, `lru`, `crossbeam-channel`, `futures-util`. `lazy_static` and `uuid` are used.
- `R/client.R` high_perf help text: lines 78-79 ("disabling chunk cache").
- hf-xet 1.7.0 config keys: `client.read_timeout` (Duration; `xet-runtime-1.7.0/src/config/groups/client.rs:63`), `chunk_cache.size_bytes` (`xet-runtime-1.7.0/src/config/groups/chunk_cache.rs:10`), `XetConfig::with_high_performance()` does not change `chunk_cache` (`xet_config.rs`).
- Fixtures: `tests/testthat/fixtures/small.geojson`, `small.parquet`, `small.tif`. `read_xet_vector` tests at `test-arrow-spatial.R:113-150`.
- Dirty tree at branch point: none for code. `EXECUTION_PLAN_10.md` (this file) and `PROMPT_TEMPLATE_10.md` / `STATE_10.md` are new in this orchestration.

## Decision log (dated)

| # | Decision | Source |
|---|---|---|
| D1 | Remove the three functions in 0.2.0 without deprecation. | ADR 0004, option 2. User agreed 2026-10-17. |
| D2 | Per-client config via optional args on `xet_client_new()`. `NULL` means hf-xet's value (environment or default). | ADR 0004. User agreed. hf-xet support verified. |
| D3 | `high_perf = TRUE` applies hf-xet's preset after the environment. The help text says so. | ADR 0004, "Configuration rules". |
| D4 | Vector argument named `ext`, not `format`. | ADR 0004. Value is a file extension. |
| D5 | Range, multi-file, vendoring deferred to 0.3.0 or later. | User agreed to scope 2026-10-17. |
| D6 | Root files deleted in this release. | User agreed 2026-10-17. Checked in T6. |
| D7 | `DESCRIPTION` becomes 0.2.0 at the gate, not in a worker task. `Cargo.toml` becomes 0.2.0 in T5 (it is not published, `publish = false`). | Revised 2026-10-18 from plan 9 D12 so that the crate version and DESCRIPTION can match at release. |
| D8 | Worker models: Haiku for T1, T2, T3, T4, T6, T8. Sonnet for T7. T5, T9 and T10 are not in the approved list; picked here: T5 Sonnet (Cargo lock and dependency removal), T9 Sonnet (several doc files must agree), T10 Haiku (one file). Escalation: Sonnet. | User approved the first list 2026-10-18. The other three are my picks; flagged in Judgment calls. |
| D9 | Concurrency: at most 2 workers at once. Each worker runs in its own worktree when its wave has more than one task. | User agreed to the default 2026-10-18. |
| D10 | Acceptance: each worker runs only its targeted tests. The orchestrator runs the routine suite serially at the end of each wave. Live suite is user-run at the gate. | User agreed 2026-10-18. |
| D11 | No exact-export test. | User decided 2026-10-18. The draft gate step G2 is dropped. |
| D12 | Commits: one per task, conventional format, no wave or task numbers. STATE and task-file commits are a separate `docs(planning)` commit per wave. | `git-workflow-standards`. |

## Judgment calls (flagged for review)

- **J1.** D8 picks for T5, T9, and T10 are not in the approved list.
- **J2.** T4 deletes `test-utils.R` and `test-parallel-downloads.R` whole, and only line ranges from `test-edge-cases.R`. If a deleted file contains a test of live code, the worker stops and reports (see T4).
- **J3.** `ext` validation rule in T8: one non-empty string, letters and digits only. Stricter than "no dot or path separator", which the draft allowed. Simpler to explain and prevents path tricks.
- **J4.** T7 maps the R arguments to hf-xet config keys with `with_config`. The string format for `client.read_timeout` is confirmed by the worker in Analysis (Duration parser), not assumed.
- **J5.** T9's README acceptance check compared bullet line counts. Baseline counts differ (29 vs 26) because `README.md` is hard-wrapped. The check now compares the set of export names in the bullets. Recorded at the pre-wave step, 2026-10-18.

## Hazards

- **H1.** `HF_TOKEN` is in the environment during the live run. Live runs are orchestrator-only and never write logs. Workers never read `.env` or print environment variables.
- **H2.** `src/Makevars` and `src/entrypoint.o` are restored before every commit and never staged.
- **H3.** Worktrees and Cargo. Each worktree has its own `src/rust/target` unless Cargo shares one. Pre-wave step P4 checks this. If not shared, a Rust-touching worker pays a cold build (5-10 minutes). Only T5 and T7 build Rust.
- **H4.** `R CMD INSTALL` is run only by the orchestrator, never by workers. Workers use `devtools::test()`, which loads the tree in place and avoids installing into the shared library from several worktrees at once.
- **H5.** `man/*.Rd` and `NAMESPACE` are regenerated by roxygen at the gate. Workers never hand-edit them.
- **H6.** `README.md` may be generated from `README.Rmd`. Re-knitting needs network access and a live `HF_TOKEN` path. T9 edits both files by hand to the same text and does not re-knit. The gate notes this.
- **H7.** extendr `Option<f64>` and `Option<bool>` arguments: the worker verifies in Analysis that `NULL` from R arrives as `None`. A `NULL` that fails to convert would break every `xet_client_new()` call.
- **H8.** `config.with_config()` returns `Result`. Any error must become an R error with no token in it. Config values are numbers, not secrets, but the no-canary rule still applies.

## Waves

| Wave | Tasks | Files (disjoint within the wave) | Batches (max 2 at once) |
|---|---|---|---|
| 1 | T1, T2, T3, T4, T5, T6 | see tasks | [T1, T2], [T3, T4], [T5, T6] |
| 2 | T7, T8 | T7: Rust lib, tests.rs, R/client.R, test-config.R, test-input-validation.R. T8: R/spatial.R, test-arrow-spatial.R. | [T7, T8] |
| 3 | T9, T10 | T9: README.Rmd, README.md, AGENTS.md. T10: NEWS.md. | [T9, T10] |

Wave 2 depends on wave 1 because T8 edits `R/spatial.R`, which T3 edits. Wave 3 depends on wave 2 because the docs describe T7 and T8's arguments.

### Task specs

Every task is one commit. Each worker's micro-plan has at most 12 steps.

**T1. Remove `read_xet_parquet_stream()`.**
- Repo: rxet. Model: Haiku. Depends on: none.
- Files, must edit: `R/arrow.R`, `R/stream.R`, `tests/testthat/test-arrow-spatial.R`, `tests/testthat/test-token-canary.R`.
- Files, can create: none.
- Spec: delete the function and its roxygen block at `R/arrow.R:135-164`. Delete `test_that("read_xet_parquet_stream returns ...")` at `test-arrow-spatial.R:51-58`. In `test-token-canary.R`, delete the two tests at `261-267` and `339-343`. In `R/stream.R:17`, change the sentence to name `read_xet_parquet()` or remove the parenthetical. Do not touch `man/`, `README.*`, `AGENTS.md`, or `NEWS.md`. Those are handled in T9, T10, and the gate.
- Do not touch: `R/spatial.R`, `R/connection.R`, `R/utils.R`, `README.*`.
- Grep anchors: `read_xet_parquet_stream` (expect 0 hits in the four files after the change).
- Acceptance: `grep -n read_xet_parquet_stream R/arrow.R R/stream.R tests/testthat/` returns nothing. Then `devtools::test(filter = "arrow-spatial|token-canary")` with `RXET_LOCAL_CAS_SERVER` set reports 0 failed, 0 errors.
- Commit: `refactor(arrow): remove read_xet_parquet_stream`.

**T2. Remove `xet_close_connection()`.**
- Repo: rxet. Model: Haiku. Depends on: none.
- Files, must edit: `R/connection.R`, `tests/testthat/test-connection.R`, `tests/testthat/test-live-hf.R`, `tests/testthat/test-local-download.R`.
- Spec: delete `xet_close_connection` and its roxygen (`R/connection.R:81` onward). In `test-connection.R`, delete the three `xet_close_connection` tests (lines 14-29) because the behavior they test is removed. At line 54, replace `xet_close_connection(conn)` with `close(conn)` and keep the `expect_null(...)` wrapper. In `test-live-hf.R:118` and `test-local-download.R:98`, replace `expect_no_error(xet_close_connection(conn))` with `expect_no_error(close(conn))`. Do not touch README or NEWS.
- Do not touch: `R/stream.R`, `R/arrow.R`, `R/spatial.R`.
- Grep anchors: `xet_close_connection`.
- Acceptance: `grep -rn xet_close_connection R tests` returns nothing. `devtools::test(filter = "connection|local-download")` with `RXET_LOCAL_CAS_SERVER` set reports 0 failed, 0 errors. `test-live-hf.R` is not run; the grep is its check.
- Commit: `refactor(connection): remove xet_close_connection`.

**T3. Remove `ext` from `read_xet_raster()`.**
- Repo: rxet. Model: Haiku. Depends on: none.
- Files, must edit: `R/spatial.R`.
- Spec: change the signature at line 73 to `read_xet_raster <- function(handle, file_hash, file_size, ...)`. Delete the `if (!is.null(ext))` block at lines 92-95 and return `rast`. Delete the `@param ext` line (10) and the sentence at lines 21-22 about the crop. Keep the `terra::crop` example at line 34. The roxygen memory text stays unchanged.
- Do not touch: `R/arrow.R`, `R/connection.R`, `tests/`, `README.*`. The `ext` test references do not exist (checked 2026-10-18).
- Grep anchors: `ext` in `R/spatial.R`, lines 10, 21-22, 73, 92-95.
- Acceptance: `grep -n "ext = NULL\|is.null(ext)\|@param ext" R/spatial.R` returns nothing. `devtools::test(filter = "arrow-spatial")` with `RXET_LOCAL_CAS_SERVER` set reports 0 failed, 0 errors.
- Commit: `refactor(spatial): remove ext argument from read_xet_raster`.

**T4. Remove dead helpers and their tests.**
- Repo: rxet. Model: Haiku. Depends on: none.
- Files, must edit: `tests/testthat/test-edge-cases.R`. Files, must delete: `R/utils.R`, `tests/testthat/test-utils.R`, `tests/testthat/test-parallel-downloads.R`.
- Spec: confirm first (grep `R/` outside `utils.R` for each helper name): none. Read `test-utils.R` in full and confirm every test calls only helpers in `R/utils.R`; if any test calls live code, STOP and report. Read `test-parallel-downloads.R` in full: tests at 3, 22, 45, 59 use `process_file_batch` (undefined), dead helpers, or nothing. Delete the file. In `test-edge-cases.R`, delete lines 3-64 and 80-108. Keep 65-79 and 109-118.
- Do not touch: `R/client.R`, `R/spatial.R`, `R/connection.R`. Do not edit `man/`.
- Grep anchors: `make_result|format_action|determine_action|evict_old_cache|evict_excess_cache|maintain_cache`.
- Acceptance: `grep -rln "make_result\|format_action\|determine_action\|evict_\|maintain_cache" R tests` returns nothing. `devtools::test(filter = "edge-cases")` reports 0 failed, 0 errors.
- Commit: `refactor(utils): remove unused cache and result helpers`.
- Baseline note: if `test-parallel-downloads.R` test 1 passes at P2, record it. The file is still deleted, because `process_file_batch` is undefined.

**T5. Cargo cleanup and version.**
- Repo: rxet. Model: Sonnet (J1). Depends on: none.
- Files, must edit: `src/rust/Cargo.toml`, `src/rust/Cargo.lock`.
- Spec: remove `tokio`, `byteorder`, `lru`, `crossbeam-channel`, `futures-util` from `[dependencies]`. Set `version = '0.2.0'`. Run `cd src/rust && cargo check --tests`. Commit `Cargo.lock` with the change. Do not edit `lib.rs`. T7 owns it.
- Do not touch: `src/rust/src/*`, `DESCRIPTION`.
- Grep anchors: `Cargo.toml` `[dependencies]`.
- Acceptance: `cd src/rust && cargo check --tests` exits 0. `grep -rn "tokio\|byteorder\|lru\|crossbeam\|futures_util" src/rust/src` returns nothing.
- Commit: `chore(rust): drop unused crates and set crate version to 0.2.0`.

**T6. Remove root model-sync files.**
- Repo: rxet. Model: Haiku. Depends on: none.
- Files, must edit: `.Rbuildignore`. Files, must delete: `TODO.md`, `models.json`, `xet-sync.R`, `xet-sync.sh`, `check-updates.sh`.
- Spec: for each deleted file, grep the repo (excluding `planning/`, `rxet.Rcheck/`, and the file itself) for its name. If any reference is found outside those, STOP and report the file and line. Otherwise delete the five files and remove their five lines from `.Rbuildignore` (`^xet-sync\.R$`, `^xet-sync\.sh$`, `^check-updates\.sh$`, `^models\.json$`, `^TODO\.md$`). Keep all other lines.
- Do not touch: `planning/`, `docs/`, `.github/`, `.gitignore`.
- Acceptance: `git ls-files | grep -E "^(TODO.md|models.json|xet-sync\.(R|sh)|check-updates\.sh)$"` returns nothing. `.Rbuildignore` no longer names them.
- Commit: `chore: remove model-sync scripts and config from the repo`.

**T7. Per-client configuration.**
- Repo: rxet. Model: Sonnet. Depends on: wave 1 complete (T5 Cargo state).
- Files, must edit: `src/rust/src/lib.rs`, `src/rust/src/tests.rs`, `R/client.R`, `tests/testthat/test-config.R`, `tests/testthat/test-input-validation.R`.
- Spec:
  1. Analysis first: read `xet-runtime-1.7.0/src/config/macros.rs` `parse_config_value` and confirm the accepted string format for `client.read_timeout`. Confirm that `NULL` from R arrives as `None` for `Option<f64>`. Record both in `## Notes`.
  2. In `lib.rs`, change `xet_init_client` (line 70) to take `timeout_sec: Option<f64>`, `cache_bytes: Option<f64>`, `high_perf: bool`. Factor a pure `fn build_config(timeout_sec, cache_bytes, high_perf) -> extendr_api::Result<XetConfig>` that calls `XetConfig::new()`, then `with_high_performance()` if `high_perf`, then `with_config("client.read_timeout", ...)` and `with_config("chunk_cache.size_bytes", ...)` when given. Pass the result to `new_with_config` (line 75). Map `with_config` errors to `Error::Other` without echoing any token.
  3. In `tests.rs`, add unit tests for `build_config`: `None` values leave `chunk_cache.size_bytes` unchanged from `XetConfig::new()`; `Some(0.0)` sets it to 0; `high_perf = true` changes concurrency fields.
  4. In `R/client.R`, add `timeout_sec = NULL`, `cache_bytes = NULL`, `high_perf = FALSE` to `xet_client_new()`. Validate: `timeout_sec` and `cache_bytes` are `NULL` or a single finite non-negative whole number; `high_perf` is a single logical. Pass them to `.Call`. Update roxygen with the rules from ADR 0004 and the corrected `high_perf` text (no claim about the chunk cache).
  5. Delete `xet_config_environment()` and its roxygen (`R/client.R:62-122` region). Remove all `Sys.setenv` calls from `R/`.
  6. Rewrite `tests/testthat/test-config.R` (delete all `xet_config_environment` tests) with validation tests for the three new args. Replace the `describe("xet_config_environment")` block at `test-input-validation.R:183-194` with the same validation cases for `xet_client_new()`.
- Do not touch: `R/spatial.R`, `R/arrow.R`, `README.*`, `AGENTS.md`, `NEWS.md`, `DESCRIPTION`.
- Grep anchors: `lib.rs:70-80`, `R/client.R:62-122`, `test-input-validation.R:183-194`.
- Acceptance:
  - `cd src/rust && cargo test build_config` if the test binary links (see P3); otherwise `cargo check --tests` and record the link result.
  - `devtools::test(filter = "config|input-validation|client")` with `RXET_LOCAL_CAS_SERVER` set reports 0 failed, 0 errors.
  - `grep -rn "xet_config_environment\|Sys.setenv" R` returns nothing.
- Commit: `feat(client): configure timeout, cache and high performance per client`.
- Escalation: Sonnet is the mid-tier. If it fails acceptance twice, the orchestrator writes the micro-TODO and runs the task itself.

**T8. `read_xet_vector(ext = NULL)`.**
- Repo: rxet. Model: Haiku. Depends on: T3 (wave 1 edits `R/spatial.R`).
- Files, must edit: `R/spatial.R`, `tests/testthat/test-arrow-spatial.R`.
- Spec: change the signature at `R/spatial.R:167` to `read_xet_vector <- function(handle, file_hash, file_size, ext = NULL, ...)`. Validate: if not `NULL`, one non-empty string with letters and digits only (J3). Build the temp file with `tempfile(fileext = paste0(".", ext))` when given, else `tempfile()`. Update the roxygen: replace "`read_xet_vector()` has no format argument of its own" with a description of `ext`. Add one test at `test-arrow-spatial.R` near line 113: `read_xet_vector(client, info$hash, info$file_size, ext = "geojson")` returns the same three-feature result as the existing test. Add one test that `ext = "geo.json"` errors.
- Do not touch: `R/client.R`, `R/stream.R`, `README.*`.
- Grep anchors: `R/spatial.R:167` (signature), roxygen around `:118-126`.
- Acceptance: `RXET_LOCAL_CAS_SERVER=$(command -v local_cas_server) Rscript -e 'devtools::test(filter = "arrow-spatial")'` reports 0 failed, 0 errors.
- Commit: `feat(spatial): add ext argument to read_xet_vector`.

**T9. Docs and surface.**
- Repo: rxet. Model: Sonnet (J1). Depends on: wave 2 complete.
- Files, must edit: `README.Rmd`, `README.md`, `AGENTS.md`.
- Spec: in `README.Rmd` and `README.md`, identically:
  - Remove the `xet_config_environment()` examples (`README.Rmd:147-153`, `README.md:151-157`). Move the three settings into the `xet_client_new()` example.
  - Remove the API list entries and the status-table rows for `xet_config_environment`, `xet_close_connection`, `read_xet_parquet_stream` (`README.Rmd:190,202,207,269,278,280`; `README.md:197,214,219,322,334,337`).
  - Show `ext` removed from `read_xet_raster`. Add `ext` to `read_xet_vector` in its signature line.
  - State 10 exports.
  - Do not re-knit (H6).
  In `AGENTS.md`: remove `read_xet_parquet_stream` from the optional-integrations table (`:176`) and from the memory and 2 GiB bullets (`:181-182`). Replace them with `read_xet_parquet()`. Remove any mention of `xet_config_environment`. Update the Experimental list and the API surface, if present.
- Do not touch: `R/`, `tests/`, `NEWS.md`, `man/`.
- Grep anchors: `README.Rmd` lines above; `AGENTS.md:170-190`.
- Acceptance: `grep -n "read_xet_parquet_stream\|xet_close_connection\|xet_config_environment" README.Rmd README.md AGENTS.md` returns nothing. The set of export names in the ``- `name(` `` bullets matches between `README.Rmd` and `README.md`. Do not compare line counts: `README.md` is hard-wrapped (baseline 29 vs 26 bullet lines, J5).
- Commit: `docs: update README and AGENTS for the 0.2.0 API`.

**T10. NEWS.**
- Repo: rxet. Model: Haiku (J1). Depends on: wave 2 complete.
- Files, must edit: `NEWS.md`.
- Spec: add `# rxet 0.2.0` above `# rxet 0.1.1`. Sections: "Breaking changes" (each removed function with its replacement: `read_xet_parquet_stream()` to `read_xet_parquet()`; `xet_close_connection()` to `close()`; `xet_config_environment()` to the `xet_client_new()` arguments; `ext` on `read_xet_raster()` to `terra::crop()`). "Features" (`timeout_sec`, `cache_bytes`, `high_perf` on `xet_client_new()`; `ext` on `read_xet_vector()`). "Fixes" (`high_perf` help text; the cache claim is removed). "Internal" (dead helpers removed; unused Rust crates removed; root files removed). Use the existing 0.1.1 entry's style. Do not edit the 0.1.1 entry.
- Acceptance: `grep -n "^# rxet 0.2.0" NEWS.md` returns one line, above `^# rxet 0.1.1`.
- Commit: `docs(news): add 0.2.0 breaking changes`.

### Gate (orchestrator, serial)

- G1. Set `DESCRIPTION` version to `0.2.0` (D7). Run `R CMD INSTALL .`. Run `Rscript -e 'roxygen2::roxygenise()'`. Expect: `man/read_xet_parquet_stream.Rd`, `man/xet_close_connection.Rd`, `man/xet_config_environment.Rd` deleted; `man/make_result.Rd` and the other five helper pages deleted; `man/xet_client_new.Rd` and `man/read_xet_raster.Rd`, `man/read_xet_vector.Rd` updated; `NAMESPACE` loses the three exports. Read the `NAMESPACE` diff. No exact-count test (D11).
- G2. Routine suite (serial): `RXET_LOCAL_CAS_SERVER=$(command -v local_cas_server) Rscript -e 'devtools::test()'`. Record counts. Baseline is P2.
- G3. Clean-archive `R CMD check --no-manual` (`_R_CHECK_FORCE_SUGGESTS_=false`). Record Status.
- G4. Grep gate: `grep -rn "read_xet_parquet_stream\|xet_close_connection\|xet_config_environment\|make_hf_api_request" R tests README.Rmd README.md AGENTS.md NEWS.md` returns hits only inside the 0.2.0 "Breaking changes" section of `NEWS.md`.
- G5. Live suite: user runs `RXET_LIVE_TESTS=1 Rscript -e 'devtools::test(filter = "live-hf")'` with `HF_TOKEN` exported. Required before tagging. Orchestrator does not run it.
- G6. Commit the gate: `chore: release 0.2.0 metadata and regenerated docs`.
- G7. Tag `v0.2.0` and push only after the user approves. Not in this plan's default path.

## Pre-wave steps (orchestrator, before wave 1)

- P1. Commit this plan and its companions: `docs(planning): add 0.2.0 orchestration plan 10`.
- P2. Baseline: `R CMD INSTALL .` exit 0. Routine suite with `RXET_LOCAL_CAS_SERVER`. Record pass, fail, error, and skip counts, and the names of any failing tests. Record whether `test-parallel-downloads.R` test 1 passes. Record the `R/` and `README.md` `^- \`` line counts for T9.
- P3. `cd src/rust && cargo check --tests && cargo test --lib` — record whether the test binary links. If it does not link, T7 falls back to `cargo check --tests` plus an R-level validation test. The fallback is noted in STATE_10.
- P4. Worktree build: check whether `pkgbuild` honors `CARGO_TARGET_DIR`. Record in STATE_10. Either outcome is acceptable; a cold build costs time only.
- P5. `git status` clean on `v0.2.0` except the plan files from P1.

## Verification of the high-performance claim

The R help said `high_perf` "disables chunk cache". hf-xet's `with_high_performance()` (`xet-runtime-1.7.0/src/config/xet_config.rs`) sets data concurrency, adaptive-concurrency bounds, reconstruction fetch sizes, and download buffers. It does not change `chunk_cache`. The text is corrected in T7. A user who wants no cache must pass `cache_bytes = 0`.

## Self-review (2026-10-18)

Two passes, run by the planner, not sub-agents.

- **Spec axis.** Every ADR 0004 item maps to a task: three removals (T1, T2, T7), raster `ext` (T3), per-client config and the `high_perf` text (T7), vector `ext` (T8), dead helpers (T4), crates and version (T5, gate), root files (T6), docs (T9), NEWS (T10). Every user answer maps to a decision (D1-D12). Deferred items are listed under out of scope. No task adds work the user did not ask for.
- **Standards axis.** Each task names its files, anchors, acceptance command, and commit message. Wave 1 files are disjoint (checked against the anchor list). Wave 2 files are disjoint, and T8 starts after T3. Wave 3 files are disjoint. Acceptance greps are scoped to specific patterns. Serial suite rule, escalation rule, and no-`R CMD INSTALL`-by-workers rule are present.
- **Fixed in review:** an over-broad `ext` grep in T3; a dropped `expect_null` wrapper in T2; a README count check that compared against a moving baseline in T9; the ADR 0004 validation bullet that still required an export count (now the gate's `NAMESPACE` review).
- **Judgment calls flagged:** J1-J4.

## Open items

- P3: whether the Rust test binary links with extendr. Decided by the pre-wave run.
- P4: whether worktree builds share a Cargo target. Decided by the pre-wave run.
- J1-J4: judgment calls above, for your review.
