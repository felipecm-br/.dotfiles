#!/usr/bin/env bash
# close-window.sh — smart guarded pane/window termination for Tmux
#
# Safeguards:
#   Prompts for confirmation if an active AI agent is running in the window/pane.
#   Otherwise saves state for reopen and closes immediately without confirmation.
#
# Usage:
#   close-window.sh [OPTIONS] [TARGET_PANE_OR_WINDOW]
#
set -euo pipefail

REAL_SCRIPT="$(readlink -f "$0" 2>/dev/null || realpath "$0")"
SCRIPT_DIR="$(dirname "$REAL_SCRIPT")"
RECORD_SCRIPT="${SCRIPT_DIR}/record-window-state.sh"

# -----------------------------------------------------------------------------
# 1. Dynamic Theme Color Extraction
# -----------------------------------------------------------------------------
_get_color() {
  local key="$1"
  local fallback="$2"
  local colors_file="$HOME/.local/state/omarchy/current/theme/colors.toml"
  if [ -f "$colors_file" ]; then
    local val
    val=$(grep -E "^\s*${key}\s*=" "$colors_file" 2>/dev/null | head -n1 | sed -E 's/.*=\s*"([^"]+)".*/\1/' || true)
    printf '%s' "${val:-$fallback}"
  else
    printf '%s' "$fallback"
  fi
}

COLOR_YELLOW=$(_get_color "yellow" "#e0af68")
COLOR_RED=$(_get_color "red" "#f7768e")
COLOR_ACCENT=$(_get_color "accent" "#7aa2f7")
COLOR_MAGENTA=$(_get_color "magenta" "#ad8ee6")
COLOR_MUTED=$(_get_color "dark_foreground" "#565f89")
COLOR_FG=$(_get_color "foreground" "#a9b1d6")
COLOR_BG=$(_get_color "background" "#1a1b26")

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
# 2. Window & Agent Analysis
# -----------------------------------------------------------------------------
PANE_ID=""
WIN_ID=""
WIN_INDEX=""
WIN_NAME=""
SESS_NAME=""
PANE_COUNT=1
IS_ACTIVE=0

AGENT_COUNT=0
ACTIVE_AGENT_COUNT=0
AGENT_LABELS=()
AGENT_DESCS=()
AGENT_STATES=()

