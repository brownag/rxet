---
id: "0002"
title: "License Apache-2.0 with the Full Text in LICENSE.md"
status: "Accepted"
date: 2026-10-15
authors:
  - "Andrew G. Brown"
supersedes: null
superseded_by: null
source_context: "EXECUTION_PLAN_2"
---

# 2. License Apache-2.0 with the Full Text in LICENSE.md

## Context and Problem Statement

The package declares the Apache-2.0 license and ships license text. An earlier
decision used `License: Apache License (>= 2) + file LICENSE` with a two-line
`YEAR`/`COPYRIGHT HOLDER` stub named `LICENSE`. At the Phase 2 release gate,
`R CMD check` reported *"License components with restrictions not permitted"*
because R's license model marks `Apache License` **non-extensible** — the
`+ file LICENSE` stub form is only permitted for licenses whose text uses the
`YEAR`/`COPYRIGHT HOLDER` template (e.g. MIT, BSD). The original baseline had a
different NOTE ("File LICENSE is not mentioned in the DESCRIPTION file"). A
license metadata form was needed that is both truthful and `R CMD check` clean.

## Decision Drivers

* No `R CMD check` NOTE attributable to license metadata.
* Ship the full Apache-2.0 license text.
* Standard CRAN-accepted metadata; minimal, conventional repository layout.

## Considered Options

1. `License: Apache License (>= 2) + file LICENSE` (stub `LICENSE`).
2. `License: Apache License (>= 2) | file LICENSE` (stub `LICENSE`).
3. `License: Apache License (>= 2)` with the full text shipped as `LICENSE.md`,
   no `LICENSE` file (chosen).
4. `License: file LICENSE` with the full Apache text in `LICENSE`.

## Decision Outcome

Chosen option: **`License: Apache License (>= 2)` plus a full-text `LICENSE.md`**,
because R declares Apache-2.0 standard (no extension needed), and `.md` license
files are ignored by R's top-level-file check while still shipping in the source
archive. Concretely: `DESCRIPTION` uses `License: Apache License (>= 2)`; the
full Apache text ships as `LICENSE.md`; `.Rbuildignore` no longer excludes
`LICENSE.md`; the two-line `LICENSE` stub is deleted.

### Consequences

* **Positive:** `R CMD check` license metadata is clean (Status: OK); the full
  license text ships; the repository uses the conventional `LICENSE.md` name.
* **Negative:** The license text lives in `LICENSE.md` rather than `LICENSE`,
  which differs from the rextendr default template.

## Validation & Compliance

* `R CMD check --no-manual` reports `checking DESCRIPTION meta-information ... OK`
  and `Status: OK`.
* Built source tarball contains `LICENSE.md` and not `LICENSE`.
* README license line references `LICENSE.md`.
