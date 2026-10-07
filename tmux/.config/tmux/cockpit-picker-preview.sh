#!/usr/bin/env bash
# cockpit-picker-preview.sh — render contextual agent card and live terminal pane preview
set -uo pipefail

session="${1:-}"
idx="${2:-}"
pane_id="${3:-}"
ppath="${4:-}"

if [ -z "$session" ] || [ -z "$idx" ]; then
  printf "  \033[38;2;146;131;116m(no active window selected)\033[0m\n"
  exit 0
fi

[ -z "$pane_id" ] && pane_id=$(tmux display-message -p -t "${session}:${idx}" '#{pane_id}' 2>/dev/null || echo "")
[ -z "$ppath" ] && ppath=$(tmux display-message -p -t "${session}:${idx}" '#{pane_current_path}' 2>/dev/null || echo "")

R='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

# Theme palette colors
_colors_toml="$HOME/.local/state/omarchy/current/theme/colors.toml"
_color_orange=$(grep '^orange' "$_colors_toml" 2>/dev/null | sed 's/.*= *"\(.*\)"/\1/' || echo "#e09d7f")
_color_yellow=$(grep '^yellow' "$_colors_toml" 2>/dev/null | sed 's/.*= *"\(.*\)"/\1/' || echo "#dbbc7f")
_color_red=$(grep '^red ' "$_colors_toml" 2>/dev/null | sed 's/.*= *"\(.*\)"/\1/' || echo "#e67e80")
_color_magenta=$(grep '^magenta' "$_colors_toml" 2>/dev/null | sed 's/.*= *"\(.*\)"/\1/' || echo "#d699b6")
_color_cyan=$(grep '^cyan' "$_colors_toml" 2>/dev/null | sed 's/.*= *"\(.*\)"/\1/' || echo "#83c092")
_color_blue=$(grep '^blue' "$_colors_toml" 2>/dev/null | sed 's/.*= *"\(.*\)"/\1/' || echo "#7fbbb3")
_color_fg=$(grep '^foreground' "$_colors_toml" 2>/dev/null | sed 's/.*= *"\(.*\)"/\1/' || echo "#d3c6aa")
_color_muted=$(grep '^muted' "$_colors_toml" 2>/dev/null | sed 's/.*= *"\(.*\)"/\1/' || echo "#475258")

