#!/usr/bin/env bash
# cockpit-picker-preview.sh — render contextual agent card and live terminal pane preview
set -uo pipefail

session="${1:-}"
idx="${2:-}"
pane_id="${3:-}"
ppath="${4:-}"
ai_raw="${5:-}"
agent_name="${6:-}"
age_str="${7:-}"
branch="${8:-}"
upstream_div="${9:-}"

if [ -z "$session" ] || [ -z "$idx" ] || [ "$idx" = "-" ]; then
  printf "  \033[38;2;146;131;116m(no active window selected)\033[0m\n"
  exit 0
fi

# Fallback resolution only if not passed from items
if [ -z "$pane_id" ] || [ "$pane_id" = "-" ]; then
  pane_id=$(tmux display-message -p -t "${session}:${idx}" '#{pane_id}' 2>/dev/null || echo "")
fi
if [ -z "$ppath" ] || [ "$ppath" = "-" ]; then
  ppath=$(tmux display-message -p -t "${session}:${idx}" '#{pane_current_path}' 2>/dev/null || echo "")
fi

R='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

# Theme palette colors — pure bash parser, zero subshell/process forks
_colors_toml="$HOME/.local/state/omarchy/current/theme/colors.toml"
_color_orange="#e09d7f"
_color_yellow="#dbbc7f"
_color_red="#e67e80"
_color_magenta="#d699b6"
_color_cyan="#83c092"
_color_blue="#7fbbb3"
_color_fg="#d3c6aa"
_color_muted="#475258"

if [[ -f "$_colors_toml" ]]; then
  while IFS='=' read -r key val; do
    key="${key//[[:space:]]/}"
    val="${val//[[:space:]\"\'\n]/}"
    case "$key" in
      orange) _color_orange="$val" ;;
      yellow) _color_yellow="$val" ;;
      red) _color_red="$val" ;;
      magenta) _color_magenta="$val" ;;
      cyan) _color_cyan="$val" ;;
      blue) _color_blue="$val" ;;
      foreground) _color_fg="$val" ;;
      muted) _color_muted="$val" ;;
    esac
  done < "$_colors_toml"
fi

