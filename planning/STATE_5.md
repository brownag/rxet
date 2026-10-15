# State 5 — Phase 5: Verify Real Xet Protocol Behavior and Make Core Integration Tests Meaningful

Resume from this file. Plan: `planning/EXECUTION_PLAN_5.md`. Worker skeleton: `planning/PROMPT_TEMPLATE_5.md`.
Status: **plan drafted; awaiting user approval** (2026-10-15). No task has started.

## Baseline checklist (observed 2026-10-15; re-verify before wave 1)

- [x] Repository instructions read: `AGENTS.md` (its "Testing" section is stale: "No formal test suite yet"; 5.4.2 fixes it).
- [x] Master input read: `planning/MASTER_PLAN.md` (Phase 5 mandate and exit gate).
- [x] Prior phases read: `planning/STATE_1.md`, `STATE_2.md`, `STATE_3.md`, `STATE_4.md`; ADRs `docs/decisions/0001`, `0002`, `0003`.
- [x] Phase 4 complete (HEAD `930554e` at plan start; `a4fb9fd` records the exit gate).
- [x] Last recorded suite: `devtools::test()` → `failed: 0  skipped: 9  passed: 143  errors: 0` (Phase 4 exit gate). Clean-archive `R CMD check` → `Status: OK`.
- [x] Live dataset metadata (public hub API, no token): `brownag/rxet-test-data` public, not gated; `test_data.parquet` Xet-stored (`xetHash` `4e99cb45…1331`, 2931 B, LFS sha256 `c25ed568…28bf4`); JSON and GeoJSON git-stored.
- [x] Anonymous Xet token endpoints returned HTTP 404 (`…/xet-read-token`, `…/xet-write-token`). Inconclusive; probed in 5.3.2.
- [x] `gh repo view brownag/rxet-test-data` → 404 (expected: the dataset is on Hugging Face, not GitHub).
- [x] Server facts: `local_cas_server` in `xet-client-1.7.0` (feature `simulation`); flags `--in-memory`, `--data-directory`, `--port`, `--host`. Routes include `/v1/reconstructions/{id}`, `/v2/reconstructions/{id}`, and xorb/shard upload routes. Install and startup not yet measured (5.0.1).
- [x] Mock-backed tests identified: `helper-mock-backend.R`, `test-stream-range.R`, `test-concurrent.R` (retired by 5.1.2). `test-parallel-downloads.R` is pure R logic (kept).
- [x] HF-token-gated tests with fake hashes: `test-streaming.R` (rewritten in 5.3.2, validation tests kept), `test-connection.R` (rewritten), `test-arrow-spatial.R` (untouched, Phase 6 — J5).
- [x] **Pre-wave-1 step (5.0.1):** done 2026-10-15; findings below.
- [ ] Pre-wave-1 suite baseline (orchestrator): `devtools::test()` → counts recorded here before wave 1.

## Decisions / user answers (2026-10-15)

- D1: Test seam is **hybrid**: routine offline success-path tests use the upstream `local_cas_server`; live tests run against `brownag/rxet-test-data` only when opted in.
- D2: Live tests run **on demand** (`RXET_LIVE_TESTS=1`), locally or by a developer. Public CI never sets it. (User answer to "what would make live tests proper": "Run live tests on demand".)
- D3: The server binary is **installed out-of-band** (`cargo install xet-client --version 1.7.0 --features simulation --bin local_cas_server --locked`). rxet's `Cargo.toml` and `Cargo.lock` are unchanged.
- D4: **Upload is local-only.** No live write in Phase 5; `xet_upload_file` stays experimental.
- D5: **Retire network-claim mock tests** (`helper-mock-backend.R`, `test-stream-range.R`, `test-concurrent.R`). Keep `test-parallel-downloads.R`.
- D6: **CI on all three platforms** (ubuntu, macos, windows) installs and runs the local-server suite.
- D7: Max 2 concurrent workers per wave, file-disjoint; Haiku workers; escalation per wave-orchestration's ladder (continues Phase 4 D8).

### Planner judgment calls (flagged for review, not asked)

- J1: `processx` and `digest` added to `Suggests` (cross-platform process management; sha256). Routine installs gain no requirement.
- J2: Live gate is `RXET_LIVE_TESTS=1`; `HF_TOKEN` read only if set. Whether anonymous reads work is probed in 5.3.2.
- J3: Known-good live integrity value is the hub LFS sha256 `c25ed568…28bf4` (2931 bytes), not a locally generated copy.
- J4: Json and GeoJSON are git-stored, so not used for Xet tests.
- J5: `test-arrow-spatial.R` untouched; Phase 6.
- J6: Server data lives in memory or a temp dir; nothing written into the repo.

