# Execution Plan 3 — Reproducible Native Build and Supported-Platform Packaging

This is orchestration plan 3 for `/wave-orchestration`. It corresponds to **Phase 3** of `planning/MASTER_PLAN.md`. It builds on the frozen v0.1 contract in `planning/EXECUTION_PLAN_1.md` / `STATE_1.md` and the corrected metadata/docs of `planning/EXECUTION_PLAN_2.md` / `STATE_2.md`.

## Goal & Scope

### Goal

Make a clean `rxet` source archive build and install consistently under the declared platform/toolchain policy. Concretely: replace the unpinned `hf-xet` git dependency with the published, checksummed crates.io `hf-xet = "1.7.0"`; commit and ship `src/rust/Cargo.lock` so the transitive graph is fixed; correct the Rust MSRV declaration to a value consistent with the dependency (`edition = "2024"`, Rust ≥ 1.85); supply the missing `src/Makevars.win.in` so Windows configure no longer selects a nonexistent template; make source-archive hygiene correct (exclude `planning/` and `docs/`, keep the lockfile); and author a 3-OS CI matrix as the mechanism that actually validates the macOS and Windows legs, which cannot be built on this Linux host. Vendoring stays deferred, with the online-build requirement documented. This phase does not change Rust runtime behavior, hardening/atomicity, live-network evidence, integrations, or release publication.

### In scope

- Pin `hf-xet` to the crates.io release `1.7.0` in `src/rust/Cargo.toml`.
- Track and ship `src/rust/Cargo.lock` (remove the `.gitignore` and `.Rbuildignore` exclusions).
- Correct the Rust MSRV: `Cargo.toml` `rust-version = '1.85'` and `DESCRIPTION` `SystemRequirements: … rustc >= 1.85.0` (D3).
- Author `src/Makevars.win.in` and add a clear missing-template guard to `tools/config.R` (D4).
- Add a `.github/workflows` build/check matrix for ubuntu/macos/windows as the platform-validation gate (D5, D9).
- Source-archive hygiene: exclude `^planning$` and `^docs$` from the source tarball; delete the stray tracked `.gitiginore` (D7).
- Document the online-build requirement in the user-facing install docs (source install needs network access to crates.io and a Rust ≥ 1.85 toolchain) and correct the stale "from git" build note in `AGENTS.md` (D6).
- Read-only verification that the pinned `hf-xet` honors the `HF_XET_*` variables `xet_config_environment()` sets (D8).
- Verify, from a clean scratch copy, that the source archive builds/installs/checks on Linux, contains the lockfile and Windows template, excludes `planning/`/`docs/` and all build products, and resolves no git dependency.

### Out of scope / explicit deferrals

- **Vendoring / offline builds** — deferred (D6). Phase 3 documents that source installation requires network access to crates.io; produces no vendor archive. (Phase 7 / CRAN prep.)
- **macOS and Windows build execution on this host** — impossible here. The CI matrix is the platform gate; a green macOS/Windows run is validated only after the user pushes (D9). Recorded as an explicit deferral.
- **Rust behavior, mutex-held I/O, atomic download, size/offset validation, `Drop` cleanup** — Phase 4.
- **Live Xet success evidence, byte-integrity, upload/auth/commit semantics** — Phase 5.
- **Arrow/terra/sf/connection memory & I/O proof** — Phase 6.
- **CRAN submission, release notes, final release-diff review, publication** — Phase 7.
- **R minimum version changes** — `R (>= 4.2)` is retained; no inspected dependency requires higher. Not reopened here.
- **Editing `src/rust/src/lib.rs`, `R/**`, `man/**`, `NAMESPACE`, tests, README, or behavior.**

### Verbatim user constraints (Phase 3 planning interview, 2026-10-15)

> Use the crates.io release `hf-xet = "1.7.0"`.

> Commit and ship `src/rust/Cargo.lock`.

> Bump MSRV to 1.85 (no separate MSRV-verification task).

> Repair the Windows template.

> Add 3-OS build/check CI.

> Defer vendoring; document the online-build requirement.

> Exclude `planning/` and `docs/` from the archive; remove `.gitiginore`.

> Include a read-only `HF_XET_*` env-var verification.

> CI is the platform gate; record the macOS/Windows deferral.

Carried from Phase 1 (`STATE_1.md`) / Phase 2: preserve all 13 exports; do not remove built functionality; routine tests stay offline/secret-free; no credentials in public CI; pin hf-xet; vendoring is later work; do not overwrite the user's `rxet.Rcheck/` or `rxet_0.1.0.tar.gz`.

## Recon log (facts from repository, 2026-10-15)

