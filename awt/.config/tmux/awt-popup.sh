#!/usr/bin/env bash
# awt-popup.sh - Floating Worktree Manager Modal with dynamic Omarchy palette
trap 'exit 0' HUP INT TERM

REAL_SCRIPT=$(readlink -f "$0" 2>/dev/null || realpath "$0")
SCRIPT_DIR=$(dirname "$REAL_SCRIPT")
# shellcheck source=/dev/null
. "$SCRIPT_DIR/theme-helper.sh"
PROJECT_DIR="${1:-$PWD}"

if [ -z "${TMUX_POPUP:-}" ]; then
    if ! git -C "$PROJECT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1 && ! git -C "$PROJECT_DIR" rev-parse --is-bare-repository >/dev/null 2>&1; then
        tmux display-message "Not in a git repository"
        exit 0
    fi

    AWT_POPUP_COLOR=$(get_theme_color orange "#e84d31")

    CURRENT_PANE=$(tmux display-message -p '#{pane_id}')
    exec tmux display-popup \
      -S "fg=$AWT_POPUP_COLOR" \
      -s "fg=${TMUX_POPUP_TEXT_COLOR:-default}" \
      -b rounded \
      -T "  " \
      -d "$PROJECT_DIR" \
      -E \
      -w 85% -h 75% \
      "TMUX_POPUP=1 AWT_ORIGIN_PANE='$CURRENT_PANE' '$REAL_SCRIPT' '$PROJECT_DIR' || true"
    exit 0
fi

# Inside the popup modal:
if [ -n "$PROJECT_DIR" ] && [ -d "$PROJECT_DIR" ]; then
    cd "$PROJECT_DIR" || true
fi

MM_BIN="$HOME/.local/bin/wm"
[ -x "$MM_BIN" ] || MM_BIN="$(command -v wm 2>/dev/null || command -v mm 2>/dev/null || echo "wm")"

output=$("$MM_BIN" -o awt \
    ${TMUX_COLOR_SPEC:+--color "$TMUX_COLOR_SPEC"})
[ -z "$output" ] && exit 0

case "$output" in
  __SWITCH_COCKPIT__*)
    COCKPIT_BIN="$HOME/.config/tmux/cockpit-picker.sh"
    [ -x "$COCKPIT_BIN" ] || COCKPIT_BIN="$(command -v cockpit-picker.sh 2>/dev/null || echo "cockpit-picker.sh")"
    exec "$COCKPIT_BIN"
    ;;
esac

# If awt-new.sh already provisioned and connected to the session, exit immediately to prevent double execution
if [ -f "/tmp/awt_new_created_${USER:-user}" ]; then
    rm -f "/tmp/awt_new_created_${USER:-user}" 2>/dev/null || true
    exit 0
fi

IFS=$'\t' read -r session target <<< "$output"
cur_session=$(tmux display-message -p '#{session_name}' 2>/dev/null || echo "")

if [ -n "$session" ] && [ "$cur_session" != "$session" ]; then
    if [ -d "$target" ] && git -C "$target" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        b="$(git -C "$target" rev-parse --abbrev-ref HEAD 2>/dev/null)"
        timeout 3s git -C "$target" pull --ff-only 2>/dev/null || \
        timeout 3s git -C "$target" pull --ff-only origin "$b" 2>/dev/null || true
    fi
    if command -v wm >/dev/null 2>&1; then
        if tmux has-session -t "$session" 2>/dev/null; then
            exec wm connect "$session"
        else
            exec wm connect "$target"
        fi
    elif command -v sesh >/dev/null 2>&1; then
        if tmux has-session -t "$session" 2>/dev/null; then
            exec sesh connect "$session"
        else
            exec sesh connect "$target"
        fi
    fi
fi

exit 0
