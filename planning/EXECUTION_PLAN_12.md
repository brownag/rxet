# EXECUTION PLAN 12: reader window policy behind a fetch seam

Source: architecture review 2026-11-05, candidate 1 ("Put the reader window policy behind a fetch seam"). Prompt: `planning/PROMPT_TEMPLATE_12.md`. State: `planning/STATE_12.md`.

## Goal & Scope

The reader window policy is the logic that serves lazy range reads for `xet_open_stream_connection()`: 64 KiB alignment, readahead from `file_size / 32` clamped to 1–16 MiB and doubling on forward reads, reset on a non-sequential read, 64 MiB eviction, and fetch-length errors. Today it lives in `src/rust/src/lib.rs:20-151`, fused to the `XetDownloadStreamGroup` fetch and to extendr's `Error` and `rprintln!`. It has no tests, and reaching it needs `local_cas_server`.

The goal is to put the policy behind a `fetch(start, end)` seam with two adapters. The stream-group adapter serves production; an in-memory adapter serves tests. Offline Rust unit tests then check fetch ranges and counts. The plan also fixes the stale "at least 16 MiB" docs.

**In scope**
- New `src/rust/src/reader.rs` (the reader window policy module): `RangeSource` trait, `WindowedReader<S>`, window constants, the length check. No extendr imports.
- `src/rust/src/lib.rs`: the `XetStreamSource` adapter replaces `XetReader`. `READERS`, `xet_open_reader`, `xet_reader_read` and `xet_close_reader` use `WindowedReader<XetStreamSource>`.
- Offline unit tests in `src/rust/src/tests.rs` covering sequential scans, backward seeks, eviction, the EOF clamp, and fetch-length errors.
- Fix the window-size wording in `R/stream_connection.R:17` and `R/arrow.R:24`. The orchestrator regenerates `man/`.
- Add `reader.rs` and the seam to the AGENTS.md layout and architecture notes.

**Out of scope (deferred)**
- Releasing the cache lock during network I/O (D4).
- Reader lifetime across C/R/Rust, the duplicated file size, and the GC-delayed close (review candidate 2).
- Merging `xet_open_connection` (candidate 3), the Rust transfer module and group-builder duplication (candidate 4), and the `via` split (candidate 5).
- The duplicate `RXET_DEBUG` parse at `lib.rs:378`, and the "client registry poisoned" wording in `registry.rs`.
- Other stale docs from the review (`stream.R:15`, `arrow.R:53` `@seealso`, README stream-connection mention, the dead mock in `test-whole-download.R:63-77`).
- The live suite. It is manual only, per AGENTS.md.
- The other stale AGENTS.md layout entries (for example, `R/stream_connection.R` is missing). 12.2.2 edits only the lines it names.
- Any change to an exported R function or its behaviour. NEWS is not updated, because nothing user-visible changes beyond doc wording.

**Verbatim user constraints**
- "Plan wave for number one."
- Seed: "put the reader window policy … behind a fetch(start, end) seam with two adapters: the XetDownloadStreamGroup stream adapter and an in-memory adapter for tests. Remove extendr types (Error, rprintln!) from the cache module. Add offline Rust unit tests in tests.rs asserting fetch ranges/counts for sequential scans, backward seeks, eviction, EOF clamp, and fetch-length errors. Also fix the stale "at least 16 MiB" docs in R/stream_connection.R:17 and R/arrow.R:24."

## Decision log (dated)