- Branch `main`; HEAD `99596b2` (Phase 2 ADR commit). Only untracked state: `rxet.Rcheck/` and `rxet_0.1.0.tar.gz` (user artifacts — do not overwrite/delete). `src/entrypoint.o` and `src/rxet.so` exist and are gitignored build products.
- `src/rust/Cargo.toml`: `rust-version = '1.70'`; `hf-xet = { git = "https://github.com/huggingface/xet-core.git" }` (no rev). `[lib] crate-type = ['rlib','staticlib']`.
- `src/rust/Cargo.lock` is present in the working tree (77 KB, untracked) and resolves `hf-xet 1.7.0` to `git+https://github.com/huggingface/xet-core.git#e922f742…` — **not** the `v1.7.0` tag (`4b485713…`). It is excluded by `.gitignore` (`src/rust/Cargo.lock` and bare `Cargo.lock`) and `.Rbuildignore` (`^src/rust/Cargo\.lock$`).
- **hf-xet is published on crates.io**, latest/default `1.7.0` (published 2026-10-06, checksummed). `docs.rs` confirms the required public surface exists in that release: `xet::xet_session::{XetSession, XetSessionBuilder, XetFileInfo, Sha256Policy, …}`. `docs.rs` shows its manifest `edition = "2024"`.
- hf-xet v1.7.0 workspace `Cargo.toml` sets `edition = "2024"` → minimum Rust **1.85**. No `rust-toolchain.toml` in xet-core. Local toolchain: rustc/cargo `1.96.0-nightly`; R 4.6.1.
- hf-xet config reads env vars as `HF_XET_{GROUP_NAME}_{FIELD_NAME}` and honors `HF_XET_HIGH_PERFORMANCE` / `HF_XET_HP` (`XetConfig::new` applies them before `with_env_overrides`). `R/client.R:105–111` sets `HF_XET_CLIENT_READ_TIMEOUT`, `HF_XET_CHUNK_CACHE_SIZE_BYTES`, `HF_XET_HIGH_PERFORMANCE`.
- `tools/config.R:74–88` selects `src/Makevars.win.in` on Windows. **No `src/Makevars.win.in` exists** anywhere in tracked history. `readLines(mv_fp)` fails opaquely when the template is missing.
- Reference implementation for the Windows template: `/home/andrew/workspace/roxigdal/src/Makevars.win.in` (same rextendr layout; `TARGET = …-pc-windows-gnu`, `libgcc_mock`, `-lws2_32 -ladvapi32 -luserenv -lbcrypt -lntdll`). Local copy of `tools/config.R`/`msrv.R` also exists there.
- `.github/` does not exist; no CI at all. `.Rbuildignore` already excludes `^\.github$`.
- `.Rbuildignore` has **no** `^planning$` or `^docs$` entry, so `planning/` (17 entries) and `docs/decisions/` currently ship in the source archive (recorded in `STATE_2.md` 2.2.1). A stray tracked `.gitiginore` (typo; 3 lines) is committed.
- Tracked files include `src/Makevars` (generated from the template by `configure`); `configure`/`configure.win` call `tools/config.R`. Both are `chmod +x`.
- Phase 2 baseline: `R CMD build .` + `_R_CHECK_FORCE_SUGGESTS_=false R CMD check --no-manual` → **Status: OK** (0 ERROR/WARNING/NOTE); suite `FAIL 0 | SKIP 11 | PASS 111`.
- `python3` + PyYAML are available (CI YAML validation). `actionlint` is not. `rg` is unavailable — use `grep`/`grep -E`.

### Baseline status before wave 1

Linux build/install/check and the test suite are green as of Phase 2. The dependency graph is unpinned and the lockfile is unshipped, the MSRV declaration (1.70) is invalid for the dependency, the Windows template is missing, and there is no CI. This plan's tasks fix those; the substantive macOS/Windows build validation is the CI matrix (deferred to the first push). Do not claim macOS/Windows are validated on this host.

## Decisions recorded

| Date | Decision | Rationale / consequence |
|---|---|---|
| 2026-10-15 | D1: Pin `hf-xet` to crates.io `"1.7.0"` (drop the git dependency). | User choice. Immutable, checksummed, and vendoring-friendly; the required `xet::xet_session` API is present in the published 1.7.0. |
| 2026-10-15 | D2: Commit and ship `src/rust/Cargo.lock`. | User choice. Fixes the full transitive graph at install time; removes the `.gitignore` + `.Rbuildignore` exclusions. |
| 2026-10-15 | D3: MSRV `1.85` in `Cargo.toml` + `DESCRIPTION`. | `hf-xet` 1.7.0 is `edition = "2024"` (≥ 1.85); the declared 1.70 was invalid. No separate MSRV-verification task (user). |
| 2026-10-15 | D4: Author `src/Makevars.win.in` and guard `tools/config.R`. | Windows is in scope (Phase 1); configure must not select a missing template. Actual Windows execution is deferred to CI. |
| 2026-10-15 | D5: Add a 3-OS `.github/workflows` build/check matrix. | User choice. CI is the only place macOS/Windows builds can run. |
| 2026-10-15 | D6: Defer vendoring; document the online-build requirement. | Matches Phase 1 ("vendoring is not the first thing"). No vendor archive in Phase 3; `3.1.5` records the online-build requirement in the install docs. |
| 2026-10-15 | D7: Exclude `^planning$` and `^docs$` from the source archive; delete `.gitiginore`. | User choice. Planning/ADR material is workflow, not package content; the typo file is dead. |
| 2026-10-15 | D8: Include read-only `HF_XET_*` env-var verification. | Phase 1 handoff item; confirms `xet_config_environment()` affects the pinned crate, without behavior change. |
| 2026-10-15 | D9: CI is the platform gate; record the macOS/Windows deferral. | No local macOS/Windows host. Local gate = Linux build/install/check + template parity + workflow authored; the matrix runs on first user push and is recorded as an explicit deferral. |

