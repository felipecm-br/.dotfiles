#!/usr/bin/env sh
# keybindings-picker.sh — interactive keybindings & workflow HUD via Waymaker.
# Invoke: prefix+? -> run-shell "keybindings-picker.sh '#{pane_id}' '#{pane_current_path}'"
set -u

REAL_SCRIPT=$(readlink -f "$0" 2>/dev/null || realpath "$0")

if [ -z "${TMUX_POPUP:-}" ]; then
  ORIGIN_ARG="${1:-}"
  CWD_ARG="${2:-$PWD}"

  YELLOW_COLOR=$(grep -E '^\s*yellow\s*=' "$HOME/.local/state/omarchy/current/theme/colors.toml" 2>/dev/null | head -n1 | sed -E 's/.*=\s*"([^"]+)".*/\1/')
  [ -n "$YELLOW_COLOR" ] || YELLOW_COLOR="#f9e2af"

  tmux display-popup \
    -S "fg=$YELLOW_COLOR" \
    -s "fg=default" \
    -b rounded \
    -T " 󰌌 " \
    -w 85% -h 75% \
    -E \
    "TMUX_POPUP=1 '$REAL_SCRIPT' '$ORIGIN_ARG' '$CWD_ARG'" || true
  exit 0
fi

[ -n "${TMUX:-}" ] || { echo "keybindings-picker: not inside tmux" >&2; exit 1; }
ORIGIN="${1:-}"
if [ -z "$ORIGIN" ]; then
  ORIGIN="$(tmux display-message -p -t '{last}' '#{pane_id}' 2>/dev/null || true)"
fi
export WM_ORIGIN_PANE="$ORIGIN"
export WM_ORIGIN_CWD="${2:-$PWD}"
export MM_ORIGIN_PANE="$ORIGIN"
export MM_ORIGIN_CWD="${2:-$PWD}"

WM_BIN="$HOME/.local/bin/wm"
[ -x "$WM_BIN" ] || WM_BIN="$(command -v wm 2>/dev/null || command -v mm 2>/dev/null || echo wm)"

exec "$WM_BIN" -o keybindings
