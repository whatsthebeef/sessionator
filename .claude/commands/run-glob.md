---
name: run-glob
description: Run the agent workflow for a slop glob (investigate → implement → test → review → finalise), restart from a phase, run unattended in a routine, or review existing changes.
user_invocable: true
---

# Run Glob

Work on a slop glob, or review existing changes.

## Usage

```
/run-glob <id>
/run-glob --from <phase> <id>
/run-glob <id> --run <runId>
/run-glob --review <id|commit-sha>
```

- `<id>` — the glob ID (e.g. `s1t4`). Its category (feature, task, bug) and slop type (sub, same, super) come from slop; there are no separate task and bug flags.
- `--from <phase>` — resume from phase 1–6. Default is 1.
- `--run <runId>` — run **unattended** as a routine run. Routines always pass this; developers never do.
- `--review <id|sha>` — review only, no code changes. With a glob ID the result is pushed to slop as the glob's local review.

### Examples

```
/run-glob s1t4                    # Work on s1t4 interactively from phase 1
/run-glob --from 3 s1b2           # Resume bug s1b2 from implementation
/run-glob --review s1t4           # Review s1t4's branch (or its squash commit if merged)
/run-glob --review abc123f        # Review a specific commit
```

## Instructions

1. **Parse arguments**: `--from` (default 1), `--run`, `--review`, and the glob ID or SHA. If no identifier was given, ask for it (interactive) or stop with an error (unattended).
2. **Follow the orchestrator workflow**: read `.claude/agents/orchestrator.md` and follow it directly in this session (do NOT launch it as a sub-agent). Pass the glob ID, the starting phase, the run ID if any, and `mode = review` for `--review`. The orchestrator reads the glob and chooses between the phase pipeline and super mode itself.
3. **Report results** when the workflow completes:
   - the glob ID and title;
   - what was done, and whether the PR was marked ready;
   - any errors (and whether `report_failure` was called);
   - for reviews: the findings summary and verdict;
   - otherwise: a reminder that any phase can be rerun with `--from` after editing its `.reviews/` file.

## Phase output files

| Phase | What happens | Output file |
|-------|-------------|-------------|
| 1 | Fetch the glob's context from slop, clarify | `.reviews/<id>-context.md` |
| 2 | Investigate, choose a proposal, push the implementation plan | `.reviews/<id>-plan.md` |
| 3 | Implement | `.reviews/<id>-implementation.md` |
| 4 | Write and run tests | `.reviews/<id>-tests.md` |
| 5 | Review cycle | `.reviews/<id>-review.md` |
| 6 | Commit, push the local review and learnings, push the branch, mark the PR ready | — |

### Restarting from a phase

Edit the output file of the previous phase, then `/run-glob --from <phase> <id>`.
