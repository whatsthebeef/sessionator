# Review-only workflow (`mode = review`)

Read this when: `mode = review` (`/run-glob --review`). It adds to `.claude/agents/orchestrator.md`; where the two differ, this guide wins for the run.

The input is a **glob ID** or a **commit SHA**. Do **not** modify any code.

1. **Context.**
   - **Glob ID** (matches `s<digits><letter><digits>`): `get_glob(id)` and `get_context(id)`, fetch the board knowledge, then `git fetch origin <id> <base>` and review `origin/<base>...origin/<id>`. If the branch no longer exists (merged and deleted), find the squash commit with `git log origin/<base> --grep='^<id>: '` and review that. Write `.reviews/<id>-context.md` with the glob details, plan.md and the commit summary.
   - **Commit SHA** (hex): verify it with `git cat-file -t <sha>` (if missing, **stop and report the error**), use `id = review-<short-sha>` (first 8 chars), and write `.reviews/<id>-context.md` from `git show --stat <sha>`. If the message starts with a glob ID, also fetch that glob's context. Fetch the knowledge for the board in `.slop/slop.conf` (`SLOP_BOARD`).
2. **Code review.** Invoke the **change_reviewer** in `standalone_review` mode with the context, the diff, every board doc whose audience includes it, the build doc, the base branch and the server URL if any. It writes `.reviews/<id>-review.md` and also runs the build, test, lint and dependency checks from the build doc.
3. **Report.** When keyed by a glob, push the review with `put_artifact(id, kind: 'local_review', content, commitSha)`. Summarise for the developer: in-scope items and suggestions, build/test/lint results, dependency warnings, and the verdict (APPROVED / CHANGES_REQUIRED).
