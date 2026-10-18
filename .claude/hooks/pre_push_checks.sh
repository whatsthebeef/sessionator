#!/usr/bin/env bash
# PreToolUse hook (Bash): before a `git push`, run the board's fast checks on what the push changes and block the push
# (exit 2, the failing lines on stderr) when they fail or can't run. Routines and sessions must not push code that fails
# lint, typecheck or the changed tests; `--no-verify` is refused here too. A person can still bypass it by pushing themselves.
#
# Checks: `.sstor/checks.sh <changed files...>` when the repo has it (exit non-zero to block). Otherwise, for a pnpm/npm
# workspace: eslint on the changed TS/JS files, `tsc --noEmit` for each changed package that has a tsconfig.json, and
# vitest for each changed test file. A tool that fails to start (not installed, module not found) blocks the push with
# an "install dependencies" message instead of passing. On every push it inspects, the hook prints one line to stderr
# starting "pre-push gate:" (also when it passes), which the local review copies: a review without it means the gate didn't run.
input=$(cat)
command=$(printf '%s' "$input" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input", {}).get("command", ""))' 2>/dev/null)
# No python3, or an unparsable payload: fall back to the raw input so a push is never missed.
[[ -z "$command" ]] && command="$input"

# A git push at the start of a line or after && ; || | ( ` or $( , with git's global options in between (`git -C dir push`).
push_re='(^|&&|;|\|\||\||\(|`)[[:space:]]*(sudo[[:space:]]+|env[[:space:]]+([A-Za-z_]+=[^[:space:]]*[[:space:]]+)*|[A-Za-z_]+=[^[:space:]]*[[:space:]]+)*git([[:space:]]+(-[Cc][[:space:]]+[^[:space:]]+|--[a-z-]+(=[^[:space:]]+)?|-[a-zA-Z]))*[[:space:]]+push([[:space:]]|$)'
printf '%s' "$command" | grep -qE "$push_re" || exit 0

if printf '%s' "$command" | grep -qE -- '--no-verify'; then
  echo "pre-push: --no-verify is not allowed here. Run the checks and fix what fails." >&2
  exit 2
fi

root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
cd "$root" || exit 0
base=$(git rev-parse --verify -q '@{upstream}' 2>/dev/null || git merge-base HEAD origin/HEAD 2>/dev/null || git rev-parse --verify -q HEAD~1 2>/dev/null) || exit 0
mapfile -t changed < <(git diff --name-only --diff-filter=d "$base" HEAD)
if [[ ${#changed[@]} -eq 0 ]]; then
  echo "pre-push gate: nothing changed since $(git rev-parse --short "$base"): no checks to run" >&2
  exit 0
fi

pm=$(python3 -c 'import json; print(json.load(open("package.json")).get("packageManager","").split("@",1)[-1])' 2>/dev/null)
install_hint="install dependencies (\`npx --yes pnpm@${pm:-<pinned>} install --frozen-lockfile\`) and push again"

out=$(mktemp)
one=$(mktemp)
trap 'rm -f "$out" "$one"' EXIT
fail=0
cannot=0
ran=()
# Runs one check. A check that can't start (tool not installed, module not found) is a failure with its own message.
run() {
  local tool=$1
  shift
  ran+=("$tool")
  : >"$one"
  if "$@" >"$one" 2>&1; then
    cat "$one" >>"$out"
    return
  fi
  cat "$one" >>"$out"
  fail=1
  local cmd="$*"
  echo "FAILED: ${cmd/#tool /npx }" >>"$out"
  if grep -qiE "ERR_MODULE_NOT_FOUND|Cannot find (module|package)|command not found|not found: |could not determine executable|ENOENT|npm error 404|npm ERR! 404|ERR_PNPM" "$one"; then
    cannot=1
    echo "pre-push: $tool could not run ($(grep -iE -m1 'ERR_MODULE_NOT_FOUND|Cannot find|not found|executable|ENOENT|404|ERR_PNPM' "$one" | cut -c1-200)): $install_hint" >>"$out"
  fi
}
# `npx --no-install` so a missing tool fails here instead of downloading an unpinned version.
tool() { npx --no-install "$@"; }

if [[ -x .sstor/checks.sh ]]; then
  run ".sstor/checks.sh" .sstor/checks.sh "${changed[@]}"
else
  mapfile -t code < <(printf '%s\n' "${changed[@]}" | grep -E '\.(ts|tsx|js|jsx|mjs|cjs)$')
  [[ ${#code[@]} -gt 0 ]] && run eslint tool eslint "${code[@]}"
  declare -A pkgs=()
  for f in "${code[@]}"; do
    d=$(dirname "$f")
    while [[ "$d" != "." && ! -f "$d/tsconfig.json" ]]; do d=$(dirname "$d"); done
    [[ -f "$d/tsconfig.json" ]] && pkgs["$d"]=1
  done
  for p in "${!pkgs[@]}"; do run tsc tool tsc -p "$p/tsconfig.json" --noEmit; done
  # Group the changed test files per package and run vitest once per package. Not in a subshell: `run` sets fail=1.
  declare -A tests=()
  for f in "${code[@]}"; do
    [[ "$f" =~ \.(test|spec)\.(ts|tsx|js|jsx)$ ]] || continue
    d=$(dirname "$f")
    while [[ "$d" != "." && ! -f "$d/package.json" ]]; do d=$(dirname "$d"); done
    tests["$d"]+="${f#"$d"/}"$'\n'
  done
  for d in "${!tests[@]}"; do
    mapfile -t files < <(printf '%s' "${tests[$d]}")
    pushd "$d" >/dev/null && { run vitest tool vitest run "${files[@]}"; popd >/dev/null; }
  done
fi

summary="${ran[*]:-no checks}"
summary=${summary// //}
# The server suite needs Postgres: say so when server or core code changed and it isn't reachable.
note=""
if printf '%s\n' "${changed[@]}" | grep -qE '^(apps/server|packages/core)/.*\.(ts|tsx)$'; then
  if [[ -z "${DATABASE_URL:-}" ]] && ! { command -v pg_isready >/dev/null && pg_isready -q 2>/dev/null; }; then
    note="; server tests: not run (no Postgres)"
  fi
fi

if [[ $fail -ne 0 ]]; then
  {
    echo "pre-push gate: ${summary} on ${#changed[@]} files: FAILED${note}"
    if [[ $cannot -ne 0 ]]; then
      echo "pre-push: a check could not run, push blocked. Install dependencies, then push again."
    else
      echo "pre-push: checks failed, push blocked. Fix the failures, commit and push again."
    fi
    tail -n 60 "$out"
  } >&2
  exit 2
fi
echo "pre-push gate: ${summary} on ${#changed[@]} files: passed${note}" >&2
exit 0
