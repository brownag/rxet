# STATE 7: Phase 6 — optional integrations and memory behaviour

Plan: `planning/EXECUTION_PLAN_7.md` (APPROVED 2026-10-16 by the user; D8 amended: CI installs arrow, terra and sf). Prompt: `planning/PROMPT_TEMPLATE_7.md`.

## Baseline (2026-10-16)

- [x] Routine suite with `RXET_LOCAL_CAS_SERVER` (orchestration 6 gate, 02cd962): pass 224, fail 0, skip 17. arrow was absent then; arrow 25.0.1, terra 1.9.51, sf 1.1.2 are installed now.
- [x] Clean-archive `R CMD check` (orchestration 6 gate): Status OK.
- [ ] Routine suite re-run with arrow, terra and sf installed: not yet recorded.
- [x] CI: macOS and Windows pass on 88a146d; Ubuntu failed on one streaming token check, fixed in 3f0b447 (not yet pushed).

## Wave board

| Task | Wave | Status |
|---|---|---|
| 7.1.1.spike-helper-paths | 1 | done (a7011b5) |
| 7.1.2.fixtures | 1 | done (7dedc9c) |
| 7.2.1.arrow-tests | 2 | done (test commit below; product fix 5f764c1) |
| 7.2.2a.spatial-read-fix (inserted) | 3 | done (fix, uncommitted until below) |
| 7.2.2.spatial-tests | 3 | pending |
| 7.3.1.helper-docs | 4 | pending |

## Task reports

(Workers append reports here.)

## 7.1.1

- Status: done (read-only spike; no code changed).
- Files changed: `planning/STATE_7.md` (this section), `planning/tasks/7.1.1.todo.md` (new micro-plan).
- Helpers (read path / temp file / connection call):
  - `read_xet_parquet`: `R/arrow.R:55-70`. In memory. No temp file. `xet_open_connection` at :67, `arrow::read_parquet(conn)` at :70.
  - `read_xet_parquet_stream`: `R/arrow.R:115-134`. In memory via `xet_stream_raw` at :125. Temp file: `tempfile(fileext=".parquet")` at :128, `writeBin` at :131, `unlink` on exit at :129. `arrow::read_parquet(tmp_file)` at :134.
  - `read_xet_raster`: `R/spatial.R:58-70`. In memory. No temp file. `xet_open_connection` at :67, `terra::rast(conn)` at :70.
  - `read_xet_vector`: `R/spatial.R:126-138`. In memory. No temp file. `xet_open_connection` at :135, `sf::st_read(conn)` at :138.
- Cap path: `xet_open_connection` (`R/connection.R:43-63`) has no cap. It calls `xet_stream_raw` at `R/connection.R:60`. The check is at `R/stream.R:48-52`, before `.Call`.
- Refusal text (probed): "in-memory read of 2147483648 bytes exceeds the 2 GiB limit (2147483647 bytes); use xet_download_file() for larger files".
- Boundary probe at 2^31 - 1: no cap error. Returns "invalid or closed client handle" (dummy handle "h", no network).
- Validation: `library(rxet)` loads from the installed package. Probes were handle-only, no client, no token.
- Deviations: none.
- Discovered: `terra::rast()` and `sf::st_read()` receive a `rawConnection`, not a path. Not verified; left for 7.2.2.
- Blockers: none. No commit made.

