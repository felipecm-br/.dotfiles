#!/usr/bin/env sh
# window-picker.sh — cross-session window picker with OpenCode state using wm
# All sessions and their windows, grouped, with color-coded AI state and live preview.

REAL_SCRIPT=$(readlink -f "$0" 2>/dev/null || realpath "$0")
SCRIPT_DIR=$(dirname "$REAL_SCRIPT")
# shellcheck source=/dev/null
. "$SCRIPT_DIR/theme-helper.sh"

if [ "$1" = "--fullscreen" ]; then
  if ! [ -t 1 ]; then
    exec tmux split-window -Z "$REAL_SCRIPT" --fullscreen
  fi
elif [ -z "${TMUX_POPUP:-}" ]; then
  ORIG_SESS=$(tmux display-message -p '#{session_name}')
  ORIG_WIN=$(tmux display-message -p '#{window_index}')
  export TMUX_ORIGIN_SESSION="$ORIG_SESS"
  export TMUX_ORIGIN_WINDOW="$ORIG_WIN"

  WIN_POPUP_COLOR=$(get_theme_color "magenta" "${TMUX_POPUP_BORDER_COLOR:-#cba6f7}")

  exec tmux display-popup \
    -S "fg=$WIN_POPUP_COLOR" \
    -s "fg=${TMUX_POPUP_TEXT_COLOR:-default}" \
    -b rounded \
    -T " 󱂬 " \
    -w 85% -h 75% \
    -E \
    "TMUX_POPUP=1 TMUX_ORIGIN_SESSION='$ORIG_SESS' TMUX_ORIGIN_WINDOW='$ORIG_WIN' '$REAL_SCRIPT'"
fi

ITEMS_SCRIPT="${SCRIPT_DIR}/window-picker-items.sh"

# Extract the active spinner from waymux if available (tmux option or waymux config)
WAYMUX_SPINNER=$(tmux show-option -gqv @ai_agent_spinner 2>/dev/null)
[ -z "$WAYMUX_SPINNER" ] && WAYMUX_SPINNER=$(grep -hE '^\s*active_spinner\s*=' "$HOME/.config/waymux/config.toml" 2>/dev/null | head -n1 | sed -E 's/.*=\s*"([^"]+)".*/\1/')
[ -n "$WAYMUX_SPINNER" ] && TMUX_SPINNER_NAME="$WAYMUX_SPINNER"

# Calculate the index of the current window for the initial selection
# We ignore group headers (lines starting with '#') and find the 0-based index of the row containing '•'
ORIG_SESS="${TMUX_ORIGIN_SESSION:-$(tmux display-message -p '#S')}"
ORIG_WIN="${TMUX_ORIGIN_WINDOW:-$(tmux display-message -p '#I')}"

ITEMS=$("$ITEMS_SCRIPT" "$ORIG_SESS" "$ORIG_WIN")
START_IDX=$(printf '%s\n' "$ITEMS" | awk '!/^#/ {n++} /•/ {print n-1; exit}')
[ -z "$START_IDX" ] && START_IDX=0
WM_BIN="$HOME/.local/bin/wm"
[ -x "$WM_BIN" ] || WM_BIN="$(command -v wm 2>/dev/null || command -v mm 2>/dev/null || echo "wm")"

PRESET="$HOME/.config/waymaker/presets/window-picker.toml"
if [ ! -f "$PRESET" ]; then
  if [ -f "$SCRIPT_DIR/window-picker.toml" ]; then
    PRESET="$SCRIPT_DIR/window-picker.toml"
  else
    PRESET="window-picker"
  fi
fi

chosen=$(printf '%s\n' "$ITEMS" | "$WM_BIN" \
  -o "$PRESET" \
  "start.cmd=$ITEMS_SCRIPT $ORIG_SESS $ORIG_WIN" \
  results.spinner="$TMUX_SPINNER_NAME" \
  --pos "$START_IDX" \
  --color "spinner:$TMUX_SPINNER_COLOR" \
  --color "$TMUX_COLOR_SPEC" \
  --group-prefix '#')

case "$chosen" in
  __CREATE_WINDOW__*)
    raw_item="${chosen#__CREATE_WINDOW__}"
    new_target=$(printf '%s\n' "$raw_item" | "$SCRIPT_DIR/window-picker-create.sh")
    if [ -n "$new_target" ]; then
      tmux switch-client -t "$new_target" 2>/dev/null || true
    fi
    ;;
  __SWITCH_SESSION__)
    if [ "$1" = "--fullscreen" ]; then
      exec "$SCRIPT_DIR/session-picker.sh" --fullscreen
    else
      exec "$SCRIPT_DIR/session-picker.sh"
    fi
    ;;
  *)
    if [ -n "$chosen" ]; then
      session=$(printf '%s' "$chosen" | head -n1 | cut -f4)
      idx=$(printf '%s' "$chosen" | head -n1 | cut -f2)
      if [ -n "$session" ] && [ -n "$idx" ]; then
        tmux switch-client -t "${session}:${idx}" 2>/dev/null || true
      fi
    fi
    ;;
esac

exit 0
