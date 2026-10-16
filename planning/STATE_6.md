# STATE 6: Close the Phase 5 residual gaps

Plan: `planning/EXECUTION_PLAN_6.md` (draft, awaiting approval). Prompt: `planning/PROMPT_TEMPLATE_6.md`.

## Baseline (from the Phase 5 final gate, 2026-10-15)

- [x] Routine suite with `RXET_LOCAL_CAS_SERVER`: pass 194, fail 0, error 0, skip 13.
- [x] Live suite with `.env` token: pass 22, fail 0, error 0, skip 0 (commit 38c80de and later, no live code change since).
- [x] Clean-archive `R CMD check --no-manual` with `_R_CHECK_FORCE_SUGGESTS_=false`, no server or live variables: Status OK; testthat 147 pass, 0 fail, 32 skip.
- [x] CI check step: `_R_CHECK_FORCE_SUGGESTS_` name corrected and `extra-packages` added (commit 3787429). Previous CI run failed: "Packages suggested but not available" (wrong override name; test packages missing). Not yet re-run after push.
- [ ] CI run after push: not validated.
- [x] Fixtures generated (scratchpad, not in repo): `multichunk_16mib.bin` (16777216 bytes), `geotiff_512x512_utm33n.tif` (1051299 bytes); hashes in `SHA256SUMS.txt`.

## Wave board

| Task | Wave | Status |
|---|---|---|
| 6.0.1.fixture-upload | 0 | done (verified 2026-10-15) |
| 6.1.1.spike-cas-format | 1 | pending |
| 6.1.2.size-mismatch-fix | 1 | pending |
| 6.2.1.fault-server | 2 | pending |
| 6.2.2.token-expiry | 3 | pending |
| 6.3.1.live-fixtures | 3 | pending |
| 6.4.1.docs | 4 | pending |
| 6.4.2.ci-validation-prep | 4 | pending |

## Known residual gaps (carried from Phase 5)

- Live multi-chunk and GeoTIFF evidence: addressed by 6.3.1 once the fixtures are uploaded.
- Token expiry during long live runs: not automated (6.2.2 is offline; live expiry manual).
- Mid-stream interruption: addressed by 6.2.1.
- Windows and macOS server runs: CI-gated; not validated until a push runs.
- Upload stays experimental; no live writes (D4).
- Size-mismatch panic message: addressed by 6.1.2.
- README.md registry sentence: addressed by 6.4.1.
- Phase 6 arrow and spatial: orchestration 7.

## Task reports

(Empty. Workers append reports here.)

### 6.0.1.fixture-upload (done)
- Plan approved 2026-10-15. User uploaded both fixtures at the dataset top level (no `fixtures/` folder; plan paths updated).
- Hub tree (anonymous): `multichunk_16mib.bin` size 16777216, LFS sha256 f307458a...dcbe6dbe (matches SHA256SUMS); `geotiff_512x512_utm33n.tif` size 1051299, LFS sha256 f60de44e...c3c4341e9e8 (matches).
- Xet hashes (resolve HEAD `X-Xet-Hash`): multichunk `5a32191c41e82f198b29d384ca4b5c38f3a3ce2f8d22b4f56f25d6aa4a50f6f9`; geotiff `f8d51851e138a95dff77a8b5c944b218eed87e39c213ff4639ae75e0c472ce1a`. Both are Xet-stored (the header is present).
- Live read of these hashes not yet run; that happens in 6.3.1.

### 6.1.1.spike-cas-format (done)

Source: `xet-client` 1.7.0 (also `xet-data`, `xet-core-structures`, `xet-runtime`, `hf-xet` all 1.7.0). Pin confirmed: `src/rust/Cargo.toml:14` `hf-xet = "1.7.0"`; `src/rust/Cargo.lock:2845-2846` `xet-client` 1.7.0. Registry crate `Cargo.toml` versions all 1.7.0. Paths below are relative to `~/.cargo/registry/src/index.crates.io-1949cf8c6b5b557f/`.

