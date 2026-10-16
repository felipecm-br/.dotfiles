#!/usr/bin/env bash
# cockpit-picker-items.sh — emit prioritized agent triage, windows, and fleet overview items
set -uo pipefail

# Helper: read a tmux global option
_tget() { tmux show-option -gqv "$1" 2>/dev/null; }

_set_hex() {
  local h="${2#\#}"
  [[ ! "$h" =~ ^[0-9a-fA-F]{6}$ ]] && h="89b4fa"
  local r=$(( 16#${h:0:2} )) g=$(( 16#${h:2:2} )) b=$(( 16#${h:4:2} ))
  printf -v "$1" '\033[38;2;%d;%d;%dm' "$r" "$g" "$b"
}

R='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

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

_set_hex C_PERM "${_color_orange:-#e09d7f}"
_set_hex C_QUESTION "${_color_magenta:-#d699b6}"
_set_hex C_ERROR "${_color_red:-#e67e80}"
_set_hex C_BUSY "${_color_yellow:-#dbbc7f}"
_set_hex C_IDLE "${_color_cyan:-#83c092}"
_set_hex C_CYAN "${_color_cyan:-#83c092}"
_set_hex C_NORMAL "${_color_muted:-#475258}"
_set_hex C_CUR "${_color_cyan:-#83c092}"
_set_hex C_NAME "${_color_fg:-#d3c6aa}"
_set_hex C_BRANCH "${_color_blue:-#7fbbb3}"
_set_hex C_MUTED "${_color_muted:-#475258}"
_set_hex C_DIFF_INS "${_color_cyan:-#83c092}"
_set_hex C_DIFF_DEL "${_color_red:-#e67e80}"
_set_hex C_DIFF_DIRTY "${_color_yellow:-#dbbc7f}"
_set_hex C_PR "${_color_magenta:-#d699b6}"

filter_agents=0
cur_session="${TMUX_ORIGIN_SESSION:-}"
cur_window="${TMUX_ORIGIN_WINDOW:-}"
if [[ -z "$cur_session" || -z "$cur_window" ]]; then
  read -r _tsess _twin < <(tmux display-message -p '#{session_name} #{window_index}' 2>/dev/null || echo "")
  [[ -z "$cur_session" ]] && cur_session="$_tsess"
  [[ -z "$cur_window" ]] && cur_window="$_twin"
fi

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
  IFS= read -r token < "$token_file" 2>/dev/null || token=""
  if [ -n "$token" ]; then
    acpd_json=$(curl -s -m 0.15 -X POST http://127.0.0.1:4040/rpc \
      -H "Authorization: Bearer $token" \
      -H "Content-Type: application/json" \
      -d '{"jsonrpc":"2.0","method":"agentState/list","id":1}' 2>/dev/null || true)
    if [ -n "$acpd_json" ]; then
      remainder="$acpd_json"
      while [[ "$remainder" =~ \"(%[0-9]+)\":\{([^}]+)\} ]]; do
        apid="${BASH_REMATCH[1]}"
        inner="${BASH_REMATCH[2]}"
        ast=""
        ats=0
        [[ "$inner" =~ \"state\":\"([^\"]+)\" ]] && ast="${BASH_REMATCH[1]}"
        [[ "$inner" =~ \"last_timestamp\":([0-9]+) ]] && ats="${BASH_REMATCH[1]}"
        acpd_st["$apid"]="$ast"
        acpd_ts["$apid"]="$ats"
        remainder="${remainder#*\"$apid\":}"
      done
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
done < <(ps -C agy,agy-bin,antigravity,opencode,claude,codex -o sess=,comm= 2>/dev/null || true)

now_ms="${EPOCHSECONDS}000"

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

tmp_raw=""

while IFS=$'\t' read -r sess idx wname pid pane_os_pid ppath pcmd ptitle raw_state ai_title; do
  case "$sess" in
    _lazygitrs*|_popups*|\.*) continue ;;
  esac

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
      porcelain_b=$(git -C "$ppath" -c submodule.recurse=false --no-optional-locks status --porcelain -b 2>/dev/null || true)
      if [[ -n "$porcelain_b" ]]; then
        git_is_repo["$ppath"]=1
        first_line="${porcelain_b%%$'\n'*}"
        # Parse: ## branch...upstream [ahead N, behind M]
        br_part="${first_line#\#\# }"
        if [[ "$br_part" =~ ^([^.[:space:]]+)\.\.\.([^[:space:]]+)(.*)$ ]]; then
          br="${BASH_REMATCH[1]}"
          rem_info="${BASH_REMATCH[3]}"
          git_has_u["$ppath"]=1
          u_a=0; u_b=0
          [[ "$rem_info" =~ ahead\ ([0-9]+) ]] && u_a="${BASH_REMATCH[1]}"
          [[ "$rem_info" =~ behind\ ([0-9]+) ]] && u_b="${BASH_REMATCH[1]}"
          git_ahead["$ppath"]="$u_a"
          git_behind["$ppath"]="$u_b"
        else
          br="${br_part%% *}"
        fi
        git_branch["$ppath"]="$br"

        dirty_files=0
        while IFS= read -r sline; do
          [[ "$sline" == "## "* || -z "$sline" ]] && continue
          ((dirty_files++))
        done <<< "$porcelain_b"

        ds_str=""
        if (( dirty_files > 0 )); then
          diff_out=$(git -C "$ppath" -c submodule.recurse=false --no-ext-diff --no-optional-locks diff --shortstat HEAD 2>/dev/null || true)
          [[ "$diff_out" =~ ([0-9]+)\ insertion ]] && ds_str="+${BASH_REMATCH[1]}"
          if [[ "$diff_out" =~ ([0-9]+)\ deletion ]]; then
            [[ -n "$ds_str" ]] && ds_str="$ds_str -${BASH_REMATCH[1]}" || ds_str="-${BASH_REMATCH[1]}"
          fi
          [[ -z "$ds_str" ]] && ds_str="*${dirty_files}"
        fi
        git_diffstat["$ppath"]="$ds_str"

        # GitHub PR & CI status cache
        if [ -n "$br" ] && [ "$br" != "main" ] && [ "$br" != "master" ] && [ "$br" != "HEAD" ] && [ "$br" != "detached" ] && command -v gh >/dev/null 2>&1; then
          hash_key="${ppath//\//_}_${br//\//_}"
          cache_file="/tmp/gh-pr-cache-${hash_key}.json"
          now_s="$EPOCHSECONDS"
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

  printf -v row '%d\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%d\t%s\t%d\t%d\t%d\t%d\t%s\t%s\t%s\t%d\n' \
    "$prio" "$ts" "$sess" "$idx" "$wname" "$pid" "$ppath" "$ico" "$short_label" "$age_str" "$branch" "$is_cur" "$st" "$is_agent" "$has_u" "$u_ahead" "$u_behind" "$diffstat_str" "$pr_num" "$pr_ci" "$diff_s"
  tmp_raw+="$row"
done < <(tmux list-panes -a -F $'#{session_name}\t#{window_index}\t#{window_name}\t#{pane_id}\t#{pane_pid}\t#{pane_current_path}\t#{pane_current_command}\t#{pane_title}\t#{?@ai_agent_state_raw,#{@ai_agent_state_raw},#{@w:@ai_agent_state_raw}}\t#{?@ai_agent_title,#{@ai_agent_title},#{@w:@ai_agent_title}}' 2>/dev/null)

# Pass 1: Identify sessions and pre-format items grouped by session
declare -A sess_prio=()
declare -A sess_ts=()
declare -A session_has_agent=()
declare -A session_items=()
declare -A session_agent_items=()
declare -A seen_windows=()
agent_count=0

sorted_raw=$(sort -t$'\t' -k1,1n -k4,4n <<< "$tmp_raw")
while IFS=$'\t' read -r prio ts s idx wname pid ppath ico agent_label age_str branch is_cur st is_agent has_u u_ahead u_behind diffstat_str pr_num pr_ci diff_s; do
  [[ -z "$s" ]] && continue
  if [ "$is_agent" = "1" ]; then
    session_has_agent["$s"]=1
    ((agent_count++))
  fi
  cur_p=${sess_prio["$s"]:-99}
  if (( prio < cur_p )); then
    sess_prio["$s"]=$prio
    sess_ts["$s"]=$ts
  fi

  # Deduplicate multiple panes in the same window (keep highest priority pane)
  win_key="${s}:${idx}"
  if [ -n "${seen_windows["$win_key"]:-}" ]; then
    continue
  fi
  seen_windows["$win_key"]=1

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
  search_title="${s} ${idx} ${wname} ${agent_label} ${branch} ${st} ${age_str} ${sync_search} ${pr_search} ${diffstat_str}"

  printf -v row '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%b\n' \
    "$search_title" "$idx" "$wname" "$s" "$pid" "$ppath" \
    "$st" "${agent_label:--}" "${age_str:--}" "${branch:--}" "${sync_search:--}" \
    "$display_line"

  session_items["$s"]+="$row"
  if [ "$is_agent" = "1" ]; then
    session_agent_items["$s"]+="$row"
  fi
done <<< "$sorted_raw"

# Pass 2: Output sessions ordered by priority with group headers
if [ "$filter_agents" -eq 1 ] && [ "$agent_count" -eq 0 ]; then
  printf "· (no active AI agents)\t0\t-\t%s\t-\t-\t-\t-\t-\t-\t-\t \033[2m(no AI agents running — press a for Fleet view)\033[0m\n" "${cur_session}"
else
  if (( ${#sess_prio[@]} == 1 )); then
    sess="${!sess_prio[*]}"
    if [ "$filter_agents" -eq 1 ]; then
      items="${session_agent_items["$sess"]:-}"
    else
      items="${session_items["$sess"]:-}"
    fi
    if [ -n "$items" ]; then
      printf '#  %s\n' "$sess"
      printf '%s' "$items"
    fi
  else
    sorted_sess_lines=$(for s in "${!sess_prio[@]}"; do printf "%d\t%s\t%s\n" "${sess_prio[$s]}" "${sess_ts[$s]}" "$s"; done | sort -t$'\t' -k1,1n -k2,2n -k3,3)
    while IFS=$'\t' read -r _p _ts sess; do
      [[ -z "$sess" ]] && continue
      if [ "$filter_agents" -eq 1 ]; then
        items="${session_agent_items["$sess"]:-}"
      else
        items="${session_items["$sess"]:-}"
      fi
      [[ -z "$items" ]] && continue
      printf '#  %s\n' "$sess"
      printf '%s' "$items"
    done <<< "$sorted_sess_lines"
  fi
fi
