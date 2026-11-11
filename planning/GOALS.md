# Project Goals (`planning/GOALS.md`)

Last Updated: 2026-11-09
Source State: `planning/STATE_13.md` (G2 shipped, commits `ffebca3`..`60d6b40`); `planning/ARCHITECTURE_REVIEW_2026-11-05.md` (converted from `architecture-review-20261105-063946.html`, status check 2026-11-09); `planning/ARCHITECTURE_REVIEW.md` (2026-10-22, folded in)

Dependency graph: G3 is unblocked (G2 shipped). G5 is soft-dependent on G3 (its trigger). G4 is independent. G1, G2, G7 and G8 are pruned as shipped.

## Circled Goal (Active)

- **[G3]** One exported connection constructor: `xet_open_stream_connection()` is the only public connection constructor. It is lazy where R allows (R >= 4.3) and `xet_open_connection()` is removed or becomes internal.
  - Why now: G2 is shipped, so the lazy path has one owner and one size. The eager `xet_open_connection()` is the last duplicate. Nothing in `R/` calls it, yet `R/stream.R:15`, `R/arrow.R:54` and `R/connection.R` still point readers at it ahead of the lazy path. Removing it also satisfies G5's trigger, so G5 can follow.
  - Exit criteria:
    - `NAMESPACE` exports one connection constructor. `export(xet_open_connection)` is gone, or the function is internal.
    - A new ADR (0008) records the export-set change as an amendment to ADR 0001/0004. The function is Experimental-tier, so the breaking change is cheap.
    - `R/stream.R:15`, `R/arrow.R:54`, `README.md` and `tests/testthat/test-whole-download.R:63-77` no longer point at the eager path. The dead mock test goes.
    - The constructor requires R >= 4.3 and errors clearly below that. No `rawConnection` fallback. The ADR records this, and the roxygen and README say so.
    - `Rscript -e 'devtools::test()'` passes with `RXET_LOCAL_CAS_SERVER` set, and `R CMD INSTALL .` exits 0.
  - ADR 0008 (R >= 4.3 floor) is written. The export-set change needs its own ADR, 0009.
  - First action: draft `docs/decisions/0009-*.md` that names the surviving constructor. Then grep `xet_open_connection` across `R/`, `README.md`, `NAMESPACE` and `tests/` to list every caller before editing.
  - Decided 2026-11-09: require R >= 4.3 for the constructor, no `rawConnection` fallback.
  - Package floor raised to R >= 4.3.0 in the same change (2026-11-09): `DESCRIPTION`, both READMEs and a NEWS development section. The R-side version guard and the C pre-4.3 stub are removed as dead code. `devtools::test(filter = "connection")` passes with and without `RXET_LOCAL_CAS_SERVER`. Uncommitted.

## Sequenced Goals (Dependency DAG)

- **[G5]** Split the whole-download module's `via` switch. Parquet gets its own helper on the stream path, and raster and vector stay on the temp-file path. Validation runs once per entry point.
  - Depends on: G3 (soft, its trigger)
  - Notes: `R/whole_download.R` still branches on `via = c("stream", "file")`. `R/arrow.R:64` uses `"stream"`, `R/spatial.R:65,148` use `"file"`. Validation runs in the shared function and again inside each branch's connection or file call.

## Independent Backlog

- **[G4]** One Rust transfer module builds the download group, pumps optional byte ranges into an R raw vector, and owns the size-mismatch error mapping. `xet_stream_raw`, `xet_stream_range`, `xet_open_reader` and `xet_download_file` all call it.
  - Notes: the range rule is decided. On 2026-11-07 the user kept the R rule, which rejects `end == start` (`R/validate.R:46`). The Rust side (`src/rust/src/lib.rs`, `rxet_stream_range`) still accepts `end == start`. That gap is recorded as a skip in the tests. Aligning Rust to the R rule is the first step of this goal, and it is small.
  - Still duplicated: the `new_download_stream_group()` builder appears at `src/rust/src/lib.rs:97` (`XetReader` fetch), `:356` (`rxet_stream_raw`) and `:421` (`rxet_stream_range`). `number_after` and `size_mismatch_message` (`lib.rs:446-452`) remain in the extendr binding file.
  - Folded from: 2026-10-22 candidate 3, and 2026-11-05 candidate 4.

## Deferred

- **[G6]** Classed client object: `R/client.R` returns a validated object instead of a bare character handle, so closed or invented handles are caught in R.
  - Trigger: a handle misuse (closed or invented handle reaching Rust) is reported as a bug.
  - Notes: from 2026-10-22 candidate 4. Speculative. It contradicts the opaque-UUID handle design in AGENTS.md and the public API in ADR 0001/0004, so reopening it needs a new ADR.

## Blocked / Pruned

- **[G2]** The stream connection module owns the open, size and close lifetime of a lazy range reader, and the C connection is tested offline through its closure seam.
  - Status: Pruned (shipped, 2026-11-08)
  - Reason: `ffebca3` (reader owns size), `f98b732` (close releases the reader at once), `37279bf` (offline connection tests over a memory-backed reader), `8a10f3b` (ADR 0007, amends 0006 decision 4). STATE_13 gate: PASS 333, FAIL 0, SKIP 17, and 20 offline connection tests pass without a server. The C side keeps one bounds copy, taken from the reader at construction. It is not a second source of truth.

- **[G1]** Put the reader window policy behind a fetch seam (`RangeSource`, in-memory adapter, fetch-log tests).
  - Status: Pruned (already shipped)
  - Reason: `src/rust/src/reader.rs` and the `RangeSource` seam exist. Commits `8e3c3ba`, `3a63a86`, `053d96f`, `3c50efb`, `6280ec0` and `0af47f8` cover it. The review's "zero tests" claim is stale.

- **[G7]** 2026-10-22 candidate 1: whole-download reader module (arrow, raster, vector share one lifecycle).
  - Status: Pruned (already shipped)
  - Reason: `e61cccb` added the internal whole-download module. Its remaining split is G5.

- **[G8]** 2026-10-22 candidate 2: one validation module for handle, hash, size and range rules.
  - Status: Pruned (already shipped)
  - Reason: `6b91cdd` added the validation module. The `>= 0` and `> 0` size drift is gone (`R/validate.R` has one size check). The duplicated 2 GiB cap went with `a25577e`, which removed the cap.
