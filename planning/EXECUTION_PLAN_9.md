# EXECUTION PLAN 9: rxet 0.1.1 patch

Status: APPROVED (2026-10-16). Not started. No tag or push in this plan. Orchestration 9 covers the 0.1.1 patch candidates in `planning/POST_0.1_PLAN.md`. It ends at a patch release candidate. Tagging, the GitHub release and pushing are not in this plan.

## Goal & Scope

**Goal.** Ship rxet 0.1.1: fix the documentation and test gaps the v0.1.0 review found, and make no behavior change beyond the connection-close guard. The patch adds no public API, changes no ADR 0001 tier, and promotes no Experimental API.

**In scope**
- Token-leak canary tests on every offline-reachable public path (download, open connection, stream range, stream raw, the four `read_xet_*` helpers, upload), with 401, 403 and mid-stream fault cases where the fault server reaches them.
- Roxygen wording: the extensionless vector temp file limit, the "80+ formats" claim, and the memory-copy claims in `R/arrow.R` and `R/spatial.R`, reworded to match what the code does.
- `xet_close_connection()` guarded with `isOpen()` so a second call does not error.
- Removal of `make_hf_api_request()` (dead code that takes the token).
- DESCRIPTION Suggests cleanup: remove `jsonlite` and `covr`, which nothing uses. `rprojroot` stays because `tests/hf_test_setup.R` uses it.
- `AGENTS.md` Rust minimum corrected from 1.70 to 1.85.
- A test asserting that `read_xet_parquet()` closes its connection on success.
- Final gate: `roxygen2::roxygenise()`, version bump to 0.1.1, `NEWS.md` 0.1.1 entry, routine suite, live suite (user-run), clean-archive `R CMD check`, CI on the pushed commit.

**Out of scope (explicit deferrals)**
- `read_xet_vector()` format argument. Deferred to 0.2.0 (user decision, 2026-10-16). It adds public API, so it cannot go in a patch.
- Measuring memory use. The memory claims are reworded instead (user decision, 2026-10-16).
- Any change to the 13 exports, the ADR 0001 tiers, or the experimental labels.
- Range-backed connections, multi-file vector formats, vendoring. These are 0.2.0 or later per `planning/POST_0.1_PLAN.md`.
- Tagging `v0.1.1`, the GitHub release and the push. Each needs separate user approval.

**Verbatim constraints (carried)**
- User, 2026-10-16: "Defer format arg to 0.2.0 (Recommended)" (in response to the vector temp question).
- User, 2026-10-16: "Reword to match known facts (Recommended)" (memory claims).
- User, 2026-10-16: "All offline paths (Recommended)" (token canary coverage).
- User, 2026-10-16: "Run it (Recommended)" (live suite at the final gate). The user exports `HF_TOKEN` in the session. Workers and the orchestrator never print, log or write the token and never read `.env`.
- Master plan Phase 7 item 7: publication needs explicit user approval. This plan does not tag or publish.

## Decision log (dated 2026-10-16)

| # | Decision | Source |
|---|---|---|
| D1 | 0.1.1 = the `POST_0.1_PLAN.md` candidates, minus the CI item (already green). | Codebase fact: CI run 38861501139 succeeded on `f1f5b96` (HEAD of v0.1.0). |
| D2 | Vector temp file: document the limit and fix the "80+ formats" wording. Format argument deferred to 0.2.0. | User: "Defer format arg to 0.2.0 (Recommended)" |
| D3 | Memory-copy claims: reword, no measurement. | User: "Reword to match known facts (Recommended)" |
| D4 | Token canaries cover every offline-reachable public path. Live is excluded. | User: "All offline paths (Recommended)" |
| D5 | If a canary finds a leak, the worker stops and reports. The fix is a new task in a later wave, never an in-place fix. | Default. Keeps the fault-finding task from becoming an unplanned code change. |
| D6 | Live suite runs at the final gate, run by the user with `HF_TOKEN` exported. | User: "Run it (Recommended)" |
| D7 | `make_hf_api_request()` is removed. No test or code references it (grep). | Codebase fact: `R/utils.R:165` only. Default. |
| D8 | Remove `jsonlite` and `covr` from Suggests. Keep `rprojroot`. | Codebase fact: neither is referenced in `R/` or `tests/`; `rprojroot` is used in `tests/hf_test_setup.R`. Default. |
| D9 | `xet_close_connection()` guards with `isOpen()`. Behavior change limited to the error case. | Default from 8.3.1 review. Flagged in J2. |
| D10 | ADR alignment: complies with ADR 0001 and ADR 0003. Supersedes neither. | Codebase fact: both `Accepted`; no scope item changes an export, tier or test-under-check rule. |
| D11 | Workers: Haiku, at most two per wave, file scopes disjoint. Orchestrator runs roxygenise and all serial gates. | Carried from orchestration 8. Default. |
| D12 | Version becomes 0.1.1 at the final gate, not in a worker task. | Default, same as J3 in plan 8. |

