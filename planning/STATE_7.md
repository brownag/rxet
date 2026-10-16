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
| 7.1.1.spike-helper-paths | 1 | pending |
| 7.1.2.fixtures | 1 | pending |
| 7.2.1.arrow-tests | 2 | pending |
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
