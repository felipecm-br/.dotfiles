#!/usr/bin/env sh
# cockpit-picker.sh — Fleet & Window Cockpit HUD powered by Matchmaker
# Displays prioritized agent states, waiting age, git branch/churn, and contextual previews.

REAL_SCRIPT=$(readlink -f "$0" 2>/dev/null || realpath "$0")

if [ "$1" = "--fullscreen" ]; then
  if ! [ -t 1 ]; then
    exec tmux split-window -Z "$REAL_SCRIPT" --fullscreen
  fi
elif [ -z "${TMUX_POPUP:-}" ]; then
  ORIG_SESS=$(tmux display-message -p '#{session_name}')
  ORIG_WIN=$(tmux display-message -p '#{window_index}')
  export TMUX_ORIGIN_SESSION="$ORIG_SESS"
  export TMUX_ORIGIN_WINDOW="$ORIG_WIN"

  COCKPIT_POPUP_COLOR=$(grep -E '^\s*orange\s*=' "$HOME/.local/state/omarchy/current/theme/colors.toml" 2>/dev/null | sed -E 's/.*=\s*"([^"]+)".*/\1/')
  [ -z "$COCKPIT_POPUP_COLOR" ] && COCKPIT_POPUP_COLOR="#e09d7f"

  SCRIPT_DIR=$(dirname "$REAL_SCRIPT")
  ISOLATOR="$SCRIPT_DIR/tmux-popup-isolate.sh"
  [ -x "$ISOLATOR" ] || ISOLATOR="$(command -v tmux-popup-isolate.sh 2>/dev/null || echo "$HOME/.config/tmux/tmux-popup-isolate.sh")"

  exec "$ISOLATOR" \
    -S "fg=$COCKPIT_POPUP_COLOR" \
    -s "fg=${TMUX_POPUP_TEXT_COLOR:-default}" \
    -b rounded \
    -T " 󰆍 " \
    -w 85% -h 75% \
    -E \
    -- "TMUX_POPUP=1 TMUX_ORIGIN_SESSION='$ORIG_SESS' TMUX_ORIGIN_WINDOW='$ORIG_WIN' '$REAL_SCRIPT'"
fi

SCRIPT_DIR=$(dirname "$REAL_SCRIPT")
ITEMS_SCRIPT="${SCRIPT_DIR}/cockpit-picker-items.sh"
_tmux_style="$HOME/.local/state/omarchy/current/theme/tmux-style.sh"
[ -f "$_tmux_style" ] || _tmux_style="${SCRIPT_DIR}/tmux-style.sh"
# shellcheck source=/dev/null
. "$_tmux_style" 2>/dev/null || true
unset _tmux_style

ACPD_SPINNER=$(tmux show-option -gqv @ai_agent_spinner 2>/dev/null)
[ -z "$ACPD_SPINNER" ] && ACPD_SPINNER="minidot"
TMUX_SPINNER_NAME="$ACPD_SPINNER"

ORIG_SESS="${TMUX_ORIGIN_SESSION:-$(tmux display-message -p '#S')}"
ORIG_WIN="${TMUX_ORIGIN_WINDOW:-$(tmux display-message -p '#I')}"

ITEMS=$("$ITEMS_SCRIPT" "$ORIG_SESS" "$ORIG_WIN")

# Adaptive start position:
# If an agent needs urgent attention (permission 󱅭 or question 󱜻), start at top (index 0).
# Otherwise, focus on the current active window (row containing •).
has_urgent=$(printf '%s\n' "$ITEMS" | grep -m1 -E '(󱅭|󱜻)' || true)
if [ -n "$has_urgent" ]; then
  START_IDX=0
else
  START_IDX=$(printf '%s\n' "$ITEMS" | awk '!/^#/ {n++} /•/ {print n-1; exit}')
  [ -z "$START_IDX" ] && START_IDX=0
fi

MM_BIN="$HOME/.local/bin/wm"
[ -x "$MM_BIN" ] || MM_BIN="$(command -v wm 2>/dev/null || command -v mm 2>/dev/null || echo "wm")"

chosen=$(printf '%s\n' "$ITEMS" | "$MM_BIN" \
  -o "$SCRIPT_DIR/cockpit-picker.toml" \
  "start.cmd=$ITEMS_SCRIPT $ORIG_SESS $ORIG_WIN" \
  results.spinner="$TMUX_SPINNER_NAME" \
  --pos "$START_IDX" \
  --color "spinner:$TMUX_SPINNER_COLOR" \
  --color "$TMUX_COLOR_SPEC" \
  --group-prefix '#')

if [ "$chosen" = "__SWITCH_SESSION__" ]; then
  if [ "$1" = "--fullscreen" ]; then
    exec "$SCRIPT_DIR/session-picker.sh" --fullscreen
  else
    exec "$SCRIPT_DIR/session-picker.sh"
  fi
fi

if [ -n "$chosen" ]; then
  session=$(printf '%s' "$chosen" | head -n1 | cut -f4)
  idx=$(printf '%s' "$chosen" | head -n1 | cut -f2)
  if [ -n "$session" ] && [ -n "$idx" ]; then
    tmux switch-client -t "${session}:${idx}" 2>/dev/null || true
  fi
fi

exit 0
