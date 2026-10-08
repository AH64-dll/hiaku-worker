#!/usr/bin/env bash
# SubagentStop hook for /orchestrate. Inert unless agent_type == "worker".
# Parallel dispatch is async, so PostToolUse has no usage; measure context size from the worker transcript here.
exec python3 -I -c '
import json, os, sys, time
d = json.load(sys.stdin)
cwd = d.get("cwd") or "."
if os.environ.get("ORCH_DEBUG"):
    os.makedirs(os.path.join(cwd, ".orchestrator"), exist_ok=True)
    open(os.path.join(cwd, ".orchestrator", "debug-stop.jsonl"), "a").write(json.dumps(d)[:4000] + "\n")
if d.get("agent_type") != "worker":
    sys.exit(0)
path = d.get("agent_transcript_path") or d.get("transcript_path")
last = peak = 0
turns = 0
try:
    for line in open(path):
        try: e = json.loads(line)
        except Exception: continue
        m = e.get("message") or {}
        u = m.get("usage") if isinstance(m, dict) else None
        if e.get("type") == "assistant" and u:
            ctx = (u.get("input_tokens") or 0) + (u.get("cache_read_input_tokens") or 0) + (u.get("cache_creation_input_tokens") or 0)
            last = ctx; peak = max(peak, ctx); turns += 1
except Exception as ex:
    last = peak = -1
if turns == 0 and peak == 0:
    sys.exit(0)
os.makedirs(os.path.join(cwd, ".orchestrator"), exist_ok=True)
with open(os.path.join(cwd, ".orchestrator", "usage.jsonl"), "a") as f:
    f.write(json.dumps({"ts": int(time.time()), "event": "worker_stop", "agent_id": d.get("agent_id"),
        "peak_context_tokens": peak, "last_context_tokens": last, "turns": turns}) + "\n")
if peak > 80000:
    print(json.dumps({"systemMessage": f"Worker context peaked at {peak} tokens (>80k of the 100k cap). Make remaining tasks smaller."}))
'
