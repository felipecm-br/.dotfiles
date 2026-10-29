#!/usr/bin/env sh
# session-picker.sh - cross-session window picker using wm
trap 'exit 0' HUP INT TERM

REAL_SCRIPT=$(readlink -f "$0" 2>/dev/null || realpath "$0")
SCRIPT_DIR=$(dirname "$REAL_SCRIPT")
# shellcheck source=/dev/null
. "$SCRIPT_DIR/theme-helper.sh"

if [ "$1" = "--fullscreen" ]; then
  if ! [ -t 1 ]; then
    echo "[$(date)] exec tmux split-window -Z $REAL_SCRIPT --fullscreen" >> /tmp/session-picker.log
    exec tmux split-window -Z "$REAL_SCRIPT" --fullscreen
  fi
elif [ -z "${TMUX_POPUP:-}" ]; then
  SESSION_POPUP_COLOR=$(get_theme_color "cyan" "${TMUX_POPUP_BORDER_COLOR:-#89dceb}")

  # Title glyph: the agent a new session launches, colored by its quota level (green/yellow/red).
  # Served from a cache so the popup opens instantly; recomputed inline only when absent or older
  # than an hour (ai-quota-refresh.timer keeps it fresh). Full numbers live in the Prefix+u popup.
  QUOTA_BIN="$HOME/.local/bin/ai-quota"
  BADGE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/ai-quota/badge-min"
  badge=""
  if [ -x "$QUOTA_BIN" ]; then
    if [ -n "$(find "$BADGE_FILE" -mmin -60 2>/dev/null)" ]; then
      badge=$(cat "$BADGE_FILE")
      [ -z "$(find "$BADGE_FILE" -mmin -2 2>/dev/null)" ] && "$QUOTA_BIN" --refresh >/dev/null 2>&1 &
    else
      badge=$("$QUOTA_BIN" --badge-min 2>/dev/null) && printf '%s' "$badge" >"$BADGE_FILE"
    fi
  fi

  tmux display-popup \
    -S "fg=$SESSION_POPUP_COLOR" \
    -s "fg=${TMUX_POPUP_TEXT_COLOR:-default}" \
    -b rounded \
    -T " ⚡ ${badge:+→ $badge }" \
    -w 85% -h 75% \
    -E \
    "TMUX_POPUP=1 '$REAL_SCRIPT' || true" || true
  exit 0
fi

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

NEXT_FILE="${XDG_RUNTIME_DIR:-/tmp}/ai-launch.next"

# Would connecting to "$1" create a session whose startup_command is ai-launch? A running session
# (by name or by path) only gets switched to, and a [[session]] entry in session.toml keeps its own
# startup_command, so neither of them asks for an agent.
creates_agent_session() {
  tmux has-session -t "=$1" 2>/dev/null && return 1
  case "$1" in
    "~"*) _path="$HOME${1#"~"}" ;;
    /*) _path="$1" ;;
    *) _path="" ;;
  esac
  if [ -n "$_path" ] && tmux list-sessions -F '#{session_path}' 2>/dev/null | grep -qxF "$_path"; then
    return 1
  fi
  grep -F "$1\"" "$HOME/.config/waymaker/session.toml" 2>/dev/null | grep -q '^name' && return 1
  return 0
}

while :; do
  chosen=$("$WM_BIN" \
    -o "$PRESET" \
    --color "${TMUX_COLOR_SPEC:-}")

  # r / a / A / c binds emit "@agent=<auto|name>" before the selection; Enter emits only the selection
  agent=$(printf '%s\n' "$chosen" | sed -n 's/^@agent=//p' | head -n 1)
  chosen=$(printf '%s\n' "$chosen" | grep -v '^@agent=' | head -n 1)

  if [ "$chosen" = "__SWITCH_WINDOW__" ] || [ "$chosen" = "__SWITCH_COCKPIT__" ]; then
    if [ "$1" = "--fullscreen" ]; then
      exec "$SCRIPT_DIR/cockpit-picker.sh" --fullscreen
    else
      exec "$SCRIPT_DIR/cockpit-picker.sh"
    fi
  fi
  [ -n "$chosen" ] || exit 0

  if [ -z "$agent" ]; then
    if creates_agent_session "$chosen"; then
      # New session: show the CLI × model menu here, in the popup, before the session exists.
      # Esc goes back to the picker; the pick is armed for the ai-launch the new session runs.
      pick=$(ai-launch --pick) || pick=""
      [ -n "$pick" ] || continue
      # shellcheck disable=SC2086 # "<agent> [args]" is split on purpose
      ai-launch --next $pick
      "$WM_BIN" connect "$chosen"
      # A session configured without ai-launch must not leave the pick armed for a later one
      setsid -f sh -c "sleep 10; rm -f '$NEXT_FILE'" </dev/null >/dev/null 2>&1
    else
      "$WM_BIN" connect "$chosen"
    fi
  else
    ai-launch --next "$agent"
    before=$(tmux list-sessions -F '#{session_id}' 2>/dev/null)
    "$WM_BIN" connect "$chosen"
    if [ "$before" = "$(tmux list-sessions -F '#{session_id}' 2>/dev/null)" ]; then
      # Existing session: startup_command did not run, so open the agent in a new window
      rm -f "$NEXT_FILE"
      pane=$(tmux new-window -P -F '#{pane_id}' -c '#{pane_current_path}')
      tmux send-keys -t "$pane" "ai-launch $agent" Enter
    fi
  fi
  exit 0
done