## Judgment calls (flagged for review)

- **J1.** Token canary tests reuse the fault server (`helper-fault-cas.R`) and the local CAS server (`helper-local-cas.R`). Paths the fault server cannot reach are marked skip with a reason, not dropped silently.
- **J2.** The `isOpen()` guard changes only the second-close behavior. `xet_close_connection()` on an open connection is unchanged.
- **J3.** The `NEWS.md` 0.1.1 entry is written at the final gate from observed counts, not by workers.

## Hazards

- **H1.** `HF_TOKEN` is in the environment during the live run. Live runs are orchestrator-only and never write logs.
- **H2.** `src/Makevars` and `src/entrypoint.o` are restored before every commit and never staged (carried from plan 7).
- **H3.** The `R/spatial.R` roxygen block is touched by task 9.1.2 only. Task 9.1.1 does not edit `R/`.
- **H4.** `man/*.Rd` files are regenerated by the orchestrator with `roxygen2::roxygenise()`. Workers do not hand-edit `man/`.
- **H5.** A canary leak discovered in 9.1.1 changes this plan. Stop the wave and report to the user before any fix.

## Waves

| Wave | Task | Files (must edit / can create) | Depends on |
|---|---|---|---|
| 1 | 9.1.1 token canary tests | can create `tests/testthat/test-token-canary.R` | none |
| 1 | 9.1.2 roxygen wording | must edit `R/spatial.R` (roxygen only, lines ~105-125 and ~160-178), `R/arrow.R` (roxygen only) | none |
| 2 | 9.1.3 close guard | must edit `R/connection.R` (`xet_close_connection`, line 81), `tests/testthat/test-connection.R` | none |
| 2 | 9.1.4 dead code, Suggests, AGENTS.md | must edit `R/utils.R` (remove `make_hf_api_request`, line 165), `DESCRIPTION` (Suggests), `AGENTS.md` (line 208) | none |
| 3 | 9.1.5 parquet close assertion | must edit `tests/testthat/test-arrow-spatial.R` | none |
| Gate | serial, orchestrator | `DESCRIPTION` version, `NEWS.md`, `man/*.Rd` via roxygenise | 9.1.1 to 9.1.5 |

Waves are separated so each wave's files are disjoint and at most two workers run at once (D11). Wave 3 has no dependency on wave 2; it is sequenced only to keep concurrency at two.

## Task specs

### 9.1.1 Token canary tests on offline paths

- **Goal.** Extend the token-leak check from the 401 path of two functions to every offline-reachable public path, with 401, 403 and mid-stream fault cases where the fault server supports them.
- **Reference implementation.** `tests/testthat/test-fault-token.R` lines 7, 104-162 (`TOKEN_CANARY`, `make_fault_client`, `expect_false(grepl(TOKEN_CANARY, msg, fixed = TRUE))`).
- **Anchors.** `R/connection.R:50` (`xet_open_connection`), `R/stream.R:105` (`xet_stream_range`), `R/stream.R` (`xet_stream_raw`), `R/arrow.R` and `R/spatial.R` (`read_xet_*`), `R/upload.R` (`xet_upload_file`).
- **Spec.** One file, `test-token-canary.R`. For each path, call it against the fault server with the canary token and assert the error message and any warning do not contain the canary. Use `skip()` with a reason for any path the fault server cannot reach. Do not assert on success paths. Do not modify `helper-fault-cas.R`.
- **Stop rule.** If any assertion fails because the canary appears in output, stop, leave the test failing, and report the path and message. Do not fix product code (D5).
- **Acceptance.** `Rscript -e 'devtools::test(filter = "token-canary")'` with `RXET_LOCAL_CAS_SERVER` set. Report pass, fail and skip counts.

### 9.1.2 Roxygen wording: vector temp file and memory claims

- **Goal.** Make the roxygen in `R/spatial.R` and `R/arrow.R` match what the code does.
- **Anchors.** `R/spatial.R:118` ("And 80+ other formats"); `R/spatial.R:173` (`tempfile()` with no extension); `R/spatial.R` and `R/arrow.R` roxygen blocks that describe memory use.
- **Spec.**
  1. Replace "And 80+ other formats" with wording that names the limit: GDAL formats that read from a single file without a file extension. State that formats that detect the driver from the extension may not open, and that `read_xet_vector()` has no format argument yet.
  2. In the memory text, state only what the code shows: the helper reads the whole file, holds about one copy of the bytes, and returns a parsed object. Remove any claim about copy counts.
  3. Do not change code lines, only roxygen comment lines.
