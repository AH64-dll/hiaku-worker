#!/usr/bin/env bash
# Installs /orchestrate into ~/.claude (user scope). Does NOT edit settings.json; merge settings.snippet.json yourself.
set -e
D="$(cd "$(dirname "$0")" && pwd)"; C="$HOME/.claude"
mkdir -p "$C/skills/orchestrate" "$C/agents" "$C/orchestrator/hooks"
cp "$D/skills/orchestrate/"* "$C/skills/orchestrate/"
cp "$D/agents/worker.md" "$C/agents/"
cp "$D/hooks/"*.sh "$C/orchestrator/hooks/"; chmod +x "$C/orchestrator/hooks/"*.sh
sed -i "s|/home/amrhares|$HOME|g" "$C/skills/orchestrate/SKILL.md"
echo "Installed. Now merge settings.snippet.json into $C/settings.json, then run: /orchestrate <task>"
