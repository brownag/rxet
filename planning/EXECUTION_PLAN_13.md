# EXECUTION PLAN 13: stream connection owns reader lifetime and size

Source goal: `planning/GOALS.md` **G2** (circled), plus the **G4** range check (scope decision). Drafted 2026-11-07 by plan-wave. Status: APPROVED by user 2026-11-07. Not yet executed. Start with wave 1.

## Goal & Scope

**Goal:** the stream connection module owns the open, size and close lifetime of a lazy range reader, and the C connection is tested offline through a memory-backed reader.

**In scope**
- Single owner for file size: the Rust reader (`src/rust/src/reader.rs`, `XetStreamSource`). C keeps a copy for seek bounds only (see J1).
- `close(conn)` releases the Rust reader immediately. The GC finalizer stays as a backstop.
- Offline tests of `src/connection.c` through a memory-backed Rust reader. They run without `local_cas_server`.
- Offline proof of early release through a registry probe on the Rust reader table.
- ADR 0007 amends ADR 0006 decision 4.
- G4 check only: settle and record the empty-range rule. Behavior changes are not in this plan.

**Out of scope**
- G3: one exported connection constructor. `xet_open_connection()` stays as is.
- G4 refactor: one Rust transfer module; `number_after` and `size_mismatch_message` move.
- G5: whole-download `via` split (`R/whole_download.R`).
- G6: classed client object. Contradicts ADR 0001/0004.
- G1, G7, G8: already shipped.
- Any change to the exported API or the R-visible behavior of `xet_stream_range` or `xet_stream_raw`.

**Verbatim constraints (from GOALS.md G2 exit criteria)**
- "File size is stored in one place. The `size #1` / `size #2` duplication in the read path is gone."
- "Closing the connection releases the Rust reader at once, without waiting for GC. A test shows this, or the comment in `R/stream_connection.R` is corrected to match the code."
- "`src/connection.c` has offline tests that drive `.xet_stream_connection(read_fun, size)` with a closure over local bytes. They run without `local_cas_server`." **(Reworded by D7; see below.)**
- "`cargo test` and `Rscript -e 'devtools::test()'` pass."
- "Any change to ADR 0006 decision 4 is recorded in a new ADR or an ADR amendment. Keep the GC finalizer unless the early-release test shows it matters."

## Decision log

- **D1 (2026-11-07), early release:** `close(conn)` releases the Rust reader immediately. The C close callback calls an R closure that runs `.xet_close_reader(id)`. The GC finalizer is kept as a backstop for connections never closed. *Why:* the R comment says release happens at close, but the code releases only at GC. The user chose the direct close.
- **D2 (2026-11-07), size owner:** the Rust reader owns the file size. R passes size only to `.xet_open_reader`. The connection constructor takes the reader id and reads the size from Rust once.
- **D3 (2026-11-07), release test:** the release proof runs offline through a registry probe. `.xet_reader_is_open(id)` reports whether the id is still in `READERS`. The test opens a memory-backed reader, closes the connection, and asserts the id is gone.
- **D4 (2026-11-07), ADR:** new `docs/decisions/0007-*.md` amends 0006 decision 4. 0006 keeps `Status: Accepted` and gains an "Amended by 0007" line.
- **D5 (2026-11-07), scope:** G4 is a check only. The task settles and records the empty-range rule. If the two rules disagree, the task stops and the user chooses the rule. No behavior change lands here.
- **D6 (2026-11-07), workers (default, not asked):** sonnet for Rust and C, haiku for tests and docs, escalation to a mid-tier model per the wave-orchestration ladder. Max 2 concurrent workers. Worktrees are created manually from the current `v030` HEAD (hazard H1).
- **D7 (2026-11-07), seam vs size (user choice):** the constructor takes the reader id, and offline tests use a memory-backed Rust reader instead of a plain R closure. *Consequence:* the G2 exit criterion "drive `.xet_stream_connection(read_fun, size)` with a closure over local bytes" no longer holds as written. GOALS.md G2 must be reworded to "drive the connection through a memory-backed reader with known bytes" before this plan is executed. The user chose this option knowingly; the reword is a gate for approval.
- **D8 (2026-11-07), registry:** `READERS` holds any `RangeSource` behind a trait object, so a memory source can sit beside `XetStreamSource`. Required by D7.

## Judgment calls for approval (J)

