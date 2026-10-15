# Execution Plan 1 — Freeze v0.1 Scope, Support Policy, and Acceptance Contract

## Goal & Scope

### Goal

Define an explicit, testable contract for the first public `rxet` release. Preserve APIs that have been built and work; defer only functionality confirmed to be a stub or claims that cannot be substantiated. Establish the initial platform, source-build/dependency, authentication, and integration-test policies so later implementation plans can address release blockers without silently deleting useful capabilities or expanding scope.

### In scope

- Inventory all public exports, help pages, README claims/examples, package metadata, native registrations, current tests, and the known release-readiness findings in `MASTER_PLAN.md`.
- Classify each exported API and material capability as supported for v0.1, experimental, or deferred, based on evidence and explicit decisions.
- Set the platform and release distribution target: Linux, macOS, and minimal Windows support are required; CRAN is the intended eventual target if feasible.
- Record the user's instruction to pin hf-xet. Plan an initial source release with online dependency access and record vendoring/CRAN readiness as a later phase, not a Phase 1 exit criterion.
- Establish a policy for opt-in live integration tests against the user's `brownag/rxet-test-data` dataset repository that do not expose credentials and are not required in public CI.
- Record decisions in this execution plan and phase state. This phase is planning/policy only; it does not implement product behavior, change exports, repair packaging, or publish a release.

### Out of scope / explicit deferrals

- Implementing/removing/renaming APIs or revising README/help/package metadata; these belong to later master-plan phases after the scope contract is approved.
- Pinning hf-xet or changing Cargo/Makevars/build files; Phase 3.
- Building a local protocol server, writing live integration tests, or validating API calls against Hugging Face; Phase 5.
- Fixing Rust safety/concurrency, input validation, or atomic-download behavior; Phase 4.
- Producing the vendor archive/configuration or satisfying CRAN offline build rules. User confirmed this is needed for eventual CRAN deployment but “doesnt need to be the first thing we tackle”; master-plan Phase 3 should address it after scope/support decisions. CRAN submission is not authorized by this plan.
- Establishing the complete platform support matrix or proving macOS/Windows builds; Phase 3 owns build validation.
- Tagging, uploading, or publishing a release.

### Verbatim user constraints

> "I dont want to remove anything that we have built that works but fine with deferring anything that is actually just a stub or deferred. agree generally but we probably should get minimal windows support. pin the hf-xet. to deploy on cran we will need to vendor but it doesnt need to be the first thing we tackle."

> "yes to all"

The user accepted the preceding recommendations for preserving supported/working features, Linux + minimal Windows as required platforms, pinning hf-xet, later vendoring for CRAN deployment, and opt-in secret-free-in-CI integration testing. The user subsequently confirmed macOS is also in scope, selected `brownag/rxet-test-data` for live testing, and confirmed CRAN is the intended eventual target if feasible. The initial distribution recommendation was a GitHub/source release with no prebuilt binaries; treat this as the initial route unless clarified during plan approval.

## Recon log (facts from repository)

- Repo root: `/home/andrew/workspace/rxet`; package guidance is in `AGENTS.md`. No repo-local `docs/decisions/` ADRs and no prior `EXECUTION_PLAN_N.md` or `STATE_N.md` exist. The only plan input is `planning/MASTER_PLAN.md`.
- Entry points: `DESCRIPTION` (30 lines), `NAMESPACE` (16), `README.md` (292), `README.Rmd` (283), `R/` wrappers (18–185 lines each), `src/rust/src/lib.rs` (335), `src/rust/Cargo.toml` (25), `src/Makevars.in` (47), `tools/config.R` (112), `tools/msrv.R` (116), `configure` (3), `configure.win` (2), `tests/hf_test_setup.R` (47), and test files under `tests/testthat/` (25–366 lines).
- Thirteen public exports appear in `NAMESPACE`: `read_xet_parquet`, `read_xet_parquet_stream`, `read_xet_raster`, `read_xet_vector`, `xet_client_close`, `xet_client_new`, `xet_close_connection`, `xet_config_environment`, `xet_download_file`, `xet_open_connection`, `xet_stream_range`, `xet_stream_raw`, and `xet_upload_file`.
- R API implementation anchors: client/config in `R/client.R`; disk download in `R/download.R`; upload in `R/upload.R`; raw/range APIs in `R/stream.R`; full-memory `rawConnection` in `R/connection.R`; Arrow in `R/arrow.R`; spatial adapters in `R/spatial.R`; Rust bindings in `src/rust/src/lib.rs`.
- README advertises `xet_get_file_metadata()`, but no such R/Rust function or export exists. README and help also assert zero-copy, parallelism, push-down, range/read behavior and other capabilities that need classification against real implementation/evidence. Existing Arrow/spatial/connection helpers materialize full files through `xet_stream_raw()`/`xet_open_connection()`; not remote range-backed connections.
- Rust currently exposes client init/close, whole-file download/upload, full raw stream, and range stream. Current code compiles and client init/close succeeds; these facts do not establish live operation correctness. Mutex-held network I/O, unbounded in-memory collection, and direct writes to final download paths are existing risks for later phases.
- Build state from initial review: `R CMD build .`, Linux `R CMD INSTALL .`, and `cargo check` succeeded in the observed environment; `_R_CHECK_FORCE_SUGGESTS_=false R CMD check --no-manual ...` had one warning (undeclared `rprojroot` in tests) and one NOTE (license metadata). Forced-suggests check could not run fully because `arrow`, `uuid`, and `covr` were absent.
- Valid package test command is `devtools::test(reporter="summary")`, not bare `testthat::test_dir()` without loading package. The observed test run had 3 failures due to absent `uuid`, and 8 skips due to optional packages/credentials/environment. It is not a clean baseline. HF-gated tests only check some failure/validation paths and do not prove successful transfers.
- The user agreed to opt-in live integration tests against `brownag/rxet-test-data`, with routine tests offline/secret-free, credentials from environment variables only, no live credentials in public CI, and a manual live-test run before release.
- Platform evidence: `tools/config.R` selects `src/Makevars.win.in` on Windows, but only `src/Makevars` and `src/Makevars.in` exist. Windows build has not been validated. User asked for minimal Windows support. Linux is validated only in the current environment. User confirmed macOS is in scope; it also remains unvalidated.
- Dependency state: `src/rust/Cargo.lock` is ignored and untracked/absent; hf-xet Git dependency in `src/rust/Cargo.toml` has no explicit rev. The user explicitly requested pinning hf-xet. A source build currently accesses online dependencies. Vendoring is required for eventual CRAN deployment but explicitly deferred from the first plan. User confirmed CRAN is the intended eventual target if feasible.
- Keep existing user workspace state: `planning/`, `rxet.Rcheck/`, and `rxet_0.1.0.tar.gz` were untracked at reconnaissance. Do not delete or stage those generated/check artifacts as part of this policy phase.

