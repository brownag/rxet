# State 4 — Phase 4: Harden Core Rust/R Operations and Failure Semantics

Resume from this file. Plan: `planning/EXECUTION_PLAN_4.md`. Worker skeleton: `planning/PROMPT_TEMPLATE_4.md`.
Status: **plan drafted; awaiting user approval** (2026-10-15). No task has started.

## Baseline checklist (observed 2026-10-15; re-verify before wave 1)

- [x] Repository instructions read: `AGENTS.md`.
- [x] Master input read: `planning/MASTER_PLAN.md` (Phase 4 mandate and exit gate).
- [x] Prior phases read: `planning/STATE_1.md`, `STATE_2.md`, `STATE_3.md`; ADRs `docs/decisions/0001`, `0002`, `0003`.
- [x] Phase 3 dependency satisfied: clean-archive `R CMD check` → `Status: OK` (`planning/STATE_3.md` 3.3.1).
- [x] Last recorded test suite: `FAIL 0 | WARN 0 | SKIP 11 | PASS 111` (Phase 3 evidence; under `R CMD check`).
- [x] Pre-wave-1 baseline (2026-10-15): `cargo check` → Finished (exit 0). `devtools::test()` → `failed: 0  skipped: 9  passed: 111  errors: 0` (skips: HF_TOKEN and optional-package guards; differs from Phase 3's `SKIP 11` under `R CMD check` only by environment).
- [x] Recon of `src/rust/src/lib.rs` (335 lines): registry lock held across blocking I/O (lines 129, 196, 252, 287); unchecked `round() as u64` and `Vec::with_capacity` on user sizes (136, 155, 203–208, 226, 259); `Drop` placeholder and `get_rt` (15, 57).
- [x] Recon of R wrappers: endpoint accepts any `http(s)://`; `xet_stream_raw` does not reject `Inf`; `xet_download_file` writes directly to `dest_path`.
- [x] Tooling present: `devtools`, `testthat`, `roxygen2`, `callr`, `processx`, `future`. Absent: `uuid`, `arrow` (their tests skip). `cargo 1.96.0-nightly`.
- [x] Untracked artifacts preserved: `rxet.Rcheck/` and `rxet_0.1.0.tar.gz` (not removed; D1 = ignore via `.gitignore`).

## Decisions / user answers (2026-10-15)

- D1: Untracked artifacts `rxet.Rcheck/` and `rxet_*.tar.gz` are ignored via `.gitignore`. Nothing deleted or moved.
- D2: In-memory size cap is 2^31 − 1 bytes (`i32::MAX`), enforced in R and Rust before network work; fallible allocation as second guard. No new public option.
- D3: Disk download is atomic: temp file in the destination directory, rename only on success; failure removes the temp file and leaves an existing `dest_path` untouched.
- D4: `xet_client_close()` during an in-flight operation: handle removed immediately, new calls error, in-flight operation completes on its owned `Arc`.
- D5: Upload keeps single-file behavior and `Sha256Policy::Skip`; lifecycle fixed (lock released; explicit error for multi-upload reports). Upload stays experimental.
- D6: Endpoint: `https://` any host; `http://` only for `localhost` / `127.0.0.1`.
- D7: Deterministic offline tests use a closed loopback port and a blackhole `serverSocket()`; no live credentials.
- D8: Max 2 concurrent workers per wave, file-disjoint; Rust tasks touching `src/rust/src/lib.rs` run in separate waves; Haiku workers; escalation per wave-orchestration's ladder.

### Planner judgment calls (flagged for review, not asked)

- J1: Registry-lock proof is a Rust unit test on a generic `Registry<T>` (task 4.3.2), because R is single-threaded and cannot contend the registry while `.Call` blocks. Call-site correctness is by grep and review.
- J2: Panic/FFI "safe error propagation" is review-level evidence (retained `safe_exec`, removed placeholder, error-path tests). No deterministic panic trigger exists without a new hook. Residual gap.
- J3: `callr` not added; lifecycle tests run in-process.
- J4: Blackhole timeouts may be slow if hf-xet retries before surfacing a timeout. Per-test wall-clock bound 60 s; a test over the bound is STOP-and-report, not a silent timeout increase.

## Wave board

| Wave | Tasks | Status | Depends on |
|---|---|---|---|
| 1 | `4.1.1.r-input-validation` | done (suite green) | none |
| 1 | `4.1.2.rust-registry-lock` | done (cargo check clean) | none |
| 2 | `4.2.1.rust-size-and-upload` | done (suite green) | 4.1.2 |
| 2 | `4.2.2.r-atomic-download` | done (suite green) | 4.1.1 |
| 3 | `4.3.1.lifecycle-failure-tests` | pending | 4.2.2, 4.2.1 |
| 3 | `4.3.2.rust-registry-tests` | pending | 4.2.1 |
| 4 | `4.4.1.docs-rd-sync` | pending | 4.3.1, 4.3.2 |
| final | Phase exit gate (orchestrator, serial) | pending | wave 4 |

## Phase exit gate checklist (orchestrator)

- [ ] `cargo check` and `cargo test --lib registry` exit 0.
- [ ] `R CMD INSTALL .` exit 0.
- [ ] Full suite serial: `devtools::test(...)` → `FAIL 0`.
- [ ] Clean-archive `R CMD build` + `R CMD check --no-manual` → `Status: OK`, no new ERROR/WARNING/NOTE vs. Phase 3 baseline.
- [ ] Manual review record: no registry guard held across a blocking call; no `Vec::with_capacity` on user sizes; no `.part` leftovers from tests.
- [ ] Residual gaps recorded: J1, J2, Windows `file.rename` (H4), success-path network (Phase 5).

## Task reports

<!-- Orchestrator and workers append reports below. One section per task id, <=15 lines each. -->

### 4.1.2.rust-registry-lock

- Status: done (uncommitted; orchestrator to review).
- File changed: `src/rust/src/lib.rs` only (diff: +15 / -51).
- Added `fn acquire_client` at L41–49 (lock, `get().cloned()`, lock released on return). Four call sites now `let client = acquire_client(handle)?;`: `xet_stream_raw` L113, `xet_stream_range` L175, `xet_download_file` L226, `xet_upload_file` L256.
- Removed `impl Drop for XetClient`, `TOKIO_RUNTIME`, `get_rt`; removed `OnceLock` and `tokio::runtime` imports.
- `safe_exec`, `xet_init_client` (insert ~L72), `xet_close_client` (remove ~L88), and `extendr_module!` unchanged. Error texts unchanged.
- Baseline `cargo check` warnings: 0. After edit: 0 warnings, `Finished`.
- Grep check: no `impl Drop for XetClient|fn get_rt|TOKIO_RUNTIME` in lib.rs.
- `tokio` remains in `src/rust/Cargo.toml` (unused in code, per H5 and coordinator answer 2). Not edited.
- Acceptance: `devtools::test(filter = "client", reporter = "summary", stop_on_failure = TRUE)` exit 0; output "client: .........." (10 passing expectations), no FAIL/SKIP/WARN lines. Exact pass counts from the summary reporter are not shown beyond these dots.
- Not committed. No R/, tests/, Cargo.* edits.

### 4.1.1.r-input-validation

- Status: complete, not committed. Worker ran on the approved micro-plan with the coordinator's clarifications (a)-(d).
- `R/client.R` 33-44: https accepted for any host; http accepted only when host (capture `^http://([^/:]+)`, tolower) is `localhost` or `127.0.0.1`; else stop with the D6 message. Roxygen `@param endpoint` updated.
- `R/stream.R` `xet_stream_raw` 35-54: finite/whole check (`file_size must be a finite whole number of bytes`) before `>= 0`; 2 GiB cap before `.Call` (literal `2147483647`). Roxygen updated.
- `R/stream.R` `xet_stream_range` 85-112: same finite/whole check on `file_size` only; cap on `end_byte - start_byte` with "in-memory requested range of ..." wording (clarification b). Roxygen updated.
- `R/connection.R` `xet_open_connection` 47-57: finite/whole check before `>= 0`; cap enforced by the `xet_stream_raw` call. Roxygen updated.
- `tests/testthat/test-input-validation.R`: 10 new `it()` blocks across the xet_client_new, xet_stream_raw, xet_stream_range, and xet_open_connection describes (Inf/NaN/fractional, 2 GiB cap, http/localhost/127.0.0.1/HTTP://LOCALHOST, remote-http and userinfo/IPv6 rejection). Loopback tests close their handles via `on.exit`.
- Acceptance: `devtools::test(filter = "input-validation|streaming", reporter = "summary", stop_on_failure = TRUE)` exit 0. Counts: 47 tests, 45 passed, 0 failed, 0 errors, 3 skipped (HF_TOKEN credential guards in test-streaming.R:5, :19, :37; pre-existing).
- Existing patterns ("file_size", "nchar.*handle", "end_byte.*file_size") still match; test-streaming.R:19 is skipped on this machine, so its "file_size" pattern was not exercised here.
- Deviations: none from the approved plan. Not run: `R CMD INSTALL`, roxygen2 (H7).
- Left untouched as directed: `src/Makevars`, `src/entrypoint.o` (modified by baseline run), `src/rust/src/lib.rs` (other worker). Other modified files in `git status` (`planning/EXECUTION_PLAN_4.md`, `planning/tasks/4.1.2...`) were not made by this task.

### 4.2.2.r-atomic-download

- Status: done (uncommitted). Only `R/download.R` edited.
- Lines: whole-number check L31-33 (after the L30 `file_size` stopifnot, `if (!(...)) stop(...)` form per coordinator); roxygen description L3-7 (one added sentence); `tmp <- tempfile(...)` and `on.exit(unlink)` L48-49; `.Call` now passes `tmp` L51; `file.rename` check L53-55; `invisible(dest_path)` L57. Dir/parent checks unchanged.
- Acceptance: `grep tempfile(` and `grep file.rename` both match (L48, L53); `devtools::test(filter = "input-validation", reporter = "summary", stop_on_failure = TRUE)` exit 0, no failure lines reported. Summary reporter prints no pass/fail counts, so exact counts are not available from this run.
- Parse check `parse("R/download.R")`: OK.
- Deviations: none from the approved plan. Not run: `R CMD INSTALL`, roxygen2 (H7), any behavioral download-failure test (owned by 4.3.1).
- Risk recorded: `file.rename()` overwrite on Windows unverified (H4); no Windows-specific code added.
- Left untouched: `src/Makevars`, `src/entrypoint.o`, all other tracked files. Untracked `planning/tasks/4.2.1...` and `4.2.2...` todo files are present.

### 4.2.1.rust-size-and-upload
- Status: done (not committed). Edited `src/rust/src/lib.rs` only.
- Added: `MAX_IN_MEMORY_BYTES` (const, ~line 14), `to_whole_bytes` (~lines 16-23).
- `xet_stream_raw`: `to_whole_bytes` + 2 GiB cap before `acquire_client`; `try_reserve_exact` replaces `with_capacity`.
- `xet_stream_range`: `to_whole_bytes` for total/start/end, existing offset-order messages kept, `checked_sub` for size, cap check before `acquire_client`, `try_reserve_exact`.
- `xet_download_file`: `to_whole_bytes(file_size, "file_size")` before `acquire_client`; no cap (D2).
- `xet_upload_file`: `report.uploads.len() != 1` error before `.values().next()`; `Sha256Policy::Skip` kept.
- Cap wording matches R (`R/stream.R` lines 50, 119) character for character.
- Checks: `grep -c "round() as u64\|with_capacity\|is_nan\|is_infinite"` on lib.rs = 0 matches. `cargo check` exit 0, 0 warnings.
- Acceptance (filter corrected per coordinator): `devtools::test(filter = "input-validation|streaming", reporter = "summary", stop_on_failure = TRUE)` exit 0. Counts: 45 passed, 0 failed, 0 errors, 3 skipped (HF_TOKEN guards, test-streaming.R:5, :19, :37).
- Deviations: none from the approved plan. Not run: `R CMD INSTALL`, roxygen2, full suite (wave-end orchestrator).
- Untouched: `src/Makevars`, `src/entrypoint.o`, `registry.rs` (not created), `R/**`, `Cargo.*`.