- **J1 (C keeps a size copy):** `src/connection.c` stores `size` for seek bounds, because `seek()` must answer synchronously in C. The Rust reader is the authoritative owner, and C's copy is derived from it once at construction. This does not fully meet "stored in one place" in the strict sense. Alternative: call back into Rust for the size on every seek. Approve J1 or ask for the alternative.
- **J2 (test-only Rust function ships in the binary):** `rxet_memory_reader_open` is compiled into the package. It is not exported, since NAMESPACE uses `exportPattern("^xet_")` and the name has no `xet_` prefix. Alternative: a `#[cfg(test)]`-only feature, which would break the R-level offline tests. Approve J2 or ask for a feature gate.

## Hazard notes (from recon)

- **H1 worktrees:** the orchestration 12 worker was created from `main` and missed the reader code. Create each worktree manually from the current HEAD.
- **H2 extendr wrappers:** `R/extendr-wrappers.R` is generated and must not be hand-edited. After `#[extendr]` signature changes, run `Rscript -e 'rextendr::document()'`, then `R CMD INSTALL .`. Wrapper names are `.<fn name>` (for example `xet_open_reader` becomes `.xet_open_reader`), so `rxet_memory_reader_open` becomes `.rxet_memory_reader_open`. Verify after regeneration.
- **H3 `src/connection.c` is `#if R_VERSION >= 4.3.0` guarded.** The R < 4.3 stub needs the same signature change.
- **H4 `src/rust/src/lib.rs` (537 lines) is shared** by 13.1.1 and 13.1.3 (read only). Use grep anchors, not full reads.
- **H5 `R_ext/Connections.h` is not a stable API** (ADR 0006). Keep C changes minimal.
- **H6 release path:** `close()` on a custom connection calls `con->close`; `destroy` runs later at GC. Release only in `close`. Do not run R code from `destroy`.
- **H7 offline tests** use `skip_if_not(is_compiled())`, never `skip_without_local_cas()`.
- **H8 `READERS` type** is `Registry<WindowedReader<XetStreamSource>>` today (anchor: `static ref READERS`). Changing it is 13.1.2, which must not run in parallel with 13.1.1, since both edit `lib.rs`.

## Baseline (pre-wave, run before 13.1.1)

Recorded in `planning/STATE_13.md`. Re-run, do not copy orchestration 12 numbers:
1. `R CMD INSTALL .` exits 0.
2. `cd src/rust && cargo test` passes; `cargo check --tests` gives 0 warnings.
3. `RXET_LOCAL_CAS_SERVER=$HOME/.cargo/bin/local_cas_server Rscript -e 'devtools::test()'` gives PASS/FAIL/SKIP/ERROR counts. Orchestration 12 recorded PASS 328, FAIL 0, SKIP 16, ERROR 0 (commit 4d66b13), as a reference only.

## Wave table

| Wave | Task | Files must-edit | Depends on | Model |
|---|---|---|---|---|
| 1 | 13.1.1 Rust: reader owns size; reader-id constructor; reader probe | `src/rust/src/lib.rs`, `src/rust/src/reader.rs`, `src/rust/src/tests.rs` | - | sonnet |
| 1 | 13.1.3 G4 empty-range check | `tests/testthat/test-validate.R` (read only: `R/validate.R`, `src/rust/src/lib.rs`) | - | haiku |
| 2 | 13.1.2 Rust: registry holds any `RangeSource`; memory-backed reader; regenerate wrappers | `src/rust/src/lib.rs`, `src/rust/src/reader.rs`, `src/rust/src/tests.rs`, `R/extendr-wrappers.R` (regenerated, the only wave-2 owner of it) | 13.1.1 | sonnet |
| 3 | 13.2.1 C: `close()` releases reader; R constructor takes reader id | `src/connection.c`, `R/stream_connection.R` | 13.1.2 | sonnet |
| 4 | 13.2.2 Offline connection tests | `tests/testthat/test-connection-offline.R` (new), `tests/testthat/test-stream-connection.R` (comment only) | 13.1.2, 13.2.1 | haiku |
| 4 | 13.3.1 ADR 0007 and 0006 amendment | `docs/decisions/0007-*.md` (new), `docs/decisions/0006-*.md`, `docs/decisions/README.md` | 13.2.1 | haiku |

Disjointness: no two tasks in one wave share a must-edit file. `R/extendr-wrappers.R` has one owner, 13.1.2, so it is regenerated once, after both Rust signature changes (13.1.1, 13.1.2). Wave 4 sets are test files vs docs.

Wave-end gate after wave 4 (orchestrator, serial): see the end of this file.

---

## Task specs

### 13.1.1 Rust: reader owns size; reader-id constructor; reader probe

