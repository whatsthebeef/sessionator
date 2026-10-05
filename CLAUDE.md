# Developer Agent System

This repository uses a multi-agent workflow orchestrated by Claude Code. The orchestrator runs all phases end-to-end, interacting with the task sheet via a web app API. Each phase writes an output file to `.reviews/` so the user can review the result and restart from any phase if needed. Supports both **tasks** (features/enhancements) and **bugs** (defect reports).

## Workflow Overview

1. **Phase 1** — Pick task/bug, create branch → `.reviews/<type>-<id>-context.md`
2. **Phase 2** — Investigate, produce plan → `.reviews/<type>-<id>-plan.md`
3. **Phase 3** — Implement the plan/fix → `.reviews/<type>-<id>-implementation.md`
4. **Phase 4** — Write and run tests → `.reviews/<type>-<id>-tests.md`
5. **Phase 5** — Review code changes → `.reviews/<type>-<id>.md`
6. **Phase 6** — Commit, attach review to Jira, extract learnings → `.sstor/docs/learnings.md`

### Running

```
/run-task --task N2-123                       # Start a specific task
/run-task --bug N2-456                        # Start fixing a specific bug
/run-task --from 3 --task N2-123              # Restart task from phase 3
/run-task --from 3 --bug N2-456              # Restart bug from phase 3
```

## Cross-Task Knowledge

The system accumulates knowledge across tasks in two ways:

- **Project learnings** (`.sstor/docs/learnings.md`): After each task completes, the orchestrator extracts architectural decisions, gotchas, and patterns into this file. All sub-agents receive it on future tasks.
- **Sibling task awareness**: When a task belongs to an epic, the orchestrator fetches other issues in the same epic and passes a digest to sub-agents so they know what's already been built.
- **Cross-LLM review** (`--cross-review`): Optionally sends proposals and code review to a second LLM (OpenAI) for an independent critique, with a limited exchange between models. Requires `OPENAI_API_KEY` in env and `api.openai.com` in sandbox allowed domains.

## Task Sheet Structure

| id | name | description | acceptance_criteria | notes | dev_notes | status | date_created |
|----|------|-------------|---------------------|-------|-----------|--------|--------------|

- **dev_notes**: Written by the developer before setting the task to `Ready`. Passed to the investigator and implementer for additional context.
- **date_created**: ISO datetime. Tasks are claimed FIFO (oldest first).
- Relevant statuses: `Ready`, `Working`, `Finished`, `Error`

## Bug Sheet Structure

| id | steps_to_reproduce | expected | actual | environment | reporter | notes | additional_notes |
|----|-------------------|----------|--------|-------------|----------|-------|-----------------|

## Conventions

- Feature branches: `task/<id>-<slug>` or `bug/<id>-<slug>` (slug derived from description)
- Phase output files: `.reviews/<type>-<id>-*.md`
- PR target: `master`
- Max review cycles: 3
- Commits should be atomic and well-described

## Project Structure

```
.claude/
├── settings.json          # Permissions, sandbox config
├── agents/
│   ├── orchestrator.md    # Main workflow — coordinates sub-agents
│   ├── investigator.md    # Analyzes task/bug, builds plan
│   ├── implementer.md     # Implements the plan, fixes review items
│   ├── qa.md               # Builds, tests, writes missing tests, browser verification
│   └── change_reviewer.md # Reviews code, classifies feedback
├── commands/
│   └── run-task.md        # Entry point: /run-task
.sstor/                    # Project-specific config (in each target project)
├── sstor.conf             # Server command, port base
└── docs/                  # Reference docs for sub-agents
    ├── index.md           # Doc index with descriptions
    └── learnings.md       # Accumulated decisions, gotchas, patterns from completed tasks
.reviews/                  # Phase output and review documents
```

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
