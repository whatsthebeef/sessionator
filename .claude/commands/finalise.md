---
name: finalise
description: Bring slop up to date for the current glob before its PR is marked ready or merged (postplan, local review, learnings), then write the completion marker that `sstor --ready` and `sstor --derge` wait for.
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
3. **Postplan (supers only)**: update `.reviews/<id>-postplan.md` from the session conversation and `git diff <base>...HEAD` (structure in the orchestrator's Super mode), then `put_artifact(id, kind: 'postplan', content, commitSha: sha)`.
4. **Local review**: if the glob's artifact list already has a `local_review` for `sha`, skip this step. Otherwise, if `.reviews/<id>-review.md` exists and covers the current changes, push it (with the test report appended if there is one) as `put_artifact(id, kind: 'local_review', content, commitSha: sha)`. If there is no review for the current changes, run the **change_reviewer** in standard mode for one round, then push its document.
5. **Learnings**: if learnings were already submitted for this glob in this session for `sha`, skip. Otherwise extract them as in the orchestrator's Phase 6 step 6 and call `submit_learning` once per learning.
6. **Marker**: only after every call above succeeded, write `.sstor/.finalised` containing exactly two lines:
   ```
   <requestId>
   <sha>
   ```
   If any step failed, do **not** write the marker. Explain what failed; sstor will stop and report instead of marking the PR ready or merging.
