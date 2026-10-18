# STATE 9: rxet 0.1.1 patch

## Baseline (recon, 2026-10-16; to be re-run before wave 1)

- Baseline tag: `v0.1.0` on origin at `f1f5b96`.
- CI: run 38861501139 on `f1f5b96` succeeded on ubuntu, windows and macos (recorded in planning).
- Routine suite at v0.1.0 gate: 242 passed, 0 failed, 0 errors, 15 skipped (STATE_8 final gate). Re-run before wave 1.
- Live suite at v0.1.0 gate: 18 passed, 0 failed, 0 errors, 0 skipped (STATE_8).
- Clean-archive `R CMD check --no-manual`: Status OK at v0.1.0.
- Pre-wave-1 steps (2026-10-16, orchestrator):
  - [x] `src/Makevars` and `src/entrypoint.o` present and tracked, tree clean. Nothing restored.
  - [x] `R CMD INSTALL .` exit 0.
  - [x] Routine baseline with `RXET_LOCAL_CAS_SERVER=/home/andrew/.cargo/bin/local_cas_server`: 242 passed, 0 failed, 0 errors, 15 skipped. Matches the v0.1.0 gate.
  - Skips: 1 `HF_TOKEN` unset, 2 terra/sf-missing checks, 12 live, 1 auth (local server does not enforce tokens, probe 5.3.1), 1 other live-like. Live tests are opt-in and are not run here.

## Wave board

| Wave | Task | Status |
|---|---|---|
| 1 | 9.1.1 token canary tests | done (0b88631) |
| 1 | 9.1.2 roxygen wording | done (8505dba) |
| 2 | 9.1.3 close guard | done (413714c) |
| 2 | 9.1.4 dead code, Suggests, AGENTS.md | done (d755d59) |
| 3 | 9.1.5 parquet close assertion | done (c946de5) |
| Gate | serial final gate | pending |

## Task reports

(Workers append here under `## {{id}}`.)

## 9.1.2 -- Roxygen wording: vector temp file and memory claims

- Status: done. Committed as `8505dba`.
- Files: `R/spatial.R` lines 18-22, 111-130 (format limit paragraph replaces "80+ formats"; vector memory text); `R/arrow.R` lines 27-29 and 113-115 (copy-count wording removed).
- Checks: `parse()` of both files ok. Non-roxygen diff lines: none. `git status` showed only the two R files changed.
- Deviations: none.
- Gotchas: `man/*.Rd` is now stale; the orchestrator regenerates it at the gate (H4). The GDAL content-detection sentence is general GDAL behaviour and is not tested in this repo.

## 9.1.1 -- Token canary tests on offline paths

- Status: done. Committed as `0b88631`.
- Files: `tests/testthat/test-token-canary.R` (new, about 390 lines). No product code, `helper-fault-cas.R` or `man/` touched.
- Command: `RXET_LOCAL_CAS_SERVER=/home/andrew/.cargo/bin/local_cas_server Rscript -e 'devtools::test(filter = "token-canary")'`. Result: 21 tests, 0 failed, 0 errors, 1 skipped (upload network 401: no upload route on the fault server). Re-run by the orchestrator, same counts.
- Canary leaks found: none. Stop rule not triggered.
- Deviations: 403 server line reads "Forbidden" (tests check the status code in the request log, not the text). Mid-stream tests reuse `start_fault_cas()` from `helper-fault-cas.R`.
- Gotchas: the readers and over-2GiB refusals need arrow, terra, sf and processx. All are installed here, so none skipped.

## 9.1.3 -- Guard xet_close_connection

- Status: done. Committed as `413714c`.
- Files: `R/connection.R` lines 81-90 (closed check only for `inherits(conn, "connection")`; only "invalid connection" counts as closed); `tests/testthat/test-connection.R` (two closed-connection tests, one non-connection error test).
- Command: `RXET_LOCAL_CAS_SERVER=... Rscript -e 'devtools::test(filter = "connection")'`. Orchestrator re-run: 0 failed, 0 errors, 1 skipped (live test, needs RXET_LIVE_TESTS=1).
- Deviations: the worker first let `xet_close_connection("x")` return silently. Orchestrator sent a fix (closed check only for real connections). Covered by a new test; `"x"` and `1` still error.
- Gotchas: the guard depends on R's "invalid connection" message text.

## 9.1.4 -- Remove dead code, prune Suggests, correct AGENTS.md

