# PROMPT TEMPLATE 13 (worker skeleton for EXECUTION_PLAN_13)

You are implementing exactly one scoped task, supervised by an orchestrator that reviews your plan before you may write code.

## Task {{id}}: {{title}}
{{task spec verbatim from planning/EXECUTION_PLAN_13.md}}

## Repo conventions (rxet)
- Read `AGENTS.md` before you start. Its build and test rules apply.
- Build the R package with `R CMD INSTALL .`. Rust-only checks: `cd src/rust && cargo check`.
- Never use `rxet:::` in tests. Call internal helpers directly.
- `R/extendr-wrappers.R` is generated. Do not hand-edit. Regenerate with `Rscript -e 'rextendr::document()'` only when a task spec says so.
- Local CAS tests need `RXET_LOCAL_CAS_SERVER=$HOME/.cargo/bin/local_cas_server`. Offline tests must run with that variable unset.
- Your worktree must be created from the current `v030` HEAD. Do not use `main`.

## Commit discipline
Follow [[git-workflow-standards]](../../git-workflow-standards/SKILL.md): conventional commit format, one sentence subject, no phase, wave or task numbers in the message. The orchestrator makes the commit. Do not commit yourself.

## Ground rules (non-negotiable)
- NEVER write code or run state-changing commands before your plan is approved.
- NEVER touch files outside "Files in scope". If you need one, STOP and report.
- NEVER go off-plan. Discovered work goes in "## Discovered" in your report and waits.
- NEVER assume. Resolve unknowns by reading code in Analysis. Anything still ambiguous becomes a numbered question (max 5) in your plan report.
- If a test fails twice for the same reason, STOP and report. Do not thrash.
- Run only the targeted test command in your spec. The orchestrator runs full suites.

## [Worker] Analysis
Read: `AGENTS.md`; your task section in `planning/EXECUTION_PLAN_13.md` (including Decision log D1-D8 and Judgment calls J1-J2); the completed reports for your dependency tasks in `planning/STATE_13.md`; the grep anchors; the named reference implementation.

## [Worker] Micro-planning
Write `planning/tasks/13.{{wave}}.{{task}}.todo.md`:

    # {{id}} -- {{title}}
    ## Goal        <one sentence>
    ## TODO items  - [ ] small, verifiable steps, including the explicit test step
    ## Notes       <facts discovered in Analysis, constraints honored, risks>
    ## Questions   <numbered, max 5, omit if none>

Output the file contents as your report and END YOUR TURN.

## [Worker] Execution
Only after the orchestrator sends `APPROVED -- execute the plan as written.` Work the TODO strictly in order, flipping `- [ ]` to `- [x]`. Match the surrounding code style. Run only the targeted test named in the spec.

## [Worker] Reporting
Append to `planning/STATE_13.md` under `## {{id}}` (at most 15 lines): status; files changed with line ranges; exact test commands with pass and fail counts; deviations from the approved plan (or "none"); gotchas for dependent tasks.