**(a) Reconstruction JSON fields.** Client type is `QueryReconstructionResponse` (`xet-client-1.7.0/src/cas_types/mod.rs:205-217`), parsed from `GET {endpoint}/v1/reconstructions/{file_id}` (`xet-client-1.7.0/src/cas_client/remote_client.rs:226`):
- top level: `offset_into_first_range` u64 (mod.rs:208), `terms` Vec of `XorbReconstructionTerm` (mod.rs:211), `fetch_info` map from xorb hash to Vec of `XorbReconstructionFetchInfo` (mod.rs:216).
- `XorbReconstructionTerm` (mod.rs:180-187): `hash` (181), `unpacked_length` u32 (184, "used for validation", mod.rs:177-178), `range` ChunkRange (186).
- `XorbReconstructionFetchInfo` (mod.rs:196-202): `range` ChunkRange (198), `url` String (199), `url_range` HttpRange (201).
- V2 (`/v2/reconstructions/{file_id}`, remote_client.rs:296-333 chooses V2 then falls back to V1): `QueryReconstructionResponseV2` (mod.rs:223-230) with `xorbs` map to `XorbMultiRangeFetch { url, ranges }` (mod.rs:234-240) and `XorbRangeDescriptor { chunks, bytes }` (mod.rs:244-249). V1 converts to V2 via `From` (mod.rs:251-277).

**(b) Term URL and Range format.** The term URL is the server-supplied signed `url` from `fetch_info` (mod.rs:199), re-fetched through `retrieve_url()` (`xet-client-1.7.0/src/cas_client/interface.rs:37`). The GET Range header is built at `remote_client.rs:616-624`: one range gives `bytes=S-E`, several give `bytes=S1-E1,S2-E2`. Ends are inclusive (`HttpRange` Display is `start-end`, mod.rs:131-135; `range_header()` = `bytes={self}`, mod.rs:82-84). `url_range` is the byte range; `range` is the chunk-index range `[start,end)`. Local server routes (`xet-client-1.7.0/src/cas_client/simulation/local_server/server.rs`): `/v1/reconstructions/{file_id}` (line 202), `/v2/reconstructions/{file_id}` (214), `/v1/fetch_term` (208), `/v1/get_xorb/{prefix}/{hash}/` (207). `fetch_term` reads `?term=` (`handlers.rs:409-418`) and decodes base64url `hash:ranges` (`handlers.rs:178-180`).

**(c) HTTP statuses that map to auth failure.** None in 1.7.0. A grep for `401`, `UNAUTHORIZED`, `Unauthorized` finds nothing in `cas_client/`, `xet-data`, or `hf-xet` outside tests. The only status with special handling is 403: term fetch sets `.with_retry_on_403()` (`remote_client.rs:600`), refreshes the signed URL on `FORBIDDEN` (`remote_client.rs:634-639`), and `retry_wrapper.rs:201-204` turns it into a retryable error. Other 4xx/5xx become a fatal `process_error("Fatal Error", ...)` (`retry_wrapper.rs:211`). Token exchange failures become `AuthError::TokenRefreshFailure` (`cas_client/auth.rs:15-19`, `auth.rs:135-136`). The local server has no 401, 403, or expiry status (grep empty), so the rejection status for 6.2.2 is not defined by the client or the local server. 6.2.2 should assert on the generic error text and must not depend on a specific status code.

