#!/usr/bin/env sh
# window-picker-create.sh — helper script to create a new window in window-picker
# Creates a new window inside the session/group of the currently selected item or header.

RAW_INPUT=$(cat)
session=""

if [ -n "$RAW_INPUT" ]; then
  first_line=$(printf '%s' "$RAW_INPUT" | head -n1)

  # 1. If cursor is on a window row: format is title \t idx \t name \t session [\t pid \t path ...]
  session=$(printf '%s' "$first_line" | cut -f4)
  candidate_path=$(printf '%s' "$first_line" | cut -f6)
  if [ -n "$candidate_path" ] && [ -d "$candidate_path" ]; then
    row_path="$candidate_path"
  fi

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

# 4. Resolve working directory of the target session to preserve context if row_path not set
if [ -z "$row_path" ]; then
  session_dir=$(tmux display-message -t "${session}:" -p '#{pane_current_path}' 2>/dev/null || true)
  if [ -n "$session_dir" ] && [ -d "$session_dir" ]; then
    row_path="$session_dir"
  fi
fi

# 5. Create new window in target session with preserved working directory
new_target=""
if [ -n "$row_path" ] && [ -d "$row_path" ]; then
  new_target=$(tmux new-window -P -F '#{session_name}:#{window_index}' -c "$row_path" -t "${session}:" 2>/dev/null || tmux new-window -P -F '#{session_name}:#{window_index}' -t "${session}:" 2>/dev/null || true)
else
  new_target=$(tmux new-window -P -F '#{session_name}:#{window_index}' -t "${session}:" 2>/dev/null || true)
fi

if [ -n "$new_target" ]; then
  tmux switch-client -t "$new_target" 2>/dev/null || true
  printf '%s\n' "$new_target"
fi