| # | Decision | Source |
|---|---|---|
| D1 | The policy moves to a new `src/rust/src/reader.rs` with no extendr imports. `lib.rs` keeps the stream-group adapter and the `#[extendr]` functions. | User, 2026-11-05 |
| D2 | The seam is a `RangeSource` trait, and `WindowedReader<S: RangeSource>` owns the source and the policy state. The two adapters are `XetStreamSource` (lib.rs) and a test-only `MemorySource` (tests.rs). | User, 2026-11-05 |
| D3 | The reader checks the length of every fetch result, for any adapter. `XetStreamSource` keeps only its early abort once the body exceeds the expected length. | User, 2026-11-05 |
| D4 | Pure refactor: fetch ranges, request counts, error conditions and message text do not change. The `size / 32` clamp moves into `WindowedReader::new`. The cache lock stays held across the fetch, documented by a comment. | User, 2026-11-05 |
| D5 | Models: mid tier (sonnet) for 12.1.1, small (haiku) for 12.1.2, 12.2.1 and 12.2.2. Escalate to sonnet after one failed retry; never a third small-model attempt. At most 2 concurrent workers, in separate worktrees when a wave has two tasks. | User, 2026-11-05 |
| D6 | Acceptance per wave: `cargo test` green, then `R CMD INSTALL .` and `devtools::test()` with `RXET_LOCAL_CAS_SERVER=$HOME/.cargo/bin/local_cas_server`. The live suite is not run. | User, 2026-11-05 |
| D7 | ADR check: ADR 0006 decision 2 (window rules) is preserved exactly; this plan only moves where those rules live. No accepted ADR is contradicted or superseded. ADR 0001/0004 are untouched because no export changes. | Orchestrator |
| D8 | AGENTS.md gets the new file and a one-line note on the seam (12.2.2). It is a small addition beyond the seed, kept because AGENTS.md lists every Rust source file. | Orchestrator (flagged for approval) |

## Interface of `reader.rs` (fixed by this plan; workers must not invent others)

```rust
//! Reader window policy: serves byte ranges of one file from cached windows,
//! fetching new windows through a `RangeSource`. Plain Rust: no R types.

use std::collections::VecDeque;
use std::sync::Mutex;

pub(crate) const READ_WINDOW_MIN: u64 = 1024 * 1024;
pub(crate) const READ_WINDOW_MAX: u64 = 16 * 1024 * 1024;
pub(crate) const READ_ALIGN_BYTES: u64 = 64 * 1024;
pub(crate) const READ_CACHE_BYTES: usize = 64 * 1024 * 1024;

/// Where windows come from. `fetch` returns the bytes of `[start, end)`.
pub(crate) trait RangeSource {
    fn fetch(&self, start: u64, end: u64) -> Result<Vec<u8>, String>;
}

pub(crate) struct WindowedReader<S: RangeSource> {
    source: S,
    file_size: u64,
    cache: Mutex<WindowCache>,   // private; today's ReaderCache, renamed
}

impl<S: RangeSource> WindowedReader<S> {
    /// Base readahead = (file_size / 32).clamp(READ_WINDOW_MIN, READ_WINDOW_MAX).
    /// The cache starts empty (no windows, 0 bytes) with readahead == base.
    pub(crate) fn new(source: S, file_size: u64) -> Self;
    /// The adapter, so lib.rs can release it on close (`finish_blocking`).
    pub(crate) fn source(&self) -> &S;
    /// Exactly `length` bytes at `offset`; `Err(String)` on overrun, source error,
    /// wrong-length fetch, or poisoned lock.
    pub(crate) fn read_at(&self, offset: u64, length: u64) -> Result<Vec<u8>, String>;
}
```

The message text must match the current code byte for byte (D4):
- Overrun: `read of {length} bytes at offset {offset} runs past the end of a {file_size} byte file`
- Poisoned: `reader cache poisoned: {e}`
- Wrong length, raised in `reader.rs` after `source.fetch`: `stream returned {n} bytes, expected {expected} for range {start}..{end}`
- The early abort in `XetStreamSource`, which stays in lib.rs: `stream returned more than {expected} bytes for range {start}..{end}`
- Errors from the source pass through unchanged. `XetStreamSource` keeps `download stream error: …` and `stream read error: …`.

## Waves

