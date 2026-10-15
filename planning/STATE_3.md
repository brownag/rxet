# State 3 — Phase 3: Reproducible Native Build and Supported-Platform Packaging

Resume from this file. The user approved this plan on 2026-10-15. Approval covers Phase 3 planning-task orchestration only — dependency pinning + lockfile policy, MSRV declaration, Windows build template, source-archive hygiene, CI workflow authoring, and read-only env-var verification. It does not authorize Rust behavior changes, vendoring, CRAN submission, live-network testing, or release publication.

## Baseline checklist (observed 2026-10-15)

- [x] Repository instructions read: `AGENTS.md` (build: `R CMD INSTALL .`, `cargo check`; tests: `devtools::test()`).
- [x] Master input read: `planning/MASTER_PLAN.md` (Phase 3 mandate and exit gate).
- [x] Prior phases read: `planning/EXECUTION_PLAN_1.md`/`STATE_1.md`, `planning/EXECUTION_PLAN_2.md`/`STATE_2.md`; ADRs `docs/decisions/0001–0003`.
- [x] Linux `R CMD build .` + `_R_CHECK_FORCE_SUGGESTS_=false R CMD check --no-manual` → Status: OK (Phase 2, 0 ERROR/WARNING/NOTE).
- [x] Test suite green under check (`FAIL 0 | SKIP 11 | PASS 111`).
- [x] Dependency facts: `hf-xet` unpinned git dep; `Cargo.lock` untracked/unshipped; resolves hf-xet 1.7.0 at `e922f742…` (≠ `v1.7.0` tag).
- [x] crates.io confirmation: `hf-xet 1.7.0` published, checksummed, exposes `xet::xet_session`; `edition = "2024"` → Rust ≥ 1.85.
- [x] Windows template `src/Makevars.win.in` absent from history; `tools/config.R` selects it and fails opaquely. Reference: `/home/andrew/workspace/roxigdal/src/Makevars.win.in`.
- [x] No `.github/` CI. `.Rbuildignore` ships `planning/`+`docs/`; stray tracked `.gitiginore` present.
- [x] Local toolchain: R 4.6.1; rustc/cargo 1.96.0-nightly; `python3`+PyYAML available; `actionlint` absent; `rg` absent.
- [x] Workspace artifacts preserved: `rxet.Rcheck/` and `rxet_0.1.0.tar.gz` are untracked and must not be overwritten or removed.

## Decisions / user answers (2026-10-15)

- D1: Pin `hf-xet` to crates.io `"1.7.0"` (drop the git dependency).
- D2: Commit and ship `src/rust/Cargo.lock` (remove `.gitignore` + `.Rbuildignore` exclusions).
- D3: MSRV `1.85` in `Cargo.toml` + `DESCRIPTION` (no separate MSRV-verification task).
- D4: Repair Windows: author `src/Makevars.win.in`; add a clear missing-template guard to `tools/config.R`.
- D5: Add a 3-OS (ubuntu/macos/windows) CI build/check matrix.
- D6: Defer vendoring; document the online-build requirement (no vendor archive); task `3.1.5` records it in the install docs.
- D7: Exclude `^planning$` + `^docs$` from the source archive; delete `.gitiginore`.
- D8: Include a read-only `HF_XET_*` env-var verification against the pinned crate.
- D9: CI is the platform gate; record the macOS/Windows first-run deferral explicitly in `STATE_3.md` and `MASTER_PLAN.md` (no local macOS/Windows host).

## Wave board

| Wave | Tasks | Status | Depends on |
|---|---|---|---|
| 1 | `3.1.1.hf-xet-pin` | done | none |
| 1 | `3.1.2.archive-hygiene` | done | none |
| 1 | `3.1.3.windows-template` | done | none |
| 1 | `3.1.4.ci-matrix` | done | none |
| 1 | `3.1.5.online-build-docs` | done | none |
| 2 | `3.2.1.env-var-check` | pending | 3.1.1 |
| 3 | `3.3.1.build-verify` | pending | 3.1.1–3.1.5, 3.2.1 |

## Task reports

<!-- Orchestrator and workers append reports below. One section per task id, <=15 lines each. -->

### 3.1.1.hf-xet-pin

