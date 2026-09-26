#!/usr/bin/env bash
# close-window.sh — saves current window/pane state and gracefully closes it
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0" 2>/dev/null || realpath "$0")")"
RECORD_SCRIPT="${SCRIPT_DIR}/record-window-state.sh"

TARGET="${1:-}"

# Inspect target pane and window metadata before any action
info=""
if [ -n "$TARGET" ]; then
  info=$(tmux display-message -t "$TARGET" -p '#{pane_id}|#{window_id}|#{session_name}|#{window_panes}|#{window_active}' 2>/dev/null || true)
else
  info=$(tmux display-message -p '#{pane_id}|#{window_id}|#{session_name}|#{window_panes}|#{window_active}' 2>/dev/null || true)
fi

pane_id=""
win_id=""
session_name=""
pane_count=1
is_active=0

if [ -n "$info" ]; then
  IFS='|' read -r pane_id win_id session_name pane_count is_active <<< "$info"
fi

# Fallback target identifiers if info was empty
target_pane="${pane_id:-$TARGET}"
target_win="${win_id:-$TARGET}"

# Record state before closing
if [ -x "$RECORD_SCRIPT" ]; then
  "$RECORD_SCRIPT" --push "${target_pane:-$target_win}" 2>/dev/null || true
fi

# If closing this pane will close the entire window, and this window is currently active:
# Preemptively switch focus to the MRU (last-window) or left neighbor (previous-window)
if [ "${pane_count:-1}" -le 1 ] && [ "${is_active:-0}" = "1" ] && [ -n "$session_name" ]; then
  win_count=$(tmux list-windows -t "$session_name" 2>/dev/null | wc -l)
  if [ "$win_count" -gt 1 ]; then
    tmux select-window -t "$session_name" -l 2>/dev/null \
      || tmux previous-window -t "$session_name" 2>/dev/null \
      || tmux next-window -t "$session_name" 2>/dev/null \
      || true
  fi
fi

# Close the pane / window explicitly by ID
if [ -n "$target_pane" ]; then
  tmux kill-pane -t "$target_pane" 2>/dev/null \
    || tmux kill-window -t "$target_win" 2>/dev/null \
    || true
elif [ -n "$target_win" ]; then
  tmux kill-window -t "$target_win" 2>/dev/null || true
else
  tmux kill-pane 2>/dev/null || tmux kill-window 2>/dev/null || true
fi