| Wave | Tasks | Files (pairwise disjoint within the wave) | Notes |
|---|---|---|---|
| 1 | 12.1.1, 12.1.2 | 12.1.1: `src/rust/src/reader.rs` (create), `src/rust/src/lib.rs`. 12.1.2: `R/stream_connection.R`, `R/arrow.R` | Rust only vs R only. Separate worktrees. |
| 2 | 12.2.1, 12.2.2 | 12.2.1: `src/rust/src/tests.rs`. 12.2.2: `AGENTS.md` | Both depend on 12.1.1. Separate worktrees. |

After merging 12.1.2, the orchestrator runs `Rscript -e 'devtools::document()'`, which regenerates `man/xet_open_stream_connection.Rd` and `man/read_xet_parquet.Rd`, and includes them in 12.1.2's commit. Workers never commit: the orchestrator commits each task with the message the spec names, after verification (wave-orchestration step 7).

Hazards (recon):
- `lib.rs` is 641 lines. Enter it with grep anchors only.
- `tests.rs` is included through `#[cfg(test)] mod tests;` in lib.rs (line ~10). A new `mod reader;` goes beside `mod registry;`.
- `READERS` is a `lazy_static` `Registry<…>` (lib.rs ~297), so `WindowedReader<XetStreamSource>` must stay `Send + Sync`. This holds today for `XetReader`, and the generic must not lose it.
- `local_cas_server` is at `$HOME/.cargo/bin/local_cas_server`, which is not on PATH in agent shells.
- No R test matches the reader's error text (`grep -rn "runs past\|stream returned\|reader cache" tests R` is empty), but D4 still requires identical text.
- `cargo test` runs offline and needs no R session.

---

## Task 12.1.1: Extract the reader window policy into reader.rs behind RangeSource

- **Repo:** rxet. **Model:** sonnet. **Depends on:** none.
- **Files in scope:** must edit `src/rust/src/lib.rs`; can create `src/rust/src/reader.rs`. Scratch goes in `.development/` (untracked). Do not touch `tests.rs`, `registry.rs`, or any R or C file.
- **Spec:**
  1. Create `reader.rs` with exactly the interface above. Move the four constants, `ReaderCache` (renamed `WindowCache`, private), `ReaderWindow` (private), `covering`, `insert`, and the body of `read_at` from lib.rs. Change only the error type: `Error::Other(format!(..))` becomes `format!(..)`.
  2. `WindowedReader::new` computes the base readahead as `xet_open_reader` does today (lib.rs ~176). It initializes `WindowCache` with no windows, `bytes: 0`, and both `readahead` and `base_readahead` set to the base.
  3. After `self.source.fetch(start, fetch_end)?`, check `data.len() as u64 == fetch_end - start`. If not, return the wrong-length message. Then slice exactly as today.
  4. Add a doc comment on `read_at` stating that the cache lock is held across the fetch (D4).
  5. In lib.rs, add `mod reader;` and `use reader::{RangeSource, WindowedReader};`. Replace `XetReader` with `struct XetStreamSource { group: XetDownloadStreamGroup, info: XetFileInfo }` implementing `RangeSource`. Its `fetch` body is today's `XetReader::fetch`, keeping the `RXET_DEBUG` `rprintln!`, the stream calls and the early "more than" abort. Drop its final `!= expected` check, which now lives in the reader. Map errors to `String`.
  6. `READERS: Registry<WindowedReader<XetStreamSource>>`. `xet_open_reader` builds the group exactly as today, then `WindowedReader::new(XetStreamSource { group, info }, size)`. `xet_reader_read` calls `reader.read_at(offset, length).map_err(Error::Other)?`. `xet_close_reader` calls `reader.source().group.finish_blocking()` where it called `reader.group.finish_blocking()` before (lib.rs ~216).
  7. Remove the now-unused imports (`Mutex` if no longer used in lib.rs) and the moved constants from lib.rs.
