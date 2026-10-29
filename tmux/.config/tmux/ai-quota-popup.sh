#!/usr/bin/env bash
# ai-quota-popup.sh — Visual AI Quota & Burn Telemetry HUD popup (Prefix + u)
#
# Renders `ai-quota --visual` in a Golden Ratio (75% × 60%) tmux popup with
# Omarchy dynamic theme colors, optional OKLab gradient border, and 1-key actions:
#   Enter       Launch recommended agent + model in a new window (ai-launch --auto)
#   a           Switch in-place to the CLI × model launch menu (ai-launch --pick)
#   r           Force-refresh live API quota & badge cache and redraw in place
#   u / q / Esc Dismiss popup immediately with zero side effect
trap 'exit 0' HUP INT TERM

REAL_SCRIPT=$(readlink -f "$0" 2>/dev/null || realpath "$0")
SCRIPT_DIR=$(dirname "$REAL_SCRIPT")
# shellcheck source=/dev/null
. "$SCRIPT_DIR/theme-helper.sh"
# shellcheck source=/dev/null
. "$SCRIPT_DIR/gradient-frame.sh"
export PATH="$HOME/.local/bin:$PATH"
PROJECT_DIR="${1:-$PWD}"

POPUP_COLOR=$(get_theme_color cyan "#94e2d5")
COLOR_CYAN=$(get_theme_color cyan "#94e2d5")
COLOR_MUTED=$(get_theme_color muted "#585b70")

_hex_to_ansi() {
  local h="${1#\#}"
  [[ "$h" =~ ^[0-9a-fA-F]{6}$ ]] || h="94e2d5"
  printf '\033[38;2;%d;%d;%dm' "$((16#${h:0:2}))" "$((16#${h:2:2}))" "$((16#${h:4:2}))"
}

if [ -z "${TMUX_POPUP:-}" ] && [ -n "${TMUX:-}" ]; then
  ORIGIN_SESSION=$(tmux display-message -p '#{session_id}' 2>/dev/null || true)
  exec tmux display-popup \
    -S "fg=$POPUP_COLOR" \
    -s "fg=${TMUX_POPUP_TEXT_COLOR:-default}" \
    -b rounded \
    -T " 󰓅 " \
    $(popup_gradient_flags BORDER_GRADIENT) \
    -d "$PROJECT_DIR" \
    -E \
    -w 75% -h 60% \
    "TMUX_POPUP=1 AI_ORIGIN_SESSION='$ORIGIN_SESSION' '$REAL_SCRIPT' '$PROJECT_DIR' || true"
fi

# Inside the popup (or direct terminal fallback):
[ -d "$PROJECT_DIR" ] && cd "$PROJECT_DIR" || true

c_cyan=$(_hex_to_ansi "$COLOR_CYAN")
c_muted=$(_hex_to_ansi "$COLOR_MUTED")
c_bold=$'\033[1m'
c_reset=$'\033[0m'

launch_choice() {
  local choice="$1"
  [ -n "$choice" ] || return 0
  local -a words=()
  read -r -a words <<<"$choice"
  local cmd
  cmd=$(printf '%q ' "$(command -v ai-launch)" "${words[@]}")
  local -a target=()
  [ -n "${AI_ORIGIN_SESSION:-}" ] && target=(-t "$AI_ORIGIN_SESSION:")
  if [ -n "${TMUX:-}" ]; then
    exec tmux new-window "${target[@]}" -c "$PROJECT_DIR" "exec $cmd"
  else
    exec ai-launch "${words[@]}"
  fi
}

printf '\033[?25l'
trap 'printf "\033[?25h"' EXIT

while :; do
  clear
  vis=$(ai-quota --visual 2>/dev/null || true)
  body=$(printf '\n%s' "$vis")
  print_modal_body "$body"
  if [ -n "${BORDER_GRADIENT:-}" ]; then
    gradient_frame_draw "$BORDER_GRADIENT" " 󰓅 " "$POPUP_COLOR" || true
  fi

  size=$(stty size < /dev/tty 2>/dev/null || echo "24 80")
  term_rows="${size% *}"
  term_cols="${size#* }"
  [ -z "$term_rows" ] || [ "$term_rows" -lt 10 ] && term_rows=24
  [ -z "$term_cols" ] || [ "$term_cols" -lt 20 ] && term_cols=80

  if [ -n "${BORDER_GRADIENT:-}" ]; then
    sep_r=$(( term_rows - 2 ))
    foot_r=$(( term_rows - 1 ))
    col=2
    w=$(( term_cols - 2 ))
  else
    sep_r=$(( term_rows - 1 ))
    foot_r=$term_rows
    col=1
    w=$(( term_cols - 1 ))
  fi
  [ "$w" -lt 10 ] && w=74
  sep_line=$(printf '─%.0s' $(seq 1 "$w"))
  footer=" ${c_bold}${c_cyan}Enter${c_reset} ${c_muted}Auto-Launch${c_reset} ${c_muted}│${c_reset} ${c_bold}${c_cyan}a${c_reset} ${c_muted}Model Menu${c_reset} ${c_muted}│${c_reset} ${c_bold}${c_cyan}r${c_reset} ${c_muted}Refresh${c_reset} ${c_muted}│${c_reset} ${c_bold}${c_cyan}Esc${c_reset} ${c_muted}Exit${c_reset}"

  # Pin Cockpit-style separator line and footer to the bottom of the popup
  printf '\033[%d;%dH%s%s%s\033[%d;%dH%s\033[%d;%dH' \
    "$sep_r" "$col" "$c_muted" "$sep_line" "$c_reset" \
    "$foot_r" "$col" "$footer" \
    "$foot_r" "$(( col + 1 ))"

  IFS= read -rsn1 key || exit 0
  if [[ "$key" == $'\e' ]]; then
    read -rsn2 -t 0.05 _ 2>/dev/null || true
    exit 0
  fi

  case "$key" in
    "" | $'\n' | $'\r')
      # Enter: launch recommended agent & model in a new window
      launch_choice "--auto"
      exit 0
      ;;
    a | A)
      printf '\033[?25h'
      clear
      choice=$(ai-launch --pick) || exit 0
      launch_choice "$choice"
      exit 0
      ;;
    r | R)
      printf '\033[%d;%dH\033[2K  %s⟳ refreshing quota telemetry…%s' "$foot_r" "$col" "$c_muted" "$c_reset"
      ai-quota --refresh 2>/dev/null || true
      ;;
    q | Q | u | U)
      exit 0
      ;;
  esac
done
