#!/usr/bin/env sh
# files-picker.sh — browse workspace/origin pane's cwd in a popup via mm -o files.
# Invoke: prefix+e (or prefix+C-e) -> run-shell "files-picker.sh '#{pane_id}' '#{pane_current_path}'"
# Enter cycles preview between 60% Golden Ratio and 100% Full-Modal view;
# Tab / Shift+Tab cycles data sources (Local files -> Frecency -> Bookmarks);
# Ctrl+V inserts the path directly into the origin pane (AI prompt);
# Ctrl+E / e opens in $EDITOR;
# y copies the selected path(s) to clipboard.
set -u

LOG=/tmp/files-picker.log

if [ -z "${TMUX_POPUP:-}" ]; then
  # Parse arguments with backwards compatibility
  if [ -n "${1:-}" ] && [ "${1#%}" != "$1" ]; then
    ORIGIN_ARG="$1"
    CWD_ARG="${2:-$HOME}"
    FULLSCREEN_ARG="${3:-}"
  else
    ORIGIN_ARG=""
    CWD_ARG="${1:-$HOME}"
    FULLSCREEN_ARG="${2:-}"
  fi

  BLUE=$(grep -E '^\s*blue\s*=' "$HOME/.local/state/omarchy/current/theme/colors.toml" 2>/dev/null | sed -E 's/.*=\s*"([^"]+)".*/\1/')
  [ -n "$BLUE" ] || BLUE="#89b4fa"

  WIDTH="90%"
  HEIGHT="85%"
  if [ "$FULLSCREEN_ARG" = "--fullscreen" ]; then
    WIDTH="96%"
    HEIGHT="92%"
  fi

  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  ISOLATOR="$SCRIPT_DIR/tmux-popup-isolate.sh"
  [ -x "$ISOLATOR" ] || ISOLATOR="$(command -v tmux-popup-isolate.sh 2>/dev/null || echo "$HOME/.config/tmux/tmux-popup-isolate.sh")"

  exec "$ISOLATOR" \
    -S "fg=$BLUE" \
    -s "fg=default" \
    -b rounded \
    -T " 󰈞 " \
    -w "$WIDTH" -h "$HEIGHT" \
    -E \
    -- "TMUX_POPUP=1 '$0' '$ORIGIN_ARG' '$CWD_ARG' '$FULLSCREEN_ARG'"
fi

[ -n "${TMUX:-}" ] || { echo "files-picker: not inside tmux" >&2; exit 1; }
ORIGIN="${1:-}"
if [ -z "$ORIGIN" ]; then
  ORIGIN="$(tmux display-message -p -t '{last}' '#{pane_id}' 2>/dev/null || true)"
fi
CWD="${2:-$HOME}"
[ -d "$CWD" ] || { tmux display-message "files-picker: directory not found: $CWD"; exit 1; }

export MM_ORIGIN_PANE="$ORIGIN"
export MM_ORIGIN_CWD="$CWD"

MM_BIN="$HOME/.local/bin/wm"
[ -x "$MM_BIN" ] || MM_BIN="$(command -v wm 2>/dev/null || command -v mm 2>/dev/null || echo wm)"

# Prefer dedicated files preset (with 60%/100% layouts and ctrl-v insert), fallback to jump
if "$MM_BIN" --dump-config -o files >/dev/null 2>&1; then
  PRESET="files"
else
  PRESET="jump"
fi

tmux set -p allow-passthrough all 2>/dev/null || true
tmux set -g allow-passthrough all 2>/dev/null || true

chosen="$(cd "$CWD" && "$MM_BIN" -o "$PRESET")" || exit 0
[ -n "$chosen" ] || exit 0

trap '' HUP
{
  echo "$(date '+%T') mm files exited, copying paths"
  if command -v wl-copy >/dev/null 2>&1; then
    printf '%s' "$chosen" | wl-copy
  elif command -v xclip >/dev/null 2>&1; then
    printf '%s' "$chosen" | xclip -in -selection clipboard
  else
    printf '%s' "$chosen" | tmux load-buffer -
  fi
  n="$(printf '%s' "$chosen" | wc -l)"
  tmux display-message "copied ($n): $(printf '%s' "$chosen" | head -n 1)"
} >>"$LOG" 2>&1 </dev/null &
exit 0