- **Anchors:** `grep -n "READ_WINDOW\|READ_ALIGN\|READ_CACHE\|struct XetReader\|struct ReaderCache\|struct ReaderWindow\|impl ReaderCache\|impl XetReader\|fn xet_open_reader\|fn xet_reader_read\|fn xet_close_reader\|static ref READERS\|^mod \|^use " src/rust/src/lib.rs`
- **Reference implementation:** `src/rust/src/registry.rs`, a crate-internal module with `Result<_, String>` errors mapped with `.map_err(Error::Other)` in lib.rs.
- **Acceptance:**
  - `cd src/rust && cargo check --tests && cargo test` passes, with 18 tests passing.
  - `grep -nE "extendr_api|rprintln!|Error::Other" src/rust/src/reader.rs` returns nothing (exit 1).
  - `cd src/rust && cargo check --tests 2>&1 | grep -c '^warning'` prints 0, matching baseline P3.
  - `grep -n "struct XetReader\|ReaderCache" src/rust/src/lib.rs` returns nothing.
- **Commit:** `refactor(reader): move the window policy behind a range source seam`

## Task 12.1.2: Correct the window-size wording in the stream connection and parquet docs

- **Repo:** rxet. **Model:** haiku. **Depends on:** none.
- **Files in scope:** must edit `R/stream_connection.R`, `R/arrow.R`. Do not hand-edit `man/`; the orchestrator regenerates it.
- **Spec:** The code starts a window at `file_size / 32` clamped to 1–16 MiB and doubles it while reads move forward. 16 MiB is the maximum, not the minimum. Reword only these two roxygen sentences to match `README.Rmd:99`, which is already correct ("a window of at least 1 MiB (larger while reads move forward, up to 16 MiB), aligned to 64 KiB"):
  - `R/stream_connection.R` ~16-18: "fetches a window that starts on a 64 KiB boundary and covers at least 16 MiB"
  - `R/arrow.R` ~23-24: "fetched on demand in windows of at least 16 MiB, aligned to 64 KiB"

  Change no other lines.
- **Anchors:** `grep -n "16 MiB" R/stream_connection.R R/arrow.R`
- **Reference:** `README.Rmd:99`, `AGENTS.md:189`.
- **Acceptance:**
  - `grep -Pzo "at least\s*(#'\s*)?16 MiB" R/stream_connection.R R/arrow.R` prints nothing and exits 1. This multi-line form catches the `arrow.R` wording, which is split across lines 23-24. Baseline: it matches in both files.
  - `grep -c "1 MiB" R/stream_connection.R R/arrow.R` is ≥1 in each file.
  - `git diff --stat` shows only these two files.
- **Commit:** `docs(stream): state the 1 to 16 MiB window range correctly`

## Task 12.2.1: Test the reader window policy offline through an in-memory range source

