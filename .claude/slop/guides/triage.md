# Triage runs

Read this when: a run with purpose `triage`. It adds to `.claude/agents/orchestrator.md`; where the two differ, this guide wins for the run.

A run with purpose `triage` means slopmux started you because a failure was left with nobody working on it: failed checks of this glob's own change, a conflict with `<base>`, or a failed run. The fire text says which and why; `get_context` returns a `triage` section with the failure output and the glob's own history (earlier runs, what they pushed, how they ended, earlier triage decisions). Don't run the phases from the start.

1. Call `get_glob` and `get_context` with the run ID, and read the failure and the history. Decide the remedy from the outcome, not from a fixed rule:
   - **fix it on the branch** and push (Phases 3-4 as far as the fix needs; the pre-push check applies), then follow the auto-fix guide;
   - **judge it not this glob's fault** (inherited from `<base>`, or flaky) with evidence, and re-run the checks: `decide_triage` with `rerun_checks` and the evidence as `why`;
   - **ask a blocking question** (`raise_question`) when only a person can say what is right;
   - **hand over** with a short brief: `decide_triage` with `handover`.
2. Record the choice and why with `decide_triage(id, runId, remedy, why)` and under `## Decisions` in the implementation record. The history says what earlier rounds tried: don't repeat what failed.
3. Hard limits: slopmux starts at most 2 rounds per failure and then hands it to a person; never merge on red checks; never touch paid infrastructure or credentials; never force-push. If you cannot finish, call `report_failure(id, reason, runId)`.
4. A rollout step that failed is not triaged: its next generation starts by itself. In that run you may fix it on the generation's branch, or report and ask.
