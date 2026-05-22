---
name: run-task
description: Run the full agent workflow for a task, bug, review, or free-text prompt (investigate → implement → test → review), or restart from a specific phase.
user_invocable: true
---

# Run Task

Execute a task, fix a bug, review existing changes, or work from a free-text prompt.

## Usage

```
/run-task --task <jira-key>
/run-task --bug <jira-key>
/run-task --review <jira-key>
/run-task --prompt "<description>"
/run-task --from <phase> --task <jira-key>
/run-task --from <phase> --bug <jira-key>
```

- `--task <jira-key>` — Jira issue key for a Story/Task (e.g. `N2-123`).
- `--bug <jira-key>` — Jira issue key for a Bug (e.g. `N2-456`).
- `--review <jira-key>` — Jira issue key for an already-implemented card to review (no code changes, review only).
- `--prompt "<description>"` — Free-text description used in place of a Jira issue.
- `--from <phase>` — Resume from phase 1–6. Default is 1.

### Examples

```
/run-task --task N2-123                   # Start a specific task from phase 1
/run-task --bug N2-456                    # Start fixing a specific bug from phase 1
/run-task --review N2-789                 # Review an already-implemented card
/run-task --prompt "Add a loading spinner to the dashboard page"
/run-task --from 3 --task N2-123          # Resume task N2-123 from implementation
```

## Instructions

You are invoking the orchestrator workflow. Follow these steps:

1. **Parse arguments**
   - Extract `--from` phase number (default: 1).
   - Extract `--task`, `--bug`, `--review`, or `--prompt`.
   - If resuming without an identifier, ask for it.

2. **Follow the Orchestrator workflow**
   Read `.claude/agents/orchestrator.md` and follow its instructions directly (do NOT launch it as a sub-agent). The orchestrator workflow runs in the main session and launches sub-agents.

   - For `--task` or `--bug`: pass the starting phase and Jira issue key into the workflow.
   - For `--review`: pass `mode = review` and the Jira issue key. The orchestrator runs the review-only workflow.
   - For `--prompt`: pass `mode = prompt` and the description text. The orchestrator skips the Jira fetch in Phase 1 and uses the prompt as the context instead.

3. **Report Results**
   When the workflow completes, report:
   - Task/Bug ID and description
   - Final status
   - Any errors or issues encountered
   - For reviews: summary of findings and whether the review passed
   - For tasks/bugs: remind the user they can restart from any phase if the result isn't satisfactory

## Phase Output Files

Each phase writes an output file to `.reviews/`. `<type>` is `task` or `bug`.

| Phase | What happens | Output file |
|-------|-------------|-------------|
| 1 | Pick work item, create branch | `.reviews/<type>-<id>-context.md` |
| 2 | Investigate, produce plan | `.reviews/<type>-<id>-plan.md` |
| 3 | Implement the plan/fix | `.reviews/<type>-<id>-implementation.md` |
| 4 | Write and run tests | `.reviews/<type>-<id>-tests.md` |
| 5 | Review code changes | `.reviews/<type>-<id>.md` |
| 6 | Finalise | — |

### Restarting from a phase

To redo from a specific phase, edit the output file from the previous phase, then:

```
/run-task --from <phase> --task <task-id>
/run-task --from <phase> --bug <bug-id>
```