**(d) Size-mismatch error text.** Repo side: `tests/testthat/test-local-failures.R:76-99` calls `xet_download_file(client, info$hash, info$file_size + 1, dest)` on 65536 bytes (expected 65537). It asserts only `expect_s3_class(err, "error")`, no destination file, and no `.part` file. It does not assert the message. R wrapper: `R/download.R:48` (`tmp`), `:49` (`on.exit` unlink), `:51` (`.Call("wrap__xet_download_file", ...)`), `:53` (rename). Rust binding: `src/rust/src/lib.rs:266` maps the download error to `"download error: {e}"` and `:270` maps finish to `"finish error: {e}"`. Crate side: the check is `xet-data-1.7.0/src/processing/file_download_session.rs:364-368` (`download_file_with_id`, which compares `n_bytes` to `file_info.file_size()`) and `:414-418`. The variant is `xet-data-1.7.0/src/error.rs:80-81`: `"File size mismatch: expected {expected} bytes but downloaded {actual} bytes"`. `hf-xet-1.7.0/src/error.rs:248-250` has no explicit arm for `SizeMismatch`, so it falls to `XetError::Internal`, displayed as `"Internal error: {0}"` (`hf-xet-1.7.0/src/error.rs:94-95`). Expected text reaching R, from source only and not yet run: `download error: Internal error: File size mismatch: expected 65537 bytes but downloaded 65536 bytes`, or the `finish error:` prefix if the task error surfaces at finish. Confirm in 6.1.2. Also, `xet-data-1.7.0/src/file_reconstruction/data_writer/unordered_writer.rs:106-110` has a different per-term "Data size mismatch" check; it is not the file-size path. The residual gap "size-mismatch panic message" (above) is not supported by this source: the path is a mapped error, not a panic. Confirm in 6.1.2.

No token values were printed or written. Repo files changed: this section only.

### 6.1.2.size-mismatch-fix (done)

- Error text change: a size mismatch now raises `downloaded size does not match file_size: expected 65537 bytes, got 65536 bytes` (exact text for the test case). The `download error:` and `finish error:` prefixes and the `Internal error` / `Task error` wrapping are dropped for this case only. All other errors keep their existing format.
- The size error surfaced at `finish_blocking` (wrapped as `finish error: Task error: File size mismatch: ...`), not at the download call as 6.1.1 predicted. The helper is applied to both mappings in `src/rust/src/lib.rs`.
- Rust: `size_mismatch_message` helper in `src/rust/src/lib.rs`, unit tests in `src/rust/src/tests.rs` (3 new).
- R: `tests/testthat/test-local-failures.R` size test now asserts the new message and no `Internal error|panic`. `R/download.R` unchanged.
- Counts: `cargo test --lib tests::` 7 passed, 0 failed. `devtools::test(filter="local-failures")` PASS 18, FAIL 0, SKIP 1 (token test, skipped by design). First reinstall attempt hit a transient Rust dep-info error and was retried; second install succeeded.
- Not committed. `src/Makevars` and `src/entrypoint.o` show as modified in the worktree and were not staged.

#### 6.1.2 addendum: debug-build panic form
- Step 1 (assert site, from a debug run with `EXTENDR_BACKTRACE=1 RUST_BACKTRACE=1`): `xet-data-1.7.0/src/progress_tracking/progress_types.rs:521:17`, a `debug_assert_eq!(self.item.total_bytes, total)` in `ItemProgressUpdater::update_item_size`, called from `xet-data-1.7.0/src/file_reconstruction/reconstruction_terms/manager.rs:180`. Left is the size set from `file_info` (the expected size), right is the total downloaded. The debug-only assert fires only in `debug_assertions` builds.
- Some debug runs also show `left: 65536 right: 0` in another task; it is not produced by this test's path and the cross-check returns None for it.
- Helper change: `size_mismatch_message` also matches `panicked with message` plus ``assertion `left == right` failed``. It parses `left:` and `right:` with `number_after`, takes the operand equal to `expected` as trusted, and uses the other as the actual count. Neither equal to `expected` returns None. Release output is unchanged in content: the same helper runs in both builds.
- Tests: `cargo test --lib tests::` 11 passed (7 prior, 4 new: debug panic form, swapped operands, neither operand expected, other panic text).
- Counts: step 8 `cargo check` clean. Step 9 `cargo test --lib tests::` 11 passed, 0 failed. Step 10 `R CMD INSTALL .` exit 0. Step 11 `devtools::test(filter="local-failures")` debug build: PASS 18, FAIL 0, SKIP 1. `tests/testthat/test-local-failures.R` unchanged in this addendum.
- Not committed; `src/Makevars` and `src/entrypoint.o` not staged.

