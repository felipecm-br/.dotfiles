#!/usr/bin/env bash
# confirm-modal.sh — themed y/n confirmation modal (replaces gum confirm)
#
# Same look as the close-session/close-window modals: Omarchy theme colors,
# nf-cod-warning badge, Home Row keys (y: confirm, n / Esc / Enter: cancel).
# Exit status: 0 when confirmed, 1 otherwise.
#
# Usage:
#   confirm-modal.sh [--popup] TITLE [SUBJECT] [YES_LABEL] [NO_LABEL]
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
COLOR_RED=$(get_theme_color "red" "#f7768e")
COLOR_ACCENT=$(get_theme_color "accent" "#7aa2f7")
COLOR_MUTED=$(get_theme_color "dark_foreground" "#565f89")
COLOR_FG=$(get_theme_color "foreground" "#a9b1d6")

BADGE=$''

_hex_to_ansi() {
  local h="${1#\#}"
  if [[ ! "$h" =~ ^[0-9a-fA-F]{6}$ ]]; then
    h="e0af68"
  fi
  printf '\033[38;2;%d;%d;%dm' "$(( 16#${h:0:2} ))" "$(( 16#${h:2:2} ))" "$(( 16#${h:4:2} ))"
}

run_modal() {
  local title="$1" subject="${2:-}" yes_label="${3:-Confirm}" no_label="${4:-Cancel}"
  local c_yellow c_red c_cyan c_muted c_fg c_reset="\033[0m" c_bold="\033[1m"
  c_yellow=$(_hex_to_ansi "$COLOR_YELLOW")
  c_red=$(_hex_to_ansi "$COLOR_RED")
  c_cyan=$(_hex_to_ansi "$COLOR_ACCENT")
  c_muted=$(_hex_to_ansi "$COLOR_MUTED")
  c_fg=$(_hex_to_ansi "$COLOR_FG")

  local body
  body=$(
    printf "\n"
    if [ -n "$subject" ]; then
      printf "  ${c_bold}${c_yellow}%s  %s${c_reset} ${c_muted}·${c_reset} ${c_bold}${c_fg}%s${c_reset}\n\n" "$BADGE" "$title" "$subject"
    else
      printf "  ${c_bold}${c_yellow}%s  %s${c_reset}\n\n" "$BADGE" "$title"
    fi
    printf "  ${c_muted}────────────────────────────────────────${c_reset}\n"
    printf "  ${c_bold}${c_red}y${c_reset} ${c_muted}%s${c_reset}   ${c_muted}│${c_reset}   ${c_bold}${c_cyan}n${c_reset} ${c_muted}/${c_reset} ${c_bold}${c_cyan}Esc${c_reset} ${c_muted}%s${c_reset}\n" \
      "$yes_label" "$no_label"
  )
  print_modal_body "$body"
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
