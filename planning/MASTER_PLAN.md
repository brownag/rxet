# rxet Initial Public Release — Master Plan

## Purpose

Prepare `rxet` for a credible initial public release by first defining a deliberately narrow, supportable product, then repairing its correctness and reproducibility, validating the real Hugging Face Xet workflows, and publishing accurate package documentation and release artifacts. This master plan is a sequence of work packages. Each phase is intended to be passed, with this document, to `/plan-wave` to author the detailed `EXECUTION_PLAN_N.md`, `PROMPT_TEMPLATE_N.md`, `STATE_N.md`, and task TODOs for `/wave-orchestration`.

**Do not execute all phases as one plan.** Run `/plan-wave` for Phase 1, approve and execute it, then continue through later phases in order. Reconcile the phase against current repository state and prior phase reports each time. A phase may be reduced or marked unnecessary only with evidence; do not silently skip an unresolved release blocker.

## Release objective and initial product boundary

Release a small, understandable R package that can reliably initialize/close a Xet client and perform the file operations that are actually verified against a supported Hugging Face Xet endpoint. The package must install from a clean source archive on explicitly supported platforms, have stable dependency resolution, return accurate errors, avoid leaving corrupt outputs after failed downloads, and document its true memory, network, authentication, and platform behavior.

Candidate initial scope, to be confirmed during Phase 1:

- Client initialization and explicit cleanup.
- Whole-file download to disk.
- Whole-file upload only if its endpoint/auth/commit semantics are validated as useful and stable for users; otherwise defer it.
- Whole-file read into memory only with explicit memory caveats and a defensible size/overflow policy.
- Byte-range reads only if verified with byte-for-byte live/integration tests and a clearly documented range contract.
- Optional Arrow/spatial adapters only if their actual I/O behavior is tested and claims are bounded. Current helpers materialize the complete file in memory; they are not remote random-access connections and do not establish push-down transfer behavior.

Explicitly do not represent unverified capabilities as release features: zero-copy, remote seek/range-backed R connections, push-down filtering, automatic token refresh, parallel download throughput, production readiness, cache guarantees, or metadata retrieval unless implemented and tested in the release scope.

## Planning and execution rules

- Use `/plan-wave` separately for each numbered phase below. The phase description, deliverables, dependencies, and exit gate are inputs to that planning interview, not permission to assume unspecified design decisions.
- `/plan-wave` must inspect repository state, the current `AGENTS.md`, prior phase plans/reports, and relevant source/test files before drafting tasks. Use a separate numbered wave-orchestration artifact set per phase; never overwrite earlier execution plans/state.
- The plan-wave author resolves open decisions with the user before drafting. Examples: supported OS/R versions, whether upload/range/integrations belong in v0.1, how live tests obtain credentials, whether CRAN submission is a goal, and acceptable source-build/offline policy.
- Each execution plan should use small bounded tasks, explicit file scopes, dependency ordering, grep anchors for source navigation, targeted acceptance commands, and the wave-orchestration micro-plan approval gate. Avoid parallel workers touching shared files.
- Do not claim a phase complete solely because code compiles. The named exit gate must pass or have an explicit, user-approved deferral recorded in that phase's `STATE_N.md` and this master plan.
- Preserve user changes and keep generated build/check artifacts out of commits unless explicitly intended.

## Repository facts and known starting state

Observed during initial release-readiness review (2026-10-15):

