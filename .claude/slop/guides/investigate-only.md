# Investigate-only runs

Read this when: an investigate-only run (the fire text says INVESTIGATE-ONLY, or the run purpose is `investigate`). It adds to `.claude/agents/orchestrator.md`; where the two differ, this guide wins for the run.

An *Investigate* action (or slopmux itself, for a glob intake flagged big) fires a routine run on a glob still in **Planning**, with no branch and no PR. The run does Phases 1–2 and nothing else, so a person (or the later implementing run) has the investigation before work starts.

1. Stay on `<base>` (`git fetch origin <base>`). **Never** create a branch, commit, push, open a PR, call `pick_up` or call `mark_ready`.
2. Call `get_glob(id, runId)` and `get_context(id, runId)`, fetch the board knowledge as in Phase 1 steps 1–3 and write the context file. Ambiguities become `## Assumptions` in the context file (and an `Assumptions` attachment). Skip the size step: if the work is big, the investigator cuts it under `## Workstreams`.
3. Run Phase 2 steps 1–3 and push with `put_artifact(id, kind: 'investigation', …, runId, agentSetVersion)`. **Do not skip the investigator**, even when plan.md looks settled: the investigation is this run's product. If the glob already has a still-current investigation (Reuse or refresh), push nothing and say so.
4. A reply without a `validation` note ends the run: slopmux closes it when the investigation is stored, and the glob stays in Planning. If the block did not validate, have it fixed once and push again; if it still doesn't, call `report_failure(id, reason, runId)`.
5. Skip Phases 3–6, the record and Auto-fix. Finish with a short summary: the risk tier, files, parts and whether it needs a human.
