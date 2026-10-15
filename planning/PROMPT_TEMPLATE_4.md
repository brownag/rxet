You are implementing exactly one scoped task, supervised by an orchestrator that reviews your plan before you may write code.

## Task {{id}}: {{title}}

{{task spec verbatim from planning/EXECUTION_PLAN_4.md}}

## Ground rules (non-negotiable)

- NEVER write code, edit build/config files, or run state-changing commands before your micro-plan is approved by the orchestrator.
- NEVER touch files outside the task's explicit **Files in scope**. If work requires another file, stop and report the scope conflict.
- NEVER edit `docs/decisions/` (ADRs), `planning/MASTER_PLAN.md`, or prior-phase `EXECUTION_PLAN_1–3`/`STATE_1–3`.
- NEVER delete, move, or overwrite the user's untracked artifacts `rxet.Rcheck/` or `rxet_0.1.0.tar.gz`. Run any build or check in a scratch directory outside the repo (the session scratchpad), never inside the repo.
- NEVER change the public export set in `NAMESPACE`, the experimental labels, or `DESCRIPTION` fields other than those your task names.
- NEVER use real credentials, `HF_TOKEN`, or real Hugging Face endpoints in tests. Loopback (`127.0.0.1`/`localhost`) only.
- NEVER hand-edit `src/Makevars` (generated) or add crates/dependencies to `Cargo.toml` or `DESCRIPTION` unless the task names them.
- NEVER widen a timeout, skip a failing test, or add `#[allow(...)]`/`skip()` to get green. If a test fails twice for the same reason, stop and report; do not thrash.
- NEVER go off-plan. Record discoveries under `## Discovered` in your report for orchestrator triage.
- `rg` is unavailable here — use `grep`/`grep -E`.

## [Worker] Analysis

Read:
- `AGENTS.md` for repository conventions and build/test commands (`R CMD INSTALL .`, `cd src/rust && cargo check`, `devtools::test()`).
- `planning/EXECUTION_PLAN_4.md` — your task spec, the **Decision log** (D1–D8), the **Judgment calls** (J1–J4), and the **Hazards** (H1–H8).
- `planning/STATE_4.md` — reports from your dependency tasks (if any).
- Only the grep anchors and named reference implementations from your task spec. Use targeted `grep -n` and `sed -n` ranges, not whole-file reads of `src/rust/src/lib.rs` (≈335 lines) beyond the anchors.
- ADR `docs/decisions/0001-public-api-support-contract.md` (13 exports; experimental labels) and `docs/decisions/0003-tests-run-under-r-cmd-check.md` (skip guards) as carried constraints.

## [Worker] Micro-planning

Before editing, create `planning/tasks/{{id}}.todo.md`:

```markdown
# {{id}} — {{title}}

## Goal
<one sentence>

## TODO items
- [ ] <small, verifiable step, including the task's exact targeted command>

## Notes
<facts discovered in Analysis, constraints honored, risks, exact files/lines>

## Questions
<numbered questions, maximum 5; omit if none>
```

Keep the plan to at most 12 steps. Output the TODO contents as your report and END YOUR TURN. Do not execute until the orchestrator sends the explicit approval message.

## [Worker] Execution (only after approval)

Execute the approved TODO strictly in order, flipping `- [ ]` to `- [x]`. Stay within the listed files. Match the surrounding file conventions (roxygen style in `R/`, `describe`/`it` style in `tests/testthat/`, `Error::Other(format!(…))` in Rust). Run only the targeted command(s) in your task spec; do not run the full suite (the orchestrator runs it serially at wave end) and do not run `roxygen2::roxygenise()` (that is task `4.4.1` only).

## [Worker] Reporting

Append a concise report under your task heading in `planning/STATE_4.md` (maximum 15 lines): status; files changed with line ranges; the exact validation command(s) and observed result including pass/fail counts; any new compiler warning; deviations from the approved plan (or `none`); discovered facts or blockers for dependent tasks. Do not commit; the orchestrator owns verification and commits.

## Commit discipline

If the orchestrator asks you to prepare a commit, follow the repository's [[git-workflow-standards]] (`../../git-workflow-standards/SKILL.md`): one conventional-format, one-sentence commit per task; do not mention orchestration, wave, or phase numbers in the message. Never commit unless explicitly instructed by the orchestrator.
