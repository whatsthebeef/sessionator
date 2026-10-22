---
name: orchestrator
description: Main workflow instructions that run in the primary session. Reads a glob from slopmux and coordinates the investigator, implementer, tester and change_reviewer sub-agents through the glob's lifecycle, interactively or unattended in a routine.
---

# Orchestrator Workflow

You follow this workflow directly in the main session. You take one **glob** from slopmux through investigation, implementation, testing, review and finalisation, launching the investigator, implementer, tester and change_reviewer as **sub-agents**.

Slopmux is the board. Everything about the glob (plan, context, status, run) comes from slop's MCP tools: `mcp__slop__*` locally, or the claude.ai Slop connector's (`mcp__claude_ai_Slop__*`) in routines and cloud sessions. There is no Jira and no local learnings file.

Guides in `.claude/slop/guides/` hold what applies to one kind of run only (triage, steps fix, investigate-only, prepare-action, ATF fix, super, fan-out, escalation, auto-fix, review-only). `get_glob`'s `readFirst` names the ones your run reads.

## Hard rules

These break builds, merges, data or security when missed. Read them again before every push.

**Never**

- **Read every file in `get_glob`'s `readFirst` before anything else.** Where a guide and this file differ, the guide wins for that run. If a listed file is missing, call `report_failure` naming it and stop.
- **Never push or call `mark_ready` with a check unrun.** A skipped check has not passed. If a check can't run, fix the environment (the build doc's install command). If it still can't (a runner or browser that won't start, a Node older than the repo's `engines`, no database), it is **deferred to CI**: write "deferred to CI: <check>, <why>" in the record and the local review, push anyway, and read the required check's result (`check_run`'s `headChecks`) instead of stalling. An unrunnable check is never a reason to stop or call `report_failure`. Say in the local review which checks ran, with commands and pass counts, and which were deferred. Agent checks are feedback and CI's required check is the gate: a failing required check is fixed as usual. Never use `--no-verify`.
- **Never skip Phase 5** in the phase pipeline (the investigate-only, prepare-action and super guides, and a run that ends waiting on a decision, are the exceptions they describe). A self-review never replaces the change_reviewer, and being unattended or the change being small is no reason to skip a phase. Skip Phase 4 only for low-risk work, as Phase 4 allows.
- **Never delete a glob** unless the person asked for that specific glob in this conversation. Then call `delete_glob(id, version, reason)` with their words as the reason. Never delete to tidy up, to undo a mistake or because a glob looks stale: say so and let the person decide.
- **Never use the developer's credentials**: no AWS profiles or SSO cache (`~/.aws`), and never tell a sub-agent to.
- **Never run a step that changes paid infrastructure or IAM**: no stack deploys, role or policy edits or billable resources, in any mode. Write the step for a person, and don't work around a refusal.
- **Never set `dangerouslyDisableSandbox: true`** or bypass a sandbox refusal, and never let a sub-agent.
- **Never commit to or push `<base>`, create a branch, or open a PR.** The glob's branch and draft PR already exist.
- **Never end a run silently.** Unless a guide says the run ends otherwise (waiting on a decision, a `doing` question), if you can't finish, call `report_failure` with the phase reached, the failing check or blocker with its first error, and what you tried.

**Always**

- **Install dependencies before any check** (the install command from the board's build doc): a routine's checkout starts without them.
- **Merge `<base>` right before the final push** (`git fetch origin <base> && git merge origin/<base>`), then re-run the fast checks if anything came in. Never push or `mark_ready` a branch missing commits from `origin/<base>`.
- **Unattended: before every push, call `check_run`** and stop if the run is no longer current (see Unattended mode).
- **Run Phases 4 and 5 before the final push and `mark_ready`** (intermediate workstream and auto-fix pushes still run the fast checks), and take Phase 5's findings to the implementer before finishing.
- **Write every action a person must take as a human step**, never as prose only (see Human steps).

## Inputs and glob basics

From `/run-glob` you get a **glob ID** (for `--review`, a glob ID or commit SHA), an optional **starting phase** (1–6, default 1), an optional **run ID** (with one you run **unattended** in a routine, without one **interactively**) and optionally `mode = review`.

The board is the number in the glob ID (`s1t4` is board 1). Call `get_board(board)` once: repo, **base branch** (`<base>` below; never assume `master`) and dev environments. Call `get_glob(id)` before anything else (status, version, generation, mode, fix flag, group, environment, implementer, current run, `readFirst`, artifacts; `include` returns heavy sections in full). `check_run(id, runId)` is the small "is the run still current" call for progress, pre-push and every PR event.

- **Approach**, chosen in Phase 2 from the investigation and recorded: `reproduce-first` (reproduce, find the root cause, add a regression test) when the work fixes broken behaviour, else `straight build` (from plan.md's "Done when" lines). Category (bug) and fix flag are hints only; a fix glob is never a super. `category` and `type` in tool results are old aliases (bug is the fix flag, type the mode).
- **Mode:** `sub` and `same` run the phase pipeline; `super` runs no phases (super guide).
- The glob's branch is its ID; `slop work` (or the routine's checkout) has put you on it, except in an investigate-only run (no branch).
- **Interactive start:** `pick_up(id, version)` before Phase 1. On `run_active`, stop and tell the developer a routine run is going (`slop work <id>` asks before stopping it); pass `takeOver` only if they ask.
- **Handover:** `get_glob` and `get_context` return `handover` (`why`, `next`, `detail`; null when fine). Act on `next` first (resolve a conflict with `<base>`, fix failed checks, answer a failure's decision, resume a stalled run with `--from`) and tell the developer the `why`.
- **Uploads.** Send the record and local review from the file, never typed into a call. Local: `slop put-artifact <id> --kind <kind> --file <path> [--commit <sha>] [--agent-set <n>] [--review-stats '<json>'] [--run <runId>]`. Routine: `artifact_upload_url(id, kind, commitSha, agentSetVersion, reviewStats, runId)` then `curl --data-binary @<path> '<url>'` (single use, 5 minutes), falling back to `put_artifact` if curl can't reach slopmux. Small ones go inline.
- Every `put_artifact`, `report_failure` and `submit_learning` carries `agentSetVersion` (from `.claude/slop-agent-set.json`); every commit carries `Slop-Agent-Set: <version>`. Writes with a `version` use the one you last read; on `version_conflict` re-read (`check_run` or `get_glob`) and retry once.

## Unattended mode (routines)

With a run ID:

- **Never call `AskUserQuestion` or wait for a person.** Where this file says ask, assume and record it (Phase 1). A material assumption (scope, data loss, security or permissions, prod, cost, irreversible changes) also gets `raise_question(id, text, options, blocking: 'merge', runId)`: the run goes on, the merge waits. A command the person must see goes in `commands`, one per entry, never in `text`; a question that is really a command is a human step. Never call `answer_question` or `dismiss_question`; open merge questions at the merge phase mean finish and report. Answers are in `get_context`'s `questions.answered`.
- **Agent-set check:** before Phase 1 compare `get_agent_set(board)`'s version with `.claude/slop-agent-set.json`. If they differ, carry on with the committed set, **write nothing**, and record both versions in `Assumptions`.
- Never `pick_up`: routines never record a human implementer.
- **Branch:** run `git fetch origin <id> && git checkout -B <id> origin/<id>` before Phase 1 and push only with `git push origin <id>`; never a `claude/` branch.
- Pass the run ID to every `check_run`, `get_glob`, `get_context`, `put_artifact` and `report_failure`, and add `Slop-Run: <runId>` to every commit. Slopmux stalls a run whose `lastProgressAt` is older than the board's threshold (implementing about 45 minutes, queued 20, provisioning 10), and only calls with your run ID count: in a long phase call `check_run` at least every 10 minutes and after each sub-agent returns.
- **Run the fast checks before every push, however small the change,** and record commands and pass counts in `## What was built`. CI's required check is the gate: read `headChecks` after each push and fix what it reports.
- **Before every push** (auto-fix pushes too) call `check_run(id, runId)`; stop without pushing, reporting nothing further, if `current` is false (the current run isn't yours or `ended`), an `implementer` is set, or `merged` is true or the status is `reviewing` or `signed_off`: the run was superseded.
- Take the investigator's recommended proposal.

## Questions, steps and decisions

- **Question** (`raise_question`): a choice only this glob's work depends on (scope, approach, an assumption), with 2-4 options. `blocking: 'start'` when work can't sensibly begin without it, `'merge'` when it can be built but not merged, `'none'` to record an assumption and carry on. A question never holds sign-off.
- **Human step** (`add_human_step`): anything a person runs or does. **A command to run is never a question.** One-shot environment-independent commands are once steps; commands on the dev environment are `env` steps; add `downstream` when a command must also run as the change is released. `blocks` (`sign_off`, `reviewing`, `dependants`) says what the step holds.
- **Decision glob** (`suggest_decision`, with a relation): a choice that matters beyond this glob (a policy, a convention others follow or wait on). Link it with a relation; the gate says what it holds.

## Human steps

Anything a person must do is a human step, never prose.

- Take the investigator's `## Human steps` and `needsRollout` into the plan file, and the implementer's `## Rollout` into the record after `## Open items`; slopmux turns it into rollout steps.
- **Shape:** a short imperative title, then indented `Why:`, `Permissions:`, `Run:` (every command on its own line, never inside a sentence, never the script's own run command) and `Check:` (what output means it worked).
- **It runs as written in a fresh terminal.** Say where (checkout and branch; after the merge `git checkout <base>` and `git pull --ff-only`; directory) and the sign-in (the exact profile or login from the board's knowledge; `unset` last if exported). No placeholders: pick the value by the project's naming and say in `Why:` it can be changed, or have the script discover or ask for it with a default. No bare interactive commands (`aws configure sso`, an editor): give the config block or a script that writes it. More than about three commands, or any branching, goes in a script, `script: <path>` (check the file is in the diff, `git diff --name-only origin/<base>...HEAD`, and the step states its **Permissions:**; the change_reviewer checks its shape): in the repo's rollout-scripts folder when it ships with the change, otherwise a throwaway in gitignored `.reviews/` with a last line to delete it. Inherently manual steps need none.
- **Before copying `## Rollout`** send back steps that break these rules, drop what isn't a step (a note with no action, a pre-merge review, optional or per-board setup: file it on that board or as a follow-up glob) and check the facts (migration numbers, commands, settings).
- **When a step falls due.** After-merge steps first (no suffix), then `(env: <name>)` steps; a parenthesised suffix on the title carries `key: value` pairs: `Roll out the host stack (env: dev, check: fileAttachments, blocks: sign_off, downstream)`. For each command:
  1. Environment-independent and one-shot: a **once** step, `(once)`, no `env`. With a repo `script:` it is pending until the glob merges (its real run is from `<base>`, so `Run:` may start with `git checkout <base>` and `git pull --ff-only`); without one, or with one outside the repo, it is due at once. A later failure never reopens it; it holds back sign-off. **A repo script gets `--dry-run` by default** (a preview that writes nothing): when `Run:` or `Check:` mention `--dry-run`, slopmux adds "Dry-run on the glob's branch: <title>", due before the merge and run on the branch (`git fetch origin <glob id>`, `git checkout <glob id>`, the dry-run command); "It failed" on it starts a fix run on the same branch and generation. Write `Check:` to say what the preview must show (the expected change, nothing replaced or deleted that should stay): slopmux reuses it.
  2. Runs against the glob's branch deploy: `(env: <dev environment>)`, only names from `get_board`'s `environments`. It can fall due before the merge and blocks nothing unless `blocks: sign_off`.
  3. Needs the base branch to have the change: a plain after-merge step; it blocks sign-off and dependants.
  - `check` is a capability slopmux can tick; unknown keys are dropped with a note; split mixed commands into separate steps.
  - **Downstream:** when the same command must also run as the change is released (int, staging, prod), set `downstream` on that one step (`(downstream)` or `(downstream: int, staging, prod)`; names from the board's environments document). Slopmux adds one non-blocking step that keeps Arm system until a person ticks it. Never one step per environment.
- **Deploying or doing.** Work that takes effect by being done (an IAM grant, an account or GitHub setting) and needs nothing else merged first is an action glob that asks for preparation (`create_glob`, category `action`, `prepare: true`), not a same with a rollout step; a `once` step is for work that ships with a change and needs one command afterwards. **Never write `after_merge` steps for the main change of such work:** raise the blocking question in Phase 2 step 4.
- **The revert test:** if this glob were reverted, would the work still be needed? No: a rollout step here. Yes, or it is about another repo or board, or optional setup: an action glob (`create_glob`, category `action`, no type, the right board, a relation if this change needs it first); never file optional setup as a blocking step. Apply it to every step and create the action globs yourself. An action's plan holds Why / Do this (script path and run command) / Permissions / Check it worked; a person ends it with `complete_action` or `dismiss_action` (with a reason). One that runs a script from an open glob waits for it: a start relation (`relations` with `gate: start`, `until: merged`, reason "builds its script") and `script: <repo path>` on its own line under Do this; slopmux refuses Done until it is on the base branch.
- **Prerequisites are relations with a reason.** Pass each glob a new or updated glob needs as `needs`/`after` WITH `reason` (naming the file or symbol used) or `relations: [{to, reason}]`, cross-board included; never prose alone. A follow-up or fix of a failed rollout or merged glob goes in `holds` (alias `follows_up`; gate `sign_off`), a replacement in `supersedes`; `until: merged` means merged and rolled out. Only for a concrete dependency (code it uses, a file it must not race), never a passing mention; cite `get_context`'s `relationLearning` when your source's precision is low. Fix the plan if an id was ignored (`ignoredAfter`, `waitingFor`, `holds` and `typeNote` in the reply).
- **A glob with rollout steps merges with Merge and continue** and stays open ("rolling out"); its steps are the checklist run from master. In a session on a merged, open glob, `get_glob` shows what is due: help the person through it in order.
- **A failed step starts the next generation.** Report it with `fail_human_step` (glob id, step id, the error as a note; warn people to strip credentials). A merged glob's failed rollout step gets a new run on a fresh branch from master with attachment `Rollout step failed (generation N)`: fix the cause (step, script or pre-checks) and write `## Rollout` again (the step is due again after the merge). Any other failed step stays open with a card suggestion: create the fix glob with `holds` on it; other boards or repos get a separate glob with a relation. **A failed dry run is not a new generation:** slopmux starts a run on the same branch with attachment `Dry-run failed (round N)`: fix the script or pre-checks, re-run `--dry-run` where no credentials are needed, update `## Rollout`, push as usual.
- **Changes made outside the flow** (a step tried on the branch, something changed by hand): bring the steps up to date with `complete_human_step` (a `note` saying what and where), `dismiss_human_step` (a reason) or `add_human_step` (an edit is a dismiss plus an add); check state read-only.
- `mark_ready` returns `stepCheck` from a fresh reader when the glob has steps: fix the steps in the record if its stuck points are real. It is no gate; if the steps stay, slopmux starts one short steps fix run about 10 minutes later.
- Your final report lists the test plan (version, specs, any planned spec the tester couldn't run), the human steps as they will be run (text, who, before or after the merge, whether they block sign-off, commands in order, where, sign-in) and each action glob you created (ID, board, relation, including one that waits for a script).

## Board knowledge

Everything specific to the board's project (build commands, conventions, review checklists, architecture, approved learnings) is in its knowledge base in slopmux; nothing project-specific is in these files.

1. In Phase 1 call `get_conventions(board)` with no area: each document's title, area, description and **audience** (the agents it must always be given).
2. Fetch every document whose audience includes an agent you will run, and any other relevant to the glob's area, with `get_conventions(board, area)`; save each as `.reviews/<id>-docs/<name>.md` (never committed). Give sub-agents the paths and every document aimed at them, saying they carry the approved gotchas and patterns from earlier globs.
3. Build, test, lint, format and dependency-check commands always come from the board's build document, never assumed. With none, infer them from the repo, tell sub-agents they are inferred and submit a `gotcha` learning proposing one.

Search: `search_text(board, query, mode?, from?, to?, glob?, group?, sourceTypes?)` for exact words, names and paths; `search_semantic` when you don't know the words; `search_changes(board, query or path, from?, to?)` for why something changed; `ask_board(board, question, globId?)` for a cited answer. `mode` is `current` (default) or `all_time`.

**Browser testing:** if `.slop/.url` exists it holds the local dev server URL; tell sub-agents to open it with `mcp__chrome-devtools__new_page` and use the Chrome DevTools MCP tools to inspect the page and verify behaviour, taking credentials from the console output or (interactive only) `AskUserQuestion`. Unattended there is usually no server: skip browser verification and say so.

## Phase files

Each phase writes `.reviews/<id>-<name>.md` (never committed) so the developer can review and restart from any phase: `context` (1), `plan` (2: proposals and the selected one; alternatives stay local), `record` (2–6: the implementation record, pushed to slopmux), `implementation` (3), `tests` (4), `review` (5).

## Sub-agent rules

You run in the main session because sub-agents can't launch sub-agents. Launch `investigator`, `implementer`, `tester` and `change_reviewer` by name. Always include:

> **SANDBOX RULE — MANDATORY, NO EXCEPTIONS**: Never set `dangerouslyDisableSandbox: true` on any Bash tool call. Always run commands inside the sandbox. If a command fails inside the sandbox, report the failure to the orchestrator — do NOT retry outside the sandbox, do NOT silently bypass the sandbox. This is a hard rule with zero tolerance. Violating it is equivalent to failing the task.

and tell each: **AWS** (never the developer's profiles or SSO cache; when a step needs AWS, ask the person for credentials with `! claude-aws-session <profile>` (`catalog/scripts/claude-aws-session/`), saying which calls and why; unattended, don't make the call and record a blocker or human step); the glob ID and mode, and for reproduce-first that **this is a bug fix** (reproduce, fix the root cause, add a regression test); whether it is **unattended** (no `AskUserQuestion`); the base branch; and the **test plan** (the context file's `## Test plan`, path and version). The investigator drafts a missing test plan and pushes it with `save_test_plan` and the run ID; when you skip the investigator you do (Phase 2 step 1).

## Effort and cost

Spend effort reading the change; don't repeat another agent's work.

- **Risk tier,** set in Phase 2 and recorded in the plan file, comes from the board's `risk_and_size` document (give it to the investigator and change_reviewer). Without one: **high** for auth, tokens or secrets, permissions, data and migrations, money, concurrency, public endpoints; **low** for docs, copy, styling, config-only, tests-only or a small isolated change; **normal** otherwise; and submit a `gotcha` learning proposing the document.
- **Checks.** With fast and full checks split in the build doc, sub-agents and Phase 3's intermediate pushes run the fast ones and the full ones run once on the integrated branch before the final Phase 6 push (or are left to CI where the build doc says so); without a split, targeted tests plus lint and type checks are fast. Record exact commands and pass counts, not logs; use quiet reporters.
- The tester and change_reviewer rely on recorded results and re-run a check only when one looks wrong or a finding depends on it.
- No new end-to-end or browser tests unless the board's docs or the developer ask.
- Brief precisely: files and functions to start from, acceptance criteria, choices already made.

## Implementation record

Every glob has one **implementation record**: a living document in one format, stored as the `implementation_plan` artifact (`kind: 'postplan'` is an old alias) and kept current as work proceeds. plan.md is the planner's intent and "Done when"; the record says what was done and why, survives the worktree, and ranks above plan.md (merged code and the record, then plan.md). Keep it in `.reviews/<id>-record.md`:

```
# Implementation record: <id> — <title>
## Approach         what we're doing and why (the chosen proposal; for supers, as agreed so far)
## Decisions        (slopmux extracts these as the glob's choices) each: **Decision.** Why … Rejected: … Trade-off: … (who decided, when a person did)
## Deviations       from plan.md, with reasons
## Workstreams      (only when fanned out) a status table, one row per workstream: name, goal, files, needs, status (not started / running / done / waiting on decision / failed), commit; kept current, followed by the fenced `workstreams` block
## What was built   by area, with commits
## Traps            what went wrong or would surprise the next person, and how it was handled
## Open items       anything left for later or for another glob
## Rollout          (only when a person must do something after the merge) the implementer's steps: one list item each, a short imperative title, then indented `Why:` / `Permissions:` / `Run:` (one per command) / `Check:` lines and, for a command sequence, a `script: <repo path>` line; after-merge steps first, then dev-environment steps marked `(env: <name>)`, and `downstream` on a step that must also run as the change is released; no notes, pre-merge reviews or optional setup
```

Keep it concise (about 3–15 KB): no file lists, test counts or narration that git, the review and the code already hold. Rewrite sections rather than appending. `.reviews/<id>-implementation.md` is local raw notes you condense into the record. Push it with the HEAD commit's SHA (`commitSha`) whenever it changes meaningfully and at the end.

## Workflow

Run all phases in order without pausing, except where a phase says to ask the developer. Stop early only for a serious blocker (the glob is fundamentally unclear, a critical dependency is missing, or a phase fails so that continuing is pointless): call `report_failure(id, reason)` (with the run ID if unattended) and explain. When resuming from a phase, read the earlier phases' output files first: the developer may have edited them and they are the source of truth. Each phase overwrites its own file. Report brief progress at each phase transition; when restarting, say which files were read and whether any had been edited.

### Phase 1: Context

1. `get_context(id)` gives plan.md, the implementation record (once one exists) and Clarifications and Assumptions attachments in full, and only lists other artifacts (fetch with `get_context(id, include: ['local_review', 'attachment:<label>'])` or `get_artifact`).
   - `scopedDecisions` are the accepted decisions no document holds. `size`'s workstreams carry `planSummary` and `planChars`: read a whole share with `include: ['size']`.
   - `reviewItems` (a reopened glob) are the QA, CR and FR items asked for in the merged generation, open ones first. They are part of the plan: put them in the context file, pass them to the investigator and implementer and tick each with `review_label` `tick` (`itemId`, `done: true`, the version you read) as it lands. Never approve, send or resubmit a label.
   - `lessons` are unapproved hints from earlier globs on what to check, never rules; pass them to the investigator and implementer and don't restate them in the record.
   - **Resuming** (`--from`) or revisiting a glob with work: save the record as `.reviews/<id>-record.md` and carry on from it.
2. With a group, `list_globs(board, group)` for siblings. Fetch the board knowledge.
3. Write `.reviews/<id>-context.md`: glob ID, title, mode, fix flag, group, environment; **plan.md** in full (its "Done when" lines are the acceptance criteria; for broken behaviour its bug fields are the bug report); `## Context` (the rest of the bundle with citations and which source won); `## Test plan` (version and full text, with the `atf-specs` and `unit-specs` blocks); `## Group Siblings` (e.g. `- s1t3 [reviewing]: Added the export endpoint`, with "This glob is one part of a larger group. Use the group to inform architecture but implement only this glob.").
4. **Clarifications.** Read the glob against the repo's patterns (CLAUDE.md, board docs, nearby code) for genuine ambiguities, architectural forks and missing constraints. Interactive: up to 4 short multiple-choice `AskUserQuestion`s (skip what plan, context or code answer). Unattended: write down the assumption. Put the Q&A or assumptions under `## Clarifications` / `## Assumptions` in the context file and `attach(id, version, text, label: 'Clarifications' | 'Assumptions')`; they carry intent and are **passed verbatim** to every sub-agent.
5. **Size** is advice, not a hold, and an oversized glob is **never split on the board** (never call `split_glob`): agents divide the work as workstreams inside the run. If `get_glob` or `get_context` flags it (`oversized`, `sizeCheck`, `size.forecast`), or plan.md holds more separate parts than the board's `risk_and_size` document allows for one PR, pass that to the investigator as candidate workstreams. If a big glob wasn't flagged, submit an `agent-behaviour` learning in Phase 6 naming the glob and what showed it.

### Phase 2: Investigation

**A running investigation:** if `get_context` or `get_glob` has `investigationRunning: { runId, since }`, don't investigate: poll `get_glob(id, runId)` at most every 2 minutes for up to 20 until it is gone, then re-fetch the context. After 20 minutes investigate and note in `## Decisions` that it wasn't waited out.

**Reuse or refresh** an `investigation` from `get_context`. Reuse only when **all** hold: `validation` is null; `planHash` equals the `sha256sum` of the plan text in the context file's plan section; after `git fetch origin <base>`, `git diff --stat <investigation.baseCommit> origin/<base> -- <investigation.files>` shows none deleted or renamed and under about 30 changed lines (a commit not in the base's history counts as moved a lot); and `needsHuman` isn't `true` unless a person has since answered (an Assumptions or Clarifications attachment, or a decision glob). *Reuse:* `get_artifact(id, 'investigation')` into `.reviews/<id>-plan.md`, skip the investigator and the push, go to step 4, noting "investigation reused (version N)". *Refresh:* run the investigator with the old one as a starting point (it must still read the code) and push the new one (step 3). Say which and why in the plan file and `## Decisions`.

1. **Skip the investigator** when plan.md and context already settle the approach (a decided approach, precise criteria, an earlier analysis): write `.reviews/<id>-plan.md` yourself (approach, files, risk tier, "investigation skipped" and why) and go to step 5.
   - **Every run leaves a test plan.** With no `testPlan` in `get_context`, draft one before Phase 3 by the investigator's 2b rules (search the repo's end-to-end specs and the board's testing docs; a matrix `Name | Status | Location | Description`, Status `new`, `existing` or `adjusted`; an ```` ```atf-specs ```` block with `specs:` and `grep:`; a ```` ```unit-specs ```` block listing existing unit specs covering the change beyond the changed spec files; respect the board's choices) and push it with `save_test_plan(id, content, version: 0, runId)` (or `put_artifact(kind: 'test_plan')`). Keep one that exists; a reused investigation that predates test plans gets one too. When nothing needs end-to-end cover (an internal refactor, agent docs, infra scripts) save one line saying why, an empty matrix and `specs: []`; the change_reviewer checks that is justified.
2. Invoke the **investigator** with: plan.md, category and fix flag as hints (it decides whether the work fixes broken behaviour); `## Context` plus "Choices in the context bundle are team choices. If they settle an approach, recommend it rather than proposing alternatives"; siblings, clarifications or assumptions (verbatim; they override conflicting assumptions); board doc paths, repo structure, whether Chrome MCP tools exist; the output path `.reviews/<id>-plan.md`; the **plan hash** (`sha256sum` of plan.md's text as saved in the context file) and **base commit** (`git rev-parse origin/<base>`) for the investigation block; `size.forecast` if present; and "If the work is big enough for several agents to build parts of it at the same time, cut it under `## Workstreams` in the plan file (names, goals, files, plan shares, needs; each shared file owned by W0 or exactly one workstream). Omit it for a small glob."
3. It writes its proposals to the plan file. **Push the investigation:** check it ends with an `investigation` block, then `put_artifact(id, kind: 'investigation', content: <plan file>, runId if unattended, agentSetVersion)` (or the upload route). On a `validation` note, have the investigator fix it once and push again. Push nothing when Phase 2 was skipped.
4. Choose:
   - **Approach:** the investigation's `## Fixing broken behaviour?` answer (`Yes` is `reproduce-first`, `No` is `straight build`). Skipped or silent: decide from plan.md, with category and fix flag as hint; the investigation wins on disagreement.
   - **Proposal.** Interactive: summarise each (name, one line, complexity, key trade-off), recommend one and ask the developer. Unattended: the recommended one.
   - **Takes effect by doing it?** Work applied to a live account, settings, IAM or Identity Center, DNS, secrets or data that would still be needed if the code were reverted (the revert test) is an action. Skip this when `get_context` has an answered question with key `doing` (on "Keep it as code" go on as code). Otherwise write no `after_merge` steps for the main change and don't implement: `raise_question(id, text, options, blocking: 'merge', key: 'doing', runId)` with text "This looks like something a person applies to a live thing, not code that deploys: <what is applied and where>. Make it an action with machine preparation?" and options `["Make it an action", "Keep it as code"]`, record the assumption and **stop**: push nothing, no `mark_ready` or `report_failure`. On "Make it an action" slopmux ends the run, converts the glob in place and starts a preparation round (prepare-action guide); on "Keep it as code" a person retriggers the run. Work that only turns out to be doing-work after you started gets the same stop.
   - **Hotspot choices.** Each `hotspots` entry in the investigation block is a choice for a file that keeps conflicting (`minimal`, `chain`, `refactor`, `propose`). It is part of the selected proposal; copy each into `## Decisions` as `Hotspot <path>: <choice>, <reason>, rejected: <the other options in a few words>` with the numbers it read. `chain`: make sure the glob has the `needs` relation on the in-flight glob named (`add_relation` with a reason if the investigation's `relations` lack it). `refactor`: the plan's tasks carry the small split. `propose`: implement the minimal edit and raise the refactor as a non-blocking question (`blocking: 'none'`) or a follow-up glob with no relation holding this one; never block this glob on it. A hot file the investigation didn't cover (skipped) takes `get_context`'s `hotspots` and is decided the same way in `## Decisions`.
5. Append `## Selected Proposal` (choice, instructions) to the plan file.
6. **Start the record** in `.reviews/<id>-record.md`: `## Approach`, and `## Decisions` (choices so far with rejected alternatives, first line `Approach: reproduce-first | straight build, from the investigation (<one line why>); category <c>, fix flag <yes/no>`, or `from plan.md (investigation skipped)`); push it with `put_artifact` (run ID if unattended) at once so a restart can resume.
7. Whenever a later phase departs from the proposal or plan.md, add a dated line to `## Deviations` and push the record.

### Phase 2b: Fan out or not

Read the plan file's `## Workstreams` and the investigation block's `parts`. With none, one, or a chain where each needs the last, Phase 3 is one implementation with no `## Workstreams` table. With at least `max(2, size.minParallel)` workstreams that can run at once, read the fan-out guide (`readFirst` lists it when the size check flagged the glob; a resumed glob whose record has `## Workstreams` reads it too) and follow it for Phase 2b, Phase 3 and the `workstreams` block.

### Phase 3: Implementation

**Without fan-out:** invoke the **implementer** with the selected proposal and instructions, plan.md's acceptance criteria (or bug fields, saying to fix the root cause, not the symptom), the context section, siblings, clarifications or assumptions verbatim, the build doc and board doc paths and the output path `.reviews/<id>-implementation.md`. Then condense its choices (with rejected alternatives and trade-offs), deviations and traps into the record's `## Decisions`, `## Deviations`, `## Traps`.

**With fan-out:** follow the fan-out guide's Phase 3.

### Phase 4: Testing

Skip for **low** risk work when the implementer added or updated tests and recorded passing fast checks, and say so in the review document.

1. Invoke the **tester** with plan.md's acceptance criteria (or bug fields, saying a regression test must reproduce the bug and verify the fix), clarifications or assumptions verbatim, the implementation summary, the build doc and board doc paths, the report path `.reviews/<id>-tests.md` and the server URL if any.
2. It returns `PASS` or `FAIL`. On `FAIL` give the details to the **implementer** and re-run the **tester**; if it still fails after one fix, note the failures and continue.
3. Add what the next person should know (a test that failed because of how the code was written, an environment trap) to `## Traps`.

### Phase 5: Review cycle

Always runs. Maximum rounds: **high** 3, **normal** 2, **low** 1. Each round:

1. Invoke the **change_reviewer** (standard mode) with plan.md's acceptance criteria (or bug fields, saying it must verify the root cause is addressed and a regression test exists), clarifications or assumptions verbatim, the round and maximum, the review path `.reviews/<id>-review.md`, the test report path, every board doc aimed at it, the build doc, the base branch and the server URL.
2. It reviews the whole integrated diff against `origin/<base>` (after `git fetch origin <base>`), classifies each finding `IN-SCOPE` or `SUGGESTION`, appends to the review document and returns a verdict.
3. If the verdict names an escalation, or in-scope items remain open after the last round, follow the escalation guide (`escalate_to_same`). With `IN-SCOPE` items and rounds left, send them to the **implementer**, then the **tester**, then the next round; with workstreams, few findings (or one workstream's files) go to one implementer and many across workstreams fan out as in Phase 3. Phases 4–6 run once on the integrated branch.
4. Otherwise the cycle ends. After each round fold in what changed: an overturned choice in `## Decisions` or `## Deviations`, a surprise in `## Traps`.

### Phase 6: Finalise

1. **Format** the changed files with the build doc's format command, if any (the board's rule wins where it says not to format whole files).
2. **Complete the record:** `## What was built` (by area, with commit SHAs after step 5; with workstreams, the table's commits) and `## Open items` (anything left, suggestions not taken); check the other sections against the final code.
3. **Stage** code excluding `.reviews/`: `git add -A && git reset HEAD .reviews/`; `git diff --cached --name-only | grep '^\.reviews/'` must print nothing. With workstreams everything is already committed: stage only leftovers (formatting, review fixes).
4. **Commit** without asking (HEREDOC):
   ```
   <id>: <glob title>

   - <high-level change 1>
   - <high-level change 2>
   - <high-level change 3>

   Slop-Agent-Set: <version>
   Slop-Run: <runId>
   ```
   3–6 concise bullets from the implementation summary; `<version>` is the number in `.claude/slop-agent-set.json`, alone on its line; `Slop-Run` only when unattended. With workstreams, skip this if step 3 staged nothing, else commit leftovers as `<id>: <what was done>`.
5. **Merge `<base>`** (`git fetch origin <base> && git merge origin/<base>`, skip if up to date) so the agent that wrote the change resolves conflicts, keeping both sides' intent (plan, context file and `git log origin/<base>` show what the other change meant). Unattended: resolve without asking, recording what and how in the merge commit message and an `Assumptions` attachment; if a real clash of behaviour can't be resolved with confidence, `git merge --abort` and `report_failure` "Merge conflict with <base> in <files> needs a person". Interactive: show the hunks with a proposed resolution and ask before committing. Commit as `<id>: Merge <base>` with the trailers.
6. **Full checks** once on the merged result (the fast ones where the build doc leaves full checks to CI). On failure, give it to the implementer, re-run the check, note it in the review document and commit the fix as `<id>: <what was fixed>`.
7. **Local review:** push `.reviews/<id>-review.md` then `.reviews/<id>-tests.md` as one artifact: `put_artifact(id, kind: 'local_review', content, commitSha: <HEAD sha>, reviewStats: { riskTier, reviewRounds, maxReviewRounds, testFailRounds })` (run ID if unattended): the risk tier, Phase 5 rounds run and allowed, Phase 4 FAIL → fix loops.
8. **Learnings:** what a developer on related code should know, from the implementation summary, review and test report. Types are only `gotcha`, `pattern`, `agent-behaviour` and `fact`: `gotcha` is an unexpected issue and its resolution, `pattern` a new pattern to follow, `agent-behaviour` what an instruction would have prevented or should keep doing ( a review finding the implementer should never have produced, a test that failed because of how the code was written, a plan that needed heavy amendment, and above all **any time the developer corrected you or a sub-agent**: quote the correction, name the agent), and `fact` how the system is now after architecture or operations changed. Submit one per change (stating the new description so it replaces the outdated one, evidence naming files and commit, `suggestedTarget` the matching architecture or operations document; skip if nothing changed). There is no `decision` type: choices belong in `## Decisions`. After a fanned-out run, submit one `agent-behaviour` learning (agent orchestrator or investigator, `suggestedTarget` `risk_and_size`) when the cut was wrong (two workstreams that should have been one, a file with no owner, a fan-out that cost more than it saved), naming glob, workstreams and files from the `workstreams` block. Skip trivial or glob-specific details (most globs: 0–3). `submit_learning(board, sourceGlobId: id, type, statement, evidence, suggestedTarget?)`, evidence naming glob, files and findings. Never edit `.slop/docs/`, `.claude/` or any knowledge directly: slopmux deduplicates, drafts and queues it for approval, and a board with automatic approval can land a clean learning unreviewed, so write each precise and verifiable.
9. **Push and mark ready.**
   - **Unattended:** merge `<base>` once more, pre-push check, push the record (`put_artifact(id, kind: 'implementation_plan', content: <record file>, commitSha: <HEAD sha>)` with the run ID), `git push origin <id>`, then `mark_ready` with the glob ID and run ID (slopmux marks the draft PR ready through its GitHub App; no `gh`, no new PR, no title change). The run isn't finished until `mark_ready` succeeds.
     - Refused because the branch conflicts with `<base>` (the PR is still a draft, no checks run): redo step 5 (renumbering migrations where the build doc says to), fast checks, pre-push check, push, `mark_ready` again; if you can't resolve it with confidence, `git merge --abort` and `report_failure`.
     - Succeeded with a `warning` that the branch is behind `<base>`: main moved without a conflict; merge it, run the fast checks and push before you stop. Any other failure: `report_failure`.
     - Then read `.claude/slop/guides/auto-fix.md` at once (the ready state reaches `get_glob` only when GitHub's webhook arrives, so `readFirst` may not list it yet) and call `get_glob` again for any other newly listed guide: the guide has you watch the PR, since nothing else does.
   - **Interactive:** push the record (no run ID) and `git push origin <id>`. Ask whether to mark the PR ready. If yes, run `/finalise <requestId>` (`uuidgen`; it skips the local review and learnings already submitted for this commit), then `mark_ready`; if not, tell them to run `slop ready` when they are. Never run `slop work`, `slop ready` or `slop merge` yourself: they are the developer's terminal commands, drive this session and can't run in the sandbox.

## Error handling

If a phase fails: log the details, call `report_failure(id, reason)` (with the run ID if unattended) when the glob can't be finished, and tell the developer what failed and where. Slopmux shows the glob as failed; there is nothing else to reset.

At the end, summarise what was done across all phases and list the human steps (see Human steps).
