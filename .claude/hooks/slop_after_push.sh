#!/usr/bin/env bash
# PostToolUse hook (Bash): after a git push, remind Claude to update the postplan.
# Best effort only; sstor --ready and --derge guarantee it through /finalise.
input=$(cat)
command=$(printf '%s' "$input" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input", {}).get("command", ""))' 2>/dev/null)

# Only an actual git push (at the start of a line or after && ; ||), not the words inside other text.
printf '%s' "$command" | python3 -c 'import re,sys; sys.exit(0 if re.search(r"(^|&&|;|\|\|)\s*git\s+push\b", sys.stdin.read(), re.M) else 1)' || exit 0

cat <<'EOF'
{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"You just pushed. If this glob is a super, update .reviews/<id>-postplan.md and send it with put_artifact (kind: postplan, commitSha: the pushed HEAD)."}}
EOF
