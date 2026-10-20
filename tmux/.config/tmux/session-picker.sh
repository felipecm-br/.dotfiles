#!/usr/bin/env sh
# session-picker.sh - cross-session window picker using wm
trap 'exit 0' HUP INT TERM

REAL_SCRIPT=$(readlink -f "$0" 2>/dev/null || realpath "$0")

if [ "$1" = "--fullscreen" ]; then
  if ! [ -t 1 ]; then
    echo "[$(date)] exec tmux split-window -Z $REAL_SCRIPT --fullscreen" >> /tmp/session-picker.log
    exec tmux split-window -Z "$REAL_SCRIPT" --fullscreen
  fi
elif [ -z "${TMUX_POPUP:-}" ]; then
  SESSION_POPUP_COLOR=$(grep -E '^\s*cyan\s*=' "$HOME/.local/state/omarchy/current/theme/colors.toml" 2>/dev/null | sed -E 's/.*=\s*"([^"]+)".*/\1/')
  [ -z "$SESSION_POPUP_COLOR" ] && SESSION_POPUP_COLOR="${TMUX_POPUP_BORDER_COLOR:-#89dceb}"

  tmux display-popup \
    -S "fg=$SESSION_POPUP_COLOR" \
    -s "fg=${TMUX_POPUP_TEXT_COLOR:-default}" \
    -b rounded \
    -T " ⚡ " \
    -w 85% -h 75% \
    -E \
    "TMUX_POPUP=1 '$REAL_SCRIPT' || true" || true
  exit 0
fi

SCRIPT_DIR=$(dirname "$REAL_SCRIPT")

_tmux_style="$HOME/.local/state/omarchy/current/theme/tmux-style.sh"
[ -f "$_tmux_style" ] || _tmux_style="${SCRIPT_DIR}/tmux-style.sh"
# shellcheck source=/dev/null
. "$_tmux_style" 2>/dev/null || true
unset _tmux_style

export PATH="$HOME/.local/bin:$PATH"

WM_BIN="$HOME/.local/bin/wm"
[ -x "$WM_BIN" ] || WM_BIN="$(command -v wm 2>/dev/null || command -v mm 2>/dev/null || echo "wm")"

PRESET="$HOME/.config/waymaker/presets/session-picker.toml"
if [ ! -f "$PRESET" ]; then
  if [ -f "$SCRIPT_DIR/session-picker.toml" ]; then
    PRESET="$SCRIPT_DIR/session-picker.toml"
  else
    PRESET="session-picker"
  fi
fi

chosen=$("$WM_BIN" \
  -o "$PRESET" \
  --color "${TMUX_COLOR_SPEC:-}")

if [ "$chosen" = "__SWITCH_WINDOW__" ] || [ "$chosen" = "__SWITCH_COCKPIT__" ]; then
  if [ "$1" = "--fullscreen" ]; then
    exec "$SCRIPT_DIR/cockpit-picker.sh" --fullscreen
  else
    exec "$SCRIPT_DIR/cockpit-picker.sh"
  fi
elif [ -n "$chosen" ]; then
  "$WM_BIN" connect "$chosen"
fi
