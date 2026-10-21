#!/usr/bin/env bash
# SessionEnd hook: sums the session's tokens per agent (orchestrator, investigator, ...) and model from the transcript and
# reports them to slopmux (`slop call report_usage`) with the glob and run ID, so a glob's runs show what they cost. It sends
# counts only, never content. Board-agnostic and best effort: no transcript, glob, python3 or slop CLI, or a failed call,
# is skipped without a word, and the hook always exits 0 so it can never block the session.
# SLOP_USAGE_DRY_RUN=1 prints the payload instead of sending it.
input=$(cat)
command -v python3 >/dev/null 2>&1 || exit 0

payload=$(
  INPUT="$input" python3 - <<'PY' 2>/dev/null
import glob, json, os, re, subprocess, sys

try:
    hook = json.loads(os.environ.get("INPUT") or "{}")
except ValueError:
    sys.exit(0)
transcript = hook.get("transcript_path")
session = hook.get("session_id")
if not transcript or not session or not os.path.isfile(transcript):
    sys.exit(0)

# The glob is the branch the session works on (`s15t311`), or SLOP_GLOB when a session is started elsewhere.
glob_id = os.environ.get("SLOP_GLOB", "")
if not glob_id:
    try:
        cwd = hook.get("cwd") or os.getcwd()
        glob_id = subprocess.run(["git", "-C", cwd, "rev-parse", "--abbrev-ref", "HEAD"], capture_output=True, text=True, timeout=10).stdout.strip()
    except Exception:
        glob_id = ""
if not re.fullmatch(r"s\d+[a-z]\d+", glob_id):
    sys.exit(0)


def lines(path):
    try:
        with open(path, encoding="utf-8") as f:
            for raw in f:
                try:
                    entry = json.loads(raw)
                except ValueError:
                    continue
                if isinstance(entry, dict):
                    yield entry
    except OSError:
        return


def blocks(entry):
    content = (entry.get("message") or {}).get("content")
    return [b for b in content if isinstance(b, dict)] if isinstance(content, list) else []


# Which agent type each sub-agent run was: the Agent tool call names it (`subagent_type`), its result names the agent ID.
agent_of_call = {}
agent_of_id = {}
for entry in lines(transcript):
    for b in blocks(entry):
        if b.get("type") == "tool_use" and b.get("name") in ("Agent", "Task"):
            agent_of_call[b.get("id")] = (b.get("input") or {}).get("subagent_type") or "general-purpose"
        if b.get("type") == "tool_result":
            result = entry.get("toolUseResult")
            if isinstance(result, dict) and result.get("agentId") and b.get("tool_use_id") in agent_of_call:
                agent_of_id[result["agentId"]] = agent_of_call[b["tool_use_id"]]

sub_dir = os.path.join(os.path.dirname(transcript), session, "subagents")
sources = [(transcript, None)] + [(p, os.path.basename(p)[len("agent-"):-len(".jsonl")]) for p in sorted(glob.glob(os.path.join(sub_dir, "agent-*.jsonl")))]

totals = {}
seen = set()
for path, file_agent_id in sources:
    for entry in lines(path):
        message = entry.get("message")
        if entry.get("type") != "assistant" or not isinstance(message, dict):
            continue
        usage = message.get("usage")
        model = message.get("model")
        if not isinstance(usage, dict) or not isinstance(model, str) or model.startswith("<"):
            continue
        # A streamed reply is written as several lines carrying the same message and request: count it once.
        key = (message.get("id"), entry.get("requestId"))
        if key != (None, None):
            if key in seen:
                continue
            seen.add(key)
        agent_id = file_agent_id or entry.get("agentId")
        if file_agent_id is None and not entry.get("isSidechain"):
            agent = "orchestrator"
        else:
            agent = agent_of_id.get(agent_id, "subagent")
        t = totals.setdefault((agent, model), [0, 0, 0, 0])
        for i, field in enumerate(("input_tokens", "output_tokens", "cache_read_input_tokens", "cache_creation_input_tokens")):
            value = usage.get(field)
            if isinstance(value, int) and value > 0:
                t[i] += value

entries = [
    {"agent": a, "model": m, "inputTokens": t[0], "outputTokens": t[1], "cacheReadTokens": t[2], "cacheWriteTokens": t[3]}
    for (a, m), t in sorted(totals.items())
    if sum(t) > 0
]
if not entries:
    sys.exit(0)
body = {"id": glob_id, "sessionId": session, "entries": entries}
run_id = os.environ.get("SLOP_RUN_ID", "")
if run_id:
    body["runId"] = run_id
print(json.dumps(body, separators=(",", ":")))
PY
)
[[ -n "$payload" ]] || exit 0

if [[ "${SLOP_USAGE_DRY_RUN:-}" == 1 ]]; then
  printf '%s\n' "$payload"
  exit 0
fi
command -v slop >/dev/null 2>&1 || exit 0
timeout 30 slop call report_usage "$payload" >/dev/null 2>&1
exit 0
