#!/usr/bin/env bash
# SessionStart hook: in a cloud/routine session (CLAUDE_CODE_REMOTE set) whose checkout has no node_modules, install the
# dependencies with the pnpm version pinned in package.json's packageManager, from the frozen lockfile, so lint,
# typecheck and tests can run before any push. Time-boxed; prints its result and never fails the session.
[[ -n "${CLAUDE_CODE_REMOTE:-}" ]] || exit 0
root="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
cd "$root" || exit 0
[[ -f package.json ]] || exit 0
[[ -d node_modules ]] && { echo "session install: node_modules present, skipped"; exit 0; }
pm=$(python3 -c 'import json; print(json.load(open("package.json")).get("packageManager",""))' 2>/dev/null)
[[ "$pm" == pnpm@* ]] || { echo "session install: packageManager is not pnpm (${pm:-unset}), skipped"; exit 0; }
log=$(mktemp)
export npm_config_cache="${TMPDIR:-/tmp}/npm-cache"
if timeout 600 npx --yes "$pm" install --frozen-lockfile >"$log" 2>&1; then
  echo "session install: $pm install --frozen-lockfile succeeded"
else
  echo "session install: $pm install failed or timed out (lint, typecheck and tests may not run; the pre-push gate will block): $(tail -n 3 "$log" | tr '\n' ' ' | cut -c1-300)"
fi
rm -f "$log"
exit 0
