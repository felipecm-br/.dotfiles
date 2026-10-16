#!/usr/bin/env bash
# reopen-window.sh — reopens the most recently closed Tmux window/tab with its file, path, session & exact position
set -euo pipefail

STATE_DIR="$HOME/.local/state/tmux"
STACK_FILE="$STATE_DIR/closed-windows.json"

if [ ! -f "$STACK_FILE" ] || [ ! -s "$STACK_FILE" ] || ! jq -e . "$STACK_FILE" >/dev/null 2>&1; then
  tmux display-message -d 1500 "󰅙 No closed tabs to reopen"
  exit 0
fi

# Pop the top entry from the stack
TOP_ITEM=$(jq '.[0] // empty' "$STACK_FILE" 2>/dev/null || true)
if [ -z "$TOP_ITEM" ] || [ "$TOP_ITEM" = "null" ]; then
  tmux display-message -d 1500 "󰅙 No closed tabs to reopen"
  exit 0
fi

# Remove the popped entry from stack atomically
tmp_file="${STACK_FILE}.${$}.tmp"
if jq '.[1:]' "$STACK_FILE" > "$tmp_file" 2>/dev/null; then
  mv "$tmp_file" "$STACK_FILE"
else
  rm -f "$tmp_file"
fi

# Extract fields
session=$(echo "$TOP_ITEM" | jq -r '.session // empty')
index=$(echo "$TOP_ITEM" | jq -r '.index // empty')
name=$(echo "$TOP_ITEM" | jq -r '.name // empty')
path=$(echo "$TOP_ITEM" | jq -r '.path // empty')
cmd=$(echo "$TOP_ITEM" | jq -r '.cmd // empty')
file=$(echo "$TOP_ITEM" | jq -r '.file // empty')
agent_title=$(echo "$TOP_ITEM" | jq -r '.agent_title // empty')
agent_state=$(echo "$TOP_ITEM" | jq -r '.agent_state // empty')

# Directory validation
if [ -z "$path" ] || [ ! -d "$path" ]; then
  path="$HOME"
fi

[ -z "$name" ] && name="restored"

current_session=$(tmux display-message -p '#{session_name}' 2>/dev/null || true)

# Resolve target session
if [ -n "$session" ] && tmux has-session -t "$session" 2>/dev/null; then
  target_session="$session"
elif [ -n "$current_session" ] && [ "$current_session" != "_popups" ]; then
  target_session="$current_session"
elif [ -n "$session" ]; then
  # Recreate session if it died
  tmux new-session -d -s "$session" -c "$path" 2>/dev/null || true
  target_session="$session"
else
  target_session="$(tmux display-message -p '#{session_name}')"
fi

# Create new window in target session at the exact original index
new_win=""
if [ -n "$index" ] && [ "$index" != "null" ] && [[ "$index" =~ ^[0-9]+$ ]]; then
  # If index is 0 and window 0 currently exists: insert before window 0
  if [ "$index" -eq 0 ] && tmux list-windows -t "$target_session" -F '#{window_index}' 2>/dev/null | grep -q '^0$'; then
    new_win=$(tmux new-window -b -P -F '#{window_id}' -t "${target_session}:0" -c "$path" -n "$name" 2>/dev/null || true)
  # If index > 0 and predecessor window exists: insert after predecessor (index - 1)
  elif [ "$index" -gt 0 ] && tmux list-windows -t "$target_session" -F '#{window_index}' 2>/dev/null | grep -q "^$(( index - 1 ))$"; then
    new_win=$(tmux new-window -a -P -F '#{window_id}' -t "${target_session}:$(( index - 1 ))" -c "$path" -n "$name" 2>/dev/null || true)
  # If target index is currently vacant: create directly at index
  elif ! tmux list-windows -t "$target_session" -F '#{window_index}' 2>/dev/null | grep -q "^${index}$"; then
    new_win=$(tmux new-window -P -F '#{window_id}' -t "${target_session}:${index}" -c "$path" -n "$name" 2>/dev/null || true)
  fi
fi

# Fallback: create window at end and move to target index if needed
if [ -z "$new_win" ]; then
  new_win=$(tmux new-window -P -F '#{window_id}' -t "${target_session}:" -c "$path" -n "$name")
  if [ -n "$index" ] && [ "$index" != "null" ] && [[ "$index" =~ ^[0-9]+$ ]]; then
    tmux move-window -s "$new_win" -t "${target_session}:${index}" 2>/dev/null || true
  fi
fi

# Ensure window name is preserved
if [ -n "$name" ] && [ "$name" != "null" ]; then
  tmux rename-window -t "$new_win" "$name" 2>/dev/null || true
fi

# Restore agent metadata if recorded
if [ -n "$agent_title" ] && [ "$agent_title" != "null" ]; then
  tmux set-option -w -t "$new_win" @ai_agent_title "$agent_title" 2>/dev/null || true
fi
if [ -n "$agent_state" ] && [ "$agent_state" != "null" ]; then
  tmux set-option -w -t "$new_win" @ai_agent_state_raw "$agent_state" 2>/dev/null || true
fi

# Launch active command or file if applicable
if [ -n "$cmd" ]; then
  tmux send-keys -t "$new_win" "$cmd" C-m
elif [ -n "$file" ]; then
  tmux send-keys -t "$new_win" "nvim $(printf '%q' "$file")" C-m
fi

# Switch focus to the newly restored window
tmux select-window -t "$new_win"
if [ "$target_session" != "$current_session" ]; then
  tmux switch-client -t "$target_session" 2>/dev/null || true
fi

# Auditory & visual feedback
label="$name"
if [ -n "$file" ]; then
  label="$(basename "$file")"
elif [ -n "$cmd" ]; then
  label="$cmd"
fi

idx_str=""
if [ -n "$index" ] && [ "$index" != "null" ]; then
  idx_str="Tab $index · "
fi

tmux display-message -d 2000 "󰁯 Reopened ${idx_str}${label} (${path})"

# Optional ACPD bell sound notification
curl -s -X POST http://localhost:4040/rpc -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"bell","params":{},"id":1}' >/dev/null 2>&1 || true