### Plan amendments from 6.1.1 (2026-10-15)
- 6.2.2 token-expiry: the "rejection status from 6.1.1" does not exist (no 401 or expiry mapping in xet-client 1.7.0 or the local server). The fault server returns 401 and the test asserts a fatal error with no token value and no destination file. A 403 would be retried by term fetch, so do not use 403.
- 6.1.2 size-mismatch: the premise "panic-style message" is not supported by source. The check is `xet-data` `File size mismatch: expected N bytes but downloaded M bytes`, wrapped by `hf-xet` as `Internal error: ...` and by rxet as `download error:` or `finish error:` (`src/rust/src/lib.rs:266,270`). Decision needed from the user: fix the wording (a clean R message) or record it as-is. 6.1.2 is held until the user decides.
- DECISION (user, 2026-10-15): 6.1.2 proceeds with "Clean the wording (Recommended)": map the size mismatch to a plain R error naming expected and downloaded sizes; no panic wording; test added.

### 6.2.1.fault-server (done, with a finding)

Files: `tests/testthat/helper-fault-cas.R` (new), `tests/testthat/test-fault-midstream.R` (new). No src changes. No commit. `src/Makevars` and `src/entrypoint.o` not staged.

Pre-coding checks (read-only):
- Fallback: a 404 on `/v2/reconstructions` triggers the V1 fallback (`xet-client-1.7.0/src/cas_client/remote_client.rs:316-321`, matches `NOT_FOUND | NOT_IMPLEMENTED`).
- `Range` and `Content-Length`: not re-checked against the code; the test does not depend on them beyond the 404 route.

Run: `Rscript -e 'devtools::test(filter="fault-midstream")'`. Per coordinator answer 1, `RXET_LOCAL_CAS_SERVER` is dropped from the command.
- Counts: 9 testcases, 0 failures, 0 errors, 0 skipped (JUnit reporter).
- Elapsed: 0.30 s total test time. The whole `devtools::test` call took about 39 s, mostly load and compile.

Exact error text (from a diagnostic run, `scratchpad/diag/capture.R`):
- `xet_download_file`: `finish error: Task error: File reconstruction error: Internal Writer Error: Byte range not sequential: expected start at 65536, got 256000000` (0.02 s).
- `xet_stream_raw`: `stream read error: Internal error: Internal Writer Error: Byte range not sequential: expected start at 65536, got 256000000` (0.02 s).
- Source of the message: `xet-data-1.7.0/src/file_reconstruction/data_writer/sequential_writer.rs:270-275`.

FINDING (must be read before relying on this test): the test passes, but it does not exercise a mid-stream drop. The error is raised by the sequential writer when a term's byte start does not match the expected position. It is not a short read and not a bad-term-body error. It fires in about 20 ms, so the client never reaches the term fetch. The server's `/xorb/` route is probably never hit. The coordinator's answer 2 (accept only term-fetch errors) is therefore NOT met: the decoder error comes from the reconstruction layer. The `got 256000000` value is not explained by the V1 JSON the server sends (one term, `unpacked_length` 65536). The cause is not yet traced. The test still checks the failure contract (error, no dest, no `.part`, no token leak, bounded time), but not the drop itself. Next step: trace where the second term's byte start comes from, and fix the JSON or the server, not the assertions.

#### 6.2.1 follow-up: finding resolved (correction 1 of 2)

Cause of `got 256000000`: the client does not ask for the whole file in one reconstruction call. The reconstruction GET carries `Range: bytes=S-E` (`xet-client-1.7.0/src/cas_client/remote_client.rs:244-248`), and a 416 means end of file (`remote_client.rs:271-273`, `retry_wrapper.rs:204`). The fault server ignored `Range`, so the second window (start 256000000, from the prefetch block sizing in `xet-data-1.7.0/src/file_reconstruction/reconstruction_terms/manager.rs:239-247`) got the same one-term JSON. `file_term.rs:285` then placed that term at the window start, and `sequential_writer.rs:270-275` rejected it. The JSON fields were not wrong.

