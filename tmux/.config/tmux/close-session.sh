#!/usr/bin/env bash
# close-session.sh — smart guarded session termination for Tmux
#
# Safeguards against accidental session termination:
# - If active AI agents are running (in any window), OR
# - If the session has more than 3 windows (>3 threshold):
# Displays a high-contrast, Golden-Ratio styled confirmation popup modal
# with Omarchy theme colors, pure Nerd Font badges, and Home Row navigation
# (y: confirm, n / Esc / Enter: cancel).
#
# If neither condition is met (<= 3 windows and 0 AI agents), closes
# the session immediately without friction.
set -euo pipefail

REAL_SCRIPT=$(readlink -f "$0" 2>/dev/null || realpath "$0")
SCRIPT_DIR=$(dirname "$REAL_SCRIPT")

# -----------------------------------------------------------------------------
# 1. Dynamic Color Palette (resolved via theme-helper.sh)
# -----------------------------------------------------------------------------
# shellcheck source=/dev/null
. "$SCRIPT_DIR/theme-helper.sh"
# shellcheck source=/dev/null
. "$SCRIPT_DIR/gradient-frame.sh"

COLOR_YELLOW=$(get_theme_color "yellow" "#e0af68")
COLOR_RED=$(get_theme_color "red" "#f7768e")
COLOR_ORANGE=$(get_theme_color "orange" "#eb927b")
COLOR_ACCENT=$(get_theme_color "accent" "#7aa2f7")
COLOR_MAGENTA=$(get_theme_color "magenta" "#ad8ee6")
COLOR_MUTED=$(get_theme_color "dark_foreground" "#565f89")
COLOR_FG=$(get_theme_color "foreground" "#a9b1d6")
COLOR_BG=$(get_theme_color "background" "#1a1b26")