- **Constraints.** Do not touch `man/*.Rd` (H4). Do not change the function signatures.
- **Acceptance.** `Rscript -e 'parse("R/spatial.R"); parse("R/arrow.R")'` succeeds. `git diff -- R/spatial.R R/arrow.R` shows changes only on `#'` lines.

### 9.1.3 Guard `xet_close_connection()`

- **Goal.** A second `xet_close_connection()` call does not error.
- **Anchors.** `R/connection.R:81-84`.
- **Spec.** Replace `close(conn)` with `if (isOpen(conn)) close(conn)`. Check what `isOpen()` does on an already-closed connection in this R version. If it errors, wrap it with `tryCatch` and treat the error as closed. Add two tests to `tests/testthat/test-connection.R`: one that closes twice without error, and one that closes a connection that arrow or the caller already closed.
- **Constraints.** No other function changes. The roxygen for `xet_close_connection` must not change, because the public contract is the same.
- **Acceptance.** `Rscript -e 'devtools::test(filter = "connection")'` with `RXET_LOCAL_CAS_SERVER` set. Zero failures.

### 9.1.4 Remove dead code, prune Suggests, correct AGENTS.md

- **Goal.** Remove dead code and unused declarations, and correct the stale Rust minimum.
- **Spec.**
  1. Delete `make_hf_api_request` from `R/utils.R` (line 165 onward, through its closing brace). Confirm first with `grep -rn make_hf_api_request R tests` that nothing else references it.
  2. In `DESCRIPTION`, remove `jsonlite,` and `covr` from `Suggests`. Keep `rprojroot`. Check with `grep -rn 'jsonlite\|covr' R tests` first.
  3. In `AGENTS.md` line 208, change "Rust >= 1.70" to "Rust >= 1.85". Search for other "1.70" occurrences and report them without changing them.
- **Acceptance.** `grep -rn make_hf_api_request R tests` returns nothing. `Rscript -e 'read.dcf("DESCRIPTION")'` parses. `Rscript -e 'devtools::test(filter = "utils")'` passes.

### 9.1.5 Assert `read_xet_parquet()` closes its connection on success

- **Goal.** Catch a future arrow change that stops closing the connection.
- **Anchors.** `R/arrow.R:75-90` (the tryCatch comment says arrow closes the connection); `tests/testthat/test-arrow-spatial.R` (the existing `read_xet_parquet` tests start at line 3).
- **Spec.** Add one test to `test-arrow-spatial.R`. Capture the connection object that `xet_open_connection` returns (use `testthat::local_mocked_bindings()` to wrap it and record the value), call `read_xet_parquet()` on the local fixture, then `expect_false(isOpen(captured))` or confirm it is closed through `tryCatch`. The test must run under `RXET_LOCAL_CAS_SERVER`.
- **Acceptance.** `Rscript -e 'devtools::test(filter = "arrow-spatial")'` with `RXET_LOCAL_CAS_SERVER` and arrow installed. Zero failures; the new test is counted as a pass, not a skip.

## Final gate (orchestrator, serial)

1. Restore `src/Makevars` and `src/entrypoint.o`. Confirm no `.env` is read or staged (H2).
2. `roxygen2::roxygenise()`. Expect `man/` changes only for the roxygen edits in 9.1.2. NAMESPACE must be unchanged.
3. Bump `DESCRIPTION` version to 0.1.1.
4. Write `NEWS.md` 0.1.1 entry from observed counts (J3). List the fixes, state that there is no API change, and state that the format argument is deferred to 0.2.0.
5. Routine suite with `RXET_LOCAL_CAS_SERVER` and arrow, terra and sf installed: `devtools::test()`. Record pass, fail, error and skip counts.
6. Live suite: the user runs `RXET_LIVE_TESTS=1 Rscript -e 'devtools::test(filter = "live-hf")'` with `HF_TOKEN` exported. Record counts only.
7. Clean-archive build: `git archive HEAD` into a scratch directory, `R CMD build --no-manual`, `R CMD check --no-manual`. Expect Status OK with no server or live variables.
8. Inspect the tarball: no `.env`, `local_cas_data/`, `planning/`, `docs/`, `.o` or `Makevars`.
9. Stop and ask the user before pushing or tagging. Tagging `v0.1.1` and the release are not in this plan.

## Residual gaps to record (not fixed here)

- The `read_xet_vector()` format argument (0.2.0).
- Shapefile and other multi-file formats (documented limitation).
- Range-backed connections (0.2.0 or later).
- The upstream xet-core "Data sender was dropped" race, unreported pending user go-ahead.
