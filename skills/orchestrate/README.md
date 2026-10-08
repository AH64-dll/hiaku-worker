# /orchestrate

Splits a big task into small self-contained tasks, runs each on a lean `worker` subagent
(Haiku 5.5, xhigh effort, no CLAUDE.md/AGENTS.md/skills/MCP, 100k compaction cap) and synthesizes.
The orchestrator is whatever model the current session uses.

Pieces
- skills/orchestrate/SKILL.md  protocol + PreToolUse/PostToolUse hooks (active only while the skill runs)
- agents/worker.md             Haiku 5.5, effort xhigh, omitClaudeMd, minimal tools, maxTurns 30
- orchestrator/hooks/pre-dispatch.sh   worker dispatches must point at a small brief file; drops `model` so worker.md's pin applies
- orchestrator/hooks/post-dispatch.sh  logs usage for foreground workers
- orchestrator/hooks/subagent-stop.sh  (registered in settings.json, ignores non-worker agents) logs peak worker context to .orchestrator/usage.jsonl
- settings.json modelSettings["claude-haiku-5-5"]: effortLevel xhigh, autoCompactWindow 100000 (backup: settings.json.bak-orchestrate)

Debug: ORCH_DEBUG=1 dumps raw hook payloads into .orchestrator/debug-*.jsonl.
Measured: empty worker ~4.5k tokens (omitClaudeMd saves ~1.6k); a task needing >100k in context fails with "Autocompact is thrashing" instead of exceeding the cap.

## Waves (v2)
1. Orchestrator writes `quality.md` (the quality bar) before anything runs.
2. Wave 1 = base work (`.orchestrator/<run>/w1/`). Then the orchestrator REVIEWS it (reads results, spot-checks sources, runs scripts) and writes `review-w1.md`.
3. Pass -> deliver. Fail -> wave 2 redoes only failed tasks with the reviewer's findings in each brief (`w2/`), then review again; and so on.
4. Max 4 waves by default (wave 1 + 3 improvement waves). Override in the task text: "max 6 waves", "waves=2", "single pass".
5. Cap reached and still not approved -> it shows the best version + unmet items and ASKS whether to do the work itself.
6. The orchestrator is told the workers' strengths/limits (100k context, 30 turns, weaker on long tasks) and fans out many narrow tasks accordingly.
