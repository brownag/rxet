# Execution Plan 5 — Phase 5: Verify Real Xet Protocol Behavior and Make Core Integration Tests Meaningful

Orchestration 5 of the rxet release plan. Source of truth: `planning/MASTER_PLAN.md`,
Phase 5. Prior phases: `EXECUTION_PLAN_1.md`/`STATE_1.md` (live-test policy, API
evidence threshold), `EXECUTION_PLAN_4.md`/`STATE_4.md` (hardening; success-path
evidence was named as this phase's residual). Governing ADRs: `docs/decisions/0001`
(13 exports, experimental labels), `0003` (suite runs under `R CMD check`; skips for
optional packages and credentials).

## Goal & Scope

**Goal.** Every included network operation (download to disk, raw and range reads,
connection helpers, upload) is proven through the real Rust path against a
protocol-compatible Xet server, with byte-integrity and failure-path assertions. The
routine suite runs offline and secret-free on Linux, macOS, and Windows in CI. A
separate on-demand live suite runs the same operations against the public Hugging Face
dataset `brownag/rxet-test-data`, with credentials taken only from the environment.
Mock-backed tests that claim network behavior they never exercise are retired.

**In scope**
- A local protocol-compatible server for routine success-path tests: the upstream
  `local_cas_server` binary from `xet-client` 1.7.0 (feature `simulation`), installed
  out-of-band.
- Test harness and fixture helpers that start, probe, and stop that server.
- Success-path and failure-path tests for: `xet_download_file`, `xet_stream_raw`,
  `xet_stream_range`, `xet_open_connection`, `xet_close_connection`, `xet_upload_file`
  (upload is local-only).
- An on-demand live suite (`RXET_LIVE_TESTS=1`) against `brownag/rxet-test-data`
  asserting the known LFS sha256 of the parquet fixture, and PAR1 magic bytes at the
  head and tail via range reads.
- Retirement of mock-backed network tests and rewrite of HF-token-gated tests that
  asserted only error paths.
- CI: install of the local server on all three platforms in the existing R-CMD-check
  workflow; no live variables in public CI.
- Testing documentation in `README.Rmd`, `README.md`, and `AGENTS.md`.

**Out of scope (deferred, do not implement)**
- Live upload or any write to a Hugging Face repository. Upload stays experimental until
  a separately approved write-target test exists (decision D4).
- Arrow, terra, and sf integration proofs (`test-arrow-spatial.R` is untouched). Phase 6.
- Memory-bounded or seekable connections. Phase 6.
- A larger or multi-chunk live fixture in `brownag/rxet-test-data`. The user may add
  one later; no task depends on it. Live multi-chunk evidence is therefore a recorded gap.
- Token lifetime and expiry behavior (`with_token_info(…, u64::MAX)`); not testable
  without fault injection. Recorded as a deferral.
- Mid-stream interruption of a download. Needs fault injection; the closed-port and
  blackhole cases from Phase 4 remain the failure-path evidence.
- Concurrency across R clients. R is single-threaded per process; registry-lock release
  is covered by Phase 4's Rust unit tests.
- Vendoring, CRAN submission, and publication. Phases 3 and 7.

**Verbatim constraints** (from `planning/MASTER_PLAN.md` and `planning/STATE_1.md`):
- Phase 5 exit gate: "Included network APIs have a reproducible passing success-path and
  failure-path test plan, exact test commands, and byte/integrity assertions. Live-only
  checks may be opt-in but must have been run manually before release and recorded in
  phase state."
- Phase 1 decision: "Use the user's Hugging Face dataset repository `brownag/rxet-test-data`
  for opt-in manual live integration testing; routine tests remain offline/secret-free,
  credentials are environment-only, and public CI must not require them."
- Phase 1 decision: "Mark an API supported only after its success behavior is demonstrated
  through actual package behavior."
- User, this phase: "I'm actually unhappy with not having proper live tests." Answered with:
  "Run live tests on demand."

**Master Phase 5 item coverage** (every item maps to a task or a deferral):

| Master item | Disposition |
|---|---|
| 1 trace mock backend; keep pure-unit tests | 5.1.2 retires network mocks; `test-parallel-downloads.R` pure logic kept |
| 2 safe test seam | Hybrid seam: local server (routine) + live opt-in (D1, D2) |
| 3 e2e tests per approved core API | 5.2.1 (upload), 5.2.2 (download, raw, range, connection), 5.3.2 (live) |
| 4 range boundaries | 5.2.2 (local, multi-chunk generated fixture); 5.3.2 (live PAR1 head and tail) |
| 5 failure paths: auth, unavailable endpoint, invalid hash, cleanup, token lifetime | 5.3.1 (invalid hash, auth if enforced, no leftovers); unavailable endpoint and cleanup from Phase 4; token lifetime and interruption deferred (see Out of scope) |
| 6 hermetic, documented, CI-compatible | 5.1.1 (harness), 5.4.1 (CI), 5.4.2 (docs) |
| 7 remove inaccurate mock assertions and README test descriptions | 5.1.2, 5.3.2 (rewrite HF-gated), 5.4.2 (README, AGENTS.md) |

## Decision log (dated 2026-10-15, user answers)

- **D1 — Test seam: hybrid.** Routine offline success-path tests run against
  `local_cas_server`. Live tests run against `brownag/rxet-test-data` only when opted in.
- **D2 — Live tests on demand.** Live tests run whenever `RXET_LIVE_TESTS=1` is set,
  locally or by the developer. Public CI never sets it. This answers "proper live tests":
  they are not limited to the pre-release gate.
- **D3 — Server binary out-of-band.** Tests locate the binary via `RXET_LOCAL_CAS_SERVER`
  or `PATH` and skip with a clear message if absent. Install command:
  `cargo install xet-client --version 1.7.0 --features simulation --bin local_cas_server --locked`.
  rxet's own `Cargo.toml` and `Cargo.lock` are unchanged.
- **D4 — Upload is local-only.** Upload success is proven against the local server with
  byte-integrity checks on download-back. No live write occurs in Phase 5. `xet_upload_file`
  stays experimental.
- **D5 — Retire network-claim mock tests.** Delete `helper-mock-backend.R`,
  `test-stream-range.R`, and `test-concurrent.R`. Keep `test-parallel-downloads.R`
  (pure R action logic).
- **D6 — CI on all three platforms.** The existing R-CMD-check matrix (ubuntu, macos,
  windows) installs the local server and runs the local-server suite on each.
- **D7 — Parallelism and models.** Max 2 concurrent workers per wave, file-disjoint, Haiku
  workers, escalation per wave-orchestration's ladder. (Continues Phase 4 D8.)

**Judgment calls made by the planner (not asked; flagged for review):**
- J1. **`processx` added to `Suggests`** for cross-platform server process management
  (`system2` cannot return a PID for reliable kill on Windows). Declared in `Suggests`, so
  routine installs gain no requirement; tests skip when it is absent.
- J2. **Live gate variable is `RXET_LIVE_TESTS=1`.** `HF_TOKEN` is read only if set. Whether
  anonymous reads of this public dataset succeed is unknown (the anonymous Xet token
  endpoints returned 404 during recon; the probe is task 5.3.2 step 1).
- J3. **Known-good live integrity value.** The parquet fixture's LFS sha256 is
  `c25ed568c3f701e640a6d9db7495b8d989ee2f6dbaf3fc0ad2216c6d5cd28bf4` (from the hub tree
  API, 2931 bytes). Live byte-integrity assertions compare against it, not against a
  locally generated copy.
- J4. **Json and GeoJSON fixtures are not Xet-stored** (git-stored; no `xetHash`). They are
  not used for Xet tests.
- J5. **`test-arrow-spatial.R` untouched.** Its HF-gated tests belong to Phase 6.
- J6. **Test server data lives in memory or a temp dir.** The local server defaults to
  `./local_cas_data`; tests always pass `--in-memory` or a `tempdir()` path, so nothing is
  written into the repo.

## Recon log (facts from the repository and hub, 2026-10-15)

- **Hub dataset** `brownag/rxet-test-data`: public, not gated, default branch `main`,
  4 siblings. `test_data.parquet` is Xet-stored: `xetHash`
  `4e99cb45a4ad980707548c95f5cc3dadb91e36889c68adbff641e56c53981331`, size 2931, LFS oid
  (sha256) `c25ed568c3f701e640a6d9db7495b8d989ee2f6dbaf3fc0ad2216c6d5cd28bf4`.
  `test_data.json` (146 B) and `test_features.geojson` (368 B) are git-stored.
  Observed via the public `api/datasets/…` endpoints, 2026-10-15; no token used.
- **Hub token endpoints**: anonymous GET of `…/xet-read-token` and `…/xet-write-token`
  returned HTTP 404. Not conclusive: the path or parameters may differ. Probed in 5.3.2.
- **`gh repo view brownag/rxet-test-data`** → 404. Expected: the dataset is on Hugging
  Face, not GitHub. Not an access problem.
- **`local_cas_server`** (`xet-client-1.7.0`, `src/cas_client/simulation/local_server/main.rs`):
  `required-features = ["simulation"]`; flags `--data-directory` (default
  `./local_cas_data`), `--port`, `--host` (default `127.0.0.1`), `--in-memory`. Routes
  include `GET /v1/reconstructions/{file_id}`, `POST /v1/reconstructions`,
  `GET /v2/reconstructions/{file_id}`, plus chunk, xorb, and shard upload routes.
- **hf-xet 1.7.0 / xet-client 1.7.0** are in the local cargo registry
  (`~/.cargo/registry/src/index.crates.io-1949cf8c6b5b557f/`). Client reads
  `HF_XET_CLIENT_READ_TIMEOUT` and `HF_XET_CLIENT_RETRY_MAX_ATTEMPTS` (Phase 3 3.2.1, Phase
  4 4.3.1).
- **Existing tests**: `test-connection.R` (25 lines) and `test-streaming.R` (51) are
  HF_TOKEN-gated and use fake hashes (`"abc123"`, `"fake_hash_nonexistent"`), asserting
  errors only. `test-streaming.R` also holds validation tests that Phase 4 relies on
  (keep them). `test-arrow-spatial.R` (48) is HF-gated (J5).
- **Mock-backed tests**: `helper-mock-backend.R` (366 lines) defines `create_mock_backend`,
  `mock_cas_chunk`, `mock_metadata_shard`, `mock_xet_read_token`, `mock_head_file_response`,
  `create_test_fixtures`, `create_test_scenarios`, `with_test_client`. Only
  `test-stream-range.R` (213) and `test-concurrent.R` (282) call them. None reach Rust.
- **`tests/fixtures/`** holds locally generated `test_data.parquet`, `test_data.json`,
  `test_features.geojson` (created by `tests/hf_test_setup.R` `create_test_files()`). Phase 6
  flags mutable locally generated fixtures as a hazard; Phase 5 does not depend on them.
- **DESCRIPTION `Suggests`**: `arrow, future.apply, jsonlite, rprojroot, sf, terra, uuid,
  testthat (>= 3.0.0), covr`. `processx` absent (J1 adds it).
- **Baseline (Phase 4 end, HEAD `930554e`)**: `devtools::test()` → `failed: 0 skipped: 9
  passed: 143 errors: 0`. Clean-archive `R CMD check` → `Status: OK`.
- **CI**: `.github/workflows/R-CMD-check.yaml` (Phase 3 3.1.4) runs ubuntu/macos/windows with
  `setup-r-dependencies`, `dtolnay/rust-toolchain@stable`, `R CMD build`, `R CMD check`.
  No server step, no cache for cargo install.
- **Toolchain**: `cargo 1.96.0-nightly`, R 4.6.1 (Phase 3), `devtools`, `testthat`,
  `roxygen2` 8.1.0, `processx`, `callr`, `future` installed; `uuid` and `arrow` absent.

## Hazards

- **H1 Windows build of the server.** `xet-client` with `simulation` pulls axum, redb, and
  related crates; a Windows compile may be slow or fail. Windows Makevars is itself
  unvalidated on this host (Phase 3 D9). CI is the only gate. If the Windows server install
  fails, the Windows local-server suite cannot run; record it and stop, do not skip silently
  (STOP-and-report).
- **H2 Install time.** `cargo install` compiles the server; CI must cache it (key on
  `xet-client` version and rustc version).
- **H3 Data directory.** Never let the server write into the repo. Use `--in-memory` or a
  `tempdir()` path.
- **H4 Port races.** Pick a free port and retry on bind failure; probe the server with a
  bounded wait before any assertion.
- **H5 Process cleanup.** Start with `processx`; kill in `on.exit` on every platform.
- **H6 Unknown auth enforcement.** Whether the local server rejects bad tokens is unknown.
  5.3.1 probes it first and writes only the failure assertions the probe confirms.
- **H7 Live reads may need a token.** Whether anonymous Xet reads of the public dataset
  succeed is unknown (J2). 5.3.2 step 1 probes; if a token is needed, the live suite
  requires `HF_TOKEN` and says so in its skip message.
- **H8 Live network failure.** With `RXET_LIVE_TESTS=1` set, a network failure is an error,
  not a skip. Skips are for unset gates and missing binaries only.
- **H9 Fixture provenance.** Routine success tests use fixtures generated in the test by
  rxet's own upload (round-trip) plus deterministic bytes; they never use the
  `tests/fixtures/` files.
- **H10 Live coverage gap.** The live dataset has one 2.9 KB file: no multi-chunk, range
  mid-chunk, or GeoTIFF evidence against real storage. Recorded as a gap; the local server
  covers multi-chunk offline.
- **H11 Upload dependency.** Routine download fixtures come from `xet_upload_file`. If upload
  is broken, the download suite fails too; 5.1.1 verifies a round-trip first, so the failure
  is attributed correctly.
- **H12 Phase 4 residuals** (J1, J2 in Phase 4) are unchanged.
- **H13 Deleting tests.** 5.1.2 deletes three files. Verify with `grep` that no remaining
  test calls a deleted helper before committing.

## Wave table

| Wave | Task | Files (must edit / create) | Depends on | Parallel with |
|---|---|---|---|---|
| 0 | `5.0.1.server-spike` (orchestrator, serial) | none in repo; installs binary; records facts in STATE_5 | none | none |
| 1 | `5.1.1.local-server-harness` | create `tests/testthat/helper-local-cas.R` (includes moved `is_compiled()`) and `tests/testthat/test-local-cas-harness.R`; edit `DESCRIPTION` (Suggests `processx`, `digest`) | 5.0.1 | none (single task) |
| 2 | `5.1.2.retire-mock-tests` | delete `tests/testthat/helper-mock-backend.R`, `tests/testthat/test-stream-range.R`, `tests/testthat/test-concurrent.R` | 5.1.1 | `5.2.1` |
| 2 | `5.2.1.local-upload-roundtrip` | create `tests/testthat/test-local-upload.R` | 5.1.1 | `5.1.2` |
| 3 | `5.2.2.local-download-read` | create `tests/testthat/test-local-download.R` | 5.1.1, 5.2.1 | `5.3.1` |
| 3 | `5.3.1.local-failure-paths` | create `tests/testthat/test-local-failures.R` | 5.1.1, 5.2.1 | `5.2.2` |
| 4 | `5.3.2.live-suite` | create `tests/testthat/test-live-hf.R`; rewrite HF-gated tests in `tests/testthat/test-connection.R` and `tests/testthat/test-streaming.R` (validation tests kept) | 5.1.2, 5.2.2 | none (single task) |
| 5 | `5.4.1.ci-local-server` | edit `.github/workflows/R-CMD-check.yaml` only | 5.3.1, 5.3.2 | `5.4.2` |
| 5 | `5.4.2.docs-testing` | edit `README.Rmd`, `README.md`, `AGENTS.md` (testing sections only) | 5.3.2 | `5.4.1` |
| final | Phase exit gate (orchestrator, serial) | none | wave 5 | none |

**Why the mock deletion waits for the harness.** `is_compiled()` lives in
`helper-mock-backend.R` and is used by most test files. 5.1.1 moves it into
`helper-local-cas.R` first; deleting the mock helper before that move would break every
Rust-gated test. This is why 5.1.2 depends on 5.1.1 and sits in wave 2, not wave 1.

Disjointness: wave 2 — `5.1.2` (three deletions) vs `5.2.1` (one new file): no overlap.
Wave 3 — `5.2.2` (new file `test-local-download.R`) vs `5.3.1` (new file
`test-local-failures.R`): no overlap. Wave 5 — workflow file vs docs files: no overlap.

Max concurrency is 2 in every wave (D7).

Note on `test-streaming.R` (5.3.2): only the three HF-gated download and range tests in it
are rewritten. The `xet_stream_raw validates input parameters` and `xet_stream_range
validates byte range parameters` tests remain, since Phase 4 relies on them.

---

## Task specs

Common acceptance rules for every task:
- Targeted command must exit 0; report verbatim pass and fail counts.
- Workers do not run the full suite; the orchestrator runs it serially at wave end.
- Every file outside "Files in scope" is untouchable. Discovered work goes in `## Discovered`.
- Local-server commands require the server binary. The orchestrator exports it once:
  `export RXET_LOCAL_CAS_SERVER="$(command -v local_cas_server)"` (or the path recorded in
  STATE_5.md by 5.0.1).

### 5.0.1.server-spike (orchestrator, serial, before wave 1)

- **Repo:** rxet. No repo file changes.
- **Purpose:** establish facts the harness depends on before any test is written.
- **Steps:**
  1. Install: `cargo install xet-client --version 1.7.0 --features simulation --bin local_cas_server --locked`. Record wall-clock time, rustc version, and binary path.
  2. Start the server: `local_cas_server --in-memory --port <free> --host 127.0.0.1` in the background. Record its startup log line and how long until it accepts connections.
  3. Probe the reconstruction route with a known-missing file id (`GET /v1/reconstructions/<64 zeros>`). Record the HTTP status and body shape.
  4. Stop the server. Record whether it exits cleanly on SIGTERM.
  5. Write the findings under `### 5.0.1 spike` in `planning/STATE_5.md`: binary path, install time, startup time, route status codes, exit behavior.
- **Acceptance:** `command -v local_cas_server` returns a path, and the spike findings are recorded. If install fails, STOP and report (H1/H2); do not start wave 1.

### 5.1.1.local-server-harness

- **Repo:** rxet
- **Files (must create):** `tests/testthat/helper-local-cas.R`, `tests/testthat/test-local-cas-harness.R`
- **Files (must edit):** `DESCRIPTION` (add `processx` and `digest` to `Suggests` only; no Imports)
- **Depends on:** 5.0.1
- **Reference implementation:** `tests/testthat/test-phase4-lifecycle.R` `closed_port()` (port selection) and `make_test_client()` (env seam, restore pattern).

**Spec**
0. **Move `is_compiled()`**: copy the function from `tests/testthat/helper-mock-backend.R` (the definition starting at `is_compiled <- function()`) verbatim into `helper-local-cas.R`, with its roxygen block. Do **not** edit or delete `helper-mock-backend.R` in this task (5.1.2 does that). After this step, `grep -n "is_compiled <- function" tests/testthat/*.R` must show the definition in both files, which is expected and temporary until 5.1.2.
1. `local_cas_binary()`: return the path from `RXET_LOCAL_CAS_SERVER`, else `Sys.which("local_cas_server")`, else `NA`. An empty environment value counts as unset.
2. `skip_without_local_cas()`: `skip_if_not(is_compiled(), ...)`, `skip_if_not_installed("processx")`, and skip if the binary is `NA` with message `local_cas_server not found: set RXET_LOCAL_CAS_SERVER (see planning/EXECUTION_PLAN_5.md)`.
3. `start_local_cas()`: pick a free loopback port (retry up to 20 times on bind failure), start the binary with `processx::process$new(binary, c("--in-memory", "--host", "127.0.0.1", "--port", port), stdout = "|", stderr = "|")`, wait up to 30 seconds for a TCP connect, and return `list(endpoint = sprintf("http://127.0.0.1:%d", port), proc = proc)`. The caller owns cleanup: `h <- start_local_cas(); on.exit(stop_local_cas(h), add = TRUE)`.
4. `stop_local_cas(handle)`: kill the process and wait for exit. Safe to call twice.
5. `make_fixture_bytes(n, seed = 1L)`: deterministic bytes via `set.seed(seed); as.raw(sample.int(256L, n, replace = TRUE) - 1L)`.
6. `upload_fixture(client, bytes)`: write bytes to `tempfile(fileext = ".bin")`, call `xet_upload_file(client, path)`, return `list(hash, file_size, sha256)` where `sha256` is `digest::digest(bytes, algo = "sha256", serialize = FALSE)`. Guard with `skip_if_not_installed("digest")`.
7. `assert_roundtrip(client, bytes)`: upload, download to a temp destination, read back, `expect_identical(readBin(dest, "raw", length(bytes)), bytes)`. This is H11's guard; it must pass before any download test relies on upload.
8. No helper uses `HF_TOKEN` or a non-loopback endpoint.
9. `test-local-cas-harness.R` has one `test_that("local server starts, answers, and stops")`: skipped by `skip_without_local_cas()` when absent; otherwise starts the server, confirms a TCP connect, stops it, and confirms `proc$is_alive()` is FALSE.

**Anchors**
- `tests/testthat/test-phase4-lifecycle.R` `closed_port`, `make_test_client`.

**Constraints (do not touch)**
- `R/**`, `src/**`, every existing `tests/testthat/test-*.R` file except the new harness smoke test, `helper-mock-backend.R` (deleted by 5.1.2, not here), `man/**`, `NAMESPACE`, `.github/**`.
- Do not add `withr`, `callr`, or any Imports entry.
- Do not write under the repo or `./local_cas_data`.

**Acceptance**
```bash
Rscript -e 'devtools::load_all(quiet = TRUE); stopifnot(exists("start_local_cas", mode = "function"), exists("assert_roundtrip", mode = "function")); cat("HELPERS_OK\n")' && Rscript -e 'devtools::test(filter = "local-cas-harness|phase4-lifecycle", reporter = "summary", stop_on_failure = TRUE)'
```
Exit 0 for both. The lifecycle suite is unchanged, so it shows no regression.

---

### 5.1.2.retire-mock-tests

- **Repo:** rxet
- **Files (must delete):** `tests/testthat/helper-mock-backend.R`, `tests/testthat/test-stream-range.R`, `tests/testthat/test-concurrent.R`
- **Depends on:** 5.1.1 (`is_compiled()` must already live in `helper-local-cas.R`)
- **Reference:** none (deletion task).

**Spec**
1. Before deleting, run `grep -n "create_mock_backend\|mock_cas_chunk\|mock_metadata_shard\|mock_xet_read_token\|mock_head_file_response\|create_test_scenarios\|create_test_fixtures\|with_test_client" tests/testthat/*.R`. Expected hits: only the three files to be deleted. If any other file hits, STOP and report (H13).
2. Delete the three files with `git rm` (tracked files). Do not delete any other file.
3. Confirm `tests/testthat/test-parallel-downloads.R` still references only `determine_action`, `format_action`, `evict_*`, `maintain_cache` (pure R helpers) and no mock helper.

**Anchors:** the grep in step 1.

**Constraints (do not touch)**
- Every other file under `tests/`, `R/`, `src/`, `man/`, `DESCRIPTION`, `NAMESPACE`.
- Do not replace the deleted coverage in this task; replacement is 5.2.x and 5.3.x.

**Acceptance**
```bash
! grep -ln "create_mock_backend\|mock_cas_chunk\|mock_metadata_shard\|mock_xet_read_token\|mock_head_file_response\|create_test_scenarios\|create_test_fixtures\|with_test_client" tests/testthat/*.R && test ! -e tests/testthat/helper-mock-backend.R && test ! -e tests/testthat/test-concurrent.R && test ! -e tests/testthat/test-stream-range.R && Rscript -e 'devtools::test(filter = "parallel-downloads|utils|input-validation", reporter = "summary", stop_on_failure = TRUE)'
```
Exit 0.

---

### 5.2.1.local-upload-roundtrip

- **Repo:** rxet
- **Files (must create):** `tests/testthat/test-local-upload.R`
- **Depends on:** 5.1.1
- **Reference:** `tests/testthat/test-local-cas-harness.R` (created in 5.1.1).

**Spec** (every test skips without the local server via `skip_without_local_cas()`)
1. Success: upload deterministic 64 KiB bytes (`make_fixture_bytes(65536L)`). Assert the result has `hash` (64 hex characters, `grepl("^[0-9a-f]{64}$", hash)`) and `file_size == 65536`.
2. Byte integrity: download the uploaded hash to a temp destination with `xet_download_file(client, hash, 65536, dest)`; assert `readBin(dest, "raw", 65536L)` is identical to the input bytes. Assert no `.part` files remain in the directory.
3. Multi-chunk: upload 4 MiB of deterministic bytes; round-trip it; assert byte identity. (Local-server only; this is the multi-chunk evidence H10 refers to.)
4. Empty file: uploading a zero-byte file must either succeed with `file_size == 0` and round-trip, or error. Probe first and assert what is observed; record in the test name which behavior is pinned. Do not guess.
5. Missing source: `xet_upload_file(client, "/nonexistent/path")` errors with `"source file does not exist"` (R-side check, no server call).
6. Upload result is stable: uploading the same bytes twice returns the same `hash`.

**Anchors**
- `R/upload.R` `xet_upload_file` (R-side existence check, `.Call` at the end).
- `src/rust/src/lib.rs` `fn xet_upload_file` (single-upload check added in 4.2.1, `Sha256Policy::Skip`).

**Constraints (do not touch)**
- Every file except `tests/testthat/test-local-upload.R`. No `R/` or `src/` change; if the upload is wrong, STOP and report with the failing assertion (do not fix product code in a test task).

**Acceptance**
```bash
Rscript -e 'devtools::test(filter = "local-upload", reporter = "summary", stop_on_failure = TRUE)'
```
Exit 0 with the local server present. With the server absent, the file must skip cleanly (report the skip count).

---

### 5.2.2.local-download-read

- **Repo:** rxet
- **Files (must create):** `tests/testthat/test-local-download.R`
- **Depends on:** 5.1.1, 5.2.1 (upload round-trip must be proven before download tests rely on it; H11)
- **Reference:** `tests/testthat/test-local-cas-harness.R`; `test-phase4-lifecycle.R` for the temp-dir pattern.

**Spec** (each test skips without the local server; fixtures come from `upload_fixture` in the test itself, never from `tests/fixtures/`)
1. Disk download byte integrity: upload 64 KiB; `xet_download_file`; assert byte identity and `file.size(dest) == 65536`.
2. Raw read: `xet_stream_raw(client, hash, 65536)` returns `raw` of length 65536, identical to the input.
3. Range boundaries on a multi-chunk fixture (4 MiB): assert byte-exact results for `[0, 1)`, `[0, 4096)`, `[4095, 4097)` (crossing a 4 KiB boundary), `[size-1, size)`, and a mid-chunk range `[1000003, 1500017)`; each compared to `bytes[(start+1):end]`.
4. Range invalid: `xet_stream_range(client, hash, size, 100, 100)` errors (empty range) and `end > size` errors, both before any server contact where possible.
5. Connection helper: `xet_open_connection(client, hash, 65536)` returns a connection; `readBin(conn, "raw", 65536L)` is identical to the input; `xet_close_connection(conn)` succeeds. This is the success evidence Phase 1 required for `xet_close_connection` (Appendix A row).
6. Cleanup: after every disk download in this file, assert no `.part` file remains beside `dest` (Phase 4 atomic-download guarantee on the success path).
7. Handle reuse: two downloads on the same client yield identical bytes (no state corruption).

**Anchors**
- `R/download.R` `xet_download_file` (temp-file rename, 4.2.2).
- `R/stream.R` `xet_stream_raw`, `xet_stream_range` (cap and range checks, 4.1.1/4.2.1).
- `R/connection.R` `xet_open_connection`, `xet_close_connection`.

**Constraints (do not touch)**
- Every file except `tests/testthat/test-local-download.R`. No `R/` or `src/` edits.

**Acceptance**
```bash
Rscript -e 'devtools::test(filter = "local-download", reporter = "summary", stop_on_failure = TRUE)'
```
Exit 0 with the local server present; skip cleanly without it.

---

### 5.3.1.local-failure-paths

- **Repo:** rxet
- **Files (must create):** `tests/testthat/test-local-failures.R`
- **Depends on:** 5.1.1, 5.2.1
- **Reference:** `tests/testthat/test-phase4-lifecycle.R` (failure-path style).

**Spec** (local server; loopback only)
1. **Probe first (H6):** with the server running, request a token-protected route with a wrong bearer token and with no token, and record the observed status. Write the probe result as a comment at the top of the file. Assertions below for auth are written only for behavior the probe confirmed; if the server accepts any token, the auth test is skipped with the reason `"local server does not enforce tokens (probe 5.3.1)"`.
2. **Invalid hash:** `xet_download_file` with a 64-zero hash errors; `dest` absent; no `.part` leftovers.
3. **Invalid hash raw:** `xet_stream_raw` with the same hash errors; no value returned.
4. **Size mismatch:** `xet_download_file` with the real hash but a wrong `file_size` (e.g., `65536 + 1`): record the observed behavior; assert that either an error occurs or the bytes returned are the real file (no silent truncation or padding). Pin what is observed.
5. **Token not leaked:** with a distinctive token string, every error from 1–4 is checked with `grepl(token, msg, fixed = TRUE)` is FALSE.
6. **Endpoint down mid-session:** start the server, create a client, stop the server, then download; expect an error within 60 seconds and no destination file.
7. **Clean shutdown:** after `stop_local_cas`, the process is no longer alive (`proc$is_alive()` is FALSE).

**Anchors**
- `src/rust/src/lib.rs` `fn xet_download_file`, `fn xet_stream_raw` error mapping (`Error::Other(format!("download error: {}", e))`).

**Constraints (do not touch)**
- Every file except `tests/testthat/test-local-failures.R`. No `R/` or `src/` edits. If the probe shows behavior the spec does not anticipate, record it under `## Discovered` and stop, not work around it.

**Acceptance**
```bash
Rscript -e 'devtools::test(filter = "local-failures", reporter = "summary", stop_on_failure = TRUE)'
```
Exit 0; skips only for the probe-justified auth skip and the absent-server skip.

---

### 5.3.2.live-suite

- **Repo:** rxet
- **Files (must create):** `tests/testthat/test-live-hf.R`
- **Files (must edit):** `tests/testthat/test-connection.R` (rewrite HF-gated tests only), `tests/testthat/test-streaming.R` (rewrite the HF-gated download and range success tests only; keep the validation tests)
- **Depends on:** 5.1.2, 5.2.2
- **Reference:** `R/download.R`, `R/stream.R`, `R/connection.R`; the dataset facts in the recon log (J3).

**Spec**
1. **Gate:** every test in `test-live-hf.R` begins with `skip_if_not(identical(Sys.getenv("RXET_LIVE_TESTS"), "1"), "live tests are opt-in: set RXET_LIVE_TESTS=1")`, then `skip_if_not(is_compiled(), ...)`. No other gate. A network failure with the gate set is an error (H8).
2. **Constants** at the top of the file: `LIVE_REPO <- "brownag/rxet-test-data"`, `LIVE_HASH <- "4e99cb45a4ad980707548c95f5cc3dadb91e36889c68adbff641e56c53981331"`, `LIVE_SIZE <- 2931`, `LIVE_SHA256 <- "c25ed568c3f701e640a6d9db7495b8d989ee2f6dbaf3fc0ad2216c6d5cd28bf4"`. Cite the hub tree API in a comment.
3. **Endpoint and token:** endpoint `https://cas-cf.huggingface.co` (the value used by `with_test_client`'s default; confirm it against the hub's `xet-read-token` response during step 4). Token from `Sys.getenv("HF_TOKEN")`; empty string is passed as-is if the probe shows anonymous reads work.
4. **Probe (J2, H7):** first test, record in its output whether an anonymous client can download `LIVE_HASH`. Assert the outcome observed and write a comment with the result. If a token is required and `HF_TOKEN` is unset, skip the rest with `"live reads require HF_TOKEN (probe 5.3.2)"`.
5. **Byte integrity:** download `LIVE_HASH` to disk; assert `file.size == 2931` and `digest::digest(file = dest, algo = "sha256") == LIVE_SHA256` (`skip_if_not_installed("digest")`).
6. **Raw read:** `xet_stream_raw(client, LIVE_HASH, 2931)`; assert length 2931 and sha256 of the raw vector equals `LIVE_SHA256`.
7. **Range boundaries (live):** `xet_stream_range` for `[0, 4)` equals `charToRaw("PAR1")` and `[2927, 2931)` equals `charToRaw("PAR1")` (Parquet head and tail magic). Also `[0, 2931)` equals the full raw read.
8. **Connection (live):** `xet_open_connection` then `readBin` of 2931 bytes equals the raw read; `xet_close_connection` succeeds.
9. **Rewrite `test-connection.R`:** replace the HF-gated test with the live assertion from step 8 (kept under the RXET_LIVE_TESTS gate in this file). The `skip_if(nchar(Sys.getenv("HF_TOKEN")) == 0, ...)` line is removed; the gate is `RXET_LIVE_TESTS`.
10. **Rewrite `test-streaming.R`:** the two HF-gated tests (`xet_stream_raw returns raw vector`, `xet_stream_raw` line 5 gate) become live assertions using `LIVE_HASH`; the validation tests (`validates input parameters`, `validates byte range parameters`) are kept unchanged.
11. **No writes:** this file never calls `xet_upload_file` (D4).

**Anchors**
- `tests/testthat/test-streaming.R` lines 3–15 (raw test), 35–51 (range validation kept).
- `tests/testthat/test-connection.R` lines 1–25.
- `tests/testthat/hf_test_files.R` `HF_TEST_FILES$parquet$hash` (matches `LIVE_HASH`; keep the file, do not edit it).

**Constraints (do not touch)**
- `tests/testthat/test-arrow-spatial.R` (J5), `tests/testthat/hf_test_files.R`, `tests/testthat/hf_test_setup.R`, `R/**`, `src/**`, `DESCRIPTION`.
- Do not print or log the token. Do not write the token into any file.

**Acceptance**
```bash
Rscript -e 'devtools::test(filter = "streaming|connection", reporter = "summary", stop_on_failure = TRUE)' && RXET_LIVE_TESTS=1 Rscript -e 'devtools::test(filter = "live-hf", reporter = "summary", stop_on_failure = TRUE)'
```
The first command must exit 0 with the gate unset (live tests skipped, validation tests passing). The second is the manual live run: it must be recorded in STATE_5.md with its exact pass and fail counts and the probe result. A failure there is a finding, not a skip.

---

---

### 5.4.1.ci-local-server

- **Repo:** rxet
- **Files (must edit):** `.github/workflows/R-CMD-check.yaml` only
- **Depends on:** 5.3.1, 5.3.2
- **Reference:** the existing workflow's `dtolnay/rust-toolchain@stable` and `R CMD check` steps (Phase 3 3.1.4).

**Spec**
1. Add a step after the Rust toolchain step, on all three operating systems: restore the cargo cache for `xet-client` (`actions/cache` keyed on `xet-client-1.7.0` and the rustc version), then run `cargo install xet-client --version 1.7.0 --features simulation --bin local_cas_server --locked` if the binary is not cached.
2. Export `RXET_LOCAL_CAS_SERVER` to the step environment using the install path (`$HOME/.cargo/bin/local_cas_server`, with `.exe` on Windows). Use `shell: bash` on all three OS (already set in Phase 3 step env).
3. Set a timeout of 45 minutes for the install step, to bound Windows compile time (H1).
4. Do not set `RXET_LIVE_TESTS` or `HF_TOKEN` anywhere in this workflow (D2, Phase 1 decision). Assert this with grep in the acceptance.
5. Leave the `R CMD check` step unchanged; it runs the local-server suite because the binary is now on `PATH`/env.

**Anchors**
- `.github/workflows/R-CMD-check.yaml` `dtolnay/rust-toolchain@stable` step and the `R CMD check` step.

**Constraints (do not touch)**
- Any other workflow file, `R/**`, `tests/**`, docs.
- No new secrets. No `pull_request_target`. No live variables.

**Acceptance**
```bash
python3 -c "import yaml,sys; d=yaml.safe_load(open('.github/workflows/R-CMD-check.yaml')); print('YAML_OK')" && ! grep -n "RXET_LIVE_TESTS\|HF_TOKEN\|secrets\." .github/workflows/R-CMD-check.yaml && grep -n "local_cas_server" .github/workflows/R-CMD-check.yaml && grep -c "windows-latest" .github/workflows/R-CMD-check.yaml
```
Exit 0; `windows-latest` count ≥ 1. CI execution is validated only after push; record that deferral in STATE_5.md (as Phase 3 did for macOS and Windows).

---

### 5.4.2.docs-testing

- **Repo:** rxet
- **Files (must edit):** `README.Rmd`, `README.md`, `AGENTS.md` (testing sections only)
- **Depends on:** 5.3.2
- **Reference:** Phase 4's 4.4.1 README edits (same hand-sync pattern for `.md`).

**Spec**
1. `AGENTS.md`: replace the "Testing" section's "No formal test suite yet" with the real commands: routine offline suite (`devtools::test()`), local-server install and `RXET_LOCAL_CAS_SERVER`, and the live run (`RXET_LIVE_TESTS=1`, `HF_TOKEN` only if the probe requires it). Name the dataset and the live gate. Do not describe anything unverified.
2. `README.Rmd` and `README.md`: any "Testing" or "Development" text is updated to match (1). Remove any sentence that claims coverage the suite does not have. Mirror into `README.md` by hand; do not re-render.
3. Do not change the public API description, the experimental labels, or the export list (ADR 0001).
4. Note in the docs that live tests are on demand and that public CI never runs them.

**Anchors**
- `AGENTS.md` section `## Testing`; `README.Rmd` and `README.md` sections that mention testing (`grep -n -i "test" README.Rmd`).

**Constraints (do not touch)**
- `R/**`, `src/**`, `tests/**`, `man/**`, `NAMESPACE`, `DESCRIPTION`, `.github/**`, `docs/decisions/**`, `planning/**` (except your report in STATE_5.md).

**Acceptance**
```bash
grep -n "RXET_LOCAL_CAS_SERVER\|RXET_LIVE_TESTS" AGENTS.md README.Rmd README.md && ! grep -n "No formal test suite yet" AGENTS.md && git diff --quiet -- NAMESPACE R/ man/
```
Exit 0.

---

## Final phase gate (orchestrator, serial, after wave 4)

1. Export `RXET_LOCAL_CAS_SERVER` and run the full routine suite: `Rscript -e 'devtools::test(reporter = "summary", stop_on_failure = TRUE)'` → exit 0, `failed: 0`. Record pass and skip counts; expected skips are the live gate and the optional packages.
2. Manual live run (D2): `RXET_LIVE_TESTS=1 Rscript -e 'devtools::test(filter = "live-hf|connection|streaming", reporter = "summary")'` against `brownag/rxet-test-data`. Record the exact result and the probe outcome (J2). A failure is a finding for the user, not a skip.
3. Clean-archive `R CMD build` and `R CMD check --no-manual` with `_R_CHECK_FORCE_SUGGESTS_=false` and **without** `RXET_LOCAL_CAS_SERVER` set: `Status: OK`, and the skips are the documented gates only. Scratch directory outside the repo.
4. Confirm no file under `tests/` writes outside `tempdir()`; confirm `local_cas_data/` does not exist in the repo.
5. Confirm `planning/tasks/` todo files for every task exist and each STATE_5 report is present.
6. Record residual gaps in STATE_5.md: live multi-chunk and GeoTIFF evidence (H10); token-lifetime and mid-stream interruption (Out of scope); Windows and macOS server runs (H1, CI-gated); arrow/spatial (Phase 6).

## Cross-task notes

- The local-server suite and the live suite both assert byte identity; they must use the same
  `make_fixture_bytes` and `LIVE_SHA256` conventions so a regression is attributed to the
  same operation in both.
- Error text for new failure-path tests follows the existing messages (`"invalid or closed
  client handle"`, `"source file does not exist"`); no product error text changes in Phase 5.
- No product code changes are expected in Phase 5. Any product defect the tests reveal is a
  STOP-and-report finding for a follow-up phase or a user decision, not a silent fix.

---

## Amendment (2026-10-15): task 5.3.0.stream-length-check (product defect fix, user-approved)

**Why this exists.** Task 5.3.1 found that `xet_stream_raw` returns `raw(0)` with no error for an unknown hash (reproduced: 64-zero hash, size 1024 → length 0). `xet_open_connection` builds on it and returns an empty connection. The Phase 5 rule is "no product fixes in test tasks; a defect is a STOP-and-report." The user chose "Fix it now" on 2026-10-15. This amendment is that fix, scoped to the minimum.

**Wave placement.** Wave 3 gate is held until 5.3.0 lands. 5.3.0 is serial (nothing else runs in parallel with it). 5.3.1's failing test then passes as written; no test is changed.

### 5.3.0.stream-length-check

- **Repo:** rxet
- **Files (must edit):** `src/rust/src/lib.rs` only
- **Depends on:** 5.2.2, 5.3.1 (committed state)
- **Reference:** the existing error style `Error::Other(format!(...))` in the same functions.

**Spec**
1. In `fn xet_stream_raw`, after the `while let Some(chunk) = stream.blocking_next()` loop, add a check: if `buf.len() as u64 != size_bytes`, return `Error::Other(format!("stream returned {} bytes, expected {} for hash {}", buf.len(), size_bytes, file_hash))`.
2. In `fn xet_stream_range`, after its loop, apply the same check against `size` with the same wording.
3. Do not change any other error text. Do not add token text to any message. The hash is public content identity, so it may appear.
4. No changes to `R/**`, `tests/**`, or other Rust files.
5. Confirm by reading the code that the success path (correct hash, full size) still returns the bytes unchanged.

**Anchors:** `grep -n "blocking_next\|Ok(buf.into_robj())\|fn xet_stream_raw\|fn xet_stream_range" src/rust/src/lib.rs`.

**Acceptance**
```bash
cd src/rust && cargo check 2>&1 | tail -1 && cd ../.. && RXET_LOCAL_CAS_SERVER=$HOME/.cargo/bin/local_cas_server Rscript -e 'devtools::test(filter = "local-failures|local-download|streaming|stream", reporter = "summary", stop_on_failure = TRUE)'
```
Exit 0. The `local-failures` invalid-hash `xet_stream_raw` test must now pass; `local-download` range boundary tests must still pass.
