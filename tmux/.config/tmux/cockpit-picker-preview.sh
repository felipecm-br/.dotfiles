#!/usr/bin/env bash
# cockpit-picker-preview.sh — render bottom-anchored live terminal pane preview
set -uo pipefail

if [[ -x "$HOME/.local/bin/waymux" ]]; then
  exec "$HOME/.local/bin/waymux" cockpit-preview "$@"
elif command -v waymux >/dev/null 2>&1; then
  exec waymux cockpit-preview "$@"
fi

session="${1:-}"
idx="${2:-}"
pane_id="${3:-}"
ppath="${4:-}"

if [ -z "$session" ] || [ -z "$idx" ] || [ "$idx" = "-" ]; then
  printf "  \033[38;2;146;131;116m(no active window selected)\033[0m\n"
  exit 0
fi

# Fallback resolution only if not passed from items
if [ -z "$pane_id" ] || [ "$pane_id" = "-" ]; then
  pane_id=$(tmux display-message -p -t "${session}:${idx}" '#{pane_id}' 2>/dev/null || echo "")
fi
if [ -z "$ppath" ] || [ "$ppath" = "-" ]; then
  ppath=$(tmux display-message -p -t "${session}:${idx}" '#{pane_current_path}' 2>/dev/null || echo "")
fi

# Single capture-pane call (captures 120 lines of scrollback + active screen)
# Strips ANSI underline attributes (SGR 4 / 24 / 4:x) to prevent distracting underlines on AI links/paths
raw_terminal=$(tmux capture-pane -ep -S -120 -t "$pane_id" 2>/dev/null | sed -E 's/\x1b\[(4|24|21|4:[0-9]+)m//g; s/\x1b\[4;([0-9;]+m)/\x1b[\1/g; s/\x1b\[([0-9;]+);4([;m])/\x1b[\1\2/g' || true)

# Render Bottom Terminal Snapshot (most up-to-date conversation scrollback)
if [ -n "$raw_terminal" ]; then
  printf '%s\n' "$raw_terminal" | awk '/[^[:space:]]/{last=NR} {lines[NR]=$0} END{for(i=1;i<=last;i++) print lines[i]}'
else
  printf "  \033[38;2;71;82;88m(pane output empty or detached)\033[0m\n"
fi

# Render Lazygitrs AI Review Notes Section at bottom (if any pending) so scroll.tail=true keeps it visible
notes_out=$("$HOME/.config/tmux/cockpit-review-notes.sh" list "$ppath" 2>/dev/null || true)
if [ -n "$notes_out" ]; then
  printf "\n%s\n" "$notes_out"
fi