- R package layout: `R/`, `src/entrypoint.c`, `src/rust/src/lib.rs`, `src/rust/Cargo.toml`, `src/Makevars.in`, `tools/config.R`, `tests/testthat/`, `man/`, `DESCRIPTION`, `NAMESPACE`, `README.md`.
- Package-level workflow in `AGENTS.md`: `R CMD INSTALL .`, Rust check via `cd src/rust && cargo check`, then R smoke tests. The exact Rust verification command after a full package install may need Cargo artifacts rebuilt because Makevars cleanup removes `src/rust/target`.
- At review time: `R CMD build .` succeeded; Linux `R CMD INSTALL .` succeeded; `cargo check` succeeded; client init/close smoke test succeeded.
- At review time: `_R_CHECK_FORCE_SUGGESTS_=false R CMD check --no-manual rxet_0.1.0.tar.gz` finished with one WARNING and one NOTE. Warning: test code uses undeclared `rprojroot`; note: `LICENSE` is not mentioned in `DESCRIPTION`. Normal forced-suggests check stopped because `arrow`, `uuid`, and `covr` were unavailable in the environment. These results are environment-specific and must be rerun from a clean source archive.
- The no-argument `testthat::test_dir("tests/testthat")` invocation failed because it did not load the package namespace; this is not a valid substitute for `devtools::test()` / package check. Establish a valid test baseline with the supported runner.
- `src/rust/Cargo.lock` is ignored and absent from tracked source; hf-xet is a Git dependency without an explicit revision in `Cargo.toml`. Cargo resolved 311 packages at review time. Build reproducibility and release archive inclusion need explicit resolution.
- `tools/config.R` selects `src/Makevars.win.in` on Windows, but that template was absent from tracked files at review time. Windows build is unverified and likely broken.
- Mock tests simulate API behavior in R but do not route Rust `hf-xet` operations through the mock. The main network-facing upload/download/range behavior lacks a verified end-to-end test.
- R API currently exports client, download/upload, raw/range stream, full-memory R connection, Arrow, and spatial functions. README claims exceed demonstrated behavior. `xet_get_file_metadata()` is documented in README but absent from implementation and NAMESPACE.
- Rust core in `src/rust/src/lib.rs` holds the global client-registry mutex during blocking network operations, accumulates streamed data in memory, and writes downloads directly to final destination before `finish_blocking()` succeeds.
- Source tarball/build/check attempts may leave `rxet.Rcheck/` and `rxet_0.1.0.tar.gz`; keep/remove these according to user workspace state and ignore rules, not by broad cleanup.

## Phase sequence

### Phase 1 — Freeze v0.1 scope, support policy, and acceptance contract

**Outcome:** An explicit product contract for the first release, including supported APIs, platforms, dependencies, R/Rust versions, credential/auth assumptions, network prerequisites, and what is deferred. Resolve ambiguity before implementation changes.

**Plan-wave input / work to plan:**

1. Inspect all public exports, help pages, README examples/claims, `DESCRIPTION`, `NAMESPACE`, current tests, and release-readiness findings above.
2. Build an API inventory mapping every exported function to its actual current behavior, required dependencies, network calls, memory profile, and test evidence.
3. Decide the v0.1 public API boundary: disk download, upload, full-memory stream, byte-range stream, connection helpers, Arrow, spatial adapters, sync tooling. Explicitly label each included, experimental, or deferred.
4. Decide initial OS/architecture and R version support; decide whether CRAN readiness/submission is in scope or whether this is a GitHub/source release with a narrower build contract.
5. Decide whether source installation must be reproducible offline, whether binaries are intended, and what exact Rust MSRV/toolchain constraints apply.
6. Define live-test policy (credential source, opt-in mechanism, safe test repository/files, cleanup, and CI availability) without committing secrets.
7. Record decisions and their rationale in phase artifacts. Do not start changing product implementation beyond planning artifacts unless the plan explicitly includes a minimal contract artifact.

**Dependencies:** None.

**Exit gate:** User-approved, testable scope and platform/release policy captured in Phase 1 `EXECUTION_PLAN_N.md`/`STATE_N.md`; no key v0.1 API remains unclassified.

### Phase 2 — Correct public API, documentation, and package metadata

**Outcome:** Public help, README, exports, metadata, and examples accurately describe only the approved Phase 1 product contract.

**Plan-wave input / work to plan:**

