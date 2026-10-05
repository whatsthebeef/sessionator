<!-- implementation-agent-system -->
# Slop agent system

Work on this repo is planned and tracked in **slop**. Each unit of work is a **glob** with an ID such as `s1t4` (board 1, task 4; `f` feature, `t` task, `b` bug). Slop's MCP tools give you the glob, its plan and its context: `mcp__slop__*` in local sessions, or the claude.ai Slop connector's tools (`mcp__claude_ai_Slop__*`) in routines and cloud sessions. They are the same tools; use whichever is available. This section and the files it mentions are installed by `sstor init`; don't edit them here. Propose changes with `submit_learning` instead.

## Running

```
/run-glob <id>                   # work on a glob (category and type come from slop)
/run-glob --from <phase> <id>    # resume from phase 1–6
/run-glob --review <id|sha>      # review only
/finalise <requestId>            # before sstor --ready / --derge
```

The orchestrator (`.claude/agents/orchestrator.md`) runs the phases and launches the investigator, implementer, tester and change_reviewer as sub-agents. Phase files go to `.reviews/<id>-*.md`, which is never committed.

## Rules

- **Branches:** the glob's branch is its ID, created by slop from the board's base branch (`get_board`). Work only on that branch. Never commit to or push the base branch, and never create PRs: slop opens each glob's draft PR at creation.
- **Commits:** `<id>: <title>`, then bullet points. Routine runs add the trailer `Slop-Run: <runId>`.
- **Merging:** squash merge only, through the PR (`sstor --merge`, the glob's Merge button or GitHub). Required checks must pass on the PR's current head.
- **Routines (unattended):** never ask questions; record assumptions on the glob. Before **every** push, check the glob with `get_glob` and stop if your run is no longer current, a human implementer is recorded, or the glob is merged.
- **Knowledge:** everything specific to this board and project (build commands, conventions, architecture, approved learnings) is in slop's knowledge base, not in these files: `get_conventions(board)` lists it and `get_conventions(board, area)` fetches it. History comes from `search_text`, `search_semantic` and `search_changes`. Submit learnings with `submit_learning`; never edit the knowledge directly.
- **Failures:** if you can't finish, call `report_failure` with the reason (and run ID in routines).
- **Sandbox:** never set `dangerouslyDisableSandbox: true`.
<!-- /implementation-agent-system -->
