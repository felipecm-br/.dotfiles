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
# 1. Dynamic Theme Color Extraction (resolved via theme-helper.sh)
# -----------------------------------------------------------------------------
# shellcheck source=/dev/null
. "$SCRIPT_DIR/theme-helper.sh"
# shellcheck source=/dev/null
. "$SCRIPT_DIR/gradient-frame.sh"

COLOR_YELLOW=$(get_theme_color "yellow" "#e0af68")


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
AGENT_COLORS=()

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
AGENT_COLORS=()

  [ -z "$WIN_ID" ] && return 0

  declare -A waymux_panes=()
  if command -v waymux >/dev/null 2>&1; then
    while IFS=$'\t' read -r apid astate atime; do
      if [ -n "$apid" ] && [ "$astate" != "closed" ]; then
        waymux_panes["$apid"]="$astate"
      fi
    done < <(waymux list 2>/dev/null || true)
  fi

  # Determine which panes to inspect:
  # If target is a specific pane in a multi-pane window, check that pane.
  # If target window has only 1 pane (closing pane closes window), check all panes in that window.
  local query_target="$WIN_ID"
  if [ "$PANE_COUNT" -gt 1 ] && [ -n "$PANE_ID" ]; then
    query_target="$PANE_ID"
  fi

  while IFS="|" read -r wid wnum wname pid pcmd ptitle raw_state raw_title raw_color; do
    local is_agent=0
    local agent_label="agent"
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
      devin)
        is_agent=1
        agent_label="devin"
        [ -z "$st" ] && st="running"
        ;;
      codex)
        is_agent=1
        agent_label="codex"
        [ -z "$st" ] && st="running"
        ;;
      muse)
        is_agent=1
        agent_label="muse"
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
      matched_cmd=$(ps -s "$pid" -o comm= 2>/dev/null | grep -m1 -E "^(agy|agy-bin|antigravity|opencode|claude|devin|codex|muse|gemini|aider)$" || true)
      if [ -n "$matched_cmd" ]; then
        is_agent=1
        agent_label="$matched_cmd"
        [ -z "$st" ] && st="running"
      fi
    fi

    if [ "$is_agent" -eq 1 ]; then
      [ -z "$agent_desc" ] && agent_desc="${raw_title:-$wname}"
      local curr_st="${st:-active}"
      AGENT_LABELS+=("$agent_label")
      AGENT_DESCS+=("$agent_desc")
      AGENT_STATES+=("$curr_st")
      AGENT_COLORS+=("$raw_color")
      AGENT_COUNT=$(( AGENT_COUNT + 1 ))

      case "$curr_st" in
        idle|done|closed|inactive|completed)
          ;;
        *)
          ACTIVE_AGENT_COUNT=$(( ACTIVE_AGENT_COUNT + 1 ))
          ;;
      esac
    fi
  done < <(tmux list-panes -t "$query_target" -F "#{window_id}|#{window_index}|#{window_name}|#{pane_id}|#{pane_current_command}|#{pane_title}|#{@ai_agent_state_raw}|#{@ai_agent_title}|#{@ai_agent_state_color}" 2>/dev/null || true)
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

  local body
  body=$(
    local note="Closing stops the agent below."
    [ "$ACTIVE_AGENT_COUNT" -gt 1 ] && note="Closing stops the $ACTIVE_AGENT_COUNT agents below."
    modal_head "Close tab ${WIN_INDEX:-?}?" "$note"

    # One row per busy agent; idle ones lose nothing and are not listed.
    local shown=0 desc
    for ((i=0; i<AGENT_COUNT; i++)); do
      case "${AGENT_STATES[$i]}" in idle|done|closed|inactive|completed) continue ;; esac
      desc="${AGENT_DESCS[$i]}"
      [ "$desc" = "$WIN_NAME" ] && desc="" # the window name is the agent's icon, not a task
      modal_agent_row "${AGENT_STATES[$i]}" "${AGENT_COLORS[$i]}" "${AGENT_LABELS[$i]}" "$desc"
      shown=$(( shown + 1 ))
      [ "$shown" -ge 3 ] && break
    done
    if [ "$ACTIVE_AGENT_COUNT" -gt 3 ]; then
      printf '  \033[38;5;8m+ %d more\033[0m\n' "$((ACTIVE_AGENT_COUNT - 3))"
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
    # Head (blank, question, note, blank) + rows + blank + rule + footer + frame.
    local show_agents=$(( ACTIVE_AGENT_COUNT > 3 ? 3 : ACTIVE_AGENT_COUNT ))
    local detail_lines=$(( show_agents + 1 ))
    [ "$ACTIVE_AGENT_COUNT" -gt 3 ] && detail_lines=$(( detail_lines + 1 ))

    local popup_h=$(( 8 + detail_lines ))
    [ "$popup_h" -gt 13 ] && popup_h=13
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
      $(popup_gradient_flags BORDER_GRADIENT) \
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
