#!/usr/bin/env bash
# workmux-dashboard-popup.sh — Floating Workmux Dashboard Popup Modal with dynamic Omarchy palette
# Launches the workmux agent fleet dashboard inside a standard Tmux popup.
trap 'exit 0' HUP INT TERM

PROJECT_DIR="."
if [ $# -gt 0 ] && [ -d "$1" ]; then
    PROJECT_DIR="$1"
    shift
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$SCRIPT_DIR/theme-helper.sh"

WORKMUX_BIN="$HOME/.local/bin/workmux"
[ -x "$WORKMUX_BIN" ] || WORKMUX_BIN="$(command -v workmux 2>/dev/null || echo "workmux")"

if ! command -v "$WORKMUX_BIN" >/dev/null 2>&1 && [ ! -x "$WORKMUX_BIN" ]; then
    tmux display-message "workmux not found in PATH"
    exit 0
fi

# Dynamic Theme Inheritance (Primary Accent Palette)
POPUP_COLOR=$(get_theme_color accent "$(get_theme_color blue "#7aa2f7")")

if [ -n "$TMUX" ]; then
    exec tmux display-popup \
      -S "fg=$POPUP_COLOR" \
      -s "fg=${TMUX_POPUP_TEXT_COLOR:-default}" \
      -b rounded \
      -T " 󱙝 " \
      -d "$PROJECT_DIR" \
      -E \
      -w 85% -h 75% \
      "$WORKMUX_BIN" dashboard "$@"
else
    exec "$WORKMUX_BIN" dashboard "$@"
fi