## Wave table

| Wave | Task | Goal | Depends on |
|---|---|---|---|
| 1 | `3.1.1.hf-xet-pin` | Pin `hf-xet` to crates.io 1.7.0, bump MSRV to 1.85, regenerate + untrack the lockfile. | None |
| 1 | `3.1.2.archive-hygiene` | Exclude `planning/`+`docs/`, ship the lockfile, delete `.gitiginore`. | None |
| 1 | `3.1.3.windows-template` | Add `src/Makevars.win.in` and a clear missing-template guard in `tools/config.R`. | None |
| 1 | `3.1.4.ci-matrix` | Author the 3-OS build/check workflow. | None |
| 1 | `3.1.5.online-build-docs` | Document the online-build requirement and fix the stale `AGENTS.md` build note. | None |
| 2 | `3.2.1.env-var-check` | Read-only: confirm the pinned crate honors the `HF_XET_*` vars `xet_config_environment()` sets. | `3.1.1` |
| 3 | `3.3.1.build-verify` | Clean source-archive build/install/check + tarball/template/lockfile verification; record the platform deferral. | `3.1.1`, `3.1.2`, `3.1.3`, `3.1.4`, `3.1.5`, `3.2.1` |

**Disjointness:** Wave-1 file scopes — `3.1.1`: `src/rust/Cargo.toml`, `src/rust/Cargo.lock`, `.gitignore`, `DESCRIPTION`; `3.1.2`: `.Rbuildignore`, `.gitiginore` (delete); `3.1.3`: `src/Makevars.win.in` (new), `tools/config.R`; `3.1.4`: `.github/workflows/**` (new); `3.1.5`: `README.Rmd`, `README.md` (regenerated), `AGENTS.md`. No two wave-1 tasks share a file.

**Worktree isolation:** Wave-1 tasks run in per-task git worktrees (or strictly sequential application) because `3.1.3`'s acceptance runs `tools/config.R`, which reads `DESCRIPTION`, while `3.1.1` edits `DESCRIPTION`. The file scopes are still pairwise-disjoint, so a shared worktree would not corrupt any file, but per-task worktrees are the required default for this plan.

**Cross-task coupling (read before executing Wave 1):** `3.1.1` makes the lockfile trackable by editing `.gitignore`; `3.1.2` makes it shippable by removing its `.Rbuildignore` line. They are in different files, so they never write the same file, but both are required for the lockfile to reach the archive. Neither task alone achieves D2.

## Task specifications

### Task 3.1.1 — hf-xet pin and lockfile tracking

- **ID:** `3.1.1.hf-xet-pin`
- **Repo:** `/home/andrew/workspace/rxet`
- **Depends on:** None
- **Files in scope:**
  - Must edit: `src/rust/Cargo.toml`, `src/rust/Cargo.lock` (regenerated), `.gitignore`; `DESCRIPTION` (one line).
  - Can create: `planning/tasks/3.1.1.hf-xet-pin.todo.md`; scratch under `planning/.development/` or `/tmp/opencode/`.
  - Do not edit: `R/**`, `man/**`, `NAMESPACE`, `tests/**`, `.Rbuildignore`, `tools/**`, `src/Makevars*`, `src/rust/src/lib.rs`, `.github/**`, or the user's `rxet.Rcheck/`/`rxet_0.1.0.tar.gz`.
- **Spec:**
  1. In `src/rust/Cargo.toml`, replace `hf-xet = { git = "https://github.com/huggingface/xet-core.git" }` with `hf-xet = "1.7.0"`. Leave all other dependencies unchanged.
  2. Change `rust-version = '1.70'` to `rust-version = '1.85'`.
  3. In `DESCRIPTION`, change `SystemRequirements: Cargo (Rust's package manager), rustc >= 1.70.0` to `…, rustc >= 1.85.0`.
  4. Regenerate the lockfile against crates.io: `cd src/rust && cargo update -p hf-xet` (or `cargo generate-lockfile` if needed). Confirm `Cargo.lock` now shows `hf-xet` version `1.7.0` with `source = "registry+https://github.com/rust-lang/crates.io-index"` and no `git+https://github.com/huggingface/xet-core` entry anywhere.
  5. In `.gitignore`, delete the `src/rust/Cargo.lock` line and the bare `Cargo.lock` line so the lockfile is trackable. Keep `src/rust/target/`, `.cargo/`, `*.o`, `*.so`, `*.a`.
  6. Verify the pinned graph compiles: `cd src/rust && cargo check`.

  **Micro-plan budget (≤12 steps):** group as: (1) `Cargo.toml` dependency swap, (2) `rust-version` bump, (3) `DESCRIPTION` MSRV, (4) regenerate lockfile, (5) confirm registry source, (6) `.gitignore` edits, (7) `cargo check`, (8) targeted validation. If you cannot fit the work in twelve steps, stop and report the overflow.
