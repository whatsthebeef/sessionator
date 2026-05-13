---
name: run-task
description: Pick up the next Ready task or fix a specific bug, running the full agent workflow (investigate → implement → test → review → PR), or restart from a specific phase.
user_invocable: true
---

# Run Task

Pick up and execute the next available task, fix a specific bug, or resume from a specific phase.

## Usage

```
/run-task --task <jira-key>
/run-task --bug <jira-key>
/run-task --from <phase> --task <jira-key>
/run-task --from <phase> --bug <jira-key>
```

- `--task <jira-key>` — Jira issue key for a Story/Task (e.g. `N2-123`). Required.
- `--bug <jira-key>` — Jira issue key for a Bug (e.g. `N2-456`). Required.
- `--from <phase>` — Resume from phase 1–6. Default is 1.

### Examples

```
/run-task --task N2-123                   # Start a specific task from phase 1
/run-task --bug N2-456                    # Start fixing a specific bug from phase 1
/run-task --from 3 --task N2-123          # Resume task N2-123 from implementation
/run-task --from 3 --bug N2-456           # Resume bug N2-456 from implementation
```

## Instructions

You are invoking the orchestrator workflow. Follow these steps:

1. **Parse arguments**
   - Extract `--from` phase number (default: 1).
   - Extract `--task` Jira issue key or `--bug` Jira issue key (optional for phase 1, required if `--from` > 1).
   - If resuming without `--task`/`--bug`, ask for the issue key.

2. **Follow the Orchestrator workflow**
   Read `.claude/agents/orchestrator.md` and follow its instructions directly (do NOT launch it as a sub-agent). The orchestrator workflow runs in the main session and launches the investigator, implementer, unit_test_writer, and change_reviewer as sub-agents.

   Pass the starting phase and Jira issue key into the workflow.

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
