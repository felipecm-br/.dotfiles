#!/usr/bin/env sh
# window-picker-create.sh — helper script to create a new window in window-picker
# Creates a new window inside the session/group of the currently selected item or header.

RAW_INPUT=$(cat)
session=""

if [ -n "$RAW_INPUT" ]; then
  first_line=$(printf '%s' "$RAW_INPUT" | head -n1)

  # 1. If cursor is on a window row: format is title \t idx \t name \t session \t display
  session=$(printf '%s' "$first_line" | cut -f4)

  # 2. If cursor is on a session group header: format is '#  <session_name>'
  if [ -z "$session" ] || [ "$session" = "$first_line" ]; then
    header_sess=$(printf '%s' "$first_line" | sed -E 's/^#[[:space:]]*//')
    if [ -n "$header_sess" ] && tmux has-session -t "$header_sess" 2>/dev/null; then
      session="$header_sess"
    fi
  fi
fi

# 3. Fallback: Origin session or current active session
if [ -z "$session" ] || ! tmux has-session -t "$session" 2>/dev/null; then
  session="${TMUX_ORIGIN_SESSION:-$(tmux display-message -p '#S')}"
fi

# 4. Resolve working directory of the target session to preserve context
session_dir=$(tmux display-message -t "${session}:" -p '#{pane_current_path}' 2>/dev/null || true)

if [ -n "$session_dir" ] && [ -d "$session_dir" ]; then
  tmux new-window -c "$session_dir" -t "${session}:" 2>/dev/null || tmux new-window -t "${session}:" 2>/dev/null || true
else
  tmux new-window -t "${session}:" 2>/dev/null || true
fi
