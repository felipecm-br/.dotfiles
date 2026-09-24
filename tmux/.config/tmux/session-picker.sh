#!/usr/bin/env sh
# session-picker.sh - cross-session window picker using wm
# Replicates session switching functionality with Waymaker

REAL_SCRIPT=$(readlink -f "$0" 2>/dev/null || realpath "$0")

if [ "$1" = "--fullscreen" ]; then
  if ! [ -t 1 ]; then
    echo "[$(date)] exec tmux split-window -Z $REAL_SCRIPT --fullscreen" >> /tmp/session-picker.log
    exec tmux split-window -Z "$REAL_SCRIPT" --fullscreen
  fi
elif [ -z "${TMUX_POPUP:-}" ]; then
  SESSION_POPUP_COLOR=$(grep -E '^\s*cyan\s*=' "$HOME/.local/state/omarchy/current/theme/colors.toml" 2>/dev/null | sed -E 's/.*=\s*"([^"]+)".*/\1/')
  [ -z "$SESSION_POPUP_COLOR" ] && SESSION_POPUP_COLOR="${TMUX_POPUP_BORDER_COLOR:-#89dceb}"

  SCRIPT_DIR=$(dirname "$REAL_SCRIPT")
  ISOLATOR="$SCRIPT_DIR/tmux-popup-isolate.sh"
  [ -x "$ISOLATOR" ] || ISOLATOR="$(command -v tmux-popup-isolate.sh 2>/dev/null || echo "$HOME/.config/tmux/tmux-popup-isolate.sh")"

  exec "$ISOLATOR" \
    -S "fg=$SESSION_POPUP_COLOR" \
    -s "fg=${TMUX_POPUP_TEXT_COLOR:-default}" \
    -b rounded \
    -T " ⚡ " \
    -w 75% -h 60% \
    -E \
    -- "TMUX_POPUP=1 '$REAL_SCRIPT'"
fi

SCRIPT_DIR=$(dirname "$REAL_SCRIPT")

_tmux_style="$HOME/.local/state/omarchy/current/theme/tmux-style.sh"
[ -f "$_tmux_style" ] || _tmux_style="${SCRIPT_DIR}/tmux-style.sh"
# shellcheck source=/dev/null
. "$_tmux_style" 2>/dev/null || true
unset _tmux_style

MM_BIN="$HOME/.local/bin/wm"
[ -x "$MM_BIN" ] || MM_BIN="$(command -v wm 2>/dev/null || command -v mm 2>/dev/null || echo "wm")"

"$MM_BIN" session list --icons | grep -Ev '(_lazygitrs|_popups|[[:space:]]+\.)' | "$MM_BIN" \
  -o "$SCRIPT_DIR/session-picker.toml" \
  --color "${TMUX_COLOR_SPEC:-}" \
| (read chosen && [ -n "$chosen" ] && "$MM_BIN" connect "$chosen"); true
