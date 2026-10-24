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
  QUOTA_BIN="$HOME/.local/bin/ai-quota"
  BADGE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/ai-quota/badge"
  badge=""
  if [ -x "$QUOTA_BIN" ]; then
    if [ -n "$(find "$BADGE_FILE" -mmin -60 2>/dev/null)" ]; then
      badge=$(cat "$BADGE_FILE")
      [ -z "$(find "$BADGE_FILE" -mmin -2 2>/dev/null)" ] && "$QUOTA_BIN" --refresh >/dev/null 2>&1 &
    else
      badge=$("$QUOTA_BIN" --badge 2>/dev/null) && printf '%s' "$badge" >"$BADGE_FILE"
    fi
  fi

  ORIGIN_SESSION=$(tmux display-message -p '#{session_id}' 2>/dev/null || true)
  exec tmux display-popup \
    -S "fg=$POPUP_COLOR,bg=default" \
    -s "bg=default,fg=default" \
    -b rounded \
    -T " 󰓅 ${badge:+ $badge }" \
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
  footer="  ${c_bold}${c_cyan}Enter${c_reset} ${c_muted}Auto-Launch${c_reset} ${c_muted}│${c_reset} ${c_bold}${c_cyan}a${c_reset} ${c_muted}Model Menu${c_reset} ${c_muted}│${c_reset} ${c_bold}${c_cyan}r${c_reset} ${c_muted}Refresh${c_reset} ${c_muted}│${c_reset} ${c_bold}${c_cyan}u${c_reset} ${c_muted}/${c_reset} ${c_bold}${c_cyan}q${c_reset} ${c_muted}/${c_reset} ${c_bold}${c_cyan}Esc${c_reset} ${c_muted}Exit${c_reset}"
  body=$(printf '\n%s\n\n%s' "$vis" "$footer")
  print_modal_body "$body"
  if [ -n "${BORDER_GRADIENT:-}" ]; then
    gradient_frame_draw "$BORDER_GRADIENT" " 󰓅 " "$POPUP_COLOR" || true
  fi

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
      printf '\n  %s⟳ refreshing quota telemetry…%s' "$c_muted" "$c_reset"
      ai-quota --refresh 2>/dev/null || true
      ;;
    q | Q | u | U)
      exit 0
      ;;
  esac
done