analyze_target() {
  local target="${1:-}"

  local info=""
  if [ -n "$target" ]; then
    info=$(tmux display-message -t "$target" -p '#{pane_id}|#{window_id}|#{window_index}|#{window_name}|#{session_name}|#{window_panes}|#{window_active}' 2>/dev/null || true)
  else
    info=$(tmux display-message -p '#{pane_id}|#{window_id}|#{window_index}|#{window_name}|#{session_name}|#{window_panes}|#{window_active}' 2>/dev/null || true)
  fi

  if [ -n "$info" ]; then
    IFS='|' read -r PANE_ID WIN_ID WIN_INDEX WIN_NAME SESS_NAME PANE_COUNT IS_ACTIVE <<< "$info"
  fi

  PANE_COUNT="${PANE_COUNT:-1}"
  IS_ACTIVE="${IS_ACTIVE:-0}"

  AGENT_COUNT=0
  ACTIVE_AGENT_COUNT=0
  AGENT_LABELS=()
  AGENT_DESCS=()
  AGENT_STATES=()

  [ -z "$WIN_ID" ] && return 0

  declare -A acpd_panes=()
  if command -v acpd-cli >/dev/null 2>&1; then
    while IFS=$'\t' read -r apid astate atime; do
      if [ -n "$apid" ] && [ "$astate" != "closed" ]; then
        acpd_panes["$apid"]="$astate"
      fi
    done < <(acpd-cli list 2>/dev/null || true)
  fi

  # Determine which panes to inspect:
  # If target is a specific pane in a multi-pane window, check that pane.
  # If target window has only 1 pane (closing pane closes window), check all panes in that window.
  local query_target="$WIN_ID"
  if [ "$PANE_COUNT" -gt 1 ] && [ -n "$PANE_ID" ]; then
    query_target="$PANE_ID"
  fi

  while IFS="|" read -r wid wnum wname pid pcmd ptitle raw_state raw_title; do
    local is_agent=0
    local agent_label="ai"
    local agent_desc=""
    local st=""

    # 1. ACPD registration check
    if [ -n "${acpd_panes["$pid"]:-}" ]; then
      is_agent=1
      st="${acpd_panes["$pid"]}"
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
      agy|agy-bin|antigravity)
        is_agent=1
        agent_label="antigravity"
        [ -z "$st" ] && st="running"
        ;;
      opencode)
        is_agent=1
        agent_label="opencode"
        [ -z "$st" ] && st="running"
        ;;
      claude)
        is_agent=1
        agent_label="claude"
        [ -z "$st" ] && st="running"
        ;;
      codex)
        is_agent=1
        agent_label="codex"
        [ -z "$st" ] && st="running"
        ;;
      gemini)
        is_agent=1
        agent_label="gemini"
        [ -z "$st" ] && st="running"
        ;;
      aider)
        is_agent=1
        agent_label="aider"
        [ -z "$st" ] && st="running"
        ;;
    esac

    # 4. Process tree inspection (descendants of pane PID)
    if [ "$is_agent" -eq 0 ] && [ -n "$pid" ]; then
      local matched_cmd
      matched_cmd=$(ps -s "$pid" -o comm= 2>/dev/null | grep -m1 -E "^(agy|agy-bin|antigravity|opencode|claude|codex|gemini|aider)$" || true)
      if [ -n "$matched_cmd" ]; then
        is_agent=1
        agent_label="$matched_cmd"
        [ -z "$st" ] && st="running"
      fi
    fi

    if [ "$is_agent" -eq 1 ]; then
      [ -z "$agent_desc" ] && agent_desc="${raw_title:-$wname}"
      agent_desc=$(printf '%s' "$agent_desc" | tr '\n\r\t' ' ' | sed -E 's/[[:space:]]+/ /g')
      if [ "${#agent_desc}" -gt 28 ]; then
        agent_desc="${agent_desc:0:25}..."
      fi
      local curr_st="${st:-active}"
      AGENT_LABELS+=("$agent_label")
      AGENT_DESCS+=("$agent_desc")
      AGENT_STATES+=("$curr_st")
      AGENT_COUNT=$(( AGENT_COUNT + 1 ))

      case "$curr_st" in
        idle|done|closed|inactive|completed)
          ;;
        *)
          ACTIVE_AGENT_COUNT=$(( ACTIVE_AGENT_COUNT + 1 ))
          ;;
      esac
    fi
  done < <(tmux list-panes -t "$query_target" -F "#{window_id}|#{window_index}|#{window_name}|#{pane_id}|#{pane_current_command}|#{pane_title}|#{@ai_agent_state_raw}|#{@ai_agent_title}" 2>/dev/null || true)
}

