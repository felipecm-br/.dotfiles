#!/usr/bin/env bash
# confirm-modal.sh — themed y/n confirmation modal (replaces gum confirm)
#
# Same look as the close-session/close-window modals: Omarchy theme colors,
# nf-cod-warning badge, Home Row keys (y: confirm, n / Esc / Enter: cancel).
# Exit status: 0 when confirmed, 1 otherwise.
#
# Usage:
#   confirm-modal.sh [--popup] QUESTION [COST] [YES_LABEL] [NO_LABEL]
#
# QUESTION is the bold first line ("Close session work?"), COST the darkgray
# line under it saying what yes loses ("Closing ends all its tabs.").
#
# --popup opens the modal in a tmux display-popup (when inside tmux) and
# returns the modal's exit status; without it the modal renders inline.
set -uo pipefail

REAL_SCRIPT=$(readlink -f "$0" 2>/dev/null || realpath "$0")
SCRIPT_DIR=$(dirname "$REAL_SCRIPT")

# shellcheck source=/dev/null
. "$SCRIPT_DIR/theme-helper.sh"
# shellcheck source=/dev/null
. "$SCRIPT_DIR/gradient-frame.sh"

COLOR_YELLOW=$(get_theme_color "yellow" "#e0af68")

BADGE=$''


run_modal() {
  local title="$1" subject="${2:-}" yes_label="${3:-Confirm}" no_label="${4:-Cancel}"

  local body
  body=$(modal_head "$title" "$subject")
  print_modal_body "$body"
  modal_footer y "$yes_label" n/Esc "$no_label"
  if [ -n "${BORDER_GRADIENT:-}" ]; then
    gradient_frame_draw "$BORDER_GRADIENT" " $BADGE " "$COLOR_YELLOW" || true
  fi

  # Hide cursor during prompt to eliminate blinking artifacts
  printf '\033[?25l'
  trap 'printf "\033[?25h"' EXIT

  local key esc_rest
  IFS= read -rsn1 key
  if [[ "$key" == $'\e' ]]; then
    read -rsn2 -t 0.05 esc_rest 2>/dev/null || true
  fi

  case "$key" in
    y|Y) return 0 ;;
    *) return 1 ;;
  esac
}

main() {
  local popup=0
  if [ "${1:-}" = "--popup" ]; then
    popup=1
    shift
  fi
  if [ $# -lt 1 ]; then
    echo "Usage: confirm-modal.sh [--popup] TITLE [SUBJECT] [YES_LABEL] [NO_LABEL]" >&2
    exit 2
  fi

  if [ "$popup" -eq 1 ] && [ -n "${TMUX:-}" ]; then
    # Fit the header line (badge + title + subject), clamped to 52..80 columns
    local subject="${2:-}"
    local popup_w=$(( ${#1} + ${#subject} + 14 ))
    [ "$popup_w" -lt 52 ] && popup_w=52
    [ "$popup_w" -gt 80 ] && popup_w=80

    local args="" arg
    for arg in "$@"; do
      args="$args $(printf '%q' "$arg")"
    done
    tmux display-popup \
      -b rounded \
      -s "bg=default,fg=default" \
      -S "fg=$COLOR_YELLOW,bg=default" \
      -T " $BADGE " \
      $(popup_gradient_flags BORDER_GRADIENT) \
      -w "$popup_w" \
      -h 8 \
      -E \
      "'$REAL_SCRIPT'$args"
    exit $?
  fi

  run_modal "$@"
  exit $?
}

main "$@"
