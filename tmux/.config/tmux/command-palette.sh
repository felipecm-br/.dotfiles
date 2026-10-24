#!/usr/bin/env sh
# command-palette.sh — VS Code-style Command Palette (Ctrl + Shift + P) via Waymaker.
# Same catalog as the Keybindings HUD (keybindings-items.sh) listed by command name with its
# shortcut on the right, plus shortcut-less tmux commands. Enter runs the selected command.
# Invoke: bind-key -n C-S-p -> run-shell "command-palette.sh '#{pane_id}' '#{pane_current_path}'"
set -u

REAL_SCRIPT=$(readlink -f "$0" 2>/dev/null || realpath "$0")
SCRIPT_DIR=$(dirname "$REAL_SCRIPT")
# shellcheck source=/dev/null
. "$SCRIPT_DIR/theme-helper.sh"

if [ -z "${TMUX_POPUP:-}" ]; then
  ORIGIN_ARG="${1:-}"
  CWD_ARG="${2:-$PWD}"

  CYAN_COLOR=$(get_theme_color cyan "#89dceb")

  tmux display-popup \
    -S "fg=$CYAN_COLOR" \
    -s "fg=default" \
    -b rounded \
    -T " 󰘳 " \
    $(popup_gradient_flags WM_BORDER_GRADIENT) -e "WM_BORDER_TITLE= 󰘳 " \
    -w 75% -h 60% \
    -E \
    "TMUX_POPUP=1 '$REAL_SCRIPT' '$ORIGIN_ARG' '$CWD_ARG'" || true
  exit 0
fi

[ -n "${TMUX:-}" ] || { echo "command-palette: not inside tmux" >&2; exit 1; }
ORIGIN="${1:-}"
if [ -z "$ORIGIN" ]; then
  ORIGIN="$(tmux display-message -p -t '{last}' '#{pane_id}' 2>/dev/null || true)"
fi
export WM_ORIGIN_PANE="$ORIGIN"
export WM_ORIGIN_CWD="${2:-$PWD}"
export MM_ORIGIN_PANE="$ORIGIN"
export MM_ORIGIN_CWD="${2:-$PWD}"
# Makes every keybindings-items.sh Reload (Tab filter modes) keep emitting palette rows.
export WM_KB_PALETTE=1

WM_BIN="$HOME/.local/bin/wm"
[ -x "$WM_BIN" ] || WM_BIN="$(command -v wm 2>/dev/null || command -v mm 2>/dev/null || echo wm)"

exec "$WM_BIN" -o keybindings -o command-palette
