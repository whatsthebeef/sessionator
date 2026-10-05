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

Run `sstor --help` for every option.