### Baseline status before execution

This phase is a planning/policy artifact phase and does not modify runtime/package files. Existing tests are not green in the observed environment. Before implementation waves begin, future plans must rerun the correct test/check commands after resolving dependency availability, and must record their own baseline. Do not claim this phase establishes a green code baseline.

## Decisions recorded

| Date | Decision | Rationale / consequence |
|---|---|---|
| 2026-10-15 | Preserve APIs that are built and work; defer only confirmed stubs/deferred features or unsupported claims. | Avoid removing useful functionality solely because the broader product claims are inaccurate. Classify APIs by evidence; later plans can improve docs, test or defer individually. |
| 2026-10-15 | Linux and minimal Windows support are required for initial release planning. | Windows must be included in support policy; Phase 3 must inspect/repair its missing template and verify a minimal source build. |
| 2026-10-15 | Pin the hf-xet Git dependency. | Dependency revision must be explicit in the Phase 3 build plan. |
| 2026-10-15 | Eventual CRAN deployment requires vendoring, but vendoring is not the first priority. | Defer vendor archive/configuration to the packaging phase; do not make it a Phase 1 exit criterion. CRAN publication remains unauthorized. |
| 2026-10-15 | Keep routine tests offline/secret-free; live tests are opt-in, use environment credentials and a dedicated known fixture, are not required in public CI, and must be run manually before release. | Makes test runs safe and CI-reproducible while retaining a real-backend acceptance gate. |
| 2026-10-15 | User accepted recommendation to preserve functional APIs, classify the existing API set, and defer only actual stubs/unsupported capabilities. | No automatic API removal is authorized; evidence and explicit policy must precede any deprecation/removal. |
| 2026-10-15 | macOS is in scope along with Linux and minimal Windows support. | Phase 3 must verify all three OS targets or report any infeasible target for an explicit user decision. |
| 2026-10-15 | Use the user's Hugging Face dataset repository `brownag/rxet-test-data` for opt-in manual live integration testing. | Phase 5 must inspect repository contents/access, define safe read operations and any write-test policy, confirm required credential scope, and never put credentials in source or public CI. |
| 2026-10-15 | Initial route is a GitHub/source release without prebuilt binaries; CRAN is the intended eventual distribution target if feasible. | Phase 3 should plan dependency pinning and later vendorization for CRAN; Phase 7 performs CRAN-oriented checks. This is not authorization to submit. |
| 2026-10-15 | Preserve currently implemented APIs provisionally; classify an API as supported only after success behavior is demonstrated using actual package behavior, preferably against the chosen live dataset where appropriate. | If success behavior is not yet demonstrated, retain provisionally but label experimental or defer its supported claim. Do not remove a working function without explicit approval. |
| 2026-10-15 | API evidence threshold: record an export as `supported` only when a success-path test demonstrates its real behavior through actual package behavior; network-backed exports with only validation/error-path evidence are `experimental pending evidence`; a genuine stub/temp-file/internal-tagged export has its supported claim `deferred`. | Prevents compile success, an exported wrapper, or error-path tests from being misread as proof of a working feature. All 13 exports remain in `NAMESPACE`; the label bounds the supported claim, it does not remove the function. |
| 2026-10-15 | Supported for v0.1: `xet_client_new`, `xet_client_close`, `xet_config_environment`. | Each has genuine R-level success-path coverage (`test-client.R:3–27,44–62`; `test-config.R`). They make no live network call, so env-var consumption by the pinned hf-xet stays a Phase 3 verification item. |
| 2026-10-15 | Experimental pending evidence for v0.1: `xet_download_file`, `xet_upload_file`, `xet_stream_raw`, `xet_stream_range`, `xet_open_connection`, `xet_close_connection`, `read_xet_parquet`, `read_xet_raster`, `read_xet_vector`. | Retained and exported but the supported claim is bounded until real success evidence exists (Appendix A shows validation/error-path or no success evidence, and `xet_close_connection`'s only test is HF_TOKEN-gated and asserts an error from `xet_open_connection`). |
| 2026-10-15 | Deferred support claim: `read_xet_parquet_stream`. | No test references it; it writes a temp `.parquet` and is `@keywords internal` yet exported. Retain provisionally; Phase 2 decides de-export vs internal and corrects the temp-file claim. |
| Phase 3 (technical) | Rust MSRV/toolchain and R minimum version — technical validation items, not unresolved user policy. | Current declarations are R >= 4.2 and Rust >= 1.70; actual compatibility not validated. Phase 3 determines exact values from dependency/platform checks; no Phase 1 policy change is required. |

## Support policy decisions — v0.1 API disposition (Task 1.2.1)

This is the final v0.1 disposition of every NAMESPACE export, derived from the Appendix A evidence. Dispositions are applied under the evidence threshold above: `supported` = success-path behavior demonstrated; `experimental pending evidence` = retained/exported but supported claim bounded until success evidence exists; `deferred support claim` = not promoted pending an API/docs decision. No export is removed. The three client/config exports are local and make no live network call; their env-var consumption by the pinned hf-xet remains a Phase 3 verification item.

| Export | Group | v0.1 disposition | Rationale (Appendix A evidence) | Downstream phase handoff |
|---|---|---|---|---|
| `xet_client_new` | Client lifecycle | supported | `success-path`: `test-client.R:3–27` (non-empty UUID handle); no network contact at init | Phase 3 confirm env-var config consumed by pinned hf-xet; Phase 5 live client-setup smoke |
| `xet_client_close` | Client lifecycle | supported | `success-path`: `test-client.R:22–27,44–62` (silent close, `NULL` return, multi-client) | Phase 4 close-vs-in-flight operation semantics |
| `xet_config_environment` | Configuration | supported | `success-path`: `test-config.R` asserts env-var effects; pure R, no I/O | Phase 3 prove pinned hf-xet honors `HF_XET_*` vars |
| `xet_close_connection` | Connection helper | experimental pending evidence | `none` success evidence: only `test-connection.R:14–25`, which is skipped unless `HF_TOKEN` is set and asserts an error from `xet_open_connection` rather than a successful close | Phase 5 add a success-path close test; Phase 2 may reconsider whether it stays a standalone export |
| `xet_download_file` | Disk download | experimental pending evidence | `validation/error-path` only: `test-input-validation.R:34–61`; no live byte-integrity evidence; writes directly to final `dest_path` | Phase 4 atomic download/cleanup; Phase 5 live byte-integrity download via `brownag/rxet-test-data` |
| `xet_upload_file` | Upload | experimental pending evidence | `validation/error-path` only: `test-input-validation.R:119–127`; endpoint/auth/commit semantics unspecified | Phase 5 determine endpoint/auth/commit semantics and obtain live evidence; defer if unsupported |
| `xet_stream_raw` | Raw stream | experimental pending evidence | `validation/error-path` only: `test-streaming.R:17–33`, `test-input-validation.R:63–77`; whole file buffered into a `Vec<u8>` then `raw()` | Phase 4 size/overflow policy; Phase 5 live byte-return; Phase 2 correct "returns metadata" doc |
| `xet_stream_range` | Range stream | experimental pending evidence | `validation/error-path` only: `test-streaming.R:35–51`; `test-stream-range.R` never calls the function; result still fully buffered and needs full `file_size` | Phase 4 boundary validation; Phase 5 byte-exact range test (needs a larger fixture); Phase 2 fix return-value/example mismatch |
| `xet_open_connection` | Connection helper | experimental pending evidence | `validation/error-path` only: `test-connection.R:3–12`; materializes the whole file via `xet_stream_raw`, not a remote/seek-backed connection | Phase 6 honest memory/I/O docs; Phase 5 success evidence |
| `read_xet_parquet` | Arrow adapter | experimental pending evidence | `validation/error-path` only: `test-arrow-spatial.R:3–26`; whole file into memory, README push-down claim unsubstantiated | Phase 6 prove `arrow::read_parquet()` accepts the `rawConnection`; remove push-down claim |
| `read_xet_parquet_stream` | Arrow adapter | deferred support claim | `none`: no test references it; writes a temp `.parquet`; `@keywords internal` yet exported | Phase 2 decide de-export vs internal and correct the temp-file claim |
| `read_xet_raster` | Spatial adapter | experimental pending evidence | `validation/error-path` only: `test-arrow-spatial.R:28–37`; whole file into memory; "partial reads/COG windows" claim unsubstantiated | Phase 6 prove `terra::rast()` reads the `rawConnection`; bound the claim |
| `read_xet_vector` | Spatial adapter | experimental pending evidence | `validation/error-path` only: `test-arrow-spatial.R:39–48`; whole file into memory; "GDAL can seek" claim unsubstantiated for a `rawConnection` | Phase 6 prove `sf::st_read()` reads the `rawConnection`; bound the claim |

### Stale / non-exported claim disposition (not API entries)

| Claim (Appendix A) | Disposition | Downstream phase handoff |
|---|---|---|
| Phantom `xet_get_file_metadata()` in README | Remove claim (no R/Rust/NAMESPACE/man implementation) | Phase 2 |
| Zero-copy / "without temporary files" / "without intermediate disk copies" | Reword to real in-memory/temp behavior | Phase 2 (truth of optional-integration paths verified Phase 6) |
| Random-access "10% of file in seconds" | Mark experimental; drop the speed claim | Phase 2; Phase 5 fixture permitting measurement |
| "Parallel downloads with automatic token refresh and retry" | Remove claim (no parallel/refresh/retry logic exists) | Phase 2 |
| "Production-ready with panic recovery and resource cleanup" | Downgrade; panic recovery real, cleanup is a placeholder | Phase 2; Phase 4 cleanup semantics |
| Performance table (metadata fetch, token refresh, worker speedup, byte-range multiples) | Remove/defer until measured | Phase 2 |
| "Parallelism: 4 workers typically achieve 3.0–3.8x" | Remove claim (no worker pool implemented) | Phase 2 |
| Architecture "Async I/O with Tokio (non-blocking to R)", bounded channels, LRU shard cache, O(log N) binary search | Remove; describe the real blocking-under-mutex model | Phase 2 |
| `xet_stream_raw` "returns metadata about streaming operation" | Correct to "returns file bytes as `raw()`" | Phase 2 |
| `xet_stream_range` example `metadata`/`result$chunks_needed` | Correct examples to a `raw()` return | Phase 2 |
| FAQ metadata-shard overlapping-chunk explanation | Rewrite or remove | Phase 2 |
| FAQ "Client is thread-safe" / Shiny concurrency | Qualify after concurrency work | Phase 4; docs Phase 2 |
| `DESCRIPTION` "Supports chunked upload and download" | Keep provisionally, bound after evidence | Phase 5 evidence; Phase 2 wording |
| `read_xet_parquet_stream` `@keywords internal` yet exported | Resolve export-vs-internal conflict | Phase 2 |
| README Testing "Range downloads … byte-range accuracy", "Concurrent clients … stress testing" | Correct to actual mock/simulation tests | Phase 2 (facts from Phase 5) |
| `AGENTS.md` integer `u32` handles vs UUID character handles | Out-of-plan doc fix | Phase 2 |
| Benchmarking scripts `tools/benchmark.R`, `tools/benchmark-extended.R` | Substantiated at file level; keep and verify runnability | Phase 7 |

## Phase handoff (Task 1.2.1)

The frozen policy maps to the master-plan phases as follows; no downstream phase may widen the v0.1 support claim without new success evidence.

| Downstream phase | Handoff facts from this policy |
|---|---|
| Phase 2 — docs/API/metadata | Apply the stale/claim disposition table; resolve the `read_xet_parquet_stream` internal-tag conflict; correct `xet_stream_raw`/`xet_stream_range` docs and the `AGENTS.md` handle text; keep all 13 exports unless a documented API-boundary decision says otherwise. |
| Phase 3 — reproducible build & platforms | Pin the hf-xet revision; determine Rust MSRV and R minimum; validate Linux, macOS, and minimal Windows source builds; plan vendoring as later work (not a Phase 1 task); confirm the pinned hf-xet honors `HF_XET_*` env vars set by `xet_config_environment`. |
| Phase 4 — hardening | Atomic download destination; release the registry mutex around blocking I/O; size/offset validation for raw/range APIs; close-vs-in-flight semantics; remove placeholder drop/cleanup. |
| Phase 5 — real Xet verification | Opt-in live tests against `brownag/rxet-test-data` using environment credentials only, no live credentials in public CI, manual live run required before release; obtain success evidence for `xet_close_connection`, download, upload, raw, and range; record that the live repo currently lacks a large/multi-chunk, GeoTIFF, or write-target fixture. |
| Phase 6 — optional integrations & memory | Prove Arrow/terra/sf accept the `rawConnection`; document full-file buffering; bound or defer unsupported remote/seek/push-down claims. |
| Phase 7 — release validation | Run offline routine tests (secret-free) plus the manual live run; verify the source archive; obtain explicit user approval before tagging/publishing. |

## Decisions resolved / remaining

Resolved: macOS is in scope; `brownag/rxet-test-data` is the live-test repository; CRAN is the intended eventual target if feasible; APIs are preserved provisionally and receive supported status only after success behavior is tested through actual package behavior. Untested APIs remain experimental or have their supported claims deferred rather than being deleted by default. The v0.1 support dispositions in this plan resolve the remaining user-policy questions: platform scope (Linux + macOS + minimal Windows), initial distribution (GitHub/source, no prebuilt binaries), CRAN as eventual target with vendoring deferred, and the offline/opt-in live-test credential policy. No unresolved user-policy item changes platform, API, or distribution scope.

Remaining: only technical values — Rust MSRV/toolchain and the exact R minimum version — require validation in Phase 3. This is not a Phase 1 policy ambiguity; the current declarations (R >= 4.2, Rust >= 1.70) are unverified starting values until that phase establishes support.

## Wave table (draft for user approval)

This is a planning-only orchestration. It uses one task in each wave because Phase 1's inventory and policy recording are tightly coupled: parallel contributors could make inconsistent classifications or require shared edits to the decision record. No code implementation task is in scope. The remaining MSRV/toolchain and R minimum-version checks are recorded for Phase 3 rather than used to block this policy phase.

| Wave | Task | Goal | Depends on |
|---|---|---|---|
| 1 | `1.1.1.api-inventory` | Produce evidence-based inventory/classification of public functions and claims in the plan artifact. | None |
| 2 | `1.2.1.support-policy` | Record approved API boundary, evidence bar, platform/distribution, dependency/build and live-test policies; identify deferred capabilities for subsequent master-plan phases. | `1.1.1` |
| 3 | `1.3.1.phase-contract` | Final consistency check of decisions against master-plan Phase 1 exit gate; complete Phase 1 state/reports and identify handoff facts for Phase 2/3/5. | `1.2.1` |

## Task specifications

### Task 1.1.1 — API inventory and evidence classification

- **ID:** `1.1.1.api-inventory`
- **Repo:** `/home/andrew/workspace/rxet`
- **Depends on:** None
- **Files in scope:**
  - Must edit: `planning/EXECUTION_PLAN_1.md` (add the inventory appendix/table only).
  - Can create: `planning/.development/` scratch only (remove scratch created by this task before reporting; do not touch user-created artifacts).
  - Do not edit runtime source, tests, README/man pages, metadata, `MASTER_PLAN.md`, generated artifacts, or the user’s existing untracked check artifacts.
- **Spec:** Verify each of the 13 exports against its R definition, Rust registration/implementation where relevant, help page, README mentions, and existing tests. For each export, record: current observable behavior; whether actual success-path or only validation/error-path evidence exists; memory/I/O model; required optional dependencies or credentials; preliminary v0.1 status (`candidate supported`, `experimental pending evidence`, or `defer/remove claim as stub`); and specific fact/task needed to resolve unknowns. Include the README-only nonexistent `xet_get_file_metadata()` and unimplemented feature claims as non-exported claims, not API entries. The user's live-test repository is `brownag/rxet-test-data`; inspect its current dataset inventory without making writes. Do not make the final scope policy: inventory findings are evidence for the user decision in Task 1.2.1.
- **Grep anchors/reference implementations:** `NAMESPACE` `export(...)`; `R/client.R` functions `xet_client_new`, `xet_client_close`, `xet_config_environment`; `R/download.R:xet_download_file`; `R/upload.R:xet_upload_file`; `R/stream.R:xet_stream_raw` and `xet_stream_range`; `R/connection.R`; `R/arrow.R`; `R/spatial.R`; `src/rust/src/lib.rs` `#[extendr]` and `extendr_module!`; relevant `tests/testthat/test-*.R`; README headings `Key Features`, `Quick Start`, `API Reference`, `Testing`.
- **Acceptance:** The plan contains an entry for all 13 exports plus a separate stale-claims list; every classification cites concrete implementation/test locations and distinguishes successful behavior evidence from validation/error-path evidence. No source files change.
- **Targeted command:** `git diff --check -- planning/EXECUTION_PLAN_1.md && rg -n '^\| `?(read_xet|xet_)|xet_get_file_metadata|Candidate supported|experimental pending evidence|defer/remove claim' planning/EXECUTION_PLAN_1.md` (adjust grep patterns to final table formatting); manual count must equal 13 exported functions and all stale claims addressed.

### Task 1.2.1 — Support policy decisions

- **ID:** `1.2.1.support-policy`
- **Repo:** `/home/andrew/workspace/rxet`
- **Depends on:** `1.1.1.api-inventory`
- **Files in scope:**
  - Must edit: `planning/EXECUTION_PLAN_1.md` (decision table, Goal & Scope if needed, phase-specific handoff section).
  - Can create: `planning/.development/` scratch only.
  - Do not edit package source/docs/tests, master plan, later phase plans, or generated build/check outputs.
- **Spec:** Using the inventory plus user answers, record an explicit supported/experimental/deferred disposition for each exported function or a precisely grouped subset with rationale. Apply the resolved Linux/macOS/minimal-Windows platform scope, API evidence threshold, eventual CRAN intent, initial GitHub/source release route without prebuilt binaries, and `brownag/rxet-test-data` live-test policy. Preserve the other constraints: pin hf-xet; eventual vendoring for CRAN, not first; offline/secret-free routine tests; opt-in environment-token live tests, no live credentials in public CI, manual live run before release; do not remove implemented functionality without evidence that it is a stub/deferred.
- **Anchors:** Task 1.1.1 inventory; `planning/MASTER_PLAN.md` Phase 1 scope/policy and later phase dependencies; prior decision table.
- **Acceptance:** No unresolved user-policy item changes required platform/API/distribution scope; every disposition has rationale and a downstream phase handoff; CRAN is recorded as the intended eventual target and vendoring as later work, not a Phase 1 task. Technical MSRV/R-version values remain explicitly for Phase 3.
- **Targeted command:** `git diff --check -- planning/EXECUTION_PLAN_1.md && rg -n 'Pending|Linux|Windows|macOS|CRAN|vendor|integration|supported|experimental|deferred' planning/EXECUTION_PLAN_1.md` plus human check against all decision rows.

### Task 1.3.1 — Phase contract consistency and handoff

- **ID:** `1.3.1.phase-contract`
- **Repo:** `/home/andrew/workspace/rxet`
- **Depends on:** `1.2.1.support-policy`
- **Files in scope:**
  - Must edit: `planning/EXECUTION_PLAN_1.md` (only corrections required by consistency review); `planning/STATE_1.md` (task completion status and concise reports).
  - Can create: no other tracked files. Task TODOs will be `planning/tasks/1.1.api-inventory.todo.md`, `planning/tasks/1.2.support-policy.todo.md`, `planning/tasks/1.3.phase-contract.todo.md`.
  - Do not edit implementation files, tests, README/man, `MASTER_PLAN.md`, or prior artifacts.
- **Spec:** Check that the approved Goal & Scope, exact user constraints, API inventory, decisions, wave/task sequence, and master-plan Phase 1 exit gate agree. Verify later-phase handoff facts for docs/API (Phase 2), pinning/platform/vendor (Phase 3), hardening (Phase 4), test policy (Phase 5), and optional integrations (Phase 6). Record acceptance outcome and any explicit deferral; do not claim resolution of code defects.
- **Anchors:** `planning/MASTER_PLAN.md` Phase 1 and phase sequence; decisions table and task specs in `EXECUTION_PLAN_1.md`; `AGENTS.md` quick-start/test conventions.
- **Acceptance:** `planning/STATE_1.md` records every task status, exact validation commands/results, and unresolved risks; plan contains no contradictory platform, release, credential, API-removal, or vendor timing statements; no implementation was performed.
- **Targeted command:** `git diff --check -- planning/EXECUTION_PLAN_1.md planning/STATE_1.md planning/PROMPT_TEMPLATE_1.md planning/tasks && rg -n 'Task 1\.[123]|Depends on|Acceptance|Targeted command|Verbatim user constraints|Pending' planning/EXECUTION_PLAN_1.md planning/STATE_1.md planning/PROMPT_TEMPLATE_1.md`.

## Hazard notes

- This phase is intentionally decision-driven. Never infer a blanket API removal from the initial review; user explicitly wants to keep built functionality that works.
- A passing compile, handle-init smoke test, or invalid-input test does not demonstrate a successful download/upload/range integration. Inventory must label evidence type precisely.
- Do not claim a Windows or macOS build from Linux static inspection. Phase 1 records Linux, macOS, and Windows as in scope; Phase 3 must execute real OS-specific build/check validation.
- “Minimal Windows support” needs a concrete acceptance definition in Phase 3 (source build/install, smoke test, architecture/R versions).
- Eventual CRAN intent and vendor requirement are recorded, but vendoring is explicitly later. Do not allow CRAN offline build requirements to expand Phase 1.
- Tests may need `uuid` currently; absence produced three `devtools::test()` failures in the observed environment. Do not edit tests/dependencies during this planning-only phase.
- Existing check outputs are user workspace artifacts. No cleanup command should include `rm -rf`, broad `git clean`, or removal of `rxet.Rcheck/`/`rxet_0.1.0.tar.gz`.
- `AGENTS.md` contains outdated architecture statements (integer handles) relative to current character UUID handles. It remains the repo convention source but should not be treated as factual product spec without checking code.

## Approval gate

**Approved by the user on 2026-10-15.** This authorizes Phase 1 planning-task orchestration only, beginning with Wave 1. It does not authorize product implementation, CRAN submission, or release publication. Workers remain subject to the per-task micro-plan approval gate.

## Appendix A — API inventory (Task 1.1.1)

Evidence basis: static inspection of `NAMESPACE` (`export(...)` lines 3–15), R wrappers under `R/`, Rust `#[extendr]` functions and `extendr_module!` (`src/rust/src/lib.rs:327`), `man/*.Rd`, `README.md`/`README.Rmd`, and `tests/testthat/test-*.R`. No test was run for this inventory. `MANUAL`/recon facts in the body above remain authoritative for build/check state.

**Export ↔ binding map.** 13 `export(...)` entries in `NAMESPACE`. Six map to Rust functions registered in `extendr_module!`: `xet_client_new`→`xet_init_client`, `xet_client_close`→`xet_close_client`, `xet_download_file`, `xet_upload_file`, `xet_stream_raw`, `xet_stream_range` (all in `src/rust/src/lib.rs`; `.Call("wrap__*")` dispatch in `R/extendr-wrappers.R`). The remaining seven are pure R: `xet_config_environment`, `xet_open_connection`, `xet_close_connection`, `read_xet_parquet`, `read_xet_parquet_stream`, `read_xet_raster`, `read_xet_vector`.

**Evidence vocabulary.** `success-path` = a test asserts a real successful return from the function's core behavior. `validation/error-path` = a test asserts only argument checks, `requireNamespace` failures, or expected errors on fake/invalid inputs. `none` = no test invokes the core behavior. No test in the repository performs a real successful Xet download, upload, or byte-range transfer.

**Preliminary v0.1 status** below is inventory input only; final disposition is Task 1.2.1. Allowed values: `candidate supported`, `experimental pending evidence`, `defer/remove claim as stub`.

| Export | R definition | Rust implementation | Help page | README mention | Evidence (type) | Memory / I/O model | Optional deps / credentials | Preliminary v0.1 status | Fact or task needed to resolve |
|---|---|---|---|---|---|---|---|---|---|
| `xet_client_new` | `R/client.R:33` | `xet_init_client`, `src/rust/src/lib.rs:72` | `man/xet_client_new.Rd` | README:49–53 (Quick Start), :178 (API Ref) | `success-path`: `tests/testthat/test-client.R:3–27` (handle non-empty, UUID format); `success-path`/`validation`: `test-input-validation.R:4–31` | Builds `XetSession` in memory only; no network contact at init; stores endpoint+token in registry keyed by UUID | endpoint+token required for subsequent ops; env vars read here via `XetConfig::new` | candidate supported | Confirm env-var config is actually consumed by the pinned hf-xet; document that init performs no network I/O |
| `xet_client_close` | `R/client.R:50` | `xet_close_client`, `src/rust/src/lib.rs:103` | `man/xet_client_close.Rd` | README:179 (API Ref) | `success-path`: `test-client.R:22–27,44–54`; `error-path`: `test-client.R:29–42` (unknown/double close) | Removes `Arc<XetClient>` from global `Mutex<HashMap>`; `Drop` Tokio spawn is a placeholder (`lib.rs:15–26`) | none | candidate supported | Document double-close error contract; verify close-vs-in-flight-operation semantics (Phase 4) |
| `xet_config_environment` | `R/client.R:100` | none (pure R; sets env vars) | `man/xet_config_environment.Rd` | README:123–139 (Configuration), :180 (API Ref) | `success-path`: `tests/testthat/test-config.R` (all cases assert env var values) | Pure R; sets `HF_XET_*` env vars, no I/O | none | candidate supported | Prove the pinned hf-xet honors `HF_XET_CLIENT_READ_TIMEOUT`, `HF_XET_CHUNK_CACHE_SIZE_BYTES`, `HF_XET_HIGH_PERFORMANCE` |
| `xet_download_file` | `R/download.R:25` | `xet_download_file`, `src/rust/src/lib.rs:238` | `man/xet_download_file.Rd` | README:56–61 (Quick Start), :184 (API Ref) | `validation/error-path`: `test-input-validation.R:34–61` (empty handle/hash, negative size, dir/non-existent parent) | xet-core file-download group writes **directly to final `dest_path`** before `finish_blocking()`; global `CLIENTS` mutex held across blocking call; no atomic temp+rename | endpoint+token | experimental pending evidence | Successful-download byte-integrity and failed-download cleanup evidence (Phases 4–5) |
| `xet_upload_file` | `R/upload.R:22` | `xet_upload_file`, `src/rust/src/lib.rs:285` | `man/xet_upload_file.Rd` | none in README API Ref | `validation/error-path`: `test-input-validation.R:119–127` (empty handle) | Upload commit via `new_upload_commit`/`upload_from_path_blocking`/`commit_blocking`; returns `list(hash, file_size)`; commit/ownership semantics unspecified | endpoint+token (write scope) | experimental pending evidence | Determine endpoint/auth/commit semantics and publish/commit behavior; obtain live success evidence |
| `xet_stream_raw` | `R/stream.R:32` | `xet_stream_raw`, `src/rust/src/lib.rs:116` | `man/xet_stream_raw.Rd` | README:68–70 (Stream), :186 (API Ref) | `validation/error-path`: `test-streaming.R:17–33`, `test-input-validation.R:63–77`, and `test-streaming.R:3–15` (fake hash errors) | Downloads **entire file into `Vec<u8>`** then converts to R `raw()`; whole file resident in R memory | endpoint+token | experimental pending evidence | Successful byte return; explicit memory/size policy; correct the "returns metadata" docstring/README |
| `xet_stream_range` | `R/stream.R:82` | `xet_stream_range`, `src/rust/src/lib.rs:168` | `man/xet_stream_range.Rd` | README:76–84 (Random-access), :187 (API Ref) | `validation/error-path`: `test-streaming.R:35–51`, `test-input-validation.R:79–95`. `test-stream-range.R` is **R-side chunk-overlap arithmetic only and never calls this function** | xet-core download stream with `Some(start..end)`; still buffers result into `Vec`; requires full-file `file_size` arg | endpoint+token | experimental pending evidence | Byte-for-byte range success test at boundaries; resolve return-value mismatch (README assigns `metadata`, man example reads `result$chunks_needed`; actual return is `raw()`) |
| `xet_open_connection` | `R/connection.R:41` | none (calls `xet_stream_raw`) | `man/xet_open_connection.Rd` | README:193 (API Ref) | `validation/error-path`: `test-connection.R:3–12`, `test-input-validation.R:97–117` | Materializes whole file via `xet_stream_raw()` then wraps in `rawConnection()`; not a remote/seek-backed connection | endpoint+token | experimental pending evidence | Success evidence; document that connection is an in-memory copy, not remote random access |
| `xet_close_connection` | `R/connection.R:66` | none (base `close()`) | `man/xet_close_connection.Rd` | README:195 (API Ref) | `none`: purpose-built test `test-connection.R:14–25` is skipped without `HF_TOKEN` and asserts an error, not a successful close | One-line wrapper around base `close(conn)`; no I/O | none | candidate supported | Confirm wrapper adds no behavior beyond base `close()` (kept as its own row per approval) |
| `read_xet_parquet` | `R/arrow.R:52` | none (calls `xet_open_connection`) | `man/read_xet_parquet.Rd` | README:91–98 (Parquet), :199 (API Ref) | `validation/error-path`: `test-arrow-spatial.R:3–26` (gated on `arrow` + `HF_TOKEN`, fake hash error) | Whole file into memory via connection; `arrow::read_parquet(conn)` | `arrow`; endpoint+token | experimental pending evidence | Prove `arrow::read_parquet()` accepts the `rawConnection`; README push-down/column-avoidance claim is unsubstantiated |
| `read_xet_parquet_stream` | `R/arrow.R:111` | none (calls `xet_stream_raw`) | `man/read_xet_parquet_stream.Rd` | none in README API Ref | `none`: no test references it | Streams whole file to memory, writes a temp `.parquet`, reads with Arrow. Contradicts "without temporary files" | `arrow`; endpoint+token | defer/remove claim as stub | Decide export vs internal: tagged `@keywords internal` (`R/arrow.R:109`) yet exported in NAMESPACE; add success coverage or de-export |
| `read_xet_raster` | `R/spatial.R:56` | none (calls `xet_open_connection`) | `man/read_xet_raster.Rd` | README:106–115 (geospatial), :200 (API Ref) | `validation/error-path`: `test-arrow-spatial.R:28–37` (only "terra required"); skipped when terra installed | Whole file into memory via connection; `terra::rast(conn)` optionally cropped | `terra`; endpoint+token | experimental pending evidence | Prove `terra::rast()` reads the `rawConnection`; "partial reads/COG windows without downloading" claim unsubstantiated |
| `read_xet_vector` | `R/spatial.R:123` | none (calls `xet_open_connection`) | `man/read_xet_vector.Rd` | README:202 (API Ref) | `validation/error-path`: `test-arrow-spatial.R:39–48` (only "sf required"); skipped when sf installed | Whole file into memory via connection; `sf::st_read(conn)` | `sf`; endpoint+token | experimental pending evidence | Prove sf/GDAL reads the `rawConnection`; "GDAL can seek within the file via the R connection" claim unsubstantiated for a `rawConnection` |

### Non-exported / stale claims (not API entries)

These are README, man, or metadata assertions with no corresponding implemented/exported behavior. They are inputs to Task 1.2.1, not API entries.

| Claim | Location | Reality / evidence | Suggested treatment (for 1.2.1) |
|---|---|---|---|
| `xet_get_file_metadata(handle, file_hash)` — "Query chunk metadata" | `README.md:189` (and `README.Rmd`) | No R definition, no `NAMESPACE` export, no Rust fn, no man page | Remove claim (phantom API) |
| "Streaming downloads into memory without temporary files"; "without intermediate disk copies" | `README.md:15`, `:10` | `xet_stream_raw` buffers whole file in memory; `read_xet_parquet_stream` writes a temp file; `xet_download_file` writes to disk | Reword to match memory/temp behavior |
| "Random access — fetch specific byte ranges (10% of file in seconds)" | `README.md:16–17` | `xet_stream_range` has no success evidence and still buffers the result | Mark experimental; no speed claim |
| "Zero-copy integration with Arrow, terra, sf, and GDAL" | `README.md:18` | All adapters copy the whole file into R memory via `xet_stream_raw` | Remove "zero-copy" |
| "Parallel downloads with automatic token refresh and retry" | `README.md:19` | No parallel, token-refresh, or retry logic in `R/` or `src/rust/src/lib.rs`; a single blocking `.blocking()` call | Remove claim |
| "Production-ready with panic recovery and resource cleanup" | `README.md:21` | Panic recovery exists (`safe_exec`, `lib.rs:29`); cleanup is a documented placeholder (`lib.rs:19–24`) | Downgrade claim |
| Performance table ("Metadata fetch 200–500ms", "Token refresh ~100ms", "Large file … Parallelizes over 4 workers", "Byte-range 5-10x faster") | `README.md:145–155` | No metadata fetch, token refresh, or worker pool implemented; measurements unverified | Remove/defer until measured |
| "Parallelism: 4 workers typically achieve 3.0–3.8x speedup" | `README.md:154` | No worker implementation exists | Remove claim |
| Architecture: "Async I/O with Tokio (non-blocking to R console)", "Bounded channels for backpressure", "LRU cache for metadata shards", "Binary search for O(log N) chunk lookup" | `README.md:215–218` | Rust uses blocking `*.blocking()` calls under a global `Mutex`; no bounded channels, metadata-shard LRU, or binary search in `lib.rs` | Remove; describe real blocking model |
| `xet_stream_raw` doc: "Returns metadata about streaming operation" | `README.md:69`; `R/stream.R:10` | Returns a `raw()` vector | Correct to "returns file bytes as `raw()`" |
| `xet_stream_range` example: `metadata <- xet_stream_range(...)`; `result$chunks_needed` | `README.md:76`; `R/stream.R:80` (man example) | Returns a `raw()` vector; no `chunks_needed` element | Correct examples to `raw()` |
| FAQ: "Querying the metadata shard identifies overlapping chunks; only those chunks are downloaded" | `README.md:252–254` | No metadata-shard querying in code; the only overlap logic is mock test arithmetic; Rust buffers the reconstructed range | Rewrite or remove |
| FAQ: "Client is thread-safe" / Shiny use | `README.md:263` | Global `Mutex<HashMap>` serializes all operations around blocking I/O; concurrent-client behavior is untested | Qualify after Phase 4 |
| DESCRIPTION: "Supports chunked upload and download" | `DESCRIPTION:9` | Chunking is internal to hf-xet; rxet-level success unverified | Evidence-needed; keep or bound after Phase 5 |
| `read_xet_parquet_stream` tagged `@keywords internal` yet exported | `R/arrow.R:109–111`; `NAMESPACE:4` | Internal tag contradicts public export | Resolve in Phase 2 |
| README Testing section claims "Range downloads … Byte-range accuracy", "Concurrent clients … Stress testing" | `README.md:234–240` | Tests are mock/simulation; `test-stream-range.R` never calls the function and asserts R-side arithmetic | Correct test description |
| README Benchmarking scripts `tools/benchmark.R`, `tools/benchmark-extended.R` | `README.md:163–169` | Files exist under `tools/` — claim substantiated at file level (not a stale claim) | Keep; verify runnability in later phase |
| `AGENTS.md` says handles are integer `u32` | `AGENTS.md` (Architecture) | Code uses UUID character handles (`lib.rs:87`, `R/client.R`) | Out-of-plan doc fix (Phase 2) |

### Live-test repository inventory (read-only; no writes)

`brownag/rxet-test-data` (public, ungated), current default-branch state inspected via the public Hub API (no credentials used): SHA `a156f80de59ef7bd4939027358693f927861a0a2`, modified 2026-06-14, `usedStorage` 2931 B.

| Path | Size | Storage | Identifier |
|---|---|---|---|
| `.gitattributes` | 2504 B | Git | oid `bed0738c7eeb449bca98b5d2f33c89a1ee56349a` |
| `test_data.json` | 146 B | Git | oid/etag `82b125d28b4895c416bcaec695cd3cff1dc646ea` |
| `test_data.parquet` | 2931 B | Xet (LFS) | `xetHash 4e99cb45a4ad980707548c95f5cc3dadb91e36889c68adbff641e56c53981331` |
| `test_features.geojson` | 368 B | Git | oid/etag `b04f3a1aeab50e4fce14e1e670f62fa9d1d03b23` |

These match the hashes recorded in `tests/testthat/hf_test_files.R:18–37` (`parquet` Xet hash, and the two Git-stored etags). Inventory facts relevant to later phases: the repository currently contains only three tiny fixtures; only `test_data.parquet` is Xet-stored. There is no large/multi-chunk file, no GeoTIFF, and no write-target fixture, so byte-range boundary testing, multi-chunk streaming, raster, and upload success evidence cannot be satisfied from this repository as it stands. `read_xet_vector` has a Git-stored GeoJSON but it is not Xet-backed.
