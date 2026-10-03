#!/usr/bin/env sh
# window-picker-preview.sh — render bottom-anchored pane preview with recent history

session="$1"
idx="$2"

if [ -z "$session" ] || [ -z "$idx" ]; then
  printf "  \033[38;2;146;131;116m(no preview)\033[0m\n"
  exit 0
fi

# Capture last 100 history lines plus active pane, stripping trailing blank lines
content=$(tmux capture-pane -ep -S -100 -t "${session}:${idx}" 2>/dev/null)
if [ -z "$content" ]; then
  printf "  \033[38;2;146;131;116m(no preview)\033[0m\n"
  exit 0
fi

printf '%s\n' "$content" | awk '/[^[:space:]]/{last=NR} {lines[NR]=$0} END{for(i=1;i<=last;i++) print lines[i]}'
