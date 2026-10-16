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
| 6.0.1.fixture-upload | 0 | pending (user upload) |
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
