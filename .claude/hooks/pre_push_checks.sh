#!/usr/bin/env bash
# PreToolUse hook (Bash): before a `git push`, run the board's fast checks on what the push changes and block the push
# (exit 2, the failing lines on stderr) when they fail. Routines and sessions must not push code that fails lint,
# typecheck or the changed tests; `--no-verify` is refused here too. A person can still bypass it by pushing themselves.
#
# Checks: `.sstor/checks.sh <changed files...>` when the repo has it (exit non-zero to block). Otherwise, for a pnpm/npm
# workspace: eslint on the changed TS/JS files, `tsc --noEmit` for each changed package that has a tsconfig.json, and
# vitest for each changed test file.
input=$(cat)
command=$(printf '%s' "$input" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input", {}).get("command", ""))' 2>/dev/null)

printf '%s' "$command" | python3 -c 'import re,sys; sys.exit(0 if re.search(r"(^|&&|;|\|\|)\s*git\s+push\b", sys.stdin.read(), re.M) else 1)' || exit 0

if printf '%s' "$command" | grep -qE -- '--no-verify'; then
  echo "pre-push: --no-verify is not allowed here. Run the checks and fix what fails." >&2
  exit 2
fi

root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
cd "$root" || exit 0
base=$(git rev-parse --verify -q '@{upstream}' 2>/dev/null || git merge-base HEAD origin/HEAD 2>/dev/null || git rev-parse --verify -q HEAD~1 2>/dev/null) || exit 0
mapfile -t changed < <(git diff --name-only --diff-filter=d "$base" HEAD)
[[ ${#changed[@]} -eq 0 ]] && exit 0

out=$(mktemp)
trap 'rm -f "$out"' EXIT
fail=0
run() { "$@" >>"$out" 2>&1 || { fail=1; echo "FAILED: $*" >>"$out"; }; }

if [[ -x .sstor/checks.sh ]]; then
  run .sstor/checks.sh "${changed[@]}"
else
  mapfile -t code < <(printf '%s\n' "${changed[@]}" | grep -E '\.(ts|tsx|js|jsx|mjs|cjs)$')
  [[ ${#code[@]} -gt 0 ]] && run npx eslint "${code[@]}"
  declare -A pkgs=()
  for f in "${code[@]}"; do
    d=$(dirname "$f")
    while [[ "$d" != "." && ! -f "$d/tsconfig.json" ]]; do d=$(dirname "$d"); done
    [[ -f "$d/tsconfig.json" ]] && pkgs["$d"]=1
  done
  for p in "${!pkgs[@]}"; do run npx tsc -p "$p/tsconfig.json" --noEmit; done
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
    pushd "$d" >/dev/null && { run npx vitest run "${files[@]}"; popd >/dev/null; }
  done
fi

if [[ $fail -ne 0 ]]; then
  {
    echo "pre-push: checks failed, push blocked. Fix the failures, commit and push again."
    tail -n 60 "$out"
  } >&2
  exit 2
fi
exit 0
