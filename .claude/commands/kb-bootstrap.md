---
name: kb-bootstrap
description: Draft the knowledge documents a board is missing (build doc, conventions as practised, architecture overview) from the code in this checkout, and submit each one to slop as a new-document proposal for an admin to approve.
user_invocable: true
---

# KB bootstrap

```
/kb-bootstrap [board]
```

Some knowledge only lives in the code: how to build and test it, the conventions it actually follows, and how it is laid out. This command reads the checkout, drafts the documents the board's knowledge base doesn't have yet, and submits each one with `submit_learning` and a `document`. Nothing reaches the knowledge base until a board admin approves the proposal on the board's Knowledge page; approving it creates (or updates) that document.

**Never edit, create or delete files in the repo**, and never call `import_knowledge`: proposals are the only output. Don't run builds, installs or tests either; read the files that describe them.

## Instructions

1. **Board**: use the argument if given; otherwise read `board` from `.claude/slop-agent-set.json`. Read `version` from the same file and pass it as `agentSetVersion` on every submission. If the current branch (`git branch --show-current`) is a glob ID on that board (`s<board>t<n>`, `f` or `b`), pass it as `sourceGlobId`; otherwise leave `sourceGlobId` out.
2. **What exists**: call `get_conventions(board)` first. Note every document's name, area, description and audience, and the approved learnings. Fetch any document whose coverage is unclear from its description with `get_conventions(board, name)`.
3. **Read the repo**, without changing anything:
   - `README*`, `CONTRIBUTING*`, `docs/` and any existing agent or editor instructions (`CLAUDE.md`, `AGENTS.md`, `.cursor/`, `.github/copilot-instructions.md`);
   - the task runner and package or build files (`package.json` scripts and workspaces, `Makefile`, `justfile`, `pyproject.toml`, `Cargo.toml`, `go.mod`, `build.gradle`, `docker-compose*`, `scripts/`);
   - CI workflows (`.github/workflows/`, `buildspec*.yml`), which show the commands that must pass;
   - linter, formatter and compiler configs (`eslint.config.*`, `.prettierrc*`, `tsconfig*.json`, `ruff.toml`, `.editorconfig`);
   - a sample of the source and tests across the main modules, to see the conventions **as practised** (naming, error handling, layering, test style), not only as configured.
4. **Decide what is missing.** The candidates are:
   - **Build doc** (`build_test_lint`, area `build`, audience `[implementer, tester, change_reviewer]`): install, build, test (fast and full), lint, typecheck and format commands, how to run locally, services the tests need, and gotchas.
   - **Conventions** (e.g. `<language>_conventions` or `<project>_conventions`, area `conventions`, audience `[implementer, change_reviewer]`): the rules the code follows that its linters don't enforce.
   - **Architecture overview** (`architecture`, area `architecture`, audience `[investigator, implementer]`): the modules and how they depend on each other, where things live, the main data flows and external services.

   Skip a candidate when an existing document already covers it, even under another name or area. If an existing document covers it only partly, don't propose a replacement; mention the gap in your report instead.
5. **Draft each missing document** in Markdown: specific to this repo, citing real paths and commands, short and scannable, with no secrets, credentials, hostnames of private systems or personal data. Say what you inferred rather than read (e.g. "the tests appear to need Postgres").
6. **Submit each one** with a separate `submit_learning` call:
   - `board`, `sourceGlobId` (if any), `agentSetVersion`;
   - `type: 'pattern'`;
   - `statement`: `New document: <name> (<one-line description>)`;
   - `evidence`: the files you read to draft it;
   - `document`: `{ name, area, audience, description, content }`, where `description` is one line and `content` is the body only (slop builds the frontmatter from the other fields).
7. **Report** to the developer: each document submitted with its KB item ID (`s<board>k<n>`), each candidate skipped and why (which existing document covers it), and any partial coverage worth a follow-up. Remind them that a board admin approves the proposals on the board's Knowledge page.

If a submission fails, report the error and continue with the next document; don't retry by other means.