- **Repo:** rxet. **Model:** haiku. **Depends on:** 12.1.1.
- **Files in scope:** must edit `src/rust/src/tests.rs`. Append the new code, and you may add `use` lines (e.g. `Mutex`). Keep the 18 existing tests unchanged. The micro-plan may group the tests 3–4 per TODO step to stay within 12 steps.
- **Spec:** Add a test-only adapter, `struct MemorySource { size: u64, log: Mutex<Vec<(u64, u64)>>, mode: Mode }`, where `Mode` is `Exact`, `Short`, `Long`, or `Fail(String)`.
  - `fetch` records `(start, end)` and returns the bytes `(i % 251) as u8` for `i in start..end`. Generate them; never allocate the whole file.
  - `Short` drops the last byte, `Long` appends one byte, and `Fail` returns `Err(msg)`.
  - Add a helper `byte(i) -> u8` for content checks.

  Use `crate::reader::{RangeSource, WindowedReader, READ_WINDOW_MIN, READ_WINDOW_MAX, READ_ALIGN_BYTES, READ_CACHE_BYTES}`. Name every test `reader_…`. Write these tests, each asserting the exact logged ranges or a count:
  1. **First read:** on a 100 MiB file, reading 10 bytes at 0 fetches `(0, 100MiB/32)` once. The bytes equal `byte(0..10)`.
  2. **Hit:** a second read inside that window adds no fetch.
  3. **Sequential growth:** on a 256 MiB file the base is 8 MiB. Three 10-byte reads, at 0 and then at the end offset of the newest window, fetch windows of 8, 16 and 16 MiB. Readahead doubles and caps at `READ_WINDOW_MAX`.
  4. **Backward seek:** continue test 3's reader. A read at offset 7 MiB with length 2 MiB spans two cached windows, so it misses. It is not inside the newest window, so readahead resets: the fetch is `(7 MiB, 15 MiB)`. A follow-up read at 15 MiB of length 10 MiB (it must reach past 24 MiB, or the window starting at 8 MiB serves it as a hit) is sequential again, so the fetch is `(15 MiB, 31 MiB)`.
  5. **Alignment:** on a fresh reader over a 100 MiB file, reading 10 bytes at offset 70_000 fetches `(65_536, 65_536 + 100MiB/32)`.
  6. **EOF clamp:** on a 100_000-byte file, the base clamps to 1 MiB and the fetch is `(0, 100_000)`.
  7. **Large read:** on a fresh reader over a 100 MiB file, reading 20 MiB at offset 0 fetches exactly `(0, 20 MiB)`.
  8. **Overrun:** reading past EOF returns an `Err` containing `runs past the end`, with no fetch logged.
  9. **Zero length:** returns empty with no fetch.
  10. **Eviction:** on a 1 GiB file the base is 16 MiB. Five non-sequential reads at 0, 100, 200, 300 and 400 MiB each fetch 16 MiB, and the fifth insert pushes the total past `READ_CACHE_BYTES`, so the window at 0 is evicted. Re-reading offset 0 logs a sixth fetch, `(0, 16 MiB)`, and re-reading 400 MiB logs none.
  11. **Wrong length:** `Short` and `Long` each return an `Err` containing `expected`.
  12. **Source error:** `Fail("boom")` returns an `Err` equal to `boom`.

  Compute the expected sizes from the constants in each assertion, not as magic numbers.
- **Anchors:** `grep -n "^use\|^#\[test\]" src/rust/src/tests.rs`, and `src/rust/src/reader.rs`, which is short; read it whole.
- **Reference implementation:** the existing registry tests at the top of `tests.rs`.
- **Acceptance:** `cd src/rust && cargo test reader_` passes ≥12 tests, and `cargo test` passes everything, ≥30 tests in total.
- **Commit:** `test(reader): check window fetches through an in-memory range source`

## Task 12.2.2: Record reader.rs and the range source seam in AGENTS.md

- **Repo:** rxet. **Model:** haiku. **Depends on:** 12.1.1.
- **Files in scope:** must edit `AGENTS.md` only.
- **Spec:**
  1. In the Codebase Layout tree, add `reader.rs` under `src/rust/src/`, between `lib.rs` and `registry.rs`, with the comment `# reader window policy behind the RangeSource seam`. Change the `lib.rs` comment from `# Rust bindings, reader cache, panic recovery` to `# Rust bindings, stream range source, panic recovery`.
  2. At the end of the "Reader cache" bullet (around line 189), append one sentence: `The policy lives in src/rust/src/reader.rs behind a RangeSource trait, so it can be tested offline with an in-memory source.`

  Change nothing else.
- **Anchors:** `grep -n "lib.rs\|registry.rs\|Reader cache" AGENTS.md`
- **Acceptance:**
  - `grep -c "reader.rs" AGENTS.md` is ≥2.
  - `git diff --stat` shows only `AGENTS.md`.
- **Commit:** `docs(agents): note the reader window policy module`

## End gate (orchestrator, serial)

1. `cd src/rust && cargo test`. Expect ≥30 passed.
2. `R CMD INSTALL .` exits 0.
3. `RXET_LOCAL_CAS_SERVER=$HOME/.cargo/bin/local_cas_server Rscript -e 'devtools::test()'`. Expect 0 failures and 16 skips, against the 328-pass baseline.
4. `git status` is clean apart from the planning files.