_hex_esc() {
  local h="${1#\#}"
  if [[ ! "$h" =~ ^[0-9a-fA-F]{6}$ ]]; then
    h="89b4fa"
  fi
  local r=$(( 16#${h:0:2} ))
  local g=$(( 16#${h:2:2} ))
  local b=$(( 16#${h:4:2} ))
  printf '\033[38;2;%d;%d;%dm' "$r" "$g" "$b"
}

C_ORANGE=$(_hex_esc "${_color_orange:-#e09d7f}")
C_YELLOW=$(_hex_esc "${_color_yellow:-#dbbc7f}")
C_RED=$(_hex_esc "${_color_red:-#e67e80}")
C_MAGENTA=$(_hex_esc "${_color_magenta:-#d699b6}")
C_CYAN=$(_hex_esc "${_color_cyan:-#83c092}")
C_BLUE=$(_hex_esc "${_color_blue:-#7fbbb3}")
C_FG=$(_hex_esc "${_color_fg:-#d3c6aa}")
C_GRAY=$(_hex_esc "${_color_muted:-#475258}")

# Git discovery
branch="non-git"
commit="n/a"
churn_info="0 modified"
churn_files=""
upstream_div=""
is_git=0

if [ -n "$ppath" ] && ( [ -d "$ppath/.git" ] || git -C "$ppath" rev-parse --is-inside-work-tree >/dev/null 2>&1 ); then
  is_git=1
  branch=$(git -C "$ppath" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "detached")
  commit=$(git -C "$ppath" log -1 --format='%h · %s (%cr)' 2>/dev/null || echo "initial")
  git_stat=$(git -C "$ppath" status --short 2>/dev/null || true)
  if [ -n "$git_stat" ]; then
    mod_count=$(printf '%s\n' "$git_stat" | grep -c '[^[:space:]]' || true)
    [ -z "$mod_count" ] && mod_count=0
    if [ "$mod_count" -gt 0 ]; then
      churn_info="${mod_count} files modified"
      churn_files=$(printf '%s\n' "$git_stat" | head -n 4 | sed 's/^/    /')
    else
      churn_info="working tree clean"
    fi
  else
    churn_info="working tree clean"
  fi

  # Remote upstream divergence (Ahead / Behind / Synced) matching AWT
  if git -C "$ppath" rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
    u_counts=$(git -C "$ppath" rev-list --left-right --count '@{u}...HEAD' 2>/dev/null || true)
    u_behind=$(echo "$u_counts" | awk '{print $1}')
    u_ahead=$(echo "$u_counts" | awk '{print $2}')
    if [ -n "$u_ahead" ] && [ -n "$u_behind" ]; then
      if [ "$u_ahead" -eq 0 ] && [ "$u_behind" -eq 0 ]; then
        upstream_div="${C_CYAN}󰄬 Synced${R}"
      else
        [[ "$u_ahead" -gt 0 ]] && upstream_div+="${C_CYAN}󰞕${u_ahead}${R} "
        [[ "$u_behind" -gt 0 ]] && upstream_div+="${C_RED}󰞒${u_behind}${R}"
        upstream_div="${upstream_div% }"
      fi
    fi
  else
    upstream_div="${C_GRAY}󰄱 local only${R}"
  fi
fi

# Query ACPD for live state & timestamp
token_file="${XDG_RUNTIME_DIR:-/run/user/$UID}/acpd/token"
acpd_st=""
acpd_ts=0
if [ -f "$token_file" ]; then
  token="$(cat "$token_file" 2>/dev/null || true)"
  if [ -n "$token" ]; then
    acpd_json=$(curl -s -m 0.25 -X POST http://127.0.0.1:4040/rpc \
      -H "Authorization: Bearer $token" \
      -H "Content-Type: application/json" \
      -d '{"jsonrpc":"2.0","method":"agentState/list","id":1}' 2>/dev/null || true)
    if [ -n "$acpd_json" ]; then
      acpd_st=$(echo "$acpd_json" | jq -r ".result[\"$pane_id\"].state // empty" 2>/dev/null || true)
      acpd_ts=$(echo "$acpd_json" | jq -r ".result[\"$pane_id\"].last_timestamp // 0" 2>/dev/null || echo 0)
    fi
  fi
fi

# Fallback: window options, then pane options
ai_raw="$acpd_st"
if [ -z "$ai_raw" ]; then
  ai_raw=$(tmux show-option -wqv -t "${session}:${idx}" @ai_agent_state_raw 2>/dev/null || true)
fi
if [ -z "$ai_raw" ]; then
  ai_raw=$(tmux show-option -pqv -t "$pane_id" @ai_agent_state_raw 2>/dev/null || true)
fi

ai_title=$(tmux show-option -wqv -t "${session}:${idx}" @ai_agent_title 2>/dev/null || true)
if [ -z "$ai_title" ]; then
  ai_title=$(tmux show-option -pqv -t "$pane_id" @ai_agent_title 2>/dev/null || true)
fi

cmd_name=$(tmux display-message -p -t "$pane_id" '#{pane_current_command}' 2>/dev/null || echo "")
pane_title=$(tmux display-message -p -t "$pane_id" '#{pane_title}' 2>/dev/null || echo "")
case "$pane_title" in alarm|zsh|bash|sh|"") pane_title="" ;; esac

# Process tree agent detection
pane_os_pid=$(tmux display-message -p -t "$pane_id" '#{pane_pid}' 2>/dev/null || echo "")
detected_agent=""
if [ -n "$pane_os_pid" ]; then
  detected_agent=$(ps -s "$pane_os_pid" -o comm= 2>/dev/null | grep -E '^(agy|agy-bin|antigravity|opencode|claude|codex)$' | head -n 1 || true)
fi

agent_name=""
if [ -n "$detected_agent" ]; then
  case "${detected_agent%-bin}" in
    agy|antigravity) agent_name="Antigravity" ;;
    claude) agent_name="Claude Code" ;;
    opencode) agent_name="OpenCode" ;;
    codex) agent_name="Codex" ;;
    *) agent_name="${detected_agent%-bin}" ;;
  esac
fi

if [ -z "$ai_title" ] && [ -n "$pane_title" ]; then
  if [ "$pane_title" != "$session" ] && [ "$pane_title" != "$cmd_name" ]; then
    ai_title="$pane_title"
  fi
fi

# Waiting age calculation
age_str=""
if (( acpd_ts > 0 )); then
  now_ms=$(date +%s000)
  diff_s=$(( (now_ms - acpd_ts) / 1000 ))
  if (( diff_s < 60 )); then
    age_str="${diff_s}s ago"
  elif (( diff_s < 3600 )); then
    age_str="$((diff_s / 60))m $((diff_s % 60))s ago"
  else
    age_str="$((diff_s / 3600))h $(((diff_s % 3600) / 60))m ago"
  fi
fi

