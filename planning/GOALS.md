# Project Goals (`planning/GOALS.md`)

Last Updated: 2026-11-07
Source State: `planning/ARCHITECTURE_REVIEW_2026-11-05.md` (converted from `architecture-review-20261105-063946.html`); `planning/ARCHITECTURE_REVIEW.md` (2026-10-22, folded in)

Dependency graph: G2 -> [G3]. G5 is soft-dependent on G3 (its trigger). G4 is independent. G1 and the 2026-10-22 candidates 1 and 2 are pruned as shipped.

## Circled Goal (Active)

- **[G2]** The stream connection module owns the open, size and close lifetime of a lazy range reader, and the C connection is tested offline through its closure seam.
  - Why now: it is the root of the lazy-read chain. Once it lands, G3 (one constructor) can collapse onto it, and the parquet path in G5 has a single owner to split around. Today reader lifetime and file size are held in C, R and Rust at once.
  - Exit criteria:
    - File size is stored in one place. The `size #1` / `size #2` duplication in the read path is gone.
    - Closing the connection releases the Rust reader at once, without waiting for GC. A test shows this, or the comment in `R/stream_connection.R` is corrected to match the code.
    - `src/connection.c` has offline tests that drive `.xet_stream_connection(read_fun, size)` with a closure over local bytes. They run without `local_cas_server`.
    - `cargo test` and `Rscript -e 'devtools::test()'` pass.
    - Any change to ADR 0006 decision 4 is recorded in a new ADR or an ADR amendment. Keep the GC finalizer unless the early-release test shows it matters.
  - First action: re-read ADR 0006 decision 4 and `src/connection.c:83-117`, then write one failing offline test that reads through the closure seam with local bytes and asserts the file size is used once.
  - Note: this replaces the 2026-10-22 decision to start on the whole-download module. That module shipped in `e61cccb`, so nothing is left to start on there.

## Sequenced Goals (Dependency DAG)

- **[G3]** One exported connection constructor: `xet_open_stream_connection()` is lazy on R ≥ 4.3 and falls back to `rawConnection` otherwise. `xet_open_connection()` is removed or becomes internal.
  - Depends on: G2
  - Notes: changes the export set fixed by ADR 0001/0004, so it needs a new ADR. The function is Experimental-tier, so the breaking change is cheap. Update `R/stream.R:15`, `R/arrow.R:53`, `README.md` and `tests/testthat/test-whole-download.R:63-77` in the same change.

## Independent Backlog

- **[G4]** One Rust transfer module builds the download group, pumps optional byte ranges into an R raw vector, and owns the size-mismatch error mapping. `xet_stream_raw`, `xet_stream_range`, `xet_open_reader` and `xet_download_file` all call it, and the empty-range rule is decided once.
  - Notes: first check the range disagreement. `R/validate.R:36-53` rejects `end == start`, and `src/rust/src/lib.rs:453-467` may not. Settle which rule is right before the refactor. This is the only candidate that may hide a user-visible inconsistency, so it can be taken in parallel with G2 if it is small.
  - Folded from: 2026-10-22 candidate 3. Still open: `number_after` and `size_mismatch_message` (`src/rust/src/lib.rs:399-405`) remain in the extendr binding file, and `tests.rs` reaches them through helpers. The two-converter merge (`to_whole_bytes` / `whole_u64`) is already gone.

## Deferred

- **[G5]** Split the whole-download module's `via` switch. Parquet gets its own helper on the stream path, and raster and vector stay on the temp-file path. Validation runs once per entry point.
  - Trigger: G3 is merged, or the `.rxet_whole_download()` name or AGENTS.md wording misleads a contributor or causes a bug.
  - Notes: `R/whole_download.R` still branches on `via = c("stream", "file")`. It builds on the module from `e61cccb`.

- **[G6]** Classed client object: `R/client.R` returns a validated object instead of a bare character handle, so closed or invented handles are caught in R.
  - Trigger: a handle misuse (closed or invented handle reaching Rust) is reported as a bug.
  - Notes: from 2026-10-22 candidate 4. Speculative. It contradicts the opaque-UUID handle design in AGENTS.md and the public API in ADR 0001/0004, so reopening it needs a new ADR.

## Blocked / Pruned

- **[G1]** Put the reader window policy behind a fetch seam (`RangeSource`, in-memory adapter, fetch-log tests).
  - Status: Pruned (already shipped)
  - Reason: `src/rust/src/reader.rs` and the `RangeSource` seam exist. Commits `8e3c3ba`, `3a63a86`, `053d96f`, `3c50efb`, `6280ec0` and `0af47f8` cover it. The review's "zero tests" claim is stale.

- **[G7]** 2026-10-22 candidate 1: whole-download reader module (arrow, raster, vector share one lifecycle).
  - Status: Pruned (already shipped)
  - Reason: `e61cccb` added the internal whole-download module. Its remaining split is G5.

- **[G8]** 2026-10-22 candidate 2: one validation module for handle, hash, size and range rules.
  - Status: Pruned (already shipped)
  - Reason: `6b91cdd` added the validation module. The `>= 0` and `> 0` size drift is gone (`R/validate.R` has one size check). The duplicated 2 GiB cap went with `a25577e`, which removed the cap.
