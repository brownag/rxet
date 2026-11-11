# 0008. Require R >= 4.3.0 for the whole package

- **Status:** Accepted
- **Date:** 2026-11-09
- **Supersedes:** none
- **Superseded by:** none
- **Amends:** 0006 (consequences: the R floor and the pre-4.3 fallback)

## Context

ADR 0006 added `xet_open_stream_connection()`, which needs
`R_new_custom_connection()` from R 4.3.0. The package still declared
`Depends: R (>= 4.2)`. The new code was guarded: an R-side version check
errored in the constructor, and `src/connection.c` had a pre-4.3 stub. Older R
could install rxet, and only the streaming constructor failed.

That left two code paths, one of which no supported user could reach in
practice, and a floor in `DESCRIPTION` that did not match the feature set.

## Decision

1. `DESCRIPTION` declares `Depends: R (>= 4.3)`. The whole package requires
   R 4.3.0.
2. The R-side version check in `xet_open_stream_connection()` is removed.
3. The `R_VERSION >= R_Version(4, 3, 0)` guard and the pre-4.3 stub in
   `src/connection.c` are removed.
4. `README.Rmd` and `README.md` state R >= 4.3. `NEWS.md` records the change
   under the development version.

## Consequences

- R 4.2 and older cannot install rxet. Users on those versions must upgrade R.
- The package has one code path. R 4.3.0 is the only supported minimum.
- The ADR 0006 consequence about building on older R no longer applies. The
  ADR 0007 note about the pre-4.3 stub no longer applies.
- Roxygen and the generated `man/` pages already say R >= 4.3.0, so they are
  unchanged.
