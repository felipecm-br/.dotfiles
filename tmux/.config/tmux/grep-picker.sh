#!/usr/bin/env sh
# grep-picker.sh — live full-text ripgrep in workspace/origin pane's cwd via mm -o rg.
# Invoke: prefix+/ -> run-shell "grep-picker.sh '#{pane_id}' '#{pane_current_path}'"
# Live search as you type (debounced ripgrep query reload);
# Enter opens Neovim directly at the matched line: nvim +{line} {file};
# Ctrl+V inserts {file}:{line} directly into origin pane (AI prompt);
# 45/55 foveal layout with line-synced bat preview;
# Ctrl+P / Ctrl+/ toggles fullscreen preview;
# Esc / q quits.
set -u

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

  BORDER_COLOR=$(grep -E '^\s*(teal|cyan|green)\s*=' "$HOME/.local/state/omarchy/current/theme/colors.toml" 2>/dev/null | head -n1 | sed -E 's/.*=\s*"([^"]+)".*/\1/')
  [ -n "$BORDER_COLOR" ] || BORDER_COLOR="#94e2d5"

  WIDTH="85%"
  HEIGHT="75%"
  if [ "$FULLSCREEN_ARG" = "--fullscreen" ]; then
    WIDTH="96%"
    HEIGHT="92%"
  fi

  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  ISOLATOR="$SCRIPT_DIR/tmux-popup-isolate.sh"
  [ -x "$ISOLATOR" ] || ISOLATOR="$(command -v tmux-popup-isolate.sh 2>/dev/null || echo "$HOME/.config/tmux/tmux-popup-isolate.sh")"

  exec "$ISOLATOR" \
    -S "fg=$BORDER_COLOR" \
    -s "fg=default" \
    -b rounded \
    -T " 󰍉 " \
    -w "$WIDTH" -h "$HEIGHT" \
    -E \
    -- "TMUX_POPUP=1 '$0' '$ORIGIN_ARG' '$CWD_ARG' '$FULLSCREEN_ARG'"
fi

[ -n "${TMUX:-}" ] || { echo "grep-picker: not inside tmux" >&2; exit 1; }
ORIGIN="${1:-}"
if [ -z "$ORIGIN" ]; then
  ORIGIN="$(tmux display-message -p -t '{last}' '#{pane_id}' 2>/dev/null || true)"
fi
CWD="${2:-$HOME}"
[ -d "$CWD" ] || { tmux display-message "grep-picker: directory not found: $CWD"; exit 1; }

export MM_ORIGIN_PANE="$ORIGIN"
export MM_ORIGIN_CWD="$CWD"

MM_BIN="$HOME/.local/bin/wm"
[ -x "$MM_BIN" ] || MM_BIN="$(command -v wm 2>/dev/null || command -v mm 2>/dev/null || echo wm)"

tmux set -p allow-passthrough all 2>/dev/null || true
tmux set -g allow-passthrough all 2>/dev/null || true

cd "$CWD" && exec "$MM_BIN" --no-read -o rg
