#!/usr/bin/env bash
# SessionStart hook: in a cloud/routine session (CLAUDE_CODE_REMOTE set) whose checkout has no node_modules, install the
# dependencies so lint, typecheck and tests can run before any push: the repo's own executable `.slop/install.sh` when it
# has one, else the pnpm or yarn version pinned in package.json's packageManager, from the frozen lockfile. Time-boxed;
# prints its result and never fails the session.
[[ -n "${CLAUDE_CODE_REMOTE:-}" ]] || exit 0
root="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
cd "$root" || exit 0
[[ -d node_modules ]] && { echo "session install: node_modules present, skipped"; exit 0; }
log=$(mktemp)
export npm_config_cache="${TMPDIR:-/tmp}/npm-cache"
export YARN_CACHE_FOLDER="${TMPDIR:-/tmp}/yarn-cache"
run() {
  local what=$1
  shift
  if timeout 600 "$@" >"$log" 2>&1; then
    echo "session install: $what succeeded"
  else
    echo "session install: $what failed or timed out (lint, typecheck and tests may not run): $(tail -n 3 "$log" | tr '\n' ' ' | cut -c1-300)"
  fi
}
if [[ -x .slop/install.sh ]]; then
  run ".slop/install.sh" .slop/install.sh
elif [[ ! -f package.json ]]; then
  :
else
  pm=$(python3 -c 'import json; print(json.load(open("package.json")).get("packageManager",""))' 2>/dev/null)
  case "$pm" in
    pnpm@*) run "$pm install --frozen-lockfile" npx --yes "$pm" install --frozen-lockfile ;;
    yarn@1.*) run "$pm install --frozen-lockfile" npx --yes "$pm" install --frozen-lockfile ;;
    yarn@*) run "$pm install --immutable" npx --yes "$pm" install --immutable ;;
    *) echo "session install: packageManager is not pnpm or yarn (${pm:-unset}) and there is no .slop/install.sh, skipped" ;;
  esac
fi
rm -f "$log"
exit 0
