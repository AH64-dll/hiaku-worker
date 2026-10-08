#!/usr/bin/env bash
# PostToolUse (Agent|Task) hook for the /orchestrate pipeline.
# For worker subagents: log token usage to .orchestrator/usage.jsonl and warn the orchestrator
# when a worker used >80k tokens (cap is 100k).
exec python3 -I -c '
import json, os, sys, time
d = json.load(sys.stdin)
ti = d.get("tool_input") or {}
if ti.get("subagent_type") != "worker":
    sys.exit(0)
r = d.get("tool_response") or {}
if not isinstance(r, dict):
    r = {}
if r.get("status") == "async_launched":
    sys.exit(0)  # usage is logged by subagent-stop.sh
usage = r.get("usage") or {}
total = r.get("totalTokens")
if total is None:
    total = sum(v for v in usage.values() if isinstance(v, int))
cwd = d.get("cwd") or "."
if os.environ.get("ORCH_DEBUG"):
    os.makedirs(os.path.join(cwd, ".orchestrator"), exist_ok=True)
    open(os.path.join(cwd, ".orchestrator", "debug-post.jsonl"), "a").write(json.dumps(d)[:6000] + "\n")
os.makedirs(os.path.join(cwd, ".orchestrator"), exist_ok=True)
with open(os.path.join(cwd, ".orchestrator", "usage.jsonl"), "a") as f:
    f.write(json.dumps({"ts": int(time.time()), "tool_use_id": d.get("tool_use_id"),
        "description": ti.get("description"), "totalTokens": total, "usage": usage}) + "\n")
if isinstance(total, int) and total > 80000:
    print(json.dumps({"hookSpecificOutput": {"hookEventName": "PostToolUse",
        "additionalContext": f"Worker used {total} tokens (>80k of the 100k cap). Make remaining tasks smaller."}}))
'
