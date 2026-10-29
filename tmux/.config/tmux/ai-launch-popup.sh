#!/usr/bin/env bash
# ai-launch-popup.sh - Floating AI agent launcher (CLI × model menu with live quota)
#
# Opens the `ai-launch` menu in a tmux popup; the choice starts in a new window of the
# originating session, rooted at the pane's directory. Esc closes the popup with no side effect.
trap 'exit 0' HUP INT TERM

REAL_SCRIPT=$(readlink -f "$0" 2>/dev/null || realpath "$0")
SCRIPT_DIR=$(dirname "$REAL_SCRIPT")
# shellcheck source=/dev/null
. "$SCRIPT_DIR/theme-helper.sh"
export PATH="$HOME/.local/bin:$PATH"
PROJECT_DIR="${1:-$PWD}"

if [ -z "${TMUX_POPUP:-}" ]; then
    AI_POPUP_COLOR=$(get_theme_color magenta "#cba6f7")

    ORIGIN_SESSION=$(tmux display-message -p '#{session_id}')
    exec tmux display-popup \
      -S "fg=$AI_POPUP_COLOR" \
      -s "fg=${TMUX_POPUP_TEXT_COLOR:-default}" \
      -b rounded \
      -T " 󰚩 " \
      $(popup_gradient_flags WM_BORDER_GRADIENT) -e "WM_BORDER_TITLE= 󰚩 " \
      -d "$PROJECT_DIR" \
      -E \
      -w 75% -h 60% \
      "TMUX_POPUP=1 AI_ORIGIN_SESSION='$ORIGIN_SESSION' '$REAL_SCRIPT' '$PROJECT_DIR' || true"
fi

# Inside the popup:
[ -d "$PROJECT_DIR" ] && cd "$PROJECT_DIR" || true

# "<agent> [args]"; empty when dismissed with Esc
choice=$(ai-launch --pick) || exit 0
[ -n "$choice" ] || exit 0

read -r -a words <<<"$choice"
# Absolute path: the new window inherits the tmux server's PATH, not this script's
cmd=$(printf '%q ' "$(command -v ai-launch)" "${words[@]}")
target=()
[ -n "${AI_ORIGIN_SESSION:-}" ] && target=(-t "$AI_ORIGIN_SESSION:")
exec tmux new-window "${target[@]}" -c "$PROJECT_DIR" "exec $cmd"