_hex_to_ansi() {
  local h="${1#\#}"
  if [[ ! "$h" =~ ^[0-9a-fA-F]{6}$ ]]; then
    h="e0af68"
  fi
  local r=$(( 16#${h:0:2} ))
  local g=$(( 16#${h:2:2} ))
  local b=$(( 16#${h:4:2} ))
  printf '\033[38;2;%d;%d;%dm' "$r" "$g" "$b"
}

# -----------------------------------------------------------------------------
# 2. Session Analysis: Windows & AI Agent Detection
# -----------------------------------------------------------------------------
analyze_session() {
  local target="$1"

  WIN_COUNT=0
  AGENT_COUNT=0
  AGENT_TABS=()
  AGENT_DESCS=()
  AGENT_STATES=()
  REASONS=()

  if ! tmux has-session -t "$target" 2>/dev/null; then
    return 0
  fi

  WIN_COUNT=$(tmux list-windows -t "$target" 2>/dev/null | wc -l)

  declare -A agent_windows=()
  declare -A waymux_panes=()

  # Query Waymux control plane daemon if available
  if command -v waymux >/dev/null 2>&1; then
    while IFS=$'\t' read -r apid astate atime; do
      if [ -n "$apid" ] && [ "$astate" != "closed" ]; then
        waymux_panes["$apid"]="$astate"
      fi
    done < <(waymux list 2>/dev/null || true)
  fi

  while IFS="|" read -r wid wnum wname pid pcmd ptitle raw_state raw_title; do
    local is_agent=0
    local agent_desc=""
    local st=""

    # 1. Waymux registration check
    if [ -n "${waymux_panes["$pid"]:-}" ]; then
      is_agent=1
      st="${waymux_panes["$pid"]}"
    fi

    # 2. Tmux window/pane options check
    if [ -n "$raw_state" ] && [ "$raw_state" != "closed" ]; then
      is_agent=1
      [ -z "$st" ] && st="$raw_state"
    fi
    if [ -n "$raw_title" ]; then
      is_agent=1
      [ -z "$agent_desc" ] && agent_desc="$raw_title"
    fi

    # 3. Direct command matching
    case "$pcmd" in
      agy|agy-bin|antigravity|opencode|claude|devin|codex|muse|gemini|aider)
        is_agent=1
        [ -z "$st" ] && st="running"
        ;;
    esac

    # 4. Process tree inspection (descendants of pane PID)
    if [ "$is_agent" -eq 0 ] && [ -n "$pid" ]; then
      if ps -s "$pid" -o comm= 2>/dev/null | grep -qE "^(agy|agy-bin|antigravity|opencode|claude|devin|codex|muse|gemini|aider)$"; then
        is_agent=1
        [ -z "$st" ] && st="running"
      fi
    fi

    if [ "$is_agent" -eq 1 ]; then
      case "${st:-active}" in
        idle|done|closed|inactive|completed)
          ;;
        *)
          agent_windows["$wid"]=1
          ;;
      esac
      [ -z "$agent_desc" ] && agent_desc="${raw_title:-$wname}"
      # Clean and truncate description if needed
      agent_desc=$(printf '%s' "$agent_desc" | tr '\n\r\t' ' ' | sed -E 's/[[:space:]]+/ /g')
      if [ "${#agent_desc}" -gt 30 ]; then
        agent_desc="${agent_desc:0:27}..."
      fi
      AGENT_TABS+=("$wnum")
      AGENT_DESCS+=("$agent_desc")
      AGENT_STATES+=("${st:-active}")
    fi
  done < <(tmux list-panes -s -t "$target" -F "#{window_id}|#{window_index}|#{window_name}|#{pane_id}|#{pane_current_command}|#{pane_title}|#{@ai_agent_state_raw}|#{@ai_agent_title}" 2>/dev/null || true)

  AGENT_COUNT="${#agent_windows[@]}"

  if [ "$AGENT_COUNT" -gt 0 ]; then
    REASONS+=("$AGENT_COUNT window(s) with active AI agents")
  fi

  if [ "$WIN_COUNT" -gt 3 ]; then
    REASONS+=("$WIN_COUNT windows open (>3 threshold)")
  fi
}

# -----------------------------------------------------------------------------
# 3. Session Termination & Client Switcher
# -----------------------------------------------------------------------------
perform_kill() {
  local target="$1"

  if ! tmux has-session -t "$target" 2>/dev/null; then
    return 0
  fi

  local cur_sess
  cur_sess=$(tmux display-message -p '#{session_name}' 2>/dev/null || echo "")

  if [ "$cur_sess" = "$target" ]; then
    # Find most recently attached non-ephemeral session to land on
    local next_sess
    next_sess=$(tmux list-sessions -F '#{session_last_attached} #{session_name}' 2>/dev/null \
      | sort -nr \
      | sed 's/^[0-9]* *//' \
      | awk -v cur="$target" '$0 != cur && $0 !~ /^(_popups|_lazygitrs|\.)/ {print; exit}' || true)

    if [ -n "$next_sess" ]; then
      tmux switch-client -t "$next_sess" 2>/dev/null || true
    else
      # Fallback to any other existing session
      tmux switch-client -n 2>/dev/null || tmux switch-client -p 2>/dev/null || true
    fi
  fi

  tmux kill-session -t "$target" 2>/dev/null || true
}

# -----------------------------------------------------------------------------
# 4. Confirmation Modal Runner (executed inside display-popup or terminal)
# -----------------------------------------------------------------------------
run_confirm_modal() {
  local target="$1"

  analyze_session "$target"

  local c_yellow c_red c_cyan c_magenta c_muted c_fg c_reset c_bold
  c_yellow=$(_hex_to_ansi "$COLOR_YELLOW")
  c_red=$(_hex_to_ansi "$COLOR_RED")
  c_cyan=$(_hex_to_ansi "$COLOR_ACCENT")
  c_magenta=$(_hex_to_ansi "$COLOR_MAGENTA")
  c_muted=$(_hex_to_ansi "$COLOR_MUTED")
  c_fg=$(_hex_to_ansi "$COLOR_FG")
  c_reset="\033[0m"
  c_bold="\033[1m"

  local body
  body=$(
    printf "\n"
    printf "  ${c_bold}${c_yellow}  KILL SESSION${c_reset} ${c_muted}·${c_reset} ${c_bold}${c_fg}%s${c_reset}\n\n" "$target"

    # Section 1: Active AI Agent Fleet
    if [ "$AGENT_COUNT" -gt 0 ]; then
      printf "  ${c_bold}${c_red}󰮯  Active AI Agents Detected (%d)${c_reset}\n" "$AGENT_COUNT"
      local show_count=$(( AGENT_COUNT > 3 ? 3 : AGENT_COUNT ))
      for ((i=0; i<show_count; i++)); do
        local tab="${AGENT_TABS[$i]}"
        local desc="${AGENT_DESCS[$i]}"
        local st="${AGENT_STATES[$i]}"
        local icon="󱥁"
        local st_color="$c_yellow"
        case "$st" in
          idle) icon="󱥂"; st_color="$c_cyan" ;;
          busy|working) icon="󱥁"; st_color="$c_yellow" ;;
          question|permission|awaiting_input) icon="󱜻"; st_color="$c_magenta" ;;
          error) icon="󰨄"; st_color="$c_red" ;;
        esac
        printf "     ${c_muted}󰚩${c_reset} ${c_bold}Tab %-2s${c_reset}  ${c_fg}%-28s${c_reset}  ${st_color}%s %-7s${c_reset}\n" \
          "$tab" "$desc" "$icon" "$st"
      done
      if [ "$AGENT_COUNT" -gt 3 ]; then
        printf "     ${c_muted}󰚩 ... and %d more active agent window(s)${c_reset}\n" "$((AGENT_COUNT - 3))"
      fi
      printf "\n"
    fi

    # Section 2: Session Window Layout Threshold
    if [ "$WIN_COUNT" -gt 3 ]; then
      printf "  ${c_bold}${c_cyan}󱂬  Layout Threshold Triggered${c_reset}\n"
      printf "     ${c_muted}󱂬${c_reset}  ${c_fg}%d active windows in session${c_reset} ${c_muted}(>3 threshold)${c_reset}\n\n" "$WIN_COUNT"
    fi

    # Divider & Hints (English Action Guide)
    printf "  ${c_muted}────────────────────────────────────────────────────────────${c_reset}\n"
    printf "  ${c_bold}${c_red}y${c_reset} ${c_muted}Kill Session${c_reset}   ${c_muted}│${c_reset}   ${c_bold}${c_cyan}n${c_reset} ${c_muted}/${c_reset} ${c_bold}${c_cyan}Esc${c_reset} ${c_muted}Keep Session${c_reset}\n"
  )
  print_modal_body "$body"
  if [ -n "${BORDER_GRADIENT:-}" ]; then
    gradient_frame_draw "$BORDER_GRADIENT" $' \uea6c ' "$COLOR_YELLOW" || true
  fi

  # Hide cursor during prompt to eliminate blinking artifacts
  printf '\033[?25l'
  trap 'printf "\033[?25h"' EXIT

  local key
  IFS= read -rsn1 key
  # Handle Esc sequences
  if [[ "$key" == $'\e' ]]; then
    read -rsn2 -t 0.05 esc_rest 2>/dev/null || true
    key="Esc"
  fi

  case "$key" in
    y|Y)
      perform_kill "$target"
      exit 0
      ;;
    *)
      # Cancelled by user (n, N, Esc, q, Enter, etc.)
      exit 0
      ;;
  esac
}

