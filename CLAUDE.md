# Developer Agent System

This repository uses a multi-agent workflow orchestrated by Claude Code. The orchestrator runs all phases end-to-end, interacting with the task sheet via a web app API. Each phase writes an output file to `.reviews/` so the user can review the result and restart from any phase if needed. Supports both **tasks** (features/enhancements) and **bugs** (defect reports).

## Workflow Overview

1. **Phase 1** — Pick task/bug, create branch → `.reviews/<type>-<id>-context.md`
2. **Phase 2** — Investigate, produce plan → `.reviews/<type>-<id>-plan.md`
3. **Phase 3** — Implement the plan/fix → `.reviews/<type>-<id>-implementation.md`
4. **Phase 4** — Write and run tests → `.reviews/<type>-<id>-tests.md`
5. **Phase 5** — Review code changes → `.reviews/<type>-<id>.md`
6. **Phase 6** — Create PR, update sheet

### Running

```
/run-task                                     # Full run from phase 1 (claims next Ready task)
/run-task --task F1S1T1                       # Start a specific task
/run-task --bug B1                            # Start fixing a specific bug
/run-task --from 3 --task F1S1T1              # Restart task from phase 3
/run-task --from 3 --bug B1                   # Restart bug from phase 3
```

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
│   ├── unit_test_writer.md # Runs tests, writes missing tests
│   └── change_reviewer.md # Reviews code, classifies feedback
├── commands/
│   └── run-task.md        # Entry point: /run-task
.sstor/                    # Project-specific config (in each target project)
├── sstor.conf             # Server command, port base
└── docs/                  # Reference docs for sub-agents
    └── index.md           # Doc index with descriptions
.reviews/                  # Phase output and review documents
```

<!-- implementation-agent-system -->
# Developer Agent System

This repository uses a multi-agent workflow orchestrated by Claude Code. The orchestrator runs all phases end-to-end, interacting with the task sheet via a web app API. Each phase writes an output file to `.reviews/` so the user can review the result and restart from any phase if needed. Supports both **tasks** (features/enhancements) and **bugs** (defect reports).

## Workflow Overview

1. **Phase 1** — Pick task/bug, create branch → `.reviews/<type>-<id>-context.md`
2. **Phase 2** — Investigate, produce plan → `.reviews/<type>-<id>-plan.md`
3. **Phase 3** — Implement the plan/fix → `.reviews/<type>-<id>-implementation.md`
4. **Phase 4** — Write and run tests → `.reviews/<type>-<id>-tests.md`
5. **Phase 5** — Review code changes → `.reviews/<type>-<id>.md`
6. **Phase 6** — Create PR, update sheet

### Running

```
/run-task                                     # Full run from phase 1 (claims next Ready task)
/run-task --task F1S1T1                       # Start a specific task
/run-task --bug B1                            # Start fixing a specific bug
/run-task --from 3 --task F1S1T1              # Restart task from phase 3
/run-task --from 3 --bug B1                   # Restart bug from phase 3
```

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
│   ├── unit_test_writer.md # Runs tests, writes missing tests
│   └── change_reviewer.md # Reviews code, classifies feedback
├── commands/
│   └── run-task.md        # Entry point: /run-task
.sstor/                    # Project-specific config (in each target project)
├── sstor.conf             # Server command, port base
└── docs/                  # Reference docs for sub-agents
    └── index.md           # Doc index with descriptions
.reviews/                  # Phase output and review documents
```

<!-- /implementation-agent-system -->
