---
name: finalise
description: Bring slop up to date for the current glob before its PR is marked ready or merged (implementation record, local review, learnings), then write the completion marker that `sstor --ready` and `sstor --derge` wait for.
user_invocable: true
---

# Finalise

```
/finalise <requestId>
```

`sstor --ready` and `sstor --derge` only continue once this has succeeded for the current request and head commit. sstor sends `/finalise <requestId>` to this session itself when the developer runs it from a terminal. When you mark the PR ready yourself, run `/finalise <requestId>` first (generate the ID with `uuidgen`), then call slop's `mark_ready` with the glob ID. Never run `sstor` yourself: it is the developer's terminal tool, it drives this session, and it cannot run inside the sandbox.

## Instructions

1. **Identify the glob**: it is the current branch name (`git branch --show-current`). Call `get_glob(id)`.
2. **Make sure the head is pushed**: if there are uncommitted changes, stop and tell the developer (don't commit for them here). If the branch is ahead of `origin/<id>`, push it: `git push origin <id>`. Record `sha = git rev-parse HEAD`.
3. **Merge the base branch (supers only; sames and subs do it in Phase 6)**: `git fetch origin <base> && git merge origin/<base>` (`baseBranch` from `get_board`). Skip if already up to date. On conflicts, resolve them keeping both sides' intent (the implementation record and `git log origin/<base>` show what the other change meant), but show the developer the conflicting hunks with a proposed resolution and ask before committing. Commit as `<id>: Merge <base>` with the trailer `Slop-Agent-Set: <version>` (from `.claude/slop-agent-set.json`), run the board's checks on the result (fast checks where the build doc leaves full checks to CI), then push as in step 2 and update `sha`.
Steps 4–5 push files: send each from its file as the orchestrator's **Uploading artifacts** paragraph says (`slop put-artifact --file` locally, `artifact_upload_url` then `curl --data-binary @<file>` in a routine), keeping inline `put_artifact` for small ones.
4. **Implementation record (every glob type)**: update `.reviews/<id>-record.md` (the format is in the orchestrator's Implementation record section) from the session conversation, `.reviews/<id>-implementation.md` and `git diff <base>...HEAD`, so that it is complete and matches the final code, then `put_artifact(id, kind: 'implementation_plan', content, commitSha: sha)`. Skip if the glob's artifact list already has an `implementation_plan` whose `commitSha` is `sha` (the orchestrator's Phase 6 pushes it for sames and subs), and push it for `sha` if it doesn't.
5. **Local review**: if the glob's artifact list already has a `local_review` for `sha`, skip this step. Otherwise, if `.reviews/<id>-review.md` exists and covers the current changes, push it (with the test report appended if there is one) as `put_artifact(id, kind: 'local_review', content, commitSha: sha)`. If there is no review for the current changes, run the **change_reviewer** in standard mode for one round, then push its document.
6. **Learnings**: if learnings were already submitted for this glob in this session for `sha`, skip. Otherwise extract them as in the orchestrator's Phase 6 step 8 and call `submit_learning` once per learning.
7. **Marker**: only after every call above succeeded, write `.sstor/.finalised` containing exactly two lines:
   ```
   <requestId>
   <sha>
   ```
   If any step failed, do **not** write the marker. Explain what failed; sstor will stop and report instead of marking the PR ready or merging.
