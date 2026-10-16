#!/usr/bin/env bash
# cockpit-picker-items.sh — emit prioritized agent triage, windows, and fleet overview items
set -uo pipefail

# Helper: read a tmux global option
_tget() { tmux show-option -gqv "$1" 2>/dev/null; }

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

R='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

_colors_toml="$HOME/.local/state/omarchy/current/theme/colors.toml"
_color_orange=$(grep '^orange' "$_colors_toml" 2>/dev/null | sed 's/.*= *"\(.*\)"/\1/' || echo "#e09d7f")
_color_yellow=$(grep '^yellow' "$_colors_toml" 2>/dev/null | sed 's/.*= *"\(.*\)"/\1/' || echo "#dbbc7f")
_color_red=$(grep '^red ' "$_colors_toml" 2>/dev/null | sed 's/.*= *"\(.*\)"/\1/' || echo "#e67e80")
_color_magenta=$(grep '^magenta' "$_colors_toml" 2>/dev/null | sed 's/.*= *"\(.*\)"/\1/' || echo "#d699b6")
_color_cyan=$(grep '^cyan' "$_colors_toml" 2>/dev/null | sed 's/.*= *"\(.*\)"/\1/' || echo "#83c092")
_color_blue=$(grep '^blue' "$_colors_toml" 2>/dev/null | sed 's/.*= *"\(.*\)"/\1/' || echo "#7fbbb3")
_color_fg=$(grep '^foreground' "$_colors_toml" 2>/dev/null | sed 's/.*= *"\(.*\)"/\1/' || echo "#d3c6aa")
_color_muted=$(grep '^muted' "$_colors_toml" 2>/dev/null | sed 's/.*= *"\(.*\)"/\1/' || echo "#475258")

C_PERM=$(_hex_esc "${_color_orange:-#e09d7f}")
C_QUESTION=$(_hex_esc "${_color_magenta:-#d699b6}")
C_ERROR=$(_hex_esc "${_color_red:-#e67e80}")
C_BUSY=$(_hex_esc "${_color_yellow:-#dbbc7f}")
C_IDLE=$(_hex_esc "${_color_cyan:-#83c092}")
C_CYAN=$(_hex_esc "${_color_cyan:-#83c092}")
C_NORMAL=$(_hex_esc "${_color_muted:-#475258}")
C_CUR=$(_hex_esc "${_color_cyan:-#83c092}")
C_NAME=$(_hex_esc "${_color_fg:-#d3c6aa}")
C_BRANCH=$(_hex_esc "${_color_blue:-#7fbbb3}")
C_MUTED=$(_hex_esc "${_color_muted:-#475258}")
C_DIFF_INS=$(_hex_esc "${_color_cyan:-#83c092}")
C_DIFF_DEL=$(_hex_esc "${_color_red:-#e67e80}")
C_DIFF_DIRTY=$(_hex_esc "${_color_yellow:-#dbbc7f}")
C_PR=$(_hex_esc "${_color_magenta:-#d699b6}")

filter_agents=0
cur_session="${TMUX_ORIGIN_SESSION:-$(tmux display-message -p '#S' 2>/dev/null || echo "")}"
cur_window="${TMUX_ORIGIN_WINDOW:-$(tmux display-message -p '#I' 2>/dev/null || echo "")}"

for arg in "$@"; do
  case "$arg" in
    --agents|agents|-a)
      filter_agents=1
      ;;
    --fleet|fleet)
      filter_agents=0
      ;;
    *)
      if [ -z "$cur_session" ]; then
        cur_session="$arg"
      elif [ -z "$cur_window" ]; then
        cur_window="$arg"
      fi
      ;;
  esac
done

# Step 1: Query ACPD once and extract pane map in a single jq pass
token_file="${XDG_RUNTIME_DIR:-/run/user/$UID}/acpd/token"
declare -A acpd_st=()
declare -A acpd_ts=()

if [ -f "$token_file" ]; then
  token="$(< "$token_file" 2>/dev/null || true)"
  if [ -n "$token" ]; then
    acpd_json=$(curl -s -m 0.15 -X POST http://127.0.0.1:4040/rpc \
      -H "Authorization: Bearer $token" \
      -H "Content-Type: application/json" \
      -d '{"jsonrpc":"2.0","method":"agentState/list","id":1}' 2>/dev/null || true)
    if [ -n "$acpd_json" ]; then
      while IFS=$'\t' read -r apid ast ats; do
        if [ -n "$apid" ]; then
          acpd_st["$apid"]="$ast"
          acpd_ts["$apid"]="$ats"
        fi
      done < <(echo "$acpd_json" | jq -r '.result | to_entries[] | "\(.key)\t\(.value.state // "")\t\(.value.last_timestamp // 0)"' 2>/dev/null || true)
    fi
  fi