1. Reconcile all exported R functions, `.Call` registrations, NAMESPACE entries, and `man/*.Rd` pages; identify stale/undocumented/unimplemented claims.
2. Remove, defer, or implement the phantom `xet_get_file_metadata()` claim according to Phase 1 decisions.
3. Correct the range return/example mismatch and all examples that claim metadata/list results when the API returns `raw()`.
4. Rewrite README capability, performance, authentication, setup, installation, memory, and integration claims to match verified contract; remove unsubstantiated “production-ready,” “zero-copy,” push-down and parallel claims unless independently validated.
5. Reconcile `DESCRIPTION` license metadata with included Apache license files and R package conventions; fix package metadata issues found in check.
6. Ensure optional package requirements and test-only dependencies are accurately declared; avoid adding unnecessary dependencies.
7. Ensure README source (`README.Rmd`) and rendered `README.md` stay consistent if both remain maintained.

**Dependencies:** Phase 1.

**Exit gate:** R package metadata, namespace, Rd cross-references, and README match the chosen API; a clean build/check has no documentation/code mismatch or license metadata issue attributable to this phase.

### Phase 3 — Reproducible native build and supported-platform packaging

**Outcome:** A clean source archive can be built and installed consistently under the declared platform/toolchain policy.

**Plan-wave input / work to plan:**

1. Inspect Cargo dependency configuration, `.gitignore`, `.Rbuildignore`, `tools/config.R`, `tools/msrv.R`, Makevars templates, configure scripts, and R source-package inclusion rules.
2. Choose and implement a reproducible hf-xet revision and Cargo dependency resolution policy. Ensure lockfile policy works for an R source package and is not accidentally omitted by ignore/build rules.
3. Validate Cargo version/MSRV parsing and align the declared Rust MSRV with actual dependency requirements; account for the project's current nightly toolchain observation without assuming nightly is required.
4. Repair Windows Makevars/build path if Windows is in scope; otherwise make unsupported status explicit and ensure configure fails clearly rather than selecting a missing template.
5. Validate macOS/Linux/Windows system linker requirements and static native library linkage for each platform in scope.
6. Decide whether vendoring is required; if yes, produce and verify the actual vendor configuration/archive and ensure no generated temporary vendor state is shipped unintentionally. If no, document online build requirement.
7. Verify source archive contains all necessary files but excludes build products, local targets, secrets, and scratch material.
8. Add/update CI for the platform matrix and repeatable build/check commands, if included by Phase 1 policy.

**Dependencies:** Phase 1; Phase 2 metadata choices may inform build metadata.

**Exit gate:** From a clean checkout/archive, all declared supported platform builds/installations pass using pinned/reproducible dependencies; unsupported platforms are explicit; no missing-template or hidden-lockfile failure remains.

**Phase 3 recorded deferral (2026-10-15):** Linux build/install/`R CMD check` pass locally from a clean `git archive HEAD` checkout (`Status: OK`; pinned crates.io `hf-xet 1.7.0`; `Cargo.lock` and `src/Makevars.win.in` ship; no `planning/`/`docs/`/build products). The macOS and Windows legs of the exit gate **cannot** be executed on the Linux development host; they are validated by the new `.github/workflows/R-CMD-check.yaml` matrix (ubuntu/macos/windows) on the first user push, and are therefore recorded here and in `planning/STATE_3.md` as an explicit, user-approved deferral (Phase 3 decision D9). Vendoring remains deferred (online crates.io build requirement documented). See `planning/EXECUTION_PLAN_3.md` and `planning/STATE_3.md` for evidence.

### Phase 4 — Harden core Rust/R operations and failure semantics

**Outcome:** Included core operations have predictable handle lifecycle, safe size/range validation, concurrency behavior, cleanup on errors, and useful R errors.

**Plan-wave input / work to plan:**