## Known limitations carried into this phase (not resolved here)

- The live dataset has one 2.9 KB Xet file: no live multi-chunk, mid-chunk range, or GeoTIFF evidence against real storage. Local-server tests cover multi-chunk offline. A larger live fixture is a user action (the user may add one to `brownag/rxet-test-data`); no task depends on it.
- Token lifetime (`with_token_info(…, u64::MAX)`) and mid-stream interruption are not tested (need fault injection). Recorded as deferrals.
- Upload live success is not proven (D4).

### 5.0.1 spike

- Binary: `~/.cargo/bin/local_cas_server` (not on this shell's `PATH`; tests must use `RXET_LOCAL_CAS_SERVER` with the full path). `local_cas_server --version` → `1.7.0`.
- Install: `cargo install xet-client --version 1.7.0 --features simulation --bin local_cas_server --locked` → rc 0 in ~29 s; rustc `1.96.0-nightly`.
- Startup: `--in-memory --host 127.0.0.1 --port <free>` accepts TCP connections in ~0.25 s.
- Missing reconstruction: `GET /v1/reconstructions/<64 zeros>` and `GET /v2/reconstructions/<64 zeros>` both return HTTP **416** ("Range not satisfiable"), not 404. Harness and failure tests must treat this as the "unknown file" response; 5.3.1 asserts the client errors, not a specific status.
- Shutdown: SIGTERM exits the process cleanly.
- Server log was empty at startup with default verbosity.

### 5.1.1.local-server-harness

- Status: done (2026-10-15). Not committed. Micro-plan: `planning/tasks/5.1.1.local-server-harness.todo.md`.
- Files: created `tests/testthat/helper-local-cas.R` (verbatim `is_compiled` copy plus `local_cas_binary`, `skip_without_local_cas`, `start_local_cas`, `stop_local_cas`, `make_fixture_bytes`, `upload_fixture`, `assert_roundtrip`) and `tests/testthat/test-local-cas-harness.R`; edited `DESCRIPTION` Suggests (`digest`, `processx`).
- `is_compiled` now defined in both `helper-local-cas.R` and `helper-mock-backend.R` (expected until 5.1.2).
- Deviation (approved): server stdout and stderr go to `tempfile()` sinks, not `"|"`; both removed in `stop_local_cas`.
- Port retry: up to 20 attempts; a dead process or no TCP connect within 30 s triggers a retry on a new port.
- Smoke test: not skipped (2 expectations passed).
- Acceptance (`RXET_LOCAL_CAS_SERVER=$HOME/.cargo/bin/local_cas_server`): `HELPERS_OK`, exit 0. Suite over `local-cas-harness|phase4-lifecycle`: 10 tests, 19 expectations passed, 0 failed, 0 skipped, 0 errors; exit 0.
- Working-tree side effect: `devtools::load_all` rebuilt `src/Makevars` and `src/entrypoint.o`, which now show as modified. Not staged, not restored (git checkout is prohibited). Needs a decision before commit.
- Not run: full `devtools::test()` (out of scope for this task).

## Wave board



| Wave | Tasks | Status | Depends on |
|---|---|---|---|
| 0 | `5.0.1.server-spike` (orchestrator, serial) | pending | none |
| 1 | `5.1.1.local-server-harness` | done (smoke test passes, 2 expectations) | 5.0.1 |
| 2 | `5.1.2.retire-mock-tests` | done (3 files removed; with_test_client moved) | 5.1.1 |
| 2 | `5.2.1.local-upload-roundtrip` | done (6 tests, server set) | 5.1.1 |
| 3 | `5.2.2.local-download-read` | done (7 tests, server set) | 5.1.1, 5.2.1 |
| 3 | `5.3.1.local-failure-paths` | done (auth skipped by probe; defect found, fixed by 5.3.0) | 5.1.1, 5.2.1 |
| 4 | `5.3.2.live-suite` | pending | 5.1.2, 5.2.2 |
| 5 | `5.4.1.ci-local-server` | pending | 5.3.1, 5.3.2 |
| 5 | `5.4.2.docs-testing` | pending | 5.3.2 |
| 3a | `5.3.0.stream-length-check` (user-approved defect fix) | done | 5.3.1 finding |
| final | Phase exit gate (orchestrator, serial) | pending | wave 5 |

## Phase exit gate checklist (orchestrator)

- [ ] Routine suite with `RXET_LOCAL_CAS_SERVER` set: `devtools::test()` → `failed: 0`; record pass and skip counts.
- [ ] Manual live run (`RXET_LIVE_TESTS=1`) against `brownag/rxet-test-data`: exact result and probe outcome recorded here. A failure is a finding for the user.
- [ ] Clean-archive `R CMD build` and `R CMD check --no-manual` (without the server variable): `Status: OK`; skips are documented gates only.
- [ ] No test writes outside `tempdir()`; no `local_cas_data/` in the repo.
- [ ] Every task's todo file and STATE report present.
- [ ] Residual gaps recorded (see "Known limitations"), plus Windows and macOS server runs (CI-gated, H1).

### Cross-task rule from 5.2.1 (applies to 5.2.2, 5.3.x, 5.3.2)

- The Xet client keeps a shard cache under `HF_HOME` (default `~/.cache/huggingface/xet`), shared across processes and endpoints. A second upload of identical bytes to a fresh server is deduplicated and then fails on download with HTTP 404. Every test that uploads or downloads a local fixture must give itself a private `HF_HOME` (use `start_upload_client()` from `test-local-upload.R`, or copy its pattern).
- Probes during 5.2.1 wrote entries under the developer's real `~/.cache/huggingface/xet`. These are harmless caches but were not intentional; no repo file is affected.

## Task reports

<!-- Orchestrator and workers append reports below. One section per task id, <=15 lines each. -->

### 5.1.2.retire-mock-tests
- Status: done (not committed). Staged deletions via `git rm`: `helper-mock-backend.R`, `test-stream-range.R`, `test-concurrent.R`.
- Created `tests/testthat/helper-test-client.R` (lines 25-44 of the old helper, verbatim: `with_test_client` + roxygen; diff-verified as identical to source block). Real-client helper, not a mock.
- Original spec grep (with `with_test_client`) hit `test-client.R`, `test-arrow-spatial.R`, `test-connection.R`, `test-streaming.R`. Coordinator amended the pattern to drop `with_test_client`.
- Amended grep (7 mock-only names) after deletions: no hits in `tests/testthat/*.R`.
- `is_compiled <- function` now only in `helper-local-cas.R:11`.
- Acceptance (filter `parallel-downloads|utils|input-validation`): exit 0; tests=71 failed=0 skipped=0 passed=89.
- Extra check (filter adds `client`): tests=78 failed=0 skipped=0 passed=99.
- Deviation: scratch output of one run was written to `/tmp/unused` instead of the scratchpad. Discarded, no repo impact.
- Untracked `planning/tasks/5.1.2.retire-mock-tests.todo.md` (micro-plan) and `planning/tasks/5.2.1.local-upload-roundtrip.todo.md` (not mine) left unstaged. `helper-test-client.R` left unstaged.
- Not run: full suite (orchestrator runs at wave end).

### 5.2.1.local-upload-roundtrip

- Status: done (2026-10-15). Not committed. Micro-plan: `planning/tasks/5.2.1.local-upload-roundtrip.todo.md`.
- Files: created `tests/testthat/test-local-upload.R` (6 tests). No `R/**`, `src/**`, helpers, or other tests touched.
- Empty-file behavior (observed, pinned): upload succeeds with hash `0`×64 and `file_size == 0`; repeat uploads give the same hash; download of that hash with size 0 writes a 0-byte file.
- Multi-chunk: 4 MiB round-trips byte-identical. 64 KiB round-trips byte-identical, no `.part` files.
- Finding (product, not fixed): `xet_upload_file` deduplicates against a persistent shard cache under `HF_HOME` (default `~/.cache/huggingface/xet`), shared across processes and endpoints. A second upload of identical bytes to a fresh server is skipped, and the download then fails with HTTP 404. The test file sets a per-test `HF_HOME` tempdir to isolate this. Future tests that reuse the same fixture bytes must do the same.
- Side effect (outside repo, not by design): the earlier runs wrote shard cache under `~/.cache/huggingface/xet`.
- Acceptance (`RXET_LOCAL_CAS_SERVER=$HOME/.cargo/bin/local_cas_server`): `devtools::test(filter = "local-upload")` exit 0; tests=6, passed=11 expectations, failed=0, errors=0, skipped=0. Repeated 3 times, same result.
- Server unset: tests=6, skipped=6, failed=0, errors=0, exit 0.
- Deviations: `start_upload_client()` helper inside the test file (sets `HF_HOME`) to isolate the cache, as above. Empty-file test title names the pinned behavior.

### 5.2.2.local-download-read

- Status: done (2026-10-15). Not committed. Micro-plan: `planning/tasks/5.2.2.local-download-read.todo.md`.
- Files: created `tests/testthat/test-local-download.R` (7 tests). No `R/**`, `src/**`, helpers, `DESCRIPTION`, or other tests touched.
- Isolation: `start_download_client()` copied from `start_upload_client()`; each test has a private `HF_HOME` tempdir. Per-test `fresh_dir()` for `.part` checks.
- Coverage: 64 KiB disk download (byte + size), `xet_stream_raw`, 4 MiB range boundaries `[0,1) [0,4096) [4095,4097) [size-1,size) [1000003,1500017)`, empty and past-EOF range errors, connection read/close, `.part` absence, handle reuse.
- Acceptance (`RXET_LOCAL_CAS_SERVER=$HOME/.cargo/bin/local_cas_server`, `devtools::test(filter = "local-download", stop_on_failure = TRUE)`): tests=7, expectations=18, failed=0, errors=0, skipped=0. Repeated 3 times, same result.
- Server unset: tests=7, skipped=7, failed=0, errors=0.
- Deviations: none from the approved plan. Note `src/Makevars` and `src/entrypoint.o` show as modified in `git status` after test runs (build outputs); not staged, not restored, left for the orchestrator.
- Side effect: none in repo or `./local_cas_data`; all temp dirs via `tempfile()`.

### 5.3.1.local-failure-paths

- Status: STOPPED on Discovered (2026-10-15). Not committed. Micro-plan: `planning/tasks/5.3.1.local-failure-paths.todo.md`.
- Files: created `tests/testthat/test-local-failures.R` only. No other edits (`src/Makevars` and `src/entrypoint.o` are modified by `devtools::load_all`, unstaged and not restored).
- Auth probe (scratchpad, `GET /v{1,2}/reconstructions/<64 zeros>`): no header, wrong token, and valid-looking token all return HTTP 416. Not enforced. Auth test skipped with the spec reason.
- Size probe (65536-byte upload, download with 65537): R error `finish error: Task error: task N panicked ... left: 65537 right: 65536`. No dest, no .part. Panic text leaks hf-xet internals; noted, not a stop condition.
- Discovered: `xet_stream_raw` with a 64-zero hash returns `raw(0)` with no error. Spec step 3 requires an error. The test for this fails by design; it is not weakened.
- Acceptance (`RXET_LOCAL_CAS_SERVER=$HOME/.cargo/bin/local_cas_server`, run twice, same result): exit 1. Tests: 6. Passed: 4. Failed: 1 test with 2 failures and 1 error (all in xet_stream_raw). Skipped: 1 (auth, probe reason). Reason for failure: Discovered above.

### 5.3.0.stream-length-check

- Status: DONE (2026-10-15). Not committed. Micro-plan: `planning/tasks/5.3.0.stream-length-check.todo.md` (APPROVED).
- Files: `src/rust/src/lib.rs` only. `R/**`, `tests/**`, Cargo files, `DESCRIPTION` untouched. No `R CMD INSTALL`; rebuild via `devtools::test`.
- Diff: 14 insertions, 0 deletions. Hunk 1 in `xet_stream_raw` (after the stream loop, before `Ok(buf.into_robj())`): `buf.len() as u64 != size_bytes` returns `Error::Other("stream returned {} bytes, expected {} for hash {}")`. Hunk 2 in `xet_stream_range`: same check against `size`.
- `cargo check`: exit 0, `Finished dev profile`.
- Acceptance (`RXET_LOCAL_CAS_SERVER=$HOME/.cargo/bin/local_cas_server`): exit 0.
  - local-download: 18 passed, 0 failed.
  - local-failures: 16 passed, 0 failed, 1 skipped (auth, probe reason). Invalid-hash `xet_stream_raw` test now passes.
  - streaming: 0 run, 3 skipped (HF_TOKEN not set, pre-existing skips, not a regression).
- Log: `/tmp/claude-1000/-home-andrew-workspace-rxet/3f2eea98-4900-4ebe-ace3-43e8966b323c/scratchpad/accept_530.log`
