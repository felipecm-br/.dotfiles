#!/usr/bin/env bash
# ai-switch-popup.sh - In-place model / effort switcher for the AI agent in the current pane
#
# Opens the `ai-switch` menu in a tmux popup over the pane; the pick is typed into that agent as its
# own slash command (/model, /effort), so the window and conversation stay. Esc closes with no effect.
# A pane without an agent gets a status-line hint instead of an empty popup.
trap 'exit 0' HUP INT TERM

REAL_SCRIPT=$(readlink -f "$0" 2>/dev/null || realpath "$0")
SCRIPT_DIR=$(dirname "$REAL_SCRIPT")
# shellcheck source=/dev/null
. "$SCRIPT_DIR/theme-helper.sh"
export PATH="$HOME/.local/bin:$PATH"
PANE="${1:-$TMUX_PANE}"

if [ -z "${TMUX_POPUP:-}" ]; then
    info=$(ai-switch -t "$PANE" --agent) || {
        tmux display-message "No AI agent in this pane · Prefix + a launches one"
        exit 0
    }
    IFS=$'\t' read -r agent current <<<"$info"
    AI_POPUP_COLOR=$(get_theme_color magenta "#cba6f7")
    title=" $(waymux icon "$agent" 2>/dev/null) $agent${current:+ · $current} "
    exec tmux display-popup \
      -S "fg=$AI_POPUP_COLOR" \
      -s "fg=${TMUX_POPUP_TEXT_COLOR:-default}" \
      -b rounded \
      -T "$title" \
      $(popup_gradient_flags WM_BORDER_GRADIENT) -e "WM_BORDER_TITLE=$title" \
      -E \
      -w 75% -h 60% \
      "TMUX_POPUP=1 '$REAL_SCRIPT' '$PANE' || true"
fi

# Inside the popup: the switch targets the pane the popup was opened from
exec ai-switch -t "$PANE"