1. Inspect `R/client.R`, `R/download.R`, `R/upload.R`, `R/stream.R`, `R/connection.R`, `R/extendr-wrappers.R`, and Rust exported functions in `src/rust/src/lib.rs`; follow package registration and extendr conventions.
2. Release the global client-registry lock before blocking network operations by obtaining an owned `Arc` for the selected client; verify close-vs-operation semantics and document/test them.
3. Add strict finite, whole-byte, representable size/offset validation in R and checked conversion/allocation handling in Rust. Decide practical limits for raw-vector APIs and return actionable errors before allocation/network work.
4. Make disk download atomic or otherwise ensure failed requests do not leave a partial/corrupt destination; preserve existing valid destination semantics and test all error paths.
5. Review upload commit behavior and ownership/lifecycle; only change API behavior within approved scope.
6. Remove misleading Tokio/runtime/drop placeholders or implement only if necessary for approved behavior; avoid unsafe or unnecessary async abstractions. Verify panic/error paths do not cross FFI incorrectly.
7. Validate endpoint and hash/token preconditions sufficiently to provide early, readable errors without leaking credentials.
8. Add deterministic tests for wrapper validation, client lifecycle, lock release/concurrent clients, and destination cleanup using the chosen test seam.

**Dependencies:** Phases 1 and 3. API contract docs from Phase 2 should be stable.

**Exit gate:** Focused tests demonstrate checked inputs, lock not held over blocking I/O, no failed-download artifact corruption, and safe FFI error propagation; Rust and package builds pass.

### Phase 5 — Verify real Xet protocol behavior and make core integration tests meaningful

**Outcome:** Included network operations are proven against a controlled or live Xet-compatible service, with explicit, repeatable evidence rather than disconnected mock-only assertions.

**Plan-wave input / work to plan:**

1. Trace current mock backend and tests to distinguish pure R helper tests from tests of actual Rust calls. Keep useful pure-unit tests, but do not present synthetic overlap calculations as proof of network range behavior.
2. Design a safe test seam: preferred deterministic local protocol-compatible test service if feasible; otherwise explicit opt-in live tests with a dedicated public/test fixture and robust skip behavior. Decide feasibility during plan-wave and ask the user where facts/credentials are needed.
3. Add end-to-end tests for each approved core API: client setup, successful download byte integrity and file size, expected failure behavior, upload metadata/commit semantics if included, and cleanup.
4. For range streaming if included, verify exact bytes at start/end boundaries, mid-chunk boundaries, empty/invalid cases according to the chosen public contract; verify reported/observed transfer scope only if measurable.
5. Test authentication failure, unavailable endpoint, invalid hash, interrupted/failing download cleanup, and token lifetime assumptions without exposing secrets.
6. Make tests hermetic where possible, credential-safe, documented, and CI-compatible; distinguish routine offline tests from manual/credentialed integration tests.
7. Remove or rewrite inaccurate mock-backed assertions and README test descriptions.

**Dependencies:** Phases 1, 3, and 4.

**Exit gate:** Included network APIs have a reproducible passing success-path and failure-path test plan, exact test commands, and byte/integrity assertions. Live-only checks may be opt-in but must have been run manually before release and recorded in phase state.

### Phase 6 — Bound and validate optional integrations and memory behavior

**Outcome:** Any retained raw-stream, connection, Arrow, terra, or sf API has behavior and resource use consistent with its name and documentation; unsupported remote-access claims are removed.

**Plan-wave input / work to plan:**

1. Decide per Phase 1 whether each helper remains public, becomes experimental, or is deferred. Do not infer that a raw connection is remote streaming.
2. For retained full-memory features, enforce/describe safe size limits, test file parsing from actual downloaded bytes, and clarify peak memory/copy behavior.
3. Investigate whether Arrow/terra/sf accept the returned connection types as assumed on declared supported versions; test their actual semantics without claiming network push-down where the implementation downloaded the whole file first.
4. If true range-backed/seekable connection behavior is desired, treat it as a separate, explicitly scoped design requiring an interface and protocol investigation; do not bolt it onto rawConnection helpers as a documentation-only change.
5. Verify optional dependencies are accessed via `requireNamespace()` and declared in `Suggests`; tests skip cleanly if absent.
6. Add representative fixtures small enough for repository policy, with provenance/licensing documented; avoid relying on locally generated mutable test data.

