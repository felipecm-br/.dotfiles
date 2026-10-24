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

  # Quota badge (Claude 5h·7d, Antigravity exhaustion, recommended agent): served from a
  # cache so the popup opens instantly; recomputed inline only when older than 10 min
  QUOTA_BIN="$HOME/.local/bin/ai-quota"
  BADGE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/ai-quota/badge"
  badge=""
  if [ -x "$QUOTA_BIN" ]; then
    if [ -n "$(find "$BADGE_FILE" -mmin -10 2>/dev/null)" ]; then
      badge=$(cat "$BADGE_FILE")
      ("$QUOTA_BIN" --badge >"$BADGE_FILE.tmp" && mv -f "$BADGE_FILE.tmp" "$BADGE_FILE") >/dev/null 2>&1 &
    else
      badge=$("$QUOTA_BIN" --badge 2>/dev/null) && printf '%s' "$badge" >"$BADGE_FILE"
    fi
  fi

  tmux display-popup \
    -S "fg=$SESSION_POPUP_COLOR" \
    -s "fg=${TMUX_POPUP_TEXT_COLOR:-default}" \
    -b rounded \
    -T " ⚡ ${badge:+ $badge }" \
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

chosen=$("$WM_BIN" \
  -o "$PRESET" \
  --color "${TMUX_COLOR_SPEC:-}")

# a / A / c binds emit "@agent=<name>" before the selection; Enter emits only the selection
agent=$(printf '%s\n' "$chosen" | sed -n 's/^@agent=//p' | head -n 1)
chosen=$(printf '%s\n' "$chosen" | grep -v '^@agent=' | head -n 1)

if [ "$chosen" = "__SWITCH_WINDOW__" ] || [ "$chosen" = "__SWITCH_COCKPIT__" ]; then
  if [ "$1" = "--fullscreen" ]; then
    exec "$SCRIPT_DIR/cockpit-picker.sh" --fullscreen
  else
    exec "$SCRIPT_DIR/cockpit-picker.sh"
  fi
elif [ -n "$chosen" ]; then
  if [ -z "$agent" ]; then
    # New sessions run startup_command = ai-launch (quota-aware pick)
    "$WM_BIN" connect "$chosen"
  else
    ai-launch --next "$agent"
    before=$(tmux list-sessions -F '#{session_id}' 2>/dev/null)
    "$WM_BIN" connect "$chosen"
    if [ "$before" = "$(tmux list-sessions -F '#{session_id}' 2>/dev/null)" ]; then
      # Existing session: startup_command did not run, so open the agent in a new window
      rm -f "${XDG_RUNTIME_DIR:-/tmp}/ai-launch.next"
      pane=$(tmux new-window -P -F '#{pane_id}' -c '#{pane_current_path}')
      tmux send-keys -t "$pane" "ai-launch $agent" Enter
    fi
  fi
fi