Status: done.
Files changed: `src/rust/Cargo.toml:6` (`rust-version = '1.85'`), `:14` (`hf-xet = "1.7.0"`); `src/rust/Cargo.lock` regenerated (untracked, now trackable) — `hf-xet`/`xet-client`/`xet-core-structures`/`xet-data`/`xet-runtime` all `1.7.0` from `registry+https://github.com/rust-lang/crates.io-index`, zero `git+` sources; `DESCRIPTION:14` (`rustc >= 1.85.0`); `.gitignore` removed `src/rust/Cargo.lock` + bare `Cargo.lock` (kept target/.cargo/*.o/*.so/*.a).
Validation: spec targeted command → exit 0 (`cargo check` finished; deps cached). `cargo update -p hf-xet` succeeded (no `generate-lockfile` fallback needed).
Deviations: none.
Gotchas: lock regeneration dropped `serde_with v3.24.0` (expected graph delta); `src/rust/Cargo.lock` reaches the archive only with `3.1.2`.

### 3.1.2.archive-hygiene

Status: done.
Files changed: `.Rbuildignore` — removed `^src/rust/Cargo\.lock$`, added `^planning$` + `^docs$` (target/vendor/.cargo exclusions kept); `.gitiginore` deleted via `git rm` (was a tracked typo file).
Validation: `! grep -Fq 'Cargo\.lock' .Rbuildignore && grep -Fqx '^planning$' .Rbuildignore && grep -Fqx '^docs$' .Rbuildignore && test ! -e .gitiginore` → exit 0.
Deviations: worker executed but did not write its todo; orchestrator recorded `planning/tasks/3.1.2.archive-hygiene.todo.md` from the approved micro-plan.
Gotchas: lockfile ships only if `3.1.1` also landed (both verified by the orchestrator).

### 3.1.3.windows-template

Status: done.
Files created: `src/Makevars.win.in` (Windows `-pc-windows-gnu` target, `librxet.a`, `@LIBDIR@`/`@PROFILE@`/`@CRAN_FLAGS@`/`@CLEAN_TARGET@`, `libgcc_mock` step, `-lws2_32 -ladvapi32 -luserenv -lbcrypt -lntdll`; no `bin document` step). Files changed: `tools/config.R` added a `file.exists(mv_fp)` guard before `readLines(mv_fp)`.
Validation: spec targeted command → exit 0; `source("tools/config.R")` regenerated `src/Makevars` byte-identical.
Deviations: none.
Gotchas: idempotency assumes `DEBUG`/`NOT_CRAN` unset and no `src/rust/vendor.tar.xz`; Windows execution is deferred to CI.

### 3.1.4.ci-matrix

Status: done.
Files created: `.github/workflows/R-CMD-check.yaml` — matrix `os: [ubuntu-latest, macos-latest, windows-latest]`, `r-version: [release]`; checkout@v4 → setup-r@v2 → setup-r-dependencies@v2 (`'"hard"'`) → dtolnay/rust-toolchain@stable → `R CMD build .` → `R CMD check --no-manual *.tar.gz` with step-level `env: _R_CHECK_FORCE_SUGGESTS: false` + `shell: bash`.
Validation: spec targeted command → exit 0 (PyYAML parse; three OS values; no secrets/HF_TOKEN/huggingface.co).
Deviations: none (Q1 resolved: step env + bash for Windows portability).
Gotchas: CI cannot run locally; macOS/Windows validation is the post-push deferral (D9).

### 3.1.5.online-build-docs

Status: done.
Files changed: `README.Rmd` (+1 prerequisite sentence under `### From source`); `README.md` regenerated (+4 lines, no rmarkdown/pandoc churn); `AGENTS.md` lines 40 (`crates.io dependency`), 111 (First Build note), 118 (`hf-xet = "1.7.0"` from crates.io pinned by `src/rust/Cargo.lock`).
Validation: spec targeted command → exit 0 (`git diff --check` clean; both README files mention crates.io/network; stale "from git" phrase gone).
Deviations: none (Q1 applied — also corrected `AGENTS.md:118` and the diagram label).
Gotchas: docs describe the post-`3.1.1` state; re-render `.Rmd` for any later doc edit.

### Orchestrator notes (Wave 1)

- All five wave-1 tasks executed in the shared working tree; file scopes are pairwise-disjoint and the only cross-task read (3.1.3 reading `DESCRIPTION` while 3.1.1 edits it) is harmless (msrv.R accepts either value; 3.1.3's acceptance depends only on `Makevars` idempotency). The plan's per-task worktree note was therefore not required.
- Orchestrator independently re-ran all five targeted commands against the combined tree: all exit 0.
- Wave-end full suite: `devtools::test(reporter = "summary", stop_on_failure = TRUE)` → exit 0 (0 failures; skips unchanged: `uuid`/`arrow`/token-gated).
- Scope check: `git status` shows only the expected files; no out-of-scope edits; user artifacts `rxet.Rcheck/`/`rxet_0.1.0.tar.gz` untouched.
- Committed one commit per task plus a planning-artifacts commit (conventional format; no wave/orchestration numbers).

### 3.2.1.env-var-check

Status: pending.

### 3.3.1.build-verify

Status: pending.
