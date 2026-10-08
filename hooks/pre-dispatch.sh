#!/usr/bin/env bash
# PreToolUse (Agent|Task) hook for the /orchestrate pipeline.
# Inert unless subagent_type == "worker". Enforces: short prompt that points at a brief file,
# brief file exists and is small, and the model param is dropped so worker.md's pin (Haiku 5.5) applies.
exec python3 -I -c '
import json, os, re, sys
d = json.load(sys.stdin)
ti = d.get("tool_input") or {}
if ti.get("subagent_type") != "worker":
    sys.exit(0)
def deny(msg):
    print(json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse",
        "permissionDecision": "deny", "permissionDecisionReason": msg}}))
    sys.exit(0)
prompt = ti.get("prompt", "")
if len(prompt) > 1500:
    deny("Worker prompt too long. Put the task in .orchestrator/<run>/tasks/<id>.brief.md and make the prompt a one-line pointer to it.")
m = re.search(r"(\.orchestrator/[^\s\"\x27`]+\.brief\.md)", prompt)
if not m:
    deny("Worker prompt must reference a brief file path like .orchestrator/<run>/tasks/<id>.brief.md.")
path = os.path.join(d.get("cwd") or ".", m.group(1))
if not os.path.isfile(path):
    deny("Brief file not found: " + m.group(1) + ". Write it before dispatching.")
if os.path.getsize(path) > 24000:
    deny("Brief is over ~6k tokens. Split the task into smaller tasks (list input paths instead of inlining content).")
new = {k: v for k, v in ti.items() if k != "model"}
print(json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse",
    "permissionDecision": "allow", "updatedInput": new}}))
'
