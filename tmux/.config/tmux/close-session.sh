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
  AGENT_LABELS=()
  AGENT_COLORS=()
  AGENT_ICONS=()
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

  while IFS="|" read -r wid wnum wname pid pcmd ptitle raw_state raw_title raw_color pane_pid; do
    local is_agent=0
    local agent_desc=""
    local agent_label="agent"
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
        agent_label="${pcmd%-bin}"
        [ -z "$st" ] && st="running"
        ;;
    esac

    # 4. Process tree inspection (descendants of pane PID)
    # Also when the pane is known but runs the agent under a wrapper (`agy` is a
    # bash script around agy-bin, so tmux reports `bash`): it names the agent.
    if [ "$agent_label" = "agent" ] && [ -n "$pane_pid" ]; then
      local matched_cmd
      matched_cmd=$(ps -s "$pane_pid" -o comm= 2>/dev/null | grep -m1 -E "^(agy|agy-bin|antigravity|opencode|claude|devin|codex|muse|gemini|aider)$" || true)
      if [ -n "$matched_cmd" ]; then
        is_agent=1
        agent_label="${matched_cmd%-bin}"
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
      # The task title only: the window name is the agent's icon.
      [ -z "$agent_desc" ] && agent_desc="$raw_title"
      AGENT_TABS+=("$wnum")
      AGENT_DESCS+=("$agent_desc")
      AGENT_STATES+=("${st:-active}")
      AGENT_LABELS+=("$agent_label")
      AGENT_COLORS+=("$raw_color")
      # The tab's own icon when its name is one glyph (set by the agent's hooks).
      if [ "${#wname}" -eq 1 ] && [[ "$wname" != [[:ascii:]] ]]; then AGENT_ICONS+=("$wname"); else AGENT_ICONS+=(""); fi
    fi
  done < <(tmux list-panes -s -t "$target" -F "#{window_id}|#{window_index}|#{window_name}|#{pane_id}|#{pane_current_command}|#{pane_title}|#{@ai_agent_state_raw}|#{@ai_agent_title}|#{@ai_agent_state_color}|#{pane_pid}" 2>/dev/null || true)

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
# busy_agent_count — agents that would lose work (not idle), one per pane.
busy_agent_count() {
  local n=0 st
  for st in "${AGENT_STATES[@]}"; do
    case "$st" in idle|done|closed|inactive|completed) ;; *) n=$((n + 1)) ;; esac
  done
  echo "$n"
}

run_confirm_modal() {
  local target="$1"

  analyze_session "$target"

  local body
  body=$(
    # What closing costs, in one sentence: the tabs (when more than 3) and the busy agents.
    local busy
    busy=$(busy_agent_count)
    local agents="the agent below" note
    [ "$busy" -gt 1 ] && agents="the $busy agents below"
    if [ "$busy" -gt 0 ] && [ "$WIN_COUNT" -gt 3 ]; then
      note="Closing ends $WIN_COUNT tabs and stops $agents."
    elif [ "$busy" -gt 0 ]; then
      note="Closing stops $agents."
    else
      note="Closing ends all $WIN_COUNT tabs."
    fi
    modal_head "Close session $target?" "$note"

    # One row per busy agent (idle ones lose nothing), the tab number in the label.
    local shown=0
    for ((i=0; i<${#AGENT_STATES[@]}; i++)); do
      case "${AGENT_STATES[$i]}" in idle|done|closed|inactive|completed) continue ;; esac
      if [ "$shown" -lt 3 ]; then
        modal_agent_row "${AGENT_STATES[$i]}" "${AGENT_COLORS[$i]}" "${AGENT_LABELS[$i]}" "tab ${AGENT_TABS[$i]}" "${AGENT_DESCS[$i]}" "${AGENT_ICONS[$i]}"
      fi
      shown=$(( shown + 1 ))
    done
    if [ "$shown" -gt 3 ]; then
      printf '  \033[38;5;8m+ %d more\033[0m\n' "$((shown - 3))"
    fi
  )
  print_modal_body "$body"
  modal_footer y Close n/Esc Keep
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
    # Head (blank, question, note, blank) + rows + blank + rule + footer + frame.
    local busy detail_lines=0
    busy=$(busy_agent_count)
    if [ "$busy" -gt 0 ]; then
      detail_lines=$(( (busy > 3 ? 3 : busy) + 1 ))
      [ "$busy" -gt 3 ] && detail_lines=$(( detail_lines + 1 ))
    fi
    local popup_h=$(( 8 + detail_lines ))
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
