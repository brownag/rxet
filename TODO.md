# TODO

## Goal
Resolve the 13 unresolved CodeRabbit review threads on PR #3 (`v040` -> `main`), verify with local checks, commit changes locally, and post replies/resolve threads on GitHub after explicit approval.

## Tasks

### 1. Planning & Setup
- [x] Commit approved `TODO.md` on branch `v040` (`docs(planning):`).

### 2. Rust Stability Fixes (`src/rust/src/lib.rs`)
- [x] Inspect and address CodeRabbit threads at `src/rust/src/lib.rs:158` and `src/rust/src/lib.rs:440`.
- [x] Run `cd src/rust && cargo check` and `cargo test`, then commit Rust fixes locally.

### 3. R & Rd Documentation Fixes (`R/arrow.R`, `R/spatial.R`, `man/read_xet_parquet.Rd`)
- [x] Inspect and address CodeRabbit threads at `R/arrow.R:32`, `man/read_xet_parquet.Rd:46`, and `R/spatial.R:71` (and regenerate `.Rd` if needed).
- [x] Commit R/Rd fixes locally.

### 4. Markdown Documentation Fixes (`README.md`, `README.Rmd`, `NEWS.md`, `AGENTS.md`, `docs/decisions/0005-remove-in-memory-cap.md`, `tools/README.md`)
- [x] Inspect and address CodeRabbit threads at `README.md:30`, `README.md:47`, `README.Rmd:107`, `NEWS.md:33`, `NEWS.md:39`, `AGENTS.md:182`, `docs/decisions/0005-remove-in-memory-cap.md:55`, and `tools/README.md:43`.
- [x] Commit documentation fixes locally.

### 5. Local Verification
- [x] Rebuild/install package (`R CMD INSTALL .`) and run `Rscript -e 'devtools::test()'`.

### 6. GitHub Remote Actions (Requires Explicit Go-Ahead)
- [ ] Present draft replies for each of the 13 threads and ask for explicit approval before pushing commits, posting replies, or resolving threads on PR #3.
- [ ] Push `v040`, post approved replies, and resolve addressed threads on GitHub.

## Notes
- Branch: `v040` (PR #3 targeting `main`).
- Planning artifacts (`TODO.md` and archived copy under `planning/`) are tracked in Git via separate `docs(planning):` commits.
- Remote actions (push, PR comments, thread resolution) will not run without explicit user approval.