Correction 1 (helper only, no assertion changed): the server parses `Range` and returns 416 when the start is at or past the file size (65536). It also logs each request line to `<ready>.req`, and logs `sent N of M` for each term body.

Result after correction 1 (diagnostic run, then the test run below):
- The error now comes from the term fetch. The `/xorb/term` route is hit.
- Request counts per call (from the server request log): download = 3 `GET /v2/reconstructions` (404), 3 `GET /v1/reconstructions`, 2 `GET /xorb/term`. Stream = the same counts. One `POST /v1/telemetry` from the client.
- Body: each `/xorb/term` response sent exactly half the body, `sent 32768 of 65536`, with `Content-Length: 65536`.
- Exact final error text, download: `finish error: Task error: File reconstruction error: CAS Client Error: Format error: I/O error: error decoding response body`.
- Exact final error text, stream: `stream read error: I/O error: I/O error: error decoding response body`.
- Classification: the HTTP body ended before its `Content-Length`, so `error decoding response body` is the short read surfacing through the HTTP layer. It is not a bad-term-body parse error. The text does not say "truncated".
- Timing: download about 2.8 s, stream about 1.9 s (diagnostic run).

Test run after correction 1 (`devtools::test(filter="fault-midstream")`): 11 testcases, 0 failures, 0 errors, 0 skipped. Total test time 2.58 s. Two new assertions: `expect_true(any(grepl("^GET /xorb/", reqs)))` in each test. These tighten the tests and loosen nothing.

### 6.2.2.token-expiry (done)

Files: `tests/testthat/test-fault-token.R` (new). `helper-fault-cas.R` and `test-fault-midstream.R` not edited (file-local 401 server with a `term_status` argument). No commit. `src/Makevars` and `src/entrypoint.o` not staged.

Pre-coding checks (read-only):
- No 401 or Unauthorized mapping in `xet-client-1.7.0/src/cas_client/` (re-checked, matches 6.1.1).
- `retry_wrapper.rs:499-520`: other 4xx are Fatal. `retry_wrapper.rs:201-204` retries only 403. `remote_client.rs:634-639` refreshes the URL only on 403.
- Source-derived guess was `Fatal Error: ... api call failed`. The real text is `Request error: HTTP status client error (401 Unauthorized)` (below), so the guess was wrong about the prefix. The assertions match on `401` only.

Run: `Rscript -e 'devtools::test(filter="fault-token")'`. Counts: FAIL 0, WARN 0, SKIP 0, PASS 17. Wall time about 0.9 s total (whole command).

Exact error text (diagnostic run, `scratchpad/diag2/capture_token.R`):
- `xet_download_file`: `finish error: Task error: File reconstruction error: CAS Client Error: Request error: HTTP status client error (401 Unauthorized), domain: http://127.0.0.1:<PORT>/xorb/term` (0.02 s).
- `xet_stream_raw`: `stream read error: Network error: Request error: HTTP status client error (401 Unauthorized), domain: http://127.0.0.1:<PORT>/xorb/term` (0.02 s).

Request log, one call each: 3 `GET /v2/reconstructions` (404), 3 `GET /v1/reconstructions`, 1 `GET /xorb/term`, `status 401`, 1 `POST /v1/telemetry`. The term fetch was not retried (hard assertion `== 1` passes).

Hygiene: `grep HF_TOKEN` on the new file is empty; the token-shaped grep `hf_[A-Za-z0-9]{20,}` on the new file and helper is empty. Canary `rxet-canary-token-XYZ` is not in either error message. `local_cas_data/` unchanged. No `.part` files in the repo.

### 6.3.1.live-fixtures (done, not committed)