## Handoff (2026-10-16)
- Next: wave 1 (7.1.1 spike, 7.1.2 fixtures). Each worker drafts a micro-plan; orchestrator approves with SendMessage; verify before committing.
- Pushed: main at e43f59a, including 3f0b447 (streaming token test accepts the upstream writer error).
- Pending: CI run for e43f59a (arrow, terra, sf now installed in CI) is not yet reviewed.
- Pending, not done: the upstream xet-core report for the "Data sender was dropped" race (needs the user's go-ahead to file).

## 7.1.2

- Status: done. Acceptance passed: fresh-dir regeneration matches committed SHA-256 for all three files; each file under 100 KB.
- Files changed (new, untracked): `tests/testthat/fixtures/make_fixtures.R`, `tests/testthat/fixtures/PROVENANCE.md`, `tests/testthat/fixtures/small.parquet`, `tests/testthat/fixtures/small.geojson`, `tests/testthat/fixtures/small.tif`. Also the plan file `planning/tasks/7.1.2.todo.md`. Nothing staged or committed.
- Versions: R 4.6.1, arrow 25.0.1, terra 1.9.51, sf 1.1.2 (not used by generator).
- SHA-256 and size:
  - small.parquet 1204 B, b2304007dff06e49999a4f203e256f24c513f58a38b0c51e3f0b4468b6deacee
  - small.geojson 529 B, 547fbd685ad0685b0ad59fded27ebe4003419e0b295d3073d8f07ce09349b4fd
  - small.tif 2240 B, b926f2c071b5eb1ce2b474698f305422c991f5069545c3afb91cc126dacfc7a9
- Validation: `Rscript -e 'parse(...)'` PARSE_OK; two fresh scratch runs identical (diff empty); acceptance run in a third scratch dir diffed against committed files (empty); PROVENANCE lists all three hashes.
- Scope: `git status --short` shows only the fixtures dir and the plan file as untracked; `git check-ignore` none; `src/` clean.
- Deviations: none from the approved plan. Raster uses a second fixed seed (20260102) alongside 20260101 for Parquet, which is one seed per output.
- Discovered: none beyond the plan's noted risk that Parquet and GeoTIFF bytes depend on library versions (recorded in PROVENANCE.md).

## 7.2.1

- Status: STOP. Product defect found in `read_xet_parquet` (`R/arrow.R:67-70`). Not fixed (product code is out of scope).
- Files changed: `tests/testthat/helper-fixtures.R` (new, 1-37); `tests/testthat/test-arrow-spatial.R` lines 14-26 replaced by four arrow tests (approx. 14-54). Plan file `planning/tasks/7.2.1.todo.md`. Nothing committed.
- Validation: `RXET_LOCAL_CAS_SERVER=$HOME/.cargo/bin/local_cas_server Rscript -e 'devtools::test(filter="arrow-spatial")'`: FAIL 1, SKIP 3, PASS 4. Skips: first arrow test (HF_TOKEN gate, untouched), terra and sf "required" tests (installed, untouched). Local server: `$HOME/.cargo/bin/local_cas_server`.
- Failure: "read_xet_parquet returns the data frame written by make_fixtures.R" errors `invalid connection` in `close(conn)` at `R/arrow.R:67`. Cause: `arrow::read_parquet()` closes a rawConnection it reads (scratch check: `isOpen(conn)` after read gives "invalid connection"). `read_xet_parquet` then calls `close(conn)` again in its `on.exit`. Every success path fails.
- Deviations (approved): spec's "returns a connection" wording does not match the product (`R/arrow.R:134` returns a data frame); stream test checks the data frame, byte equality is checked through `xet_open_connection`. Lines 14-26 (HF_TOKEN test) replaced with local-server tests.
- Discovered: `read_xet_parquet` needs the close-after-read removed or guarded (e.g. `tryCatch(close(conn), error = function(e) NULL)` or drop the `on.exit`), a product fix requiring a separate task. The 2 GiB refusal test passes, with no client and no network.
- Blockers: the product defect above. Awaiting orchestrator decision on the fix task.
- Orchestrator (after 7.2.1): product defect fixed in `R/arrow.R` (commit 5f764c1): `read_xet_parquet` no longer closes the connection in `on.exit`; it closes it only on the error path. Re-run `devtools::test(filter="arrow-spatial")` with `RXET_LOCAL_CAS_SERVER=$HOME/.cargo/bin/local_cas_server`: 5 pass, 0 fail, 3 skip (first arrow test and the terra/sf absence checks).
- Note: the old `read_xet_parquet handles nonexistent files gracefully` test (HF_TOKEN-gated) was replaced by the approved local-server tests.

## 7.2.2a
- Status: done (acceptance passed on local server; nothing committed).
- Files changed: `R/spatial.R` lines 67-79 (`read_xet_raster` body: readBin, close, tempfile, on.exit unlink, writeBin, rast, unwrap(wrap), crop) and 135-149 (`read_xet_vector` body: readBin, close, tempfile, on.exit unlink, writeBin, sf::st_read(path)). Roxygen, signatures, guards and stopifnot unchanged. Plan `planning/tasks/7.2.2a.todo.md`.
- Deviation (approved option c, function changed): `terra::readAll()` is not exported in terra 1.9.51. Used `terra::unwrap(terra::wrap(rast))` to load values into memory before unlink (probe: sum of 1..256 = 32896, inMemory TRUE).
- Acceptance: `RXET_LOCAL_CAS_SERVER=$HOME/.cargo/bin/local_cas_server Rscript <scratchpad>/accept_7_2_2a.R` gave raster nrow 16, ncol 16, values length 256 readable after return; vector feature count 3; temp files added by each read 0. Output "ACCEPTANCE PASS".
- Discovered: the raster is loaded into memory, so peak memory is the file bytes plus the raster values. Single-file temp writes cannot serve multi-file formats such as shapefiles (`.shp/.dbf/.shx`), which the roxygen lists; not fixed, signature unchanged.
- Discovered: terra reads pixel values lazily from the path; unlinking a file-backed raster makes `values()` fail (`[readStart] file does not exist`).
- sf path: `sf::st_read` reads the full file, so no extra load step was added.

## 7.2.2
- Status: done (acceptance passed on local server; nothing committed).
- Files changed: `tests/testthat/test-arrow-spatial.R` lines 61-101 (two new tests, inserted after the 2 GiB test and before the "requires" tests). Plan `planning/tasks/7.2.2.todo.md` (new).
- Tests: "read_xet_raster returns the 16x16 GeoTIFF with the generator's values" (dims, CRS "32633", values vs `set.seed(20260102L); round(runif(256), 4)` with tolerance 1e-6, read after return; no new tempdir file). "read_xet_vector returns the three-feature GeoJSON fixture" (class sf, 3 features, matches `sf::st_read` of the fixture; no new tempdir file).
- Cell order: `make_fixtures.R` uses `terra::values(r) <- round(runif(256), 4)`, which fills cells 1..256 in order (row-major from top-left). Committed values match the seeded sequence within 1e-6 (max abs diff 2.9e-8, Float32).
- Command: `RXET_LOCAL_CAS_SERVER=$HOME/.cargo/bin/local_cas_server Rscript -e 'devtools::test(filter="arrow-spatial")'`: FAIL 0, SKIP 3, PASS 14. Skips: HF_TOKEN test (untouched), terra and sf "requires" tests (installed, untouched). Both new tests ran and passed.
- Local server: `$HOME/.cargo/bin/local_cas_server`.
- Deviations: approved change applied (seeded values, not terra reading the committed file). Tolerance 1e-6 is needed for Float32 storage; `identical()` fails.
- Discovered: `sf::st_read` in `read_xet_vector` prints a "Reading layer" message to the console (not quiet). Not a failure.
- Discovered: no new temp files were left by either read.