- **Repo:** rxet
- **Files in scope (must edit):** `src/rust/src/lib.rs`, `src/rust/src/reader.rs`, `src/rust/src/tests.rs`
- **Files in scope (can create):** none. Temp work in `.development/`.
- **Depends on:** none
- **Spec:**
  1. In `src/rust/src/reader.rs`, add `pub(crate) fn file_size(&self) -> u64` on `WindowedReader` (it already stores `file_size`).
  2. In `src/rust/src/lib.rs`, change `xet_stream_connection(read_fun, file_size)` to `xet_stream_connection(read_fun: Robj, close_fun: Robj, reader_handle: &str)`. It looks up the reader in `READERS`, takes `file_size()`, and calls `rxet_connection_new(read_fun, close_fun, size as f64)`. Reject a non-function `close_fun` the same way `read_fun` is rejected.
  3. Add `#[extendr] fn xet_reader_is_open(reader_handle: &str) -> bool`. It returns whether `READERS` still holds the id. Register it in `extendr_module!`.
  4. `xet_open_reader` stays the only function that takes `file_size` from R.
  5. In `src/rust/src/tests.rs`, add unit tests: a `WindowedReader` reports the size it was built with; `xet_reader_is_open` returns false for an unknown id.
  6. Do not change the `READERS` locking or the window policy.
- **Anchors:** `lib.rs` `fn xet_open_reader` (around line 66), `fn xet_stream_connection` (around line 119), `static ref READERS` (around line 193), `extendr_module!` (end of file). `reader.rs` `pub(crate) struct WindowedReader` (around line 25), `pub(crate) fn new` (around line 66).
- **Reference implementation:** `reader.rs` `WindowedReader::new` and `read_at` for style.
- **Do not touch:** `R/*.R`, `src/connection.c`, `tests/`, `docs/`, the window constants.
- **Acceptance:**
  - `cd src/rust && cargo test` passes (18 existing plus the new tests).
  - `cd src/rust && cargo check --tests 2>&1 | grep -c '^warning'` prints `0`.
- **Targeted test command:** `cd src/rust && cargo test reader`
- **Note:** do not run `rextendr::document()` here. Wrappers are regenerated in 13.2.1.

### 13.1.3 G4 empty-range check

- **Repo:** rxet
- **Files in scope (must edit):** `tests/testthat/test-validate.R`
- **Files in scope (read only):** `R/validate.R` (anchor: `.rxet_check_range`, around lines 36-53), `src/rust/src/lib.rs` (anchor: `fn xet_stream_range`, around lines 335-400; the range check is near lines 351-361)
- **Depends on:** none
- **Spec:**
  1. Read `.rxet_check_range`. It rejects `end_byte <= start_byte`.
  2. Read the range check in `xet_stream_range`. It allows `end == start` (the error text is "must be >= start"). Confirm by reading, not by running.
  3. Add tests to `tests/testthat/test-validate.R` that pin the current R behavior (an empty range errors). Add a Rust-side case as `skip("G4: empty-range rule disagreement, see EXECUTION_PLAN_13 D5")` if the rules differ.
  4. Record in `planning/STATE_13.md` under `## 13.1.3`: the exact rule in each layer, and whether they agree.
  5. Do not change any rule. If the rules disagree, the report says "STOP: user decides" and the orchestrator asks the user before any change.
- **Anchors:** `grep -n "end_byte\|start_byte" R/validate.R`; `grep -n "must be >= start" src/rust/src/lib.rs`.
- **Reference implementation:** existing range tests in `tests/testthat/test-validate.R`.
- **Do not touch:** `R/validate.R` and `src/rust/src/lib.rs` (read only).
- **Acceptance:** `Rscript -e 'devtools::test(filter = "validate")'` passes; any Rust-side skip shows its reason.
- **Targeted test command:** `Rscript -e 'devtools::test(filter = "validate")'`

### 13.1.2 Rust: registry holds any `RangeSource`; memory-backed reader

