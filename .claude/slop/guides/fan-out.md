# Fan-out: workstreams in one run

Read this when: the size check flagged the glob, the plan or investigation cuts workstreams, or the implementation record has `## Workstreams`. It adds to `.claude/agents/orchestrator.md`; where the two differ, this guide wins for the run.

## Phase 2b: Fan out or not

Read the plan file's `## Workstreams` and the investigation block's `parts`.

- **No fan-out** (none or one workstream, a chain where each needs the last, or workstreams too small for an agent): Phase 3 is one implementation, with no `## Workstreams` table.
- **Fan out** when at least `max(2, size.minParallel)` workstreams can run at once (`minParallel` is the board's learned floor in `get_context.size`, 2 if absent) and each is **worth an agent** (at least 2 tasks or 3 files, or the learned floor; smaller ones fold into the workstream they need, or W0). Below the floor run one implementation and say so in `## Decisions`. No file may be owned by two workstreams: merge two that edit one file, or move it to W0.
- Order by needs (W0 first); write the `## Workstreams` table (all `not started`) and the `workstreams` block (`fannedOut` true, `maxParallel` the most that can run together, `predictedFiles` from the plan file, empty `actualFiles` and `conflicts`, `attempts` 0, `durationMinutes` null) into the record, push it, and record the decision and why in `## Decisions`.
- **Scope cut (interactive only).** If the investigator flagged a workstream that could ship alone and nothing needs it, offer once via `AskUserQuestion` to make it a follow-up glob (`create_glob` in group `workstreams`, `after: [<id>]` if it needs this glob's code), recording the answer as `Clarifications`; if accepted, remove it from the plan file's `## Workstreams`, the block's `parts` and the work, and note it in `## Decisions`. **Never in a routine:** keep the whole scope and note the possible cut under `## Open items`.

## Phase 3 with fan-out

1. **Resuming** (`--from 3`, a take-over, a re-run): run only workstreams not `done` and keep what is on the branch. A `running` one whose commits aren't on the branch is `not started`; one `waiting on decision` stays held.
2. **W0 first,** by one implementer on the glob's branch in the main checkout, limited to W0's files and plan share. Commit it as `<id>: W0 <goal>` (Phase 6 step 4 trailers), mark it `done`, push.
3. **Then every parallel workstream at once:** one `implementer` each, launched together in one message with `isolation: worktree`, branched from the glob's branch after W0, briefed in Mode C with its name, plan slice and acceptance criteria, files, the W0 contract (the committed code), the files it must not touch (every other workstream's), the shared rules (clarifications or assumptions verbatim, build and board docs, unattended flag, sandbox rule) and the output path `.reviews/<id>-implementation-<workstream>.md`. `.reviews/` is never committed, so pass **absolute paths into the main checkout's `.reviews/`** for inputs and output. It commits in its worktree as `<id>: <workstream>` with the Phase 6 step 4 trailers (give the exact lines) and doesn't push. A `uses` pair starts together; a workstream that needs another parallel one starts, from the then-current branch, once that one is integrated. Mark them `running`; in a routine keep progress moving.
4. **Integrate each finished workstream** in dependency order as it returns: `git merge --no-ff` its branch (or cherry-pick, keeping its commits), run the fast checks for its files, mark it `done` with its commit in the table and block (`actualFiles` from `git diff --name-only` of its commits, `conflicts`, `attempts`, `durationMinutes`), pre-push check, push branch and record. Resolve small additive conflicts yourself; return a real conflict (both sides changed the same logic) to that workstream's implementer with the hunks. Handle `## Needs from other workstreams` per the needs loop. Integrate a `uses` pair user-after-provider.
5. **A failed workstream** (a blocker, or checks it can't fix) is retried once by a new implementer in a fresh worktree from the current branch, given the failure; finished ones stay integrated. On a second failure mark it `failed`, push the record and, after the rest are integrated, `report_failure` naming it.
6. **A decision mid-run:** when a workstream hits a choice only a person can make, raise a decision glob (`submit_learning` creates one) and `suggest_decision(<decision id>)`, give this glob a `merge` relation on it (`add_relation(id, to: <decision id>, gate: 'merge', until: 'decided', version, reason)`) and record the choice and what is held in `## Decisions`. Mark that workstream `waiting on decision`, finish and integrate the others, push the record. **The run then ends waiting:** skip Phases 4–6 and `mark_ready`, call `check_run` once more with the run ID and finish with a summary naming the held workstream and decision (not `report_failure`); the next run resumes from the record with the decision. Interactive: ask the developer instead.
7. **Integrated-branch failures.** Once all are integrated, run the full checks before Phase 4. A failure goes to the owner of the failing files as a fix brief on the glob's branch (not a worktree); one spanning owners, or with none, goes to one implementer with the whole diff. Record under `## Decisions` which combination broke. Fold each workstream's choices, deviations and traps into the record, keep table and block current, and remove the worktrees (`git worktree remove`).

**Needs loop.** A `## Needs from other workstreams` request is handled once per (requester, file): owner not started: add it to the owner's brief; running: send it when the owner returns; `done`: make the small change yourself on the glob's branch or move the file to the requester (record an ownership change in `## Decisions` and update the block's `parts` in the plan file). A second request for the same file between the same two workstreams merges them for the rest of the run (update table and block).

**Changing W0 mid-run.** Only you change W0, on a needs request or a real conflict that needs it. Pause new workstreams, commit `<id>: W0 amend <what>` (with the trailers), mark every `done` workstream that needs W0 as `recheck` (the block keeps `done`), run its fast checks on the integrated branch, re-brief its implementer only if they fail, then mark it `done` again; re-brief running ones with the amendment and record it in `## Decisions`. At most 2 amendments per run: after the second, stop fanning out and finish the rest one by one on the branch, noting why.

**Soft dependencies.** A need marked `uses` (calls code another adds, no shared contract) runs in parallel against an interface the investigator wrote into both briefs (signature and behaviour) and is integrated user-after-provider; if the interface is wrong, the fix is a W0 amendment. Record `uses` in the block.

## Workstreams block

When fanned out, `## Workstreams` ends with one fenced ```` ```workstreams ```` block of strict JSON, rewritten with the table at every step of Phase 3 and pushed with the record. A malformed block is kept as text with a `validation` note in the reply (fix and push again); a changed one is recorded as a `WorkstreamsRecorded` event that slopmux learns from. Leave the section out when not fanned out.

```workstreams
{
  "fannedOut": true,
  "maxParallel": 2,
  "workstreams": [
    {"name": "W0", "goal": "the contract", "predictedFiles": ["a.ts"], "actualFiles": ["a.ts"], "needs": [], "state": "done", "attempts": 1, "conflicts": [], "durationMinutes": 14},
    {"name": "W1", "goal": "the web part", "predictedFiles": ["b.tsx"], "actualFiles": ["b.tsx", "c.ts"], "needs": ["W0"], "uses": [], "state": "running", "attempts": 1, "conflicts": [], "durationMinutes": null}
  ]
}
```

`fannedOut` is true when at least 2 ran at once; `maxParallel` is the most that did (1 to the number of workstreams). Per workstream: unique `name`, `goal`, `predictedFiles` (the investigator's cut), `actualFiles` (empty until integrated), `needs` (names, no cycles), optional `uses` (see Soft dependencies; omit when empty), `state` (`not_started`, `running`, `done`, `waiting_decision`, `failed`, `skipped`), `attempts` (a retry makes 2), `conflicts` (files that conflicted at integration) and `durationMinutes` (null until it ends). Lists are lists of strings, possibly empty.