- Status: done. Committed as `d755d59`.
- Files: `R/utils.R` lines 150-185 deleted (`make_hf_api_request` with its roxygen block); `DESCRIPTION` Suggests (`jsonlite`, `covr` removed); `AGENTS.md` line 208 (1.70 to 1.85).
- Checks: `grep make_hf_api_request R tests` empty; `grep 'jsonlite\|covr' R tests .github` empty; DESCRIPTION parses; utils suite 0 failed, 0 errors (orchestrator re-run).
- Other "1.70" hits: all under `planning/` (not changed).
- Deviations: deleted line 150 (a blank line) as well, so no trailing blank line is left.

## 9.1.5 -- Assert read_xet_parquet closes its connection on success

- Status: done. Committed as `c946de5`.
- Files: `tests/testthat/test-arrow-spatial.R` lines 22-49 (new test, inserted after the data-frame test).
- Command: `RXET_LOCAL_CAS_SERVER=... Rscript -e 'devtools::test(filter = "arrow-spatial")'`. Orchestrator re-run: 0 failed, 0 errors, 3 skipped (all pre-existing: HF_TOKEN, terra missing-package, sf missing-package). New test: pass, 3 expectations, not skipped.
- Deviations: the worker's first handler would have turned any error into "closed". Orchestrator narrowed it to "invalid connection" only, as in 9.1.3.
- Gotchas: a closed R connection makes `isOpen()` error "invalid connection", not return FALSE.

## Final gate (orchestrator, serial)

- Pre-gate: `src/Makevars`, `src/entrypoint.o` clean. `HF_TOKEN` not set in this session. No `.env` read.
- `roxygen2::roxygenise()`: changed `man/read_xet_parquet.Rd`, `read_xet_parquet_stream.Rd`, `read_xet_raster.Rd`, `read_xet_vector.Rd`; deleted `make_hf_api_request.Rd`. NAMESPACE unchanged.
- Version: 0.1.0 to 0.1.1 in DESCRIPTION.
- NEWS.md: 0.1.1 entry added above 0.1.0 (35 insertions, no deletions).
- Commit `5493a21` (chore: release 0.1.1 metadata and regenerated docs).
- Routine suite (`devtools::test()`, `RXET_LOCAL_CAS_SERVER` set): 305 passed, 0 failed, 0 errors, 16 skipped. Baseline was 242 / 0 / 0 / 15. The added skip is the upload network-401 placeholder.
- Live suite: not run by the orchestrator. Needs `HF_TOKEN` in the user's session.
- Clean archive: `git archive HEAD` into scratch, `R CMD build --no-manual`. Tarball has no `.env`, `local_cas_data/`, `planning/`, `docs/`, `.o` or `Makevars`.
- `R CMD check --no-manual` on the tarball: running (see result below).
- Tag `v0.1.1`, GitHub release and push: not done. Need user approval.
- First clean-archive `R CMD check` (HEAD `5493a21`): Status 1 NOTE. "Namespace in Imports field not imported from: 'httr2'". Cause: 9.1.4 removed the only caller (`make_hf_api_request`). v0.1.0 had Status OK.
- Fix: commit `050bfb1` drops `httr2` from Imports (whole Imports field removed). Not in the plan's DESCRIPTION edits; flagged. No public behavior change.
- Re-check on `050bfb1`: running.
- Re-check on `050bfb1`: `R CMD check --no-manual` Status OK (no NOTE, WARNING or ERROR). Run with `_R_CHECK_FORCE_SUGGESTS_=false` in the environment; the optional packages are installed here, so no check depended on that.
- Gate status: routine suite done, check done. Live suite pending (user, with `HF_TOKEN`). Tag, release and push pending (user approval).
- Commit `009cd24`: untracked `src/Makevars` and `src/entrypoint.o` (`git rm --cached`), added `src/Makevars` and `src/Makevars.win` to `.gitignore`. Files stay on disk. Requested by the user.
- Re-check on `009cd24` (archive from HEAD without Makevars, so `configure` must regenerate it): running.
- Re-check on `009cd24`: build OK, `R CMD check --no-manual` Status OK. Tarball has `Makevars.in` and `Makevars.win.in` only; `configure` regenerates `Makevars` at build time.
- Live suite (user request, orchestrator run): `HF_TOKEN` sourced from `.env` in-process, token value not printed and confirmed absent from the log. `devtools::test(filter = "live-hf")` with `RXET_LIVE_TESTS=1`: 18 passed, 0 failed, 0 errors, 0 skipped.
- Pushed `main` to origin: `f1f5b96..009cd24`. No tag, no release.
- CI run 38940447222 on `009cd24` (R-CMD-check, push): success.
