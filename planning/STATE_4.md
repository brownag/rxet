# State 4 — Phase 4: Harden Core Rust/R Operations and Failure Semantics

Resume from this file. Plan: `planning/EXECUTION_PLAN_4.md`. Worker skeleton: `planning/PROMPT_TEMPLATE_4.md`.
Status: **plan drafted; awaiting user approval** (2026-10-15). No task has started.

## Baseline checklist (observed 2026-10-15; re-verify before wave 1)

- [x] Repository instructions read: `AGENTS.md`.
- [x] Master input read: `planning/MASTER_PLAN.md` (Phase 4 mandate and exit gate).
- [x] Prior phases read: `planning/STATE_1.md`, `STATE_2.md`, `STATE_3.md`; ADRs `docs/decisions/0001`, `0002`, `0003`.
- [x] Phase 3 dependency satisfied: clean-archive `R CMD check` → `Status: OK` (`planning/STATE_3.md` 3.3.1).
- [x] Last recorded test suite: `FAIL 0 | WARN 0 | SKIP 11 | PASS 111` (Phase 3 evidence; under `R CMD check`).
- [ ] **Pre-wave-1 step (to run):** `cd src/rust && cargo check` → exit 0; `Rscript -e 'devtools::test(reporter = "summary", stop_on_failure = TRUE)'` → exit 0. Record counts here before wave 1 begins.
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
| 1 | `4.1.1.r-input-validation` | pending | none |
| 1 | `4.1.2.rust-registry-lock` | pending | none |
| 2 | `4.2.1.rust-size-and-upload` | pending | 4.1.2 |
| 2 | `4.2.2.r-atomic-download` | pending | 4.1.1 |
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
