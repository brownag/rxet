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