- Files: `tests/testthat/test-live-hf.R` only (6 constants, 4 new tests). `helper-live-hf.R` unchanged. No commit; `src/Makevars` and `src/entrypoint.o` not staged.
- Constants: `LIVE_MULTI_HASH` / `LIVE_MULTI_SIZE` (16777216) / `LIVE_MULTI_SHA256`; `LIVE_GEO_HASH` / `LIVE_GEO_SIZE` (1051299) / `LIVE_GEO_SHA256`. Literals checked against the scratchpad `SHA256SUMS.txt` and the 6.0.1 Xet hashes.
- New tests: (a) multi download, size and sha256; (b) range `[65536, 69632)` compared with the same bytes from a full download (offset is "not the start of the file"; not claimed as a verified chunk boundary); (c) GeoTIFF download, size, sha256, TIFF magic; (d) GeoTIFF `xet_stream_raw` equals the downloaded bytes.
- Gate unset: `Rscript -e 'devtools::test(filter="live-hf")'` gives FAIL 0, SKIP 9 (5 existing and 4 new), PASS 0.
- Gate set: `RXET_LIVE_TESTS=1` with `.env` loaded in a subshell, output through a `sed` redaction. Result: 9 tests, 18 expectations, FAIL 0, ERROR 0, SKIP 0. The probe line reported `HF_TOKEN set`.
- Timings (JUnit reporter, scratchpad `live-hf-junit.xml`, per test including its expectations): (a) multi download about 2.19 s; (b) multi range about 1.83 s (includes the second 16 MiB download); (c) GeoTIFF download about 1.95 s; (d) GeoTIFF stream about 1.55 s. Existing live tests ran in the same run (probe about 1.0 s, LIVE_HASH download about 1.0 s).
- Xet read timings for the 16 MiB file: one download about 2.1 s, measured on a cold private `HF_HOME` per test.

## Phase 6 (orchestration 6) final gate (2026-10-15)
- Routine suite with RXET_LOCAL_CAS_SERVER (`devtools::test()`, debug build): pass 224, fail 0, error 0, skip 17 (live gate, server-auth probe, optional packages).
- Live suite with the user's `.env` token (`RXET_LIVE_TESTS=1`, filter `live-hf|connection|streaming`; token never printed): pass 30, fail 0, error 0, skip 0. Includes the 16 MiB and GeoTIFF fixtures.
- Clean archive (git archive HEAD into scratchpad), `R CMD check --no-manual` with `_R_CHECK_FORCE_SUGGESTS_=false` and no server/live/token variables: Status OK; testthat pass 175, fail 0, skip 36 (server and live gates only).
- No `local_cas_data/` in the repo; `git status` clean apart from task todo files, committed with this record.
- Finding during the gate: the size-mismatch panic reappeared in the debug build (assertion in progress_types.rs:521). Fixed in 059bacd so both build profiles return the plain message.

## Residual gaps after orchestration 6
- CI: the workflow fix (3787429) was pushed on main; the new run after the 6.x commits is not yet recorded. Windows and macOS server runs remain unvalidated until a run completes.
- Token expiry against the real CAS is manual; the offline test covers the 401 response, not a real expired token.
- Mid-stream drop uses an offline fault server that ends the body early; it does not reproduce a real network interruption.
- Live access token expires; very long live runs may fail mid-run.
- README.md is a hand copy of README.Rmd; a re-render would overwrite the edits.
- Known leftovers: AGENTS.md "Why lazy_static + Mutex + Arc?" rationale (lines ~222-225) and the README.md design-principles line collapse (line ~222).
- Phase 6 arrow and spatial: orchestration 7.

## CI feedback after the gate (2026-10-16)
- CI on 88a146d: macOS pass, Windows pass, Ubuntu fail. The single failure was `test-fault-token.R` (stream, 401 message check): the stream returned "Data sender was dropped before sending data" instead of the 401 message. Reproduced locally at 1 in 15 runs.
- Cause (upstream, not rxet): xet-data's stream writer reports its own "Data sender was dropped" error (sequential_writer.rs:107,124; download_stream.rs:133,175) when a failed fetch closes the channel, and the fetch's 401 does not reach the caller. The download path reports the 401 correctly.
- Change: the streaming test accepts either message. The 401 request-log assertion, the error, no-data, no-token and time bounds are unchanged. Result after change: 10 of 10 runs passing (17 expectations each).
- Action: report upstream to xet-core with the reproducer (not yet filed).
