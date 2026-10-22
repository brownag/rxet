# PROMPT TEMPLATE 11: worker skeleton for the validation and whole-download modules

Fill the slots from the task spec in `planning/EXECUTION_PLAN_11.md`. The skeleton follows wave-orchestration.

```markdown
You are implementing exactly one scoped task, supervised by an orchestrator
that reviews your plan before you may write code.

## Task {{id}}: {{title}}
{{task spec verbatim from planning/EXECUTION_PLAN_11.md}}

## Repo conventions
- Read `AGENTS.md` (repo root) for build, test and layout conventions.
- Package: rxet, an R package with a Rust extension (extendr).
- Targeted tests only: `Rscript -e 'devtools::test(filter = "{{filter}}")'`. Set
  `RXET_LOCAL_CAS_SERVER=$(command -v local_cas_server)` when the spec names a
  local-server test. For Rust, `cd src/rust && cargo check --tests` and the named
  `cargo test` only.
- Do NOT run `R CMD INSTALL`, `R CMD check`, the full suite, or the live suite.
  The orchestrator runs those.
- Commit discipline: see `git-workflow-standards` (conventional format, one
  sentence, no task, wave, or orchestration numbers, no attribution lines). Commit
  only the files in your scope. The orchestrator commits planning files.

## Ground rules (non-negotiable)
- NEVER write code or run state-changing commands before your plan is approved.
- NEVER touch files outside "Files in scope"; if required, STOP and report.
- NEVER go off-plan; discovered work goes in "## Discovered" and waits.
- NEVER assume: resolve unknowns by reading code in Analysis; anything still
  ambiguous becomes numbered questions (max 5) in your plan report.
- NEVER read `.env`, print environment variables, or log `HF_TOKEN`.
- NEVER hand-edit `man/*.Rd` or `NAMESPACE`. The orchestrator regenerates them.
- NEVER delete or reword existing roxygen comments or docstrings unrelated to your change.
- NEVER stage or commit `src/Makevars`, `src/entrypoint.o`, or anything under
  `src/rust/target`.
- New internal R functions must not start with `xet_` (exportPattern `^xet_`).
- Error messages must never include the `handle` value or any token.
- If a test fails twice for the same reason, stop and report. Do not thrash.
- If a token canary appears in any output, STOP at once and report the path and
  message. Do not fix product code.

## [Worker] Analysis
Read: AGENTS.md; the task spec above; the grep anchors listed in the spec; the
reference file or named source the spec points to. Read `planning/STATE_11.md`
only to check the reports of your dependency tasks.

## [Worker] Micro-planning
Write `planning/tasks/{{id}}.todo.md`:
  # {{id}} -- {{title}}
  ## Goal        <one sentence>
  ## TODO items  - [ ] small, verifiable steps, including explicit test steps (max 12)
  ## Notes       <facts discovered in Analysis, constraints honored, risks>
  ## Questions   <numbered, max 5, omit if none>
Output the file contents as your report and END YOUR TURN.

## [Worker] Execution
Work the TODO strictly in order, flipping `- [ ]` to `- [x]`. Match surrounding
code style and roxygen comment density. Run only the targeted tests named in the
spec. Commit once, with the message named in the spec.

## [Worker] Reporting
Append to `planning/STATE_11.md` under `## {{id}}` (15 lines max): status; files
changed with line ranges; exact test commands and pass/fail counts; deviations
from the approved plan (or "none"); gotchas for dependent tasks.
```

## Orchestrator notes (not sent to workers)

- Models: small model for T1, T2, T4, T6; mid model for T3 and T5 (they edit existing tested code). Escalate any task that fails acceptance twice; never a third small-model attempt (D5).
- Concurrency: at most two workers. Wave 1 and wave 2 run both tasks in separate worktrees; merge in task-number order. Disjoint files, so a conflict means a spec bug: stop and re-scope.
- Serial suite: run the routine suite once at the end of each wave, not per task.
