---
name: run-task
description: Pick up the next Ready task or fix a specific bug, running the full agent workflow (investigate → implement → test → review → PR), or restart from a specific phase.
user_invocable: true
---

# Run Task

Pick up and execute the next available task, fix a specific bug, or resume from a specific phase.

## Usage

```
/run-task
/run-task --task <task-id>
/run-task --bug <bug-id>
/run-task --from <phase> --task <task-id>
/run-task --from <phase> --bug <bug-id>
```

- `--from <phase>` — Resume from phase 1–6. Default is 1.
- `--task <task-id>` — Optional in phase 1 (fetches that specific task). Required when resuming (phases 2–6).
- `--bug <bug-id>` — Fetch and fix a specific bug. Required when resuming a bug (phases 2–6).

### Examples

```
/run-task                                 # Start a new task from phase 1 (claims next Ready)
/run-task --task F1S1T1                   # Start a specific task from phase 1
/run-task --bug B1                        # Start fixing a specific bug from phase 1
/run-task --from 3 --task F1S1T1          # Resume task F1S1T1 from implementation
/run-task --from 3 --bug B1              # Resume bug B1 from implementation
```

## Instructions

You are invoking the orchestrator workflow. Follow these steps:

1. **Resolve the web app URL and API key**
   - Read `TASK_APP_URL` and `TASK_APP_KEY` from environment variables.
   - If either is not set, ask the user for the missing value(s).

2. **Parse arguments**
   - Extract `--from` phase number (default: 1).
   - Extract `--task` task ID or `--bug` bug ID (optional for phase 1, required if `--from` > 1).
   - If resuming without `--task`/`--bug`, ask for the ID.

3. **Follow the Orchestrator workflow**
   Read `.claude/agents/orchestrator.md` and follow its instructions directly (do NOT launch it as a sub-agent). The orchestrator workflow runs in the main session and launches the investigator, implementer, unit_test_writer, and change_reviewer as sub-agents.

   Pass the resolved URL, API key, starting phase, and task/bug ID into the workflow.

4. **Report Results**
   When the workflow completes, report:
   - Task/Bug ID and description
   - PR URL (if created)
   - Final status
   - Any errors or issues encountered
   - Remind the user they can restart from any phase if the result isn't satisfactory

## Phase Output Files

Each phase writes an output file to `.reviews/`. `<type>` is `task` or `bug`.

| Phase | What happens | Output file |
|-------|-------------|-------------|
| 1 | Pick work item, create branch | `.reviews/<type>-<id>-context.md` |
| 2 | Investigate, produce plan | `.reviews/<type>-<id>-plan.md` |
| 3 | Implement the plan/fix | `.reviews/<type>-<id>-implementation.md` |
| 4 | Write and run tests | `.reviews/<type>-<id>-tests.md` |
| 5 | Review code changes | `.reviews/<type>-<id>.md` |
| 6 | Create PR, update sheet | — |

### Restarting from a phase

To redo from a specific phase, edit the output file from the previous phase, then:

```
/run-task --from <phase> --task <task-id>
/run-task --from <phase> --bug <bug-id>
```
