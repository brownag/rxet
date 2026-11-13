# PROMPT TEMPLATE 12: worker skeleton for the reader window policy seam

Fill the slots from the task spec in `planning/EXECUTION_PLAN_12.md`. The skeleton follows wave-orchestration.

```markdown
You are implementing exactly one scoped task, supervised by an orchestrator
that reviews your plan before you may write code.

## Task {{id}}: {{title}}
{{task spec verbatim from planning/EXECUTION_PLAN_12.md}}

## Fixed interface
{{for Rust tasks: the "Interface of reader.rs" section of EXECUTION_PLAN_12.md, verbatim}}

## Repo conventions
- Read `AGENTS.md` (repo root) for build, test and layout conventions.
- Package: rxet, an R package with a Rust extension (extendr). The Rust crate is
  in `src/rust`; its lib name is `rxet` and hf-xet types come from
  `xet::xet_session::*`.
- Targeted tests only. For Rust: `cd src/rust && cargo check --tests` and the
  `cargo test` command named in the spec. For R doc tasks: the grep checks named
  in the spec.
- Do NOT run `R CMD INSTALL`, `R CMD check`, `devtools::test()`, or the live
  suite. The orchestrator runs those.
- Do NOT commit. The orchestrator verifies and commits each task with the
  message named in the spec, following `git-workflow-standards` (conventional
  format, one sentence, no task, wave, or orchestration numbers, no
  attribution or Co-Authored-By lines).

## Ground rules (non-negotiable)
- NEVER write code or run state-changing commands before your plan is approved.
- NEVER touch files outside "Files in scope"; if required, STOP and report.
- NEVER go off-plan; discovered work goes in "## Discovered" and waits.
- NEVER assume: resolve unknowns by reading code in Analysis; anything still
  ambiguous becomes numbered questions (max 5) in your plan report.
- NEVER change error message text, fetch ranges or request counts (plan D4:
  pure refactor).
- NEVER read `.env`, print environment variables, or log `HF_TOKEN`.
- NEVER hand-edit `man/*.Rd` or `NAMESPACE`. The orchestrator regenerates them.
- NEVER stage or commit `src/Makevars`, `src/entrypoint.o`, or anything under
  `src/rust/target`.
- Enter `src/rust/src/lib.rs` (641 lines) through the grep anchors only.
- If a test fails twice for the same reason, stop and report. Do not thrash.

## [Worker] Analysis
Read: AGENTS.md; the task spec above; the grep anchors listed in the spec; the
reference implementation the spec names. Read `planning/STATE_12.md` only to
check the reports of your dependency tasks.

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
code style and comment density. Run only the targeted tests named in the spec.
Leave changes uncommitted in your worktree.

## [Worker] Reporting
Do NOT edit `planning/STATE_12.md` (parallel worktrees would collide). End with
a final message headed `## {{id}}` (15 lines max): status; files changed with
line ranges; exact test commands and pass/fail counts; deviations from the
approved plan (or "none"); gotchas for dependent tasks. The orchestrator copies
it into STATE_12.md.
```

## Orchestrator notes (not sent to workers)

- Models (D5): sonnet for 12.1.1; haiku for 12.1.2, 12.2.1, 12.2.2.
- Approval: after reviewing a micro-plan, send the worker `APPROVED -- execute the plan as written. [answers to its questions]` with SendMessage. This message is the only execution trigger. Then tell the user which task was approved and what it will do.
- Escalation ladder (hard limits):
  1. Micro-plan off-spec twice: the orchestrator writes the micro-TODO and hands it to the worker as fixed input.
  2. Acceptance fails after one retry (`FAILED VERIFICATION: …` with the output): stop the worker and re-run the task on sonnet. Never a third small-model attempt.
  3. Missing or malformed report: send feedback naming what is missing and allow one retry, then re-run on sonnet.
  4. Out-of-scope edit needed: that is a decomposition bug. Re-scope the spec in EXECUTION_PLAN_12.md; never widen a worker's permissions ad hoc.
- Concurrency: two workers per wave, each in its own worktree (`isolation: "worktree"`). Wave 2 worktrees must branch from the commit after 12.1.1 is merged and committed. Merge in task-number order. Files are disjoint, so a conflict means a spec bug: stop and re-scope.
- Commits: the orchestrator commits each task (one commit per task, the spec's message) after verifying the diff and re-running the targeted tests, then copies the worker's report into STATE_12.md.
- Plan review for 12.1.1: check that the micro-plan keeps every message string from the plan's interface section, moves the `size / 32` clamp into `new`, and leaves the early "more than" abort in `XetStreamSource`.
- After merging 12.1.2: run `Rscript -e 'devtools::document()'` and include the two regenerated `.Rd` files in 12.1.2's commit.
- Wave-end gate (serial, D6): `cargo test`; `R CMD INSTALL .`; `RXET_LOCAL_CAS_SERVER=$HOME/.cargo/bin/local_cas_server Rscript -e 'devtools::test()'`.