- **Repo:** rxet
- **Files in scope (must edit):** `src/rust/src/lib.rs`, `src/rust/src/reader.rs`, `src/rust/src/tests.rs`, `R/extendr-wrappers.R` (regenerated, not hand-edited)
- **Files in scope (can create):** none
- **Depends on:** 13.1.1
- **Spec:**
  1. In `reader.rs`, add `fn finish(&self) -> Result<(), String>` with a default no-op to the `RangeSource` trait (anchor: `pub(crate) trait RangeSource`).
  2. In `lib.rs`, `XetStreamSource` implements `finish` by calling `self.group.finish_blocking()`. Move the call out of `xet_close_reader` (anchor: `fn xet_close_reader`), which now calls `reader.source().finish()` through the trait. Keep the error swallowed as it is today.
  3. Change `READERS` to hold `WindowedReader<Box<dyn RangeSource + Send>>`. Add `Send` or `Sync` bounds only if the compiler requires them. Document the choice in a comment.
  4. Add a memory source (`MemorySource` in `tests.rs` already exists from the G1 work; move or reuse it, do not duplicate). Expose `#[extendr] fn rxet_memory_reader_open(bytes: Raw) -> Result<String>` that builds a `WindowedReader` over a `Box<MemorySource>` with the bytes and returns its id. Register it in `extendr_module!`. This is internal (see J2).
  5. `cargo test` covers: a memory reader reads bytes at offsets; `finish` on a memory source is a no-op.
  6. Run `Rscript -e 'rextendr::document()'` once. This regenerates `R/extendr-wrappers.R` for the signature changes from 13.1.1 and the new function here. Confirm the diff touches only the wrappers for `xet_stream_connection`, `xet_reader_is_open` and `rxet_memory_reader_open`.
  7. Run `R CMD INSTALL .`.
- **Anchors:** `static ref READERS` (around line 193); `fn xet_close_reader` (around line 105); `MemorySource` in `tests.rs`.
- **Reference implementation:** `reader.rs` `RangeSource` seam and the G1 in-memory adapter.
- **Do not touch:** `src/connection.c`, `R/` (except the regenerated `R/extendr-wrappers.R`), `tests/testthat/`.
- **Acceptance:** `cd src/rust && cargo test` passes; `cargo check --tests` gives 0 warnings; `R CMD INSTALL .` exits 0.
- **Targeted test command:** `cd src/rust && cargo test memory` (or the new test names).
- **Escalation hint:** if the trait-object change forces a broad rewrite, stop and report; do not widen the scope.

### 13.2.1 C: `close()` releases the reader; R constructor takes reader id

- **Repo:** rxet
- **Files in scope (must edit):** `src/connection.c`, `R/stream_connection.R`
- **Files in scope (read only):** `R/extendr-wrappers.R` (already regenerated by 13.1.2; do not edit)
- **Depends on:** 13.1.2
- **Spec:**
  1. In `src/connection.c`, `rxet_connection_new(read_fun, size)` (anchor: `SEXP rxet_connection_new`) becomes `rxet_connection_new(read_fun, close_fun, size)`. Store and preserve `close_fun` the same way `read_fun` is preserved.
  2. `rxet_conn_close` (anchor: `static void rxet_conn_close`) calls `close_fun()` once, guarded by `closed`, then sets `closed = 1`. `rxet_conn_destroy` releases `close_fun` (and does not call R).
  3. Update the `#else /* R < 4.3.0 */` stub for the new signature.
  4. In `R/stream_connection.R`, `xet_open_stream_connection`: build `reader <- function(offset, n) .xet_reader_read(id, offset, n)` and `close_fun <- function() .rxet_close_reader_quietly(id)`, then call `.xet_stream_connection(reader, close_fun, id)`. Keep the guard environment and its finalizer as the backstop.
  5. Correct the comment above the guard so it says: close releases now; the finalizer covers connections never closed.
  6. Check that `R/extendr-wrappers.R` already has `.xet_stream_connection(read_fun, close_fun, reader_handle)` (`grep -n "xet_stream_connection" R/extendr-wrappers.R`). If it does not, STOP and report: 13.1.2 is incomplete.
  7. Run `R CMD INSTALL .`.
- **Anchors:** `src/connection.c` `rxet_conn_close`, `rxet_connection_new`, the `#else` stub. `R/stream_connection.R` `xet_open_stream_connection`, the `reg.finalizer` line, `.rxet_close_reader_quietly`.
- **Reference implementation:** `read_fun` preservation in `rxet_connection_new` and `rxet_conn_destroy`.
- **Do not touch:** `R/whole_download.R`, `R/arrow.R`, `R/stream.R` (G3 scope), `src/rust/`, `tests/`.
- **Acceptance:**
  - `R CMD INSTALL .` exits 0.
  - `grep -n "file_size" R/stream_connection.R` shows `file_size` only in argument checks and `.xet_open_reader`.
  - `RXET_LOCAL_CAS_SERVER=$HOME/.cargo/bin/local_cas_server Rscript -e 'devtools::test(filter = "stream-connection")'` passes.
