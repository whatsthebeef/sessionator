# Steps fix runs

Read this when: a run with purpose `steps_fix`. It adds to `.claude/agents/orchestrator.md`; where the two differ, this guide wins for the run.

A run with purpose `steps_fix` means slopmux started you (a stuck reading stood for 10 minutes after the run before you went quiet, or ended) because a fresh reader said a person would get stuck on the glob's steps (the `## Rollout` of the implementation record) and the run before you left them as they were. The fire text lists the points; `get_context` returns a `stepsFix` section with the stuck points of the current reading (step, kind, what, the step's title) and `stepsMoved`. You are the one short round: don't run the phases, don't change code or the glob's scope, and don't call `mark_ready`.

1. Call `get_glob` and `get_context` with the run ID. If `stepsMoved` is true the steps changed since you were queued: call `decide_steps_fix(id, runId, [])` and stop.
2. Read the board's operations document and conventions first (`get_conventions(board, 'operations')`, then `'conventions'`). A profile, role, account, setting or command they document is known, so a point about it is not real; name what they leave out as a gap in the step instead of inventing it.
3. For each point, either:
   - **rewrite it**: read the implementation record (`get_artifact`, kind `implementation_plan`), change only the affected steps in `## Rollout` (a command in its own `Run:` line, where to run it, the sign-in, the exact values, a `Check:` line), and push the record with `put_artifact(id, kind: 'implementation_plan', …, runId, agentSetVersion)` using the record's own `commitSha`: no code push, nothing else in the record changes; or
   - **say it is not real**, with the evidence (the document and line that answers it).
4. Record each point with `decide_steps_fix(id, runId, decisions)`: one entry per point (`step`, `kind`, `outcome` `rewritten` or `not_real`, `why`). A `not_real` reason is shown to the person under the warning on the step, and a change to the steps is read again by the reader. The person can still dismiss a point, so nothing waits on this run to merge.
5. Hard limits: slopmux starts one such round per glob generation; never touch paid infrastructure, credentials or IAM; never force-push; never merge. Before writing, call `get_glob` with the run ID and stop if your run is no longer current, a human implementer is recorded or the glob is merged. If you cannot finish, call `report_failure(id, reason, runId)`: the points stay as a warning on the steps and no second round starts.
6. After `decide_steps_fix`, follow the auto-fix guide from step 1: subscribe to the PR's activity, because your run watches the PR again.