fi

# Step 2: Query running processes once globally to map agent sessions
declare -A sess_agent=()
while read -r p_sess p_comm; do
  case "$p_comm" in
    agy|agy-bin|antigravity|opencode|claude|codex)
      sess_agent["$p_sess"]="${p_comm%-bin}"
      ;;
  esac
done < <(ps -eo sess,comm 2>/dev/null || true)

now_ms=$(date +%s000)

# Memoization caches for Git and PR metadata by directory path (ppath)
declare -A git_checked=()
declare -A git_is_repo=()
declare -A git_branch=()
declare -A git_has_u=()
declare -A git_ahead=()
declare -A git_behind=()
declare -A git_diffstat=()
declare -A git_pr_num=()
declare -A git_pr_ci=()

# Temporary file to collect candidates for priority sorting
tmp_raw=$(mktemp /tmp/triage-items-XXXXXX)

tmux list-panes -a -F '#{session_name}|#{window_index}|#{window_name}|#{pane_id}|#{pane_pid}|#{pane_current_path}|#{pane_current_command}|#{pane_title}|#{@ai_agent_state_raw}|#{@ai_agent_title}' 2>/dev/null | while IFS='|' read -r sess idx wname pid pane_os_pid ppath pcmd ptitle raw_state ai_title; do
  case "$sess" in
    _lazygitrs*|_popups*|\.*) continue ;;
  esac

  # Fallback to window options if pane options not set directly
  [ -z "$raw_state" ] && raw_state=$(tmux show-option -wqv -t "${sess}:${idx}" @ai_agent_state_raw 2>/dev/null || true)
  [ -z "$ai_title" ] && ai_title=$(tmux show-option -wqv -t "${sess}:${idx}" @ai_agent_title 2>/dev/null || true)

  # Check pre-scanned process table for agent binaries
  detected_agent=""
  if [ -n "$pane_os_pid" ]; then
    detected_agent="${sess_agent["$pane_os_pid"]:-}"
  fi

  # Extract ACPD state & timestamp from pre-parsed hash map
  st="${acpd_st["$pid"]:-}"
  ts=${acpd_ts["$pid"]:-0}

  [ -z "$st" ] && st="$raw_state"
  if [ -z "$st" ]; then
    if [ -n "$detected_agent" ]; then
      st="idle"
    else
      st="normal"
    fi
  fi

  # Urgency priority (1 = highest urgency)
  case "$st" in
    permission)
      prio=1
      ico="󱅭"
      c_ico="$C_PERM"
      ;;
    question|awaiting_input)
      prio=2
      ico="󱜻"
      c_ico="$C_QUESTION"
      ;;
    stalled|hanging)
      prio=2
      ico="󱥁"
      c_ico="$C_PERM"
      ;;
    error)
      prio=3
      ico="󰨄"
      c_ico="$C_ERROR"
      ;;
    busy|working)
      prio=4
      ico="@SPIN@"
      c_ico="$C_BUSY"
      ;;
    idle)
      prio=5
      ico="󱥂"
      c_ico="$C_IDLE"
      ;;
    *)
      # Check if command, process tree or title is an AI agent
      if [ -n "$detected_agent" ] || [[ "$pcmd" =~ ^(agy|antigravity|opencode|claude|codex)$ ]] || [[ "$ptitle" =~ (agy|antigravity|opencode|claude) ]]; then
        prio=5
        ico="󰑮"
        c_ico="$C_BUSY"
      else
        prio=6
        ico="·"
        c_ico="$C_NORMAL"
      fi
      ;;
  esac

  # Elapsed waiting age string
  age_str=""
  diff_s=0
  if (( ts > 0 )); then
    diff_s=$(( (now_ms - ts) / 1000 ))
    if (( diff_s < 60 )); then
      age_str="${diff_s}s"
    elif (( diff_s < 3600 )); then
      age_str="$((diff_s / 60))m$((diff_s % 60))s"
    else
      age_str="$((diff_s / 3600))h$(((diff_s % 3600) / 60))m"
    fi
  fi

  # Resolve Git & PR metadata with path memoization
  branch=""
  u_ahead=0
  u_behind=0
  has_u=0
  diffstat_str=""
  pr_num=""
  pr_ci=""

  if [ -n "$ppath" ] && [ -d "$ppath" ]; then
    if [ -z "${git_checked["$ppath"]:-}" ]; then
      git_checked["$ppath"]=1
      if [ -d "$ppath/.git" ] || git -C "$ppath" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        git_is_repo["$ppath"]=1
        br=$(git -C "$ppath" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
        git_branch["$ppath"]="$br"

        if git -C "$ppath" rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
          git_has_u["$ppath"]=1
          u_counts=$(git -C "$ppath" rev-list --left-right --count '@{u}...HEAD' 2>/dev/null || true)
          git_behind["$ppath"]="$(echo "$u_counts" | awk '{print $1}')"
          git_ahead["$ppath"]="$(echo "$u_counts" | awk '{print $2}')"
        fi

        # Diffstat calculation
        ds_str=""
        diff_out=$(git -C "$ppath" diff --shortstat HEAD 2>/dev/null || true)
        if [ -n "$diff_out" ]; then
          ins=$(echo "$diff_out" | sed -nE 's/.*, ([0-9]+) insertion.*/+\1/p')
          del=$(echo "$diff_out" | sed -nE 's/.*, ([0-9]+) deletion.*/-\1/p')
          [ -n "$ins" ] && ds_str="$ins"
          if [ -n "$del" ]; then
            [ -n "$ds_str" ] && ds_str="$ds_str $del" || ds_str="$del"
          fi
        fi
        dirty_files=$(git -C "$ppath" status --porcelain 2>/dev/null | wc -l)
        if (( dirty_files > 0 )) && [ -z "$ds_str" ]; then
          ds_str="*${dirty_files}"
        fi
        git_diffstat["$ppath"]="$ds_str"

        # GitHub PR & CI status cache
        if [ -n "$br" ] && [ "$br" != "main" ] && [ "$br" != "master" ] && [ "$br" != "HEAD" ] && [ "$br" != "detached" ] && command -v gh >/dev/null 2>&1; then
          hash_key=$(printf '%s:%s' "$ppath" "$br" | md5sum | awk '{print $1}')
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
            pr_tsv=$(jq -r '[.number // "", (if .statusCheckRollup == null or (.statusCheckRollup | length) == 0 then (.commit_state // "none") elif ([.statusCheckRollup[] | select(.conclusion == "FAILURE" or .conclusion == "TIMED_OUT")] | length) > 0 then "failure" elif ([.statusCheckRollup[] | select(.status == "IN_PROGRESS" or .status == "QUEUED" or .conclusion == null)] | length) > 0 then "pending" elif ([.statusCheckRollup[] | select(.conclusion == "SUCCESS")] | length) > 0 then "success" else (.commit_state // "none") end)] | @tsv' "$cache_file" 2>/dev/null || true)
            if [ -n "$pr_tsv" ]; then
              IFS=$'\t' read -r pr_n pr_ci <<< "$pr_tsv"
              git_pr_num["$ppath"]="$pr_n"
              git_pr_ci["$ppath"]="$pr_ci"
            fi
          fi
        fi
      fi
    fi

    if [ "${git_is_repo["$ppath"]:-0}" -eq 1 ]; then
      branch="${git_branch["$ppath"]:-}"
      has_u="${git_has_u["$ppath"]:-0}"
      u_ahead="${git_ahead["$ppath"]:-0}"
      u_behind="${git_behind["$ppath"]:-0}"
      diffstat_str="${git_diffstat["$ppath"]:-}"
      pr_num="${git_pr_num["$ppath"]:-}"
      pr_ci="${git_pr_ci["$ppath"]:-}"
    fi
  fi

  is_agent=0
  if [ -n "$detected_agent" ] || [[ "$pcmd" =~ ^(agy|antigravity|opencode|claude|codex)$ ]] || [ -n "$ai_title" ]; then
    is_agent=1
  elif [ "$st" != "normal" ] && [ "$st" != "" ]; then
    is_agent=1
  fi

  # Identify agent label without slow pane captures
  agent_label=""
  if [ -n "$ai_title" ]; then
    agent_label="$ai_title"
  elif [ -n "$detected_agent" ]; then
    agent_label="$detected_agent"
  elif [[ "$pcmd" =~ ^(agy|antigravity|opencode|claude|codex)$ ]]; then
    agent_label="$pcmd"
  fi

  # Truncate agent label for list display
  short_label=""
  if [ -n "$agent_label" ]; then
    clean_label=$(printf '%s' "$agent_label" | tr '\t\r\n' '   ' | sed -E 's/[ ]+/ /g; s/^[ ]+//; s/[ ]+$//')
    if [ "${#clean_label}" -gt 24 ]; then
      short_label="${clean_label:0:23}…"
    else
      short_label="$clean_label"
    fi
  fi

  # Active marker
  is_cur=0
  if [ "$sess" = "$cur_session" ] && [ "$idx" = "$cur_window" ]; then
    is_cur=1
  fi

  # Ensure empty fields do not shift tab delimiter parsing
  [ -z "$short_label" ] && short_label="-"
  [ -z "$age_str" ] && age_str="-"
  [ -z "$branch" ] && branch="-"
  [ -z "$diffstat_str" ] && diffstat_str="-"
  [ -z "$pr_num" ] && pr_num="-"
  [ -z "$pr_ci" ] && pr_ci="-"

  printf '%d\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%d\t%s\t%d\t%d\t%d\t%d\t%s\t%s\t%s\t%d\n' \
    "$prio" "$ts" "$sess" "$idx" "$wname" "$pid" "$ppath" "$ico" "$short_label" "$age_str" "$branch" "$is_cur" "$st" "$is_agent" "$has_u" "$u_ahead" "$u_behind" "$diffstat_str" "$pr_num" "$pr_ci" "$diff_s" \
    >> "$tmp_raw"
done

# Pass 1: Identify which sessions have an active/idle AI agent and calculate min priority
declare -A sess_prio=()
declare -A sess_ts=()
declare -A session_has_agent=()

while IFS=$'\t' read -r prio ts sess idx wname pid ppath ico agent_label age_str branch is_cur st is_agent has_u u_ahead u_behind diffstat_str pr_num pr_ci diff_s; do
  if [ "$is_agent" = "1" ]; then
    session_has_agent["$sess"]=1
  fi
  cur_p=${sess_prio["$sess"]:-99}
  if (( prio < cur_p )); then
    sess_prio["$sess"]=$prio
    sess_ts["$sess"]=$ts
  fi
done < "$tmp_raw"

# Pass 2: Output sessions ordered by priority with group headers
declare -A seen_windows=()
agent_count=$(awk -F'\t' '$14 == 1 { c++ } END { print c+0 }' "$tmp_raw")

if [ "$filter_agents" -eq 1 ] && [ "$agent_count" -eq 0 ]; then
  printf "· (no active AI agents)\t0\t-\t%s\t-\t-\t-\t-\t-\t-\t-\t \033[2m(no AI agents running — press a for Fleet view)\033[0m\n" "${cur_session}"
else
  for sess in $(for s in "${!sess_prio[@]}"; do printf "%d\t%s\t%s\n" "${sess_prio[$s]}" "${sess_ts[$s]}" "$s"; done | sort -t$'\t' -k1,1n -k2,2n -k3,3 | cut -f3); do
    if [ "$filter_agents" -eq 1 ] && [ -z "${session_has_agent["$sess"]:-}" ]; then
      continue
    fi

    header_printed=0

    while IFS=$'\t' read -r prio ts s idx wname pid ppath ico agent_label age_str branch is_cur st is_agent has_u u_ahead u_behind diffstat_str pr_num pr_ci diff_s; do
      [ "$s" != "$sess" ] && continue

      if [ "$filter_agents" -eq 1 ] && [ "$is_agent" -ne 1 ]; then
        continue
      fi

      # Deduplicate multiple panes in the same window (keep highest priority pane)
      win_key="${sess}:${idx}"
      if [ -n "${seen_windows["$win_key"]:-}" ]; then
        continue
      fi
      seen_windows["$win_key"]=1

      if [ "$header_printed" -eq 0 ]; then
        printf '#  %s\n' "$sess"
        header_printed=1
      fi

      [ "$agent_label" = "-" ] && agent_label=""
      [ "$age_str" = "-" ] && age_str=""
      [ "$branch" = "-" ] && branch=""
      [ "$diffstat_str" = "-" ] && diffstat_str=""
      [ "$pr_num" = "-" ] && pr_num=""
      [ "$pr_ci" = "-" ] && pr_ci=""

      # State icon formatted with color
      case "$st" in
        permission) c_ico="$C_PERM" ;;
        question|awaiting_input) c_ico="$C_QUESTION" ;;
        stalled|hanging) c_ico="$C_PERM" ;;
        error) c_ico="$C_ERROR" ;;
        busy|working) c_ico="$C_BUSY" ;;
        idle) c_ico="$C_IDLE" ;;
        *) c_ico="$C_NORMAL" ;;
      esac

      if [ "$is_agent" = "1" ]; then
        ai_ico="${c_ico}${ico}${R} "
      else
        ai_ico="  "
      fi

      if [ "$is_cur" -eq 1 ]; then
        cur_dot="${C_CUR}•${R}"
        c_wname="${C_CUR}"
      else
        cur_dot="${C_MUTED}·${R}"
        c_wname="${C_NAME}"
      fi

      if [ "${#idx}" -eq 1 ]; then
        idx_col="${C_MUTED}${idx}${R}${cur_dot}  "
      else
        idx_col="${C_MUTED}${idx}${R}${cur_dot} "
      fi

      # Branch tag & remote sync status
      branch_tag=""
      sync_search=""
      if [ -n "$branch" ]; then
        branch_tag=" ${C_BRANCH}⎇ ${branch}${R}"
        if [ "${has_u:-0}" -eq 1 ]; then
          if [ "${u_ahead:-0}" -eq 0 ] && [ "${u_behind:-0}" -eq 0 ]; then
            branch_tag+="${C_CYAN} 󰄬${R}"
            sync_search="synced"
          else
            if [ "${u_ahead:-0}" -gt 0 ]; then
              branch_tag+="${C_CYAN} 󰞕${u_ahead}${R}"
              sync_search+=" ahead"
            fi
            if [ "${u_behind:-0}" -gt 0 ]; then
              branch_tag+="${C_ERROR} 󰞒${u_behind}${R}"
              sync_search+=" behind"
            fi
          fi
        fi
      fi

      # Diffstat badge
      diff_badge=""
      if [ -n "$diffstat_str" ]; then
        for part in $diffstat_str; do
          if [[ "$part" =~ ^\+ ]]; then
            diff_badge+=" ${C_DIFF_INS}${part}${R}"
          elif [[ "$part" =~ ^\- ]]; then
            diff_badge+=" ${C_DIFF_DEL}${part}${R}"
          else
            diff_badge+=" ${C_DIFF_DIRTY}${part}${R}"
          fi
        done
      fi

      # PR and CI badge
      pr_badge=""
      pr_search=""
      if [ -n "$pr_num" ]; then
        ci_ico=""
        case "$pr_ci" in
          success) ci_ico="${C_CYAN}󰄬${R}" ;;
          failure) ci_ico="${C_RED}󰅚${R}" ;;
          pending) ci_ico="${C_YELLOW}@SPIN@${R}" ;;
        esac
        pr_badge=" ${C_PR}󰏫#${pr_num}${R}${ci_ico:+ ${ci_ico}}"
        pr_search="PR:#${pr_num} ci:${pr_ci}"
      elif [ -n "$pr_ci" ] && [ "$pr_ci" != "none" ]; then
        case "$pr_ci" in
          success) pr_badge=" ${C_CYAN}󰄬 CI${R}" ;;
          failure) pr_badge=" ${C_RED}󰅚 CI${R}" ;;
          pending) pr_badge=" ${C_YELLOW}@SPIN@ CI${R}" ;;
        esac
        pr_search="ci:${pr_ci}"
      fi

      # Age tag
      age_tag=""
      if [ -n "$age_str" ]; then
        age_tag=" ${C_MUTED}${age_str}${R}"
      fi

      # Agent badge
      agent_tag=""
      if [ -n "$agent_label" ]; then
        agent_tag=" ${c_ico}[${agent_label}]${R}"
      fi

      display_line=" ${ai_ico}${idx_col}${c_wname}${wname}${R}${agent_tag}${age_tag}${branch_tag}${diff_badge}${pr_badge}   "
      search_title="${sess} ${idx} ${wname} ${agent_label} ${branch} ${st} ${age_str} ${sync_search} ${pr_search} ${diffstat_str}"

      printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%b\n' \
        "$search_title" "$idx" "$wname" "$sess" "$pid" "$ppath" \
        "$st" "${agent_label:--}" "${age_str:--}" "${branch:--}" "${sync_search:--}" \
        "$display_line"
    done < <(sort -t$'\t' -k1,1n -k4,4n "$tmp_raw")
  done
fi

rm -f "$tmp_raw"
