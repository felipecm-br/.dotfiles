#!/usr/bin/env bash
# toggle-ai-split.sh — Toggle a 35% right-side AI agent split pane (Prefix + o)
#
# If the current window has >1 pane, closes the adjacent pane (:+.); otherwise opens
# a 35% right split in the current directory running `ai-launch --auto` (quota-aware
# recommended agent and model; honors $AI_LAUNCH_AGENT and ignores Claude's $AI_AGENT).
set -euo pipefail

PROJECT_DIR="${1:-}"
if [ -z "$PROJECT_DIR" ]; then
  PROJECT_DIR=$(tmux display-message -p '#{pane_current_path}' 2>/dev/null || pwd)
fi

pane_cnt=$(tmux list-panes 2>/dev/null | wc -l)
if [ "$pane_cnt" -gt 1 ]; then
  exec tmux kill-pane -t :.+
fi

LAUNCH_BIN="$HOME/.local/bin/ai-launch"
[ -x "$LAUNCH_BIN" ] || LAUNCH_BIN=$(command -v ai-launch 2>/dev/null || echo "")

if [ -n "$LAUNCH_BIN" ]; then
  cmd=$(printf 'exec %q --auto' "$LAUNCH_BIN")
else
  agent_cmd=$(command -v agy >/dev/null 2>&1 && echo agy || echo opencode)
  cmd="exec $agent_cmd"
fi

exec tmux split-window -h -l 35% -c "$PROJECT_DIR" "$cmd"