- **Grep anchors / references:** `src/rust/Cargo.toml` (`hf-xet`, `rust-version`); `src/rust/Cargo.lock` (`name = "hf-xet"`, `git+https://github.com/huggingface`); `.gitignore` (lines 5 and 11); `DESCRIPTION:14`; `docs.rs/hf-xet/1.7.0` (API present); `tools/msrv.R:92–111` (MSRV compare uses `DESCRIPTION`).
- **Constraints ("do not touch"):** no Rust source changes; do not alter other deps; do not edit `.Rbuildignore` (that is `3.1.2`); keep all 13 exports.
- **Acceptance:** `Cargo.toml` has no git `hf-xet` and declares `rust-version = '1.85'`; `Cargo.lock` pins `hf-xet 1.7.0` from the crates.io registry with no git source; `git check-ignore -q src/rust/Cargo.lock` is false; `DESCRIPTION` declares `rustc >= 1.85.0`; `cargo check` succeeds.
- **Targeted command:** `cd src/rust && cargo check && cd ../.. && ! grep -q 'git = "https://github.com/huggingface/xet-core' src/rust/Cargo.toml && grep -q "rust-version = '1.85'" src/rust/Cargo.toml && ! grep -q 'git+https://github.com/huggingface/xet-core' src/rust/Cargo.lock && grep -A1 'name = "hf-xet"' src/rust/Cargo.lock | grep -q 'version = "1.7.0"' && grep -A2 'name = "hf-xet"' src/rust/Cargo.lock | grep -q 'crates.io-index' && ! git check-ignore -q src/rust/Cargo.lock && grep -q 'rustc >= 1.85.0' DESCRIPTION`

### Task 3.1.2 — Source-archive hygiene

- **ID:** `3.1.2.archive-hygiene`
- **Repo:** `/home/andrew/workspace/rxet`
- **Depends on:** None
- **Files in scope:**
  - Must edit: `.Rbuildignore`.
  - Must delete: `.gitiginore` (`git rm .gitiginore`).
  - Can create: `planning/tasks/3.1.2.archive-hygiene.todo.md`; scratch under `/tmp/opencode/`.
  - Do not edit: `.gitignore`, `src/**`, `R/**`, `DESCRIPTION`, `tools/**`, `.github/**`, `docs/**`, `planning/**` (other than the todo), or user artifacts.
- **Spec:**
  1. In `.Rbuildignore`, remove the `^src/rust/Cargo\.lock$` line so the lockfile ships in the source archive.
  2. Add `^planning$` and `^docs$` so planning artifacts and ADRs are excluded from the source tarball.
  3. Keep the existing `^src/rust/target$`, `^src/rust/vendor$`, and `^src/\.cargo$` entries (build products must stay excluded).
  4. Delete the stray tracked `.gitiginore` (a typo for `.gitignore`; its three lines are already covered: `cran-comments.md` and `TODO.md` are in `.Rbuildignore`, and `scratch/` does not exist): `git rm .gitiginore`.

  **Micro-plan budget (≤12 steps):** (1) remove the lockfile exclusion, (2) add `^planning$`, (3) add `^docs$`, (4) confirm build-product exclusions remain, (5) `git rm .gitiginore`, (6) targeted validation.
- **Grep anchors / references:** `.Rbuildignore` (line 6 `^src/rust/Cargo\.lock$`, lines 3–5, and end); `git ls-files` shows `.gitiginore`; `.gitiginore` content (`cran-comments.md`, `TODO.md`, `scratch/`).
- **Constraints ("do not touch"):** no source/doc changes; do not remove the target/vendor/.cargo exclusions; do not add broad patterns that could drop needed files.
- **Acceptance:** `.Rbuildignore` contains no `Cargo\.lock` entry and contains exact lines `^planning$` and `^docs$`; `.gitiginore` no longer exists.
- **Targeted command:** `! grep -Fq 'Cargo\.lock' .Rbuildignore && grep -Fqx '^planning$' .Rbuildignore && grep -Fqx '^docs$' .Rbuildignore && test ! -e .gitiginore`

### Task 3.1.3 — Windows build template and configure guard

- **ID:** `3.1.3.windows-template`
- **Repo:** `/home/andrew/workspace/rxet`
- **Depends on:** None
- **Files in scope:**
  - Must create: `src/Makevars.win.in`.
  - Must edit: `tools/config.R` (add a missing-template guard only).
  - Can create: `planning/tasks/3.1.3.windows-template.todo.md`; scratch under `/tmp/opencode/`.
  - Do not edit: `src/Makevars.in`, `src/Makevars`, `src/rust/**`, `tools/msrv.R`, `configure`, `configure.win`, `.Rbuildignore`, `DESCRIPTION`, or user artifacts.