# -----------------------------------------------------------------------------
# 5. CLI Entrypoint
# -----------------------------------------------------------------------------
main() {
  local force=0
  local check_only=0
  local is_modal=0
  local target_session=""

  while [ $# -gt 0 ]; do
    case "$1" in
      -f|--force)
        force=1
        shift
        ;;
      --check)
        check_only=1
        shift
        ;;
      --confirm-modal)
        is_modal=1
        shift
        ;;
      -h|--help)
        cat <<EOF
Usage: close-session.sh [OPTIONS] [SESSION]

Smart guarded session termination for Tmux.

Safeguards:
  Prompts for confirmation if active AI agents are running in any window,
  or if the session contains more than 3 windows (>3 threshold).
  Otherwise closes the session immediately without confirmation.

Options:
  -f, --force         Bypass checks and terminate session immediately
  --check             Diagnostic check: output analysis without killing
  --confirm-modal     Internal modal execution inside popup
  -h, --help          Show this help message
EOF
        exit 0
        ;;
      *)
        if [ -z "$target_session" ]; then
          target_session="$1"
        fi
        shift
        ;;
    esac
  done

  # Default to current tmux session
  if [ -z "$target_session" ]; then
    target_session=$(tmux display-message -p '#{session_name}' 2>/dev/null || echo "")
  fi

  if [ -z "$target_session" ]; then
    echo "close-session: No active tmux session detected" >&2
    exit 1
  fi

  if ! tmux has-session -t "$target_session" 2>/dev/null; then
    echo "close-session: Session '$target_session' not found" >&2
    exit 1
  fi

  # 1. Modal execution path
  if [ "$is_modal" -eq 1 ]; then
    run_confirm_modal "$target_session"
    exit 0
  fi

  # 2. Force termination path
  if [ "$force" -eq 1 ]; then
    perform_kill "$target_session"
    exit 0
  fi

  # 3. Analyze session state
  analyze_session "$target_session"

  # Diagnostic check mode
  if [ "$check_only" -eq 1 ]; then
    local needs_confirm=0
    if [ "$AGENT_COUNT" -gt 0 ] || [ "$WIN_COUNT" -gt 3 ]; then
      needs_confirm=1
    fi
    echo "session=$target_session"
    echo "windows=$WIN_COUNT"
    echo "agent_windows=$AGENT_COUNT"
    echo "needs_confirm=$needs_confirm"
    for r in "${REASONS[@]}"; do
      echo "reason=$r"
    done
    exit 0
  fi

  # 4. Evaluate safeguard criteria
  # Condition: Active AI agents running OR > 3 windows on session
  if [ "$AGENT_COUNT" -eq 0 ] && [ "$WIN_COUNT" -le 3 ]; then
    # Neither condition met: safe to close immediately
    perform_kill "$target_session"
    exit 0
  fi

  # 5. Condition triggered: show confirmation
  if [ -n "${TMUX:-}" ]; then
    # Calculate adaptive popup height (compact HUD)
    local detail_lines=0
    if [ "$AGENT_COUNT" -gt 0 ]; then
      local show_agents=$(( AGENT_COUNT > 3 ? 3 : AGENT_COUNT ))
      detail_lines=$(( detail_lines + show_agents + 2 ))
      [ "$AGENT_COUNT" -gt 3 ] && detail_lines=$(( detail_lines + 1 ))
    fi
    if [ "$WIN_COUNT" -gt 3 ]; then
      detail_lines=$(( detail_lines + 3 ))
    fi

    local popup_h=$(( 8 + detail_lines ))
    [ "$popup_h" -lt 11 ] && popup_h=11
    [ "$popup_h" -gt 18 ] && popup_h=18
    local popup_w=68

    # Warning theme: golden yellow border and nf-cod-warning badge
    local border_color="$COLOR_YELLOW"
    local badge="  "

    # Escape session name for safety
    local target_escaped
    target_escaped=$(printf '%q' "$target_session")

    # Close any currently open ephemeral popup to avoid conflicts
    tmux display-popup -C 2>/dev/null || true

    # Launch Golden Ratio confirmation popup modal with transparent background
    exec tmux display-popup \
      -b rounded \
      -s "bg=default,fg=default" \
      -S "fg=$border_color,bg=default" \
      -T "$badge" \
      $(popup_gradient_flags BORDER_GRADIENT) \
      -w "$popup_w" \
      -h "$popup_h" \
      -E \
      "'$REAL_SCRIPT' --confirm-modal $target_escaped"
  else
    # Terminal fallback outside tmux
    run_confirm_modal "$target_session"
  fi
}

main "$@"
