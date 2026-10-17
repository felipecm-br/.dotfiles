#!/usr/bin/env bash
# agent-action.sh — Guarded agent actions (approval, denial, prompt dispatch) for Cockpit HUD
set -euo pipefail

if [[ -x "$HOME/.local/bin/waymux" ]]; then
  exec "$HOME/.local/bin/waymux" agent-action "$@"
elif command -v waymux >/dev/null 2>&1; then
  exec waymux agent-action "$@"
fi

action="${1:-}"
state="${2:-}"
pid="${3:-}"
shift 3 2>/dev/null || true

# Validate pane id: must start with '%'
if [[ ! "$pid" =~ ^%[0-9]+$ ]]; then
  # Invalid or empty pane ID (e.g. focused on a header row)
  exit 0
fi

case "$action" in
  approve)
    case "$state" in
      permission|question|awaiting_input)
        tmux send-keys -t "$pid" 'y' Enter
        ;;
      *)
        tmux display-message "Action ignored: Pane $pid is not awaiting confirmation (state: ${state:-normal})"
        ;;
    esac
    ;;
  deny)
    case "$state" in
      permission|question|awaiting_input)
        tmux send-keys -t "$pid" 'n' Enter
        ;;
      *)
        tmux display-message "Action ignored: Pane $pid is not awaiting confirmation (state: ${state:-normal})"
        ;;
    esac
    ;;
  prompt)
    prompt_text="$*"
    if [ -n "$prompt_text" ]; then
      tmux send-keys -l -t "$pid" -- "$prompt_text"
      tmux send-keys -t "$pid" Enter
    fi
    ;;
  *)
    echo "Usage: $0 {approve|deny|prompt} <state> <pid> [args...]" >&2
    exit 1
    ;;
esac
