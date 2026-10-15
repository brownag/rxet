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
| 2 | `5.1.2.retire-mock-tests` | pending | 5.1.1 |
| 2 | `5.2.1.local-upload-roundtrip` | pending | 5.1.1 |
| 3 | `5.2.2.local-download-read` | pending | 5.1.1, 5.2.1 |
| 3 | `5.3.1.local-failure-paths` | pending | 5.1.1, 5.2.1 |
| 4 | `5.3.2.live-suite` | pending | 5.1.2, 5.2.2 |
| 5 | `5.4.1.ci-local-server` | pending | 5.3.1, 5.3.2 |
| 5 | `5.4.2.docs-testing` | pending | 5.3.2 |
| final | Phase exit gate (orchestrator, serial) | pending | wave 5 |

## Phase exit gate checklist (orchestrator)

- [ ] Routine suite with `RXET_LOCAL_CAS_SERVER` set: `devtools::test()` → `failed: 0`; record pass and skip counts.
- [ ] Manual live run (`RXET_LIVE_TESTS=1`) against `brownag/rxet-test-data`: exact result and probe outcome recorded here. A failure is a finding for the user.
- [ ] Clean-archive `R CMD build` and `R CMD check --no-manual` (without the server variable): `Status: OK`; skips are documented gates only.
- [ ] No test writes outside `tempdir()`; no `local_cas_data/` in the repo.
- [ ] Every task's todo file and STATE report present.
- [ ] Residual gaps recorded (see "Known limitations"), plus Windows and macOS server runs (CI-gated, H1).

## Task reports

<!-- Orchestrator and workers append reports below. One section per task id, <=15 lines each. -->
