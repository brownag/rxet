# Post-0.1 plan

Status: draft, 2026-10-16. Baseline is `v0.1.0` (origin tag at `f1f5b96`). Sources: `planning/STATE_8.md` (residual gaps), `planning/tasks/8.3.1.review.md`, `planning/MASTER_PLAN.md` (scope exclusions), `planning/STATE_7.md` (deferred connection work).

`TODO.md` is a pre-planning roadmap. Its items are mostly superseded and are not used here.

## Scope rules

- The 0.1 support contract (ADR 0001) does not change in a patch release. Experimental APIs stay experimental until live evidence supports promotion.
- A patch release (0.1.x) fixes defects and documentation drift. It adds no new public API.
- New public API (range-backed connections, multi-file vector formats) goes in 0.2.0 or later.
- Explicitly excluded from any claim, now and later unless implemented and tested: zero-copy, automatic token refresh, parallel throughput, push-down filtering, cache guarantees, production readiness.

## 0.1.1 (patch) candidates

Ordered by risk to users. Each is a candidate; `/plan-wave` decides the final set.

1. **Token-leak coverage (medium).** The claim "does not write the token into its error output" is tested only on the 401 path of `xet_download_file()` and `xet_stream_raw()`. Add canary tests for the other paths: `xet_open_connection()`, `xet_stream_range()`, the `read_xet_*` helpers, `xet_upload_file()`, and 403 and network errors. Fix any leak found.
2. **`read_xet_vector()` temp file (low, user-visible). Decided 2026-10-16: document the limit; the format argument is deferred to 0.2.0.** The temp file has no extension (`R/spatial.R:173`). GDAL drivers that detect format by extension may fail to open it. Give the temp file the extension of the input, or document the limit. Also correct the "80+ formats" wording at `R/spatial.R:118`.
3. **`xet_close_connection()` on a closed connection (low).** It errors with "invalid connection". Guard with `isOpen()`, or document the error.
4. **Memory-copy claims (medium, docs).** The memory-copy wording in `R/arrow.R` and `R/spatial.R` is not measured. Either measure it or reword it to match what is known.
5. **Doc drift (low).** `AGENTS.md:208` says Rust >= 1.70. The enforced minimum is 1.85.0.
6. **Dead code (low).** `make_hf_api_request` (`R/utils.R:165`) takes the token and has no callers. Remove it.
7. **Unused Suggests (low).** `jsonlite` and `covr` are declared but unused. Remove them. `rprojroot` stays because `tests/hf_test_setup.R` uses it.
8. **Parquet connection close (low, test).** `read_xet_parquet()` relies on arrow closing the connection on success (`R/arrow.R:83-88`). Add an `isOpen()` assertion to `tests/testthat/test-arrow-spatial.R` so a future arrow change is caught.
9. **CI confirmation (done).** CI run 38861501139 on `f1f5b96` succeeded on all three platforms. No task needed.

Decisions from the 0.1.1 planning interview (2026-10-16): token canaries cover all offline paths; memory claims are reworded, not measured; the live suite runs at the final gate. See `planning/EXECUTION_PLAN_9.md`.

Out of 0.1.1 unless you ask: any change to the public API surface, and any promotion of an Experimental API.

## Deferred features (0.2.0 or later)

| Item | Why deferred | Gate to start |
|---|---|---|
| Range-backed or seekable R connection | Needs remote random access. Master plan item 4 and STATE_7 defer it. | Byte-for-byte live and local tests for range reads, and a documented range contract. |
| Multi-file vector formats (shapefile, `.shp`/`.dbf`/`.shx`) | Sidecar files cannot go in one temp file. | A multi-file temp directory design, with cleanup tests. |
| Vendored crates for offline builds | Phase 3 kept the build online via crates.io. | A decision on vendor size and license review, and a CRAN-style offline test. |
| Promote Experimental APIs to Supported | ADR 0001 requires live evidence. The 9 Experimental APIs have it only partly. | Recorded live evidence per API, and an ADR amendment. |
| Upstream "Data sender was dropped" race | Upstream xet-core issue, not reported. | Your go-ahead to report it upstream, and a minimal reproduction. |
| Streaming optional helpers | The optional helpers read the whole file into memory. | A design that bounds memory without changing the 2 GiB cap semantics. |

## Out of scope for the foreseeable future

- Zero-copy handoff, automatic token refresh, parallel download throughput, push-down filtering, cache guarantees, and metadata retrieval. Each needs a design and evidence before it becomes a claim.

## Process

- Each patch or minor release gets its own `planning/EXECUTION_PLAN_N.md` and `STATE_N.md`, created with `/plan-wave`.
- A release is not tagged or published without your explicit approval.
- Keep this document updated when an item ships or is dropped.