**Dependencies:** Phases 1, 4, and 5. Phase 2 must be updated for resulting API decisions.

**Exit gate:** Every retained integration has tests on supported dependency versions and honest memory/I/O documentation; deferred ones are absent from public claims or explicitly marked experimental.

### Phase 7 — Full release validation, release notes, and publication gate

**Outcome:** A clean, auditable release candidate passes package checks and the chosen platform/integration matrix, with final user-facing release materials.

**Plan-wave input / work to plan:**

1. Run from a clean checkout: source build, source archive inspection, installation, offline test suite, and `R CMD check` under declared policy; run live integration tests per documented process.
2. Resolve all errors/warnings/notes that are in release scope; explain any unavoidable environment/platform notes in `cran-comments.md` or release notes as appropriate.
3. Verify exported API and documentation index, examples, license/attribution files, package version, authorship/contact, repository links, and supported-platform statement.
4. Review dependency licenses and the included native dependency/build footprint; ensure published source contains no credentials, local artifacts, untracked generated outputs, or unintended vendor material.
5. Add concise release notes with verified features, limitations, installation prerequisites, authentication setup, breaking/known limitations, and test evidence.
6. Perform a final independent code/spec/correctness review of the complete release diff and verify the exact source tarball intended for distribution.
7. Obtain explicit user release approval before tagging/publishing; publishing is not implicit in a passing validation task.

**Dependencies:** Phases 1–6.

**Exit gate:** Clean release candidate passes agreed quality gates; no unresolved critical/high blocker; user explicitly approves publication. Tag/upload/publish only if separately authorized.

## Cross-phase risk register

| Risk | Why it matters | Required treatment |
|---|---|---|
| Docs overclaim capabilities | Users may rely on incomplete or memory-heavy behavior | Phase 1 freezes scope; Phase 2 corrects claims; Phase 6 validates integrations |
| No real network success-path evidence | Core function may compile/install but fail against actual Hub protocol | Phase 5 test seam and recorded live verification |
| Unpinned native dependency graph | Rebuilds can change or fail unpredictably | Phase 3 locks/pins dependency policy and tests clean archive |
| Missing Windows template / unclear platform support | Source install may fail on users' systems | Phase 1 sets policy; Phase 3 verifies every claimed platform |
| Full-file buffering | Large inputs can exhaust process memory and make “streaming” claims false | Narrow v0.1 scope, size limits, honest docs; redesign only as explicit scope |
| Mutex across network waits | One slow request can block unrelated clients | Fix in Phase 4 and verify concurrency behavior |
| Partial destination on failure | Users may consume corrupt or empty output as valid | Atomic download/cleanup in Phase 4 and tested failure path |
| Public upload semantics/auth unclear | API may not correspond to common HF repository upload workflow | Decide in Phase 1; validate in Phase 5; defer if unsupported |
| Tests use undeclared/missing optional tooling | Checks can warn/fail in clean environments | Declare dependency or remove/restructure setup in Phases 2/5/7 |

## Definition of release-ready

The initial public release is ready only when all of the following hold:

1. Its public scope and platform/toolchain contract are explicit and user-approved.
2. Every exported/documented capability exists and its claims match demonstrated behavior.
3. The core supported download path has successful byte-integrity and failure-cleanup evidence; every other included network operation has corresponding evidence.
4. Build dependencies are pinned/reproducible according to the declared source-build policy, and every claimed platform builds.
5. Input conversions, memory exposure, client lifecycle, concurrency, and failure behavior have explicit bounds and tests appropriate to the supported scope.
6. A clean source archive installs and passes agreed package checks; test dependencies are declared and tests run through a valid package runner.
7. License, attribution, release notes, installation instructions, and known limitations are complete.
8. No critical/high finding remains open, and the user separately approves publication.
