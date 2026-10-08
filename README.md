# Haiku-Worker

`/orchestrate`: a Claude Code skill that splits a big task into many small tasks and runs them on lean
**Claude Haiku 5.5** workers (xhigh effort, no CLAUDE.md/skills/MCP, 100k context cap), in quality-gated waves.

- The orchestrator is whatever model your session uses.
- Wave 1 = base work. The orchestrator then REVIEWS it against a written quality bar; if it fails, later waves redo only the failed tasks with the reviewer's findings. Default max 4 waves (say "max N waves" to change). At the cap without approval it asks whether to do the work itself.
- Workers get only a short brief file; hooks enforce that and log each worker's peak context to `.orchestrator/usage.jsonl`.

## Install
```
./install.sh
```
then merge `settings.snippet.json` into `~/.claude/settings.json` (Haiku 5.5 xhigh + 100k auto-compact + SubagentStop logging hook). Requires Claude Code >= 2.1.288.

## Use
`/orchestrate <big task> [max N waves]`

See `skills/orchestrate/README.md` for details and measured behavior.
