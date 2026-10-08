# sessionator

Dotfiles and the `sstor` script, which runs one tmux session and git worktree per slop glob.

## sstor and globs

- `sstor --glob <id>` / `sstor --new "<prompt>"` pick up (or create) a glob, make its worktree on
  the glob's branch and launch `/run-glob`. `--env <name>` sets the glob's environment; with
  `--deploy` it deploys there instead (`.sstor/deploy.sh <env>`, with `SLOP_ENV` set).
- **One glob per instance.** The glob ID is recorded in `<worktree>/.sstor/glob`, and a Claude Code
  PreToolUse hook (`scripts/sstor_glob_guard.py`, installed into the instance's
  `.claude/settings.local.json` by `sstor init`) blocks `git checkout`, `git switch` and
  `git worktree add` to another glob's branch. Start other work with `sstor --glob <other>`. The
  hook does nothing where `.sstor/glob` is absent (routines, plain checkouts).
- `--ready`, `--checkpoint`, `--merge` and `--derge` fail fast: they stop at once, saying where the
  glob's branch is checked out (`git worktree list`), when the worktree isn't on the glob's branch
  or Claude isn't running in the `<session>:claude` window, instead of waiting for a `/finalise`
  marker that won't come.
- `sstor --checkpoint` (for a super): `/finalise`, slop's merge-and-continue (printed as not
  available yet until slop provides it, s15f3), then merge `origin/<base>` into the glob branch and
  push.

- `sstor --glob <id> --resolve` fixes a merge conflict with the base branch in your own mergetool
  (slop's card suggests it when its remote resolution fails). It uses the glob's worktree (making it
  if needed), refuses uncommitted changes, fetches, requires the branch to be at `origin/<id>`, and
  merges `origin/<base>` (the base is origin's default branch; override with `SSTOR_BASE`). A clean
  merge is committed and pushed without a tool; on conflicts it runs `git mergetool` (your
  `merge.tool`; if none is set it says so and uses git's default), checks no conflict markers remain,
  runs `SSTOR_CHECKS` if set (sstor has no fast-check list of its own, so otherwise it says it
  skipped them), commits `<id>: Merge <base>` and runs `git push origin <id>`. If you abort the
  mergetool the merge stays in progress: `git mergetool` continues it, `git merge --abort` drops it.
  It never launches Claude or a routine and never force-pushes. Tests:
  `python3 -m unittest scripts/test_sstor_resolve.py`.

- **Local servers.** The board's local-run spec (`{ "build"?, "launch" }`, board data in slop) reaches
  the checkout as `.sstor/local-run.json` through `slop init`. A new session's server window runs
  `build && launch` with `SLOP_GLOB`, `SLOP_ENV`, `SLOP_BOARD`, `SLOP_WORKTREE` and `SLOP_URL_FILE`
  set. sstor does no port handling: the launch script picks its ports (`scripts/sstor-port <base>`
  prints the first free one) and writes its URL to `$SLOP_URL_FILE` (`.sstor/.url`). The old
  `SERVER_BUILD`/`SERVER_CMD`/`PORT_BASE`/`SERVER_URL_TEMPLATE` keys in `.sstor/sstor.conf` still work
  for one release, with a deprecation warning, only when `.sstor/local-run.json` is absent.

Run `sstor --help` for every option.