_set_hex() {
  local h="${2#\#}"
  [[ ! "$h" =~ ^[0-9a-fA-F]{6}$ ]] && h="89b4fa"
  local r=$(( 16#${h:0:2} )) g=$(( 16#${h:2:2} )) b=$(( 16#${h:4:2} ))
  printf -v "$1" '\033[38;2;%d;%d;%dm' "$r" "$g" "$b"
}

_set_hex C_ORANGE "$_color_orange"
_set_hex C_YELLOW "$_color_yellow"
_set_hex C_RED "$_color_red"
_set_hex C_MAGENTA "$_color_magenta"
_set_hex C_CYAN "$_color_cyan"
_set_hex C_BLUE "$_color_blue"
_set_hex C_FG "$_color_fg"
_set_hex C_GRAY "$_color_muted"

# Git discovery
commit="n/a"
churn_info="working tree clean"
churn_files=""
is_git=0

if [ -n "$branch" ] && [ "$branch" != "-" ] && [ "$branch" != "non-git" ]; then
  is_git=1
elif [ -z "$branch" ] && [ -n "$ppath" ] && ( [ -d "$ppath/.git" ] || git -C "$ppath" rev-parse --is-inside-work-tree >/dev/null 2>&1 ); then
  is_git=1
  branch=$(git -C "$ppath" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "detached")
fi

if [ "$is_git" -eq 1 ] && [ -n "$ppath" ]; then
  commit=$(git -C "$ppath" log -1 --format='%h · %s (%cr)' 2>/dev/null || echo "initial")
  git_stat=$(git -C "$ppath" status --short 2>/dev/null || true)
  if [ -n "$git_stat" ]; then
    mod_count=$(printf '%s\n' "$git_stat" | grep -c '[^[:space:]]' || true)
    if [ "${mod_count:-0}" -gt 0 ]; then
      churn_info="${mod_count} files modified"
      churn_files=$(printf '%s\n' "$git_stat" | head -n 4 | sed 's/^/    /')
    fi
  fi
fi

# Fallback agent discovery if not passed from items
if [ -z "$ai_raw" ] || [ "$ai_raw" = "-" ]; then
  token_file="${XDG_RUNTIME_DIR:-/run/user/$UID}/acpd/token"
  if [ -f "$token_file" ]; then
    token="$(cat "$token_file" 2>/dev/null || true)"
    if [ -n "$token" ]; then
      acpd_json=$(curl -s -m 0.1 -X POST http://127.0.0.1:4040/rpc \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"agentState/list","id":1}' 2>/dev/null || true)
      if [ -n "$acpd_json" ]; then
        ai_raw=$(echo "$acpd_json" | jq -r ".result[\"$pane_id\"].state // empty" 2>/dev/null || true)
      fi
    fi
  fi
  [ -z "$ai_raw" ] && ai_raw=$(tmux show-option -wqv -t "${session}:${idx}" @ai_agent_state_raw 2>/dev/null || true)
  [ -z "$ai_raw" ] && ai_raw=$(tmux show-option -pqv -t "$pane_id" @ai_agent_state_raw 2>/dev/null || true)
fi

[ "$ai_raw" = "-" ] && ai_raw=""
[ "$agent_name" = "-" ] && agent_name=""
[ "$age_str" = "-" ] && age_str=""

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
  stalled|hanging)
    status_badge="${C_ORANGE}${BOLD}󱥁 STALLED / HANGING${R}"
    card_border="$C_ORANGE"
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
    else
      status_badge="${C_GRAY}TERMINAL${R}"
      card_border="$C_GRAY"
    fi
    ;;
esac

if [ -n "$age_str" ]; then
  status_badge="${status_badge}  ${C_GRAY}• ${age_str} ago${R}"
fi

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
  (( pad < 0 )) && pad=0
  printf "${card_border}│${R} %b%*s ${card_border}│${R}\n" "$content" "$pad" ""
}

# Single capture-pane call for both task prompt and bottom snapshot (captures 120 lines of scrollback)
raw_terminal=$(tmux capture-pane -ep -S -120 -t "$pane_id" 2>/dev/null || true)

# Render Top Context Card
printf "${card_border}╭%s╮${R}\n" "${DASHES:0:$(( W - 2 ))}"
_box_line "${BOLD}󰈈 Status:${R} ${status_badge}"
if [ -n "$agent_name" ]; then
  _box_line "${BOLD}󰑮 Agent:${R}  ${C_YELLOW}${agent_name}${R}"
fi

captured_task=$(printf '%s\n' "$raw_terminal" | sed -E 's/\x1b\[[0-9;]*[a-zA-Z]//g' | grep -E '^([>❯] |User:|Input:)' | tail -n 1 | sed -E 's/^[>❯[:space:]]+//; s/^(User:|Input:)[[:space:]]*//' | tr -s ' ' | head -c 80)
if [ -n "$captured_task" ]; then
  clean_task="$captured_task"
  max_tk=$(( W - 14 ))
  if (( ${#clean_task} > max_tk && max_tk > 5 )); then
    clean_task="${clean_task:0:$(( max_tk - 1 ))}…"
  fi
  _box_line "${BOLD}󰞋 Task:${R}   ${C_FG}${clean_task}${R}"
fi

if [ "$is_git" -eq 1 ]; then
  sync_str=""
  if [ -n "$upstream_div" ] && [ "$upstream_div" != "-" ]; then
    case "$upstream_div" in
      *synced*) sync_str="  ${C_CYAN}󰄬 Synced${R}" ;;
      *ahead*behind*) sync_str="  ${C_CYAN}󰞕 Ahead${R} ${C_RED}󰞒 Behind${R}" ;;
      *ahead*) sync_str="  ${C_CYAN}󰞕 Ahead${R}" ;;
      *behind*) sync_str="  ${C_RED}󰞒 Behind${R}" ;;
      *local*) sync_str="  ${C_GRAY}󰄱 Local${R}" ;;
      *) sync_str="  ${C_CYAN}${upstream_div}${R}" ;;
    esac
  fi

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

  # GitHub PR & CI status checks (cached 60s, non-blocking background refresh)
  if [ "$branch" != "main" ] && [ "$branch" != "master" ] && [ "$branch" != "detached" ] && command -v gh >/dev/null 2>&1; then
    hash_key=$(printf '%s:%s' "$ppath" "$branch" | md5sum | awk '{print $1}')
    cache_file="/tmp/gh-pr-cache-${hash_key}.json"
    now_s=$(date +%s)
    cache_age=9999
    if [ -f "$cache_file" ]; then
      cache_mtime=$(stat -c %Y "$cache_file" 2>/dev/null || echo 0)
      cache_age=$(( now_s - cache_mtime ))
    fi

    if [ "$cache_age" -gt 60 ]; then
      touch "$cache_file" 2>/dev/null || true
      (
        cd "$ppath" 2>/dev/null || exit 0
        if gh pr view --json number,title,state,statusCheckRollup > "${cache_file}.tmp" 2>/dev/null && [ -s "${cache_file}.tmp" ]; then
          mv "${cache_file}.tmp" "$cache_file"
        else
          c_sha=$(git rev-parse HEAD 2>/dev/null || echo "")
          if [ -n "$c_sha" ]; then
            c_state=$(gh api "repos/:owner/:repo/commits/${c_sha}/status" --jq .state 2>/dev/null || echo "none")
            if [ -n "$c_state" ] && [ "$c_state" != "none" ]; then
              echo "{\"commit_state\":\"$c_state\"}" > "$cache_file"
            else
              echo "{}" > "$cache_file"
            fi
          else
            echo "{}" > "$cache_file"
          fi
          rm -f "${cache_file}.tmp"
        fi
      ) &
    fi

    if [ -s "$cache_file" ]; then
      pr_raw=$(jq -r '[.number // "", (if .statusCheckRollup == null or (.statusCheckRollup | length) == 0 then (.commit_state // "none") elif ([.statusCheckRollup[] | select(.conclusion == "FAILURE" or .conclusion == "TIMED_OUT")] | length) > 0 then "failure" elif ([.statusCheckRollup[] | select(.status == "IN_PROGRESS" or .status == "QUEUED" or .conclusion == null)] | length) > 0 then "pending" elif ([.statusCheckRollup[] | select(.conclusion == "SUCCESS")] | length) > 0 then "success" else (.commit_state // "none") end), (.title // "")] | @tsv' "$cache_file" 2>/dev/null || true)
      if [ -n "$pr_raw" ]; then
        IFS=$'\t' read -r pr_num ci_status pr_title <<< "$pr_raw"
        ci_badge=""
        case "$ci_status" in
          success) ci_badge="${C_CYAN}󰄬 CI Passing${R}" ;;
          failure) ci_badge="${C_RED}󰅚 CI Failing${R}" ;;
          pending) ci_badge="${C_YELLOW}@SPIN@ CI Pending${R}" ;;
        esac

        if [ -n "$pr_num" ]; then
          clean_pr_title="$pr_title"
          max_pr=$(( W - 18 - ${#ci_status} ))
          if (( ${#clean_pr_title} > max_pr && max_pr > 5 )); then
            clean_pr_title="${clean_pr_title:0:$(( max_pr - 1 ))}…"
          fi
          _box_line "${BOLD}󰏫 PR #${pr_num}:${R}  ${C_FG}${clean_pr_title}${R}${ci_badge:+  ${ci_badge}}"
        elif [ -n "$ci_badge" ]; then
          _box_line "${BOLD}󰙨 Checks:${R}   ${ci_badge} ${C_GRAY}(remote branch commit)${R}"
        fi
      fi
    fi
  fi

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

# Render Bottom Terminal Snapshot (most up-to-date conversation scrollback)
if [ -n "$raw_terminal" ]; then
  printf '%s\n' "$raw_terminal" | awk '/[^[:space:]]/{last=NR} {lines[NR]=$0} END{for(i=1;i<=last;i++) print lines[i]}'
else
  printf "  ${C_GRAY}(pane output empty or detached)${R}\n"
fi