# -----------------------------------------------------------------------------
# 3. Window & Pane Closure
# -----------------------------------------------------------------------------
perform_close() {
  local target="${1:-}"
  analyze_target "$target"

  local target_pane="${PANE_ID:-$target}"
  local target_win="${WIN_ID:-$target}"

  # Record state before closing for tab reopen (Ctrl+Shift+T)
  if [ -x "$RECORD_SCRIPT" ]; then
    "$RECORD_SCRIPT" --push "${target_pane:-$target_win}" 2>/dev/null || true
  fi

  # If closing this pane will close the entire window, and this window is currently active:
  # Preemptively switch focus to the MRU (last-window) or left neighbor (previous-window)
  if [ "${PANE_COUNT:-1}" -le 1 ] && [ "${IS_ACTIVE:-0}" = "1" ] && [ -n "$SESS_NAME" ]; then
    local win_count
    win_count=$(tmux list-windows -t "$SESS_NAME" 2>/dev/null | wc -l)
    if [ "$win_count" -gt 1 ]; then
      tmux select-window -t "$SESS_NAME" -l 2>/dev/null \
        || tmux previous-window -t "$SESS_NAME" 2>/dev/null \
        || tmux next-window -t "$SESS_NAME" 2>/dev/null \
        || true
    fi
  fi

  # Close the pane / window explicitly by ID
  if [ -n "$target_pane" ]; then
    tmux kill-pane -t "$target_pane" 2>/dev/null \
      || tmux kill-window -t "$target_win" 2>/dev/null \
      || true
  elif [ -n "$target_win" ]; then
    tmux kill-window -t "$target_win" 2>/dev/null || true
  else
    tmux kill-pane 2>/dev/null || tmux kill-window 2>/dev/null || true
  fi
}

# -----------------------------------------------------------------------------
# 4. Confirmation Modal Runner (executed inside display-popup or terminal)
# -----------------------------------------------------------------------------
run_confirm_modal() {
  local target="${1:-}"
  analyze_target "$target"

  local c_yellow c_red c_cyan c_magenta c_muted c_fg c_reset c_bold
  c_yellow=$(_hex_to_ansi "$COLOR_YELLOW")
  c_red=$(_hex_to_ansi "$COLOR_RED")
  c_cyan=$(_hex_to_ansi "$COLOR_ACCENT")
  c_magenta=$(_hex_to_ansi "$COLOR_MAGENTA")
  c_muted=$(_hex_to_ansi "$COLOR_MUTED")
  c_fg=$(_hex_to_ansi "$COLOR_FG")
  c_reset="\033[0m"
  c_bold="\033[1m"

  local tab_label="Tab ${WIN_INDEX:-?}"
  [ -n "$WIN_NAME" ] && tab_label="${tab_label} (${WIN_NAME})"

  printf "\n"
  printf "  ${c_bold}${c_yellow}  KILL WINDOW${c_reset} ${c_muted}·${c_reset} ${c_bold}${c_fg}%s${c_reset}\n\n" "$tab_label"

  printf "  ${c_bold}${c_red}󰮯  Active AI Agent in Window${c_reset}\n"
  local shown=0
  for ((i=0; i<AGENT_COUNT; i++)); do
    local st="${AGENT_STATES[$i]}"
    case "$st" in
      idle|done|closed|inactive|completed)
        continue
        ;;
    esac

    local label="${AGENT_LABELS[$i]}"
    local desc="${AGENT_DESCS[$i]}"
    local icon="󱥁"
    local st_color="$c_yellow"
    case "$st" in
      busy|working) icon="󱥁"; st_color="$c_yellow" ;;
      question|permission|awaiting_input) icon="󱜻"; st_color="$c_magenta" ;;
      error|stalled) icon="󰨄"; st_color="$c_red" ;;
      *) icon="󰑮"; st_color="$c_yellow" ;;
    esac
    printf "     ${c_muted}󰚩${c_reset} ${c_bold}%-12s${c_reset}  ${c_fg}%-28s${c_reset}  ${st_color}%s %-7s${c_reset}\n" \
      "$label" "$desc" "$icon" "$st"
    shown=$(( shown + 1 ))
    [ "$shown" -ge 3 ] && break
  done
  if [ "$ACTIVE_AGENT_COUNT" -gt 3 ]; then
    printf "     ${c_muted}󰚩 ... and %d more active agent(s)${c_reset}\n" "$((ACTIVE_AGENT_COUNT - 3))"
  fi
  printf "\n"

  # Divider & Compact Action Keys (English Action Guide)
  printf "  ${c_muted}────────────────────────────────────────────────────────────${c_reset}\n"
  printf "  ${c_bold}${c_red}y${c_reset} ${c_muted}Kill Window${c_reset}   ${c_muted}•${c_reset}   ${c_bold}${c_cyan}n${c_reset} ${c_muted}/${c_reset} ${c_bold}${c_cyan}Esc${c_reset} ${c_muted}Keep Window${c_reset}\n"

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
      perform_close "$target"
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
  local target=""

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
Usage: close-window.sh [OPTIONS] [TARGET_PANE_OR_WINDOW]