status_badge="Normal Shell"
card_border="$C_GRAY"
case "$ai_raw" in
  permission)
    status_badge="${C_ORANGE}${BOLD}󱅭 PERMISSION REQUIRED${R}"
    card_border="$C_ORANGE"
    ;;
  question|awaiting_input)
    status_badge="${C_MAGENTA}${BOLD}󱜻 INTERACTIVE QUESTION${R}"
    card_border="$C_MAGENTA"
    ;;
  error)
    status_badge="${C_RED}${BOLD}󰨄 EXECUTION ERROR${R}"
    card_border="$C_RED"
    ;;
  busy|working)
    status_badge="${C_YELLOW}${BOLD}󰑮 WORKING (${agent_name:-agent})${R}"
    card_border="$C_YELLOW"
    ;;
  idle)
    status_badge="${C_CYAN}${BOLD}󱥂 IDLE / READY (${agent_name:-agent})${R}"
    card_border="$C_CYAN"
    ;;
  *)
    if [ -n "$agent_name" ]; then
      status_badge="${C_CYAN}${BOLD}󱥂 READY (${agent_name})${R}"
      card_border="$C_CYAN"
    elif [[ "$cmd_name" =~ ^(agy|antigravity|opencode|claude|codex)$ ]] || [[ "$pane_title" =~ (agy|antigravity|opencode|claude) ]]; then
      status_badge="${C_YELLOW}${BOLD}󰑮 RUNNING (${cmd_name:-agent})${R}"
      card_border="$C_YELLOW"
    else
      status_badge="${C_GRAY}TERMINAL (${cmd_name:-shell})${R}"
      card_border="$C_GRAY"
    fi
    ;;
esac

# Append age to status badge if available
if [ -n "$age_str" ]; then
  status_badge="${status_badge}  ${C_GRAY}• ${age_str}${R}"
fi

# Calculate box width (clamped dynamically)
preview_w="${COLUMNS:-80}"
(( preview_w < 50 )) && preview_w=50
W=$(( preview_w - 2 ))
(( W > 76 )) && W=76
(( W < 48 )) && W=48

DASHES="────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────"

_box_line() {
  local content="$1"
  local clean=$(printf "%b" "$content" | sed -E "s/\x1b\[[0-9;]*[a-zA-Z]//g" | tr -d '\r\n')
  local len=${#clean}
  local max_content=$(( W - 4 ))
  local pad=$(( max_content - len ))
  if (( pad < 0 )); then
    pad=0
  fi
  printf "${card_border}│${R} %b%*s ${card_border}│${R}\n" "$content" "$pad" ""
}

# Render Top Context Card with clean border (no text)
printf "${card_border}╭%s╮${R}\n" "${DASHES:0:$(( W - 2 ))}"
_box_line "${BOLD}󰈈 Status:${R} ${status_badge}"
if [ -n "$agent_name" ]; then
  _box_line "${BOLD}󰑮 Agent:${R}  ${C_YELLOW}${agent_name}${R}"
fi
if [ "$is_git" -eq 1 ]; then
  sync_str=""
  [ -n "$upstream_div" ] && sync_str="  ${upstream_div}"

  max_cnt=$(( W - 4 ))
  clean_sync=$(printf "%b" "$sync_str" | sed -E "s/\x1b\[[0-9;]*[a-zA-Z]//g")
  churn_part="    ${BOLD}󰄧 Churn:${R} ${churn_info}"
  clean_churn=$(printf "%b" "$churn_part" | sed -E "s/\x1b\[[0-9;]*[a-zA-Z]//g")
  avail_b=$(( max_cnt - 10 - ${#clean_sync} - ${#clean_churn} ))
  clean_branch="$branch"
  if (( ${#clean_branch} > avail_b && avail_b > 6 )); then
    clean_branch="${clean_branch:0:$(( avail_b - 1 ))}…"
  fi

  _box_line "${BOLD}󰊢 Branch:${R} ${C_BLUE}${clean_branch}${R}${sync_str}${churn_part}"

  clean_commit="$commit"
  max_c=$(( W - 14 ))
  if (( ${#clean_commit} > max_c )); then
    clean_commit="${clean_commit:0:$(( max_c - 1 ))}…"
  fi
  _box_line "${BOLD}󰜘 Commit:${R} ${DIM}${clean_commit}${R}"
fi
printf "${card_border}╰%s╯${R}\n" "${DASHES:0:$(( W - 2 ))}"

# If there are modified files, show a compact preview
if [ -n "$churn_files" ]; then
  printf "${DIM}%s${R}\n" "$churn_files"
  printf "\n"
fi

# Render Bottom Terminal Snapshot (most recent 20 lines of the conversation)
raw_terminal=$(tmux capture-pane -ep -t "$pane_id" 2>/dev/null || true)
if [ -n "$raw_terminal" ]; then
  printf '%s\n' "$raw_terminal" | awk '/[^[:space:]]/{last=NR} {lines[NR]=$0} END{for(i=1;i<=last;i++) print lines[i]}' | tail -n 20
else
  printf "  ${C_GRAY}(pane output empty or detached)${R}\n"
fi