- **Spec:**
  1. Create `src/Makevars.win.in` modeled on `/home/andrew/workspace/roxigdal/src/Makevars.win.in`, adapted for `rxet`: `TARGET = $(subst 64,x86_64,$(subst 32,i686,$(WIN)))-pc-windows-gnu`; `TARGET_DIR = ./rust/target`; `LIBDIR = $(TARGET_DIR)/$(TARGET)/@LIBDIR@`; `STATLIB = $(LIBDIR)/librxet.a`; `PKG_LIBS = -L$(LIBDIR) -lrxet -lws2_32 -ladvapi32 -luserenv -lbcrypt -lntdll`. Keep the `libgcc_mock` creation step and the placeholder tokens `tools/config.R` substitutes and that are meaningful on Windows: `@LIBDIR@`, `@PROFILE@`, `@CRAN_FLAGS@`, `@CLEAN_TARGET@`. (`@TARGET@`/`@PANIC_EXPORTS@` are optional: the target triple is a make-level `$(TARGET)` used for `--target`, and `tools/config.R`'s `gsub` is a harmless no-op for a token the template omits. The roxigdal reference omits both.) **Do not** add a `cargo run --bin document` step — `rxet` has no `document` binary (wrappers are hand-maintained in `src/rust/src/lib.rs` + `R/extendr-wrappers.R`).
  2. In `tools/config.R`, immediately before `mv_txt <- readLines(mv_fp)` (around line 97), insert a guard: if `!file.exists(mv_fp)`, `stop()` with a message naming the missing template and the detected platform (Windows vs. Unix), instead of the opaque `cannot open the connection` from `readLines`.
  3. Confirm the Linux path is unaffected: `Rscript -e 'source("tools/config.R")'` regenerates `src/Makevars`; assert it is unchanged.

  **Micro-plan budget (≤12 steps):** (1) study the roxigdal reference and `src/Makevars.in`, (2) author `src/Makevars.win.in`, (3) add the `tools/config.R` guard, (4) regenerate `src/Makevars` on Linux, (5) targeted validation. If you cannot fit the work in twelve steps, stop and report the overflow.
- **Grep anchors / references:** `tools/config.R:74–97` (`is_windows`, `mv_fp`, `readLines`); `src/Makevars.in` (placeholder contract, `librxet.a`); `/home/andrew/workspace/roxigdal/src/Makevars.win.in` (reference); `configure.win`; `src/rust/Cargo.toml` (`[lib] name = 'rxet'`).
- **Constraints ("do not touch"):** do not modify the Unix `Makevars.in`/`Makevars`; do not change `configure`/`configure.win`; do not add rust build steps (`document`) that do not exist for `rxet`.
- **Acceptance:** `src/Makevars.win.in` exists with the Windows target, `librxet.a`, the `ws2_32`/sys-lib linker flags, and the required `@…@` placeholders (`@LIBDIR@`, `@PROFILE@`, `@CRAN_FLAGS@`, `@CLEAN_TARGET@`), and no `bin document` step; `tools/config.R` contains a `file.exists(mv_fp)` guard; sourcing `tools/config.R` on Linux succeeds and leaves `src/Makevars` byte-identical.
- **Targeted command:** `test -f src/Makevars.win.in && grep -q 'librxet.a' src/Makevars.win.in && grep -q 'pc-windows-gnu' src/Makevars.win.in && grep -q '@LIBDIR@' src/Makevars.win.in && grep -q '@PROFILE@' src/Makevars.win.in && grep -q 'ws2_32' src/Makevars.win.in && ! grep -q 'bin document' src/Makevars.win.in && grep -q 'file.exists(mv_fp)' tools/config.R && Rscript -e 'source("tools/config.R")' && git diff --exit-code -- src/Makevars`

### Task 3.1.4 — CI build/check matrix

- **ID:** `3.1.4.ci-matrix`
- **Repo:** `/home/andrew/workspace/rxet`
- **Depends on:** None
- **Files in scope:**
  - Must create: `.github/workflows/R-CMD-check.yaml`.
  - Can create: `planning/tasks/3.1.4.ci-matrix.todo.md`; scratch under `/tmp/opencode/`.
  - Do not edit: any existing tracked file (this task adds a workflow only), or user artifacts.
- **Spec:**
  1. Create `.github/workflows/R-CMD-check.yaml` (a workflow file only; no other `.github` content required).
  2. Define a `matrix` with `os: [ubuntu-latest, macos-latest, windows-latest]` and a single `r-version: [release]`.
  3. Steps (secret-free, no live/credentialed tests): `actions/checkout@v4`; `r-lib/actions/setup-r@v2`; `r-lib/actions/setup-r-dependencies@v2` with `dependencies: '"hard"'`; install the stable Rust toolchain (`dtolnay/rust-toolchain@stable`) — the CI MSRV target is the declared `1.85` floor at minimum, stable is acceptable; build with `R CMD build .`; check with `_R_CHECK_FORCE_SUGGESTS_=false R CMD check --no-manual *.tar.gz`.
  4. Follow `[[github-actions-ci]]` for the workflow shape and the rextendr Rust+R pattern. Do **not** reference any secret, `HF_TOKEN`, or live Xet endpoint.
  5. Trigger on `push` and `pull_request` to `main` (and `workflow_dispatch`).

  **Micro-plan budget (≤12 steps):** (1) review `[[github-actions-ci]]` + the rextendr pattern, (2) author the workflow, (3) validate YAML + OS values + no secrets. If you cannot fit the work in twelve steps, stop and report the overflow.
- **Grep anchors / references:** `.Rbuildignore:2` (`^\.github$` already excludes CI from the archive); `github-actions-ci` skill; `AGENTS.md` build commands (`R CMD build .`, `R CMD check`); `DESCRIPTION:14` (MSRV).
- **Constraints ("do not touch"):** do not modify `DESCRIPTION`/`Cargo.toml`/`.Rbuildignore`; no secrets; no live tests; do not add pkgdown/coverage jobs.
- **Acceptance:** the workflow file exists and is valid YAML (parses with PyYAML), lists all three OS values, and contains no secret/credential references. (Execution is CI-side; this task only authors the workflow.)
- **Targeted command:** `test -f .github/workflows/R-CMD-check.yaml && python3 -c 'import yaml,sys; yaml.safe_load(open(".github/workflows/R-CMD-check.yaml"))' && grep -q 'ubuntu-latest' .github/workflows/R-CMD-check.yaml && grep -q 'macos-latest' .github/workflows/R-CMD-check.yaml && grep -q 'windows-latest' .github/workflows/R-CMD-check.yaml && ! grep -nEi 'secrets\.|HF_TOKEN|huggingface\.co' .github/workflows/R-CMD-check.yaml`

### Task 3.1.5 — Online-build documentation

- **ID:** `3.1.5.online-build-docs`
- **Repo:** `/home/andrew/workspace/rxet`
- **Depends on:** None
- **Files in scope:**
  - Must edit: `README.Rmd`, `README.md` (regenerated), `AGENTS.md`.
  - Can create: `planning/tasks/3.1.5.online-build-docs.todo.md`; scratch under `/tmp/opencode/`.
  - Do not edit: `R/**`, `man/**`, `NAMESPACE`, `DESCRIPTION`, `src/**`, `tools/**`, `.Rbuildignore`, `.gitignore`, `.github/**`, or user artifacts.
- **Spec:**
  1. In `README.Rmd`, in the Installation section, add a short factual prerequisite: building from source compiles the Rust `hf-xet` client and downloads crates from crates.io, so it requires network access and a Rust toolchain (≥ 1.85). Make no performance or capability claims.
  2. Regenerate `README.md` with `rmarkdown::render("README.Rmd", quiet = TRUE)` and remove the generated `README.html`; keep `README.Rmd` and `README.md` consistent.
  3. In `AGENTS.md`, correct the "First Build (Slow)" note that says dependencies are downloaded "from git" — the `hf-xet` dependency is now the crates.io `1.7.0` release, and source builds require network access to crates.io. Do not change other guidance, build/test commands, or the architecture description.
- **Grep anchors / references:** `README.Rmd`/`README.md` Installation section; `AGENTS.md` "First Build (Slow)" and "Dependency Issues" notes; the D1/D6 decisions.
- **Constraints ("do not touch"):** no behavior/code changes; no new claims; keep the two README files consistent; do not touch the Phase 2 claim corrections.
- **Acceptance:** both `README.md` and `README.Rmd` state the source-build network/Rust-toolchain requirement; `README.md` is freshly rendered from `README.Rmd` (no unexpected diff); `AGENTS.md` no longer says `hf-xet` is fetched from git.
- **Targeted command:** `Rscript -e 'rmarkdown::render("README.Rmd", quiet = TRUE)' && rm -f README.html && git diff --check -- README.md README.Rmd && grep -qiE 'crates\.io|network access' README.md && grep -qiE 'crates\.io|network access' README.Rmd && ! grep -q 'transitive deps from git' AGENTS.md`

### Task 3.2.1 — Pinned-crate `HF_XET_*` env-var verification (read-only)

- **ID:** `3.2.1.env-var-check`
- **Repo:** `/home/andrew/workspace/rxet`
- **Depends on:** `3.1.1`
- **Files in scope:**
  - Must edit: `planning/STATE_3.md` (append report only).
  - Can create: `planning/tasks/3.2.1.env-var-check.todo.md`; scratch under `/tmp/opencode/`.
  - Do not edit: any package/source/test/doc/config file. This is a read-only investigation.
- **Spec:**
  1. Fetch the pinned crate sources: `cd src/rust && cargo fetch`. Locate `${CARGO_HOME:-$HOME/.cargo}/registry/src/*/hf-xet-1.7.0/src/`.
  2. Confirm the config-derived env-var contract: `XetConfig` applies overrides named `HF_XET_{GROUP_NAME}_{FIELD_NAME}` and honors `HF_XET_HIGH_PERFORMANCE` / `HF_XET_HP` (docs.rs `XetConfig`). Verify in the fetched source that the specific fields exist so that `HF_XET_CLIENT_READ_TIMEOUT` maps to `client.read_timeout` and `HF_XET_CHUNK_CACHE_SIZE_BYTES` maps to `chunk_cache.size_bytes` (adjust if the real field/group names differ).
  3. Record, per variable (`HF_XET_CLIENT_READ_TIMEOUT`, `HF_XET_CHUNK_CACHE_SIZE_BYTES`, `HF_XET_HIGH_PERFORMANCE`), whether it is honored, with `file:line` evidence, in the `3.2.1` report in `STATE_3.md`.
  4. If any variable is **not** honored, record it as a finding for Phase 7 / README correction (do **not** change `R/client.R` or docs here).

  **Micro-plan budget (≤12 steps):** (1) `cargo fetch`, (2) locate the pinned source, (3) confirm the `HF_XET_{GROUP}_{FIELD}` contract, (4) check each of the three variables, (5) record the report. If you cannot fit the work in twelve steps, stop and report the overflow.
- **Grep anchors / references:** `R/client.R:100–113` (`xet_config_environment`); docs.rs `hf-xet/1.7.0` `XetConfig` (`with_env_overrides`, `HF_XET_{GROUP}_{FIELD}`, `HF_XET_HIGH_PERFORMANCE`/`HF_XET_HP`); fetched crate `src/` under `$CARGO_HOME/registry/src/*/hf-xet-1.7.0/`.
- **Constraints ("do not touch"):** read-only; no code, test, doc, or config changes; evidence must cite the pinned 1.7.0 source, not memory.
- **Acceptance:** the `STATE_3.md` report states, with `file:line` evidence from the fetched `hf-xet-1.7.0` source, whether each of the three variables `xet_config_environment()` sets is honored; any mismatch is recorded as a downstream finding.
- **Targeted command:** `cd src/rust && cargo fetch && REG="${CARGO_HOME:-$HOME/.cargo}/registry/src" && ls "$REG"/*/hf-xet-1.7.0 >/dev/null && grep -rEn 'HF_XET_|read_timeout|size_bytes|with_env_overrides' "$REG"/*/hf-xet-1.7.0/src | grep -Ei 'HF_XET_|read_timeout|size_bytes|env_overrides' | head -40`

### Task 3.3.1 — Phase 3 build/platform verification (orchestrator gate)

- **ID:** `3.3.1.build-verify`
- **Repo:** `/home/andrew/workspace/rxet`
- **Depends on:** `3.1.1`, `3.1.2`, `3.1.3`, `3.1.4`, `3.1.5`, `3.2.1`
- **Files in scope:**
  - Must edit: `planning/STATE_3.md` (append report/status); `planning/MASTER_PLAN.md` (record the macOS/Windows deferral only).
  - Can create: `planning/tasks/3.3.1.build-verify.todo.md`; scratch under `/tmp/opencode/` only.
  - Do not edit: package source, docs, metadata, config, tests — read-only except to report. If a defect is found, report it; do not fix it in this task.
- **Spec:**
  1. From a scratch copy (protecting the user's `rxet.Rcheck/`/`rxet_0.1.0.tar.gz`), run `R CMD build .` then `_R_CHECK_FORCE_SUGGESTS_=false R CMD check --no-manual rxet_0.1.0.tar.gz`. Confirm **Status: OK** (0 ERROR/WARNING/NOTE) and that the suite runs (`FAIL 0 | SKIP ≤11 | PASS 111`).
  2. Inspect the tarball contents: `src/rust/Cargo.lock` present; `src/Makevars.win.in` present; `planning/` absent; `docs/` absent; no `src/rust/target/`, `src/.cargo/`, `vendor/`, `*.o`, `*.so` inside.
  3. Confirm no git dependency remains: `! grep -q 'git+https://github.com/huggingface/xet-core' src/rust/Cargo.lock`; confirm `hf-xet 1.7.0` from the crates.io registry.
  4. Confirm declaration consistency: `Cargo.toml` `rust-version = '1.85'` and `DESCRIPTION` `rustc >= 1.85.0` agree. Note that the `R CMD build`/`check` run exercises `tools/msrv.R` (via `configure`), which parses these declarations and compares them to the installed toolchain — this is the indirect validation of MSRV parsing.
  5. Confirm the CI workflow exists and parses. Record that **macOS/Windows execution is the CI matrix gate and is pending the first user push** (explicit deferral, D9) — in BOTH `STATE_3.md` and a short `planning/MASTER_PLAN.md` Phase 3 note (master plan rule 30 requires the deferral in the phase state and the master plan). Do not claim those platforms are validated locally.
  6. Record exact commands and observed output in `STATE_3.md`; list any residual finding and its owning later phase.
- **Grep anchors / references:** `planning/MASTER_PLAN.md` Phase 3 exit gate; this plan's Decisions; `AGENTS.md` build commands; `src/Makevars.in`; `src/Makevars.win.in`; `.Rbuildignore`.
- **Constraints ("do not touch"):** do not modify package files; do not delete/overwrite the user's untracked `rxet.Rcheck/`/`rxet_0.1.0.tar.gz`; run build/check in scratch.
- **Acceptance:** recorded evidence shows Linux `R CMD build`/`R CMD check` OK, tarball contents correct (lockfile + Windows template present; `planning/`/`docs/`/build products absent), crates.io pin confirmed, MSRV declarations consistent, CI workflow present, and the macOS/Windows deferral explicitly noted.
- **Targeted command (run from scratch, e.g. `SCRATCH=/tmp/opencode/rxet-plan3; rm -rf "$SCRATCH"; mkdir -p "$SCRATCH"; cp -r . "$SCRATCH/src"` then operate in `"$SCRATCH/src"`):** `R CMD build . && _R_CHECK_FORCE_SUGGESTS_=false R CMD check --no-manual rxet_0.1.0.tar.gz && tar tzf rxet_0.1.0.tar.gz | grep -q 'src/rust/Cargo.lock' && tar tzf rxet_0.1.0.tar.gz | grep -q 'src/Makevars.win.in' && ! tar tzf rxet_0.1.0.tar.gz | grep -qE 'planning/|docs/|src/rust/target/|rxet\.so|\.o$' && ! grep -q 'git+https://github.com/huggingface/xet-core' src/rust/Cargo.lock`. This task is executed by the **orchestrator** (serial acceptance gate, not delegated to a cheap worker).

## Hazard notes

- **crates.io API drift risk:** the pinned 1.7.0 is a different revision from the git commit currently in the working `Cargo.lock` (`e922f742…`). `cargo check` in `3.1.1` is the guard; if it fails on an API difference, **stop and report** — do not patch `src/rust/src/lib.rs` in this phase (Rust behavior is Phase 4/5 scope).
- **First build after the dependency switch is slow** (full re-resolve + recompile of ~300 crates). This is expected; do not treat a long build as a hang.
- **`.gitignore` + `.Rbuildignore` coupling:** the lockfile only ships if both edits land (`3.1.1` untracks it, `3.1.2` un-excludes it). `3.3.1` verifies the combined result.
- **Do not weaken build-product exclusions** in `.Rbuildignore` (`^src/rust/target$`, `^src/\.cargo$`, `^src/rust/vendor$`). The source archive must not carry `target/`, `*.o`, `*.so`, or `.cargo/`.
- **`source("tools/config.R")` rewrites the tracked `src/Makevars`.** It is idempotent on Linux given unchanged inputs; assert `git diff --exit-code -- src/Makevars`. Do not hand-edit `src/Makevars`.
- **Windows can't be built here.** The template is validated statically (target triple, link flags, placeholders); real execution is the CI matrix. Do not claim a Windows build from static inspection.
- **CI cannot be run locally.** `3.1.4` authors the workflow and validates YAML only; green CI is a post-push event (D9).
- **`HF_XET_*` names are an assumption to verify, not a fact to assert.** `3.2.1` must cite the pinned 1.7.0 source; if a name is wrong, record it (Phase 7/README) rather than editing `R/client.R`.
- **No `rg`** in this environment; use `grep`/`grep -E`. `python3` + PyYAML available; `actionlint` is not.
- **Do not overwrite user artifacts**: `rxet.Rcheck/` and `rxet_0.1.0.tar.gz` are untracked user state; run any build/check in a scratch directory (`/tmp/opencode/...`).
- **Do not edit ADRs** (`docs/decisions/`). This phase's decisions go in `EXECUTION_PLAN_3.md`/`STATE_3.md`; enduring ADRs are a separate concern.

## Escalation and execution policy

Standard wave-orchestration ladder applies. Wave-1 workers run only their targeted commands microplan-gated by the orchestrator. `3.2.1` is a read-only worker task in Wave 2. `3.3.1.build-verify` is the serial acceptance gate and is executed by the **orchestrator** (not delegated to a cheap worker). One conventional-format, one-sentence commit per task (no orchestration/wave numbers), per `[[git-workflow-standards]]`. Verification must not silently fix defects; it reports back for orchestrator triage.

## Approval gate

**Approved by the user on 2026-10-15.** Approval authorizes Phase 3 planning-task orchestration only: dependency pinning + lockfile policy, MSRV declaration, Windows build template, source-archive hygiene, CI workflow authoring, and read-only env-var verification. It does **not** authorize Rust behavior changes, vendoring, CRAN submission, live-network testing, or release publication. Workers remain subject to the per-task micro-plan approval gate.