Smart guarded window/pane termination for Tmux.

Safeguards:
  Prompts for confirmation if an active AI agent is running in the window/pane.
  Otherwise saves state for reopen and closes immediately without confirmation.

Options:
  -f, --force         Bypass checks and close window/pane immediately
  --check             Diagnostic check: output analysis without closing
  --confirm-modal     Internal modal execution inside popup
  -h, --help          Show this help message
EOF
        exit 0
        ;;
      *)
        if [ -z "$target" ]; then
          target="$1"
        fi
        shift
        ;;
    esac
  done

  # Default to current active pane if target not specified
  if [ -z "$target" ]; then
    target=$(tmux display-message -p '#{pane_id}' 2>/dev/null || echo "")
  fi

  # 1. Modal execution path
  if [ "$is_modal" -eq 1 ]; then
    run_confirm_modal "$target"
    exit 0
  fi

  # 2. Force termination path
  if [ "$force" -eq 1 ]; then
    perform_close "$target"
    exit 0
  fi

  # 3. Analyze target state
  analyze_target "$target"

  # Diagnostic check mode
  if [ "$check_only" -eq 1 ]; then
    local needs_confirm=0
    [ "$ACTIVE_AGENT_COUNT" -gt 0 ] && needs_confirm=1
    echo "target=$target"
    echo "pane_id=$PANE_ID"
    echo "win_id=$WIN_ID"
    echo "win_index=$WIN_INDEX"
    echo "win_name=$WIN_NAME"
    echo "agent_count=$AGENT_COUNT"
    echo "active_agent_count=$ACTIVE_AGENT_COUNT"
    echo "needs_confirm=$needs_confirm"
    for ((i=0; i<AGENT_COUNT; i++)); do
      echo "agent=${AGENT_LABELS[$i]}:${AGENT_STATES[$i]}:${AGENT_DESCS[$i]}"
    done
    exit 0
  fi

  # 4. Evaluate safeguard criteria:
  # If NO AI agents are actively working/waiting (or if all agents are idle): safe to close immediately with 0ms delay!
  if [ "$ACTIVE_AGENT_COUNT" -eq 0 ]; then
    perform_close "$target"
    exit 0
  fi

  # 5. Safeguard triggered: show confirmation popup
  if [ -n "${TMUX:-}" ]; then
    local show_agents=$(( ACTIVE_AGENT_COUNT > 3 ? 3 : ACTIVE_AGENT_COUNT ))
    local detail_lines=$(( show_agents + 2 ))
    [ "$ACTIVE_AGENT_COUNT" -gt 3 ] && detail_lines=$(( detail_lines + 1 ))

    local popup_h=$(( 8 + detail_lines ))
    [ "$popup_h" -lt 11 ] && popup_h=11
    [ "$popup_h" -gt 15 ] && popup_h=15
    local popup_w=68

    local border_color="$COLOR_YELLOW"
    local badge="  "

    local target_escaped
    target_escaped=$(printf '%q' "$target")

    # Close any currently open ephemeral popup
    tmux display-popup -C 2>/dev/null || true

    exec tmux display-popup \
      -b rounded \
      -s "bg=default,fg=default" \
      -S "fg=$border_color,bg=default" \
      -T "$badge" \
      -w "$popup_w" \
      -h "$popup_h" \
      -E \
      "'$REAL_SCRIPT' --confirm-modal $target_escaped"
  else
    # Terminal fallback outside tmux
    run_confirm_modal "$target"
  fi
}

main "$@"