- **Targeted test command:** `R CMD INSTALL . && RXET_LOCAL_CAS_SERVER=$HOME/.cargo/bin/local_cas_server Rscript -e 'devtools::test(filter = "stream-connection")'`
- **Escalation hint:** if `close_fun` ordering with `R_PreserveObject` is wrong, stop and report with the failing output, per the ladder.

### 13.2.2 Offline connection tests

- **Repo:** rxet
- **Files in scope (must edit):** `tests/testthat/test-stream-connection.R` (comment only)
- **Files in scope (can create):** `tests/testthat/test-connection-offline.R`
- **Depends on:** 13.1.2, 13.2.1
- **Spec:**
  1. New `tests/testthat/test-connection-offline.R`, `context("Connection offline")`. Gate each test with `skip_if_not(is_compiled(), "Rust extension not available")`. Never call `skip_without_local_cas()`.
  2. Helper inside the file: `offline_conn <- function(bytes)` opens `id <- .rxet_memory_reader_open(bytes)` and returns `.xet_stream_connection(reader, close_fun, id)` built the same way as `xet_open_stream_connection` (copy the two closures; do not call `xet_open_stream_connection`, which needs a client).
  3. Cover over the memory-backed reader: sequential read matches bytes; seek to start, current and end; read past end returns the bytes that exist; seek outside the file errors "outside the file".
  4. Early release: `conn <- offline_conn(raw)`, `id` captured, `close(conn)`, assert `!.xet_reader_is_open(id)`. Capture `id` by returning it from the helper.
  5. Size: `seek(conn, 0, "end")` equals `length(bytes)`.
  6. In `test-stream-connection.R`, fix the comment on the "closing releases its reader" test if it is now wrong. Do not change its assertions.
- **Anchors:** `R/stream_connection.R` `xet_open_stream_connection` (copy its closures); `tests/testthat/test-stream-connection.R` lines 52-62.
- **Reference implementation:** `tests/testthat/test-stream-connection.R` for the seek and read style.
- **Do not touch:** `R/`, `src/`, the assertions in the local-CAS tests.
- **Acceptance:** `env -u RXET_LOCAL_CAS_SERVER Rscript -e 'devtools::test(filter = "connection-offline")'` passes, with `local_cas_server` removed from `PATH`.
- **Targeted test command:** `env -u RXET_LOCAL_CAS_SERVER PATH=/usr/bin:/bin Rscript -e 'devtools::test(filter = "connection-offline")'`

### 13.3.1 ADR 0007 and 0006 amendment

- **Repo:** rxet
- **Files in scope (must edit):** `docs/decisions/0006-lazy-range-streaming-connection.md`, `docs/decisions/README.md`
- **Files in scope (can create):** `docs/decisions/0007-close-releases-reader-and-size-owned-by-reader.md`
- **Depends on:** 13.2.1
- **Spec:**
  1. Read 0006 decision 4 and the README table format.
  2. Write ADR 0007 in 0006's layout: Status Accepted, Date 2026-11-07, Supersedes none, Amends 0006 decision 4. Context: finalizer-only release; size duplication. Decision: D1, D2, D7, J1, J2. Consequences: close releases now; GC is a backstop; `.xet_stream_connection` signature change; R < 4.3 stub updated; memory-backed reader is internal.
  3. In 0006, add an "Amended by 0007 (decision 4)" line under Status. Do not change decision 4's text.
  4. Add a 0007 row to the README table, Context `EXECUTION_PLAN_13`.
- **Anchors:** 0006 `## Decision` item 4; the README table.
- **Reference implementation:** 0006 for layout.
- **Do not touch:** other ADRs.
- **Acceptance:** `grep -n "Amended by 0007" docs/decisions/0006-*.md` matches; `grep -n "0007" docs/decisions/README.md` matches; the new ADR has all required sections.
- **Targeted test command:** none (docs). The orchestrator reviews the diff.

---

## Wave-end gate (orchestrator, serial, after wave 3)

1. `cd src/rust && cargo test`
2. `R CMD INSTALL .`
3. `RXET_LOCAL_CAS_SERVER=$HOME/.cargo/bin/local_cas_server Rscript -e 'devtools::test()'`
4. `env -u RXET_LOCAL_CAS_SERVER PATH=/usr/bin:/bin Rscript -e 'devtools::test(filter = "connection-offline")'`
5. Confirm GOALS.md G2 is reworded per D7 and the `size #1`/`size #2` grep is clean (J1 is approved or revised).

Record counts in `planning/STATE_13.md`.
