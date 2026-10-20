#!/usr/bin/env bash
# cockpit-picker-diff.sh — live git diff view with syntax highlighting for Cockpit HUD layout 2
set -uo pipefail

if [[ -x "$HOME/.local/bin/waymux" ]]; then
  exec "$HOME/.local/bin/waymux" cockpit-diff "$@"
elif command -v waymux >/dev/null 2>&1; then
  exec waymux cockpit-diff "$@"
fi

session="${1:-}"
idx="${2:-}"
pane_id="${3:-}"
ppath="${4:-}"
ai_raw="${5:-}"
agent_name="${6:-}"
age_str="${7:-}"
branch="${8:-}"
upstream_div="${9:-}"

# Fallback resolution for session header rows or missing fields
if [ -z "$session" ] || [ -z "$idx" ] || [ "$idx" = "-" ]; then
  if [[ "$session" =~ ^#[[:space:]]*(.+) ]]; then
    session="${BASH_REMATCH[1]}"
  fi
fi

if [ -z "$ppath" ] || [ "$ppath" = "-" ]; then
  if [ -n "$session" ] && [ -n "$idx" ] && [ "$idx" != "-" ]; then
    ppath=$(tmux display-message -p -t "${session}:${idx}" '#{pane_current_path}' 2>/dev/null || echo "")
  elif [ -n "$session" ]; then
    ppath=$(tmux display-message -p -t "${session}:" '#{pane_current_path}' 2>/dev/null || echo "")
  fi
fi
[ -z "$ppath" ] && ppath="$PWD"

if [ -z "$pane_id" ] || [ "$pane_id" = "-" ]; then
  if [ -n "$session" ] && [ -n "$idx" ] && [ "$idx" != "-" ]; then
    pane_id=$(tmux display-message -p -t "${session}:${idx}" '#{pane_id}' 2>/dev/null || echo "")
  fi
fi

R='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

# Theme palette colors (resolved via theme-helper.sh — zero subshell/process forks)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$SCRIPT_DIR/theme-helper.sh"

_color_orange=$(get_theme_color orange "#e09d7f")
_color_yellow=$(get_theme_color yellow "#dbbc7f")
_color_red=$(get_theme_color red "#e67e80")
_color_magenta=$(get_theme_color magenta "#d699b6")
_color_cyan=$(get_theme_color cyan "#83c092")
_color_blue=$(get_theme_color blue "#7fbbb3")
_color_fg=$(get_theme_color foreground "#d3c6aa")
_color_muted=$(get_theme_color muted "#475258")

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

# Verify target directory is a git repository
if ! git -C "$ppath" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  card_border="$C_GRAY"
  printf "${card_border}╭%s╮${R}\n" "${DASHES:0:$(( W - 2 ))}"
  _box_line "${BOLD}󰈈 Mode:${R}   ${C_CYAN}${BOLD}󰊢 LIVE GIT DIFF (Side-by-Side)${R} ${DIM}[v toggles preview]${R}"
  _box_line "${BOLD}󰅚 Target:${R} ${C_RED}Not a Git Repository${R}"
  clean_path="$ppath"
  max_p=$(( W - 14 ))
  if (( ${#clean_path} > max_p )); then
    clean_path="${clean_path:0:$(( max_p - 1 ))}…"
  fi
  _box_line "${BOLD}󰉋 Path:${R}   ${C_GRAY}${clean_path}${R}"
  printf "${card_border}╰%s╯${R}\n" "${DASHES:0:$(( W - 2 ))}"
  printf "\n"
  printf "  %b(Press %b?%b for help, %bv%b to return to terminal snapshot)%b\n" "$C_GRAY" "$C_BLUE$BOLD" "$C_GRAY" "$C_CYAN$BOLD" "$C_GRAY" "$R"
  exit 0
fi

# Resolve git branch name
if [ -z "$branch" ] || [ "$branch" = "-" ] || [ "$branch" = "non-git" ]; then
  branch=$(git -C "$ppath" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "detached")
fi

# Check working tree status
porcelain=$(git -C "$ppath" status --porcelain 2>/dev/null || true)
untracked_files=""
untracked_count=0
modified_count=0

if [ -n "$porcelain" ]; then
  untracked_files=$(printf '%s\n' "$porcelain" | grep '^??' | sed -E 's/^\?\?[[:space:]]*//' || true)
  untracked_count=$(printf '%s\n' "$porcelain" | grep -c '^??' || true)
  modified_count=$(printf '%s\n' "$porcelain" | grep -c -v '^??' || true)
fi

diff_type=""
scope_desc=""
stat_summary=""
diff_stat=""
base_commit=""

if [ -n "$porcelain" ]; then
  diff_type="uncommitted"
  scope_desc="Working Tree (Staged & Unstaged)"
  card_border="$C_ORANGE"

  if [ "$modified_count" -gt 0 ]; then
    stat_summary=$(git -C "$ppath" diff HEAD --shortstat 2>/dev/null || git -C "$ppath" diff --shortstat 2>/dev/null || true)
    stat_summary=$(printf '%s' "$stat_summary" | tr -s ' ' | sed 's/^[[:space:]]*//')
    diff_stat=$(git -C "$ppath" diff HEAD --stat --color=always 2>/dev/null || git -C "$ppath" diff --stat --color=always 2>/dev/null || true)
  fi

  if [ "$untracked_count" -gt 0 ]; then
    if [ -n "$stat_summary" ]; then
      stat_summary="${stat_summary}, ${untracked_count} untracked"
    else
      stat_summary="${untracked_count} untracked file(s)"
    fi
  fi
else
  card_border="$C_CYAN"
  def_branch=""
  if git -C "$ppath" rev-parse --verify refs/remotes/origin/HEAD >/dev/null 2>&1; then
    def_branch=$(git -C "$ppath" rev-parse --abbrev-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@' || echo "")
  fi
  [ -z "$def_branch" ] && git -C "$ppath" rev-parse --verify main >/dev/null 2>&1 && def_branch="main"
  [ -z "$def_branch" ] && git -C "$ppath" rev-parse --verify master >/dev/null 2>&1 && def_branch="master"

  if [ -n "$def_branch" ] && [ "$branch" != "$def_branch" ] && [ "$branch" != "detached" ]; then
    base_commit=$(git -C "$ppath" merge-base "$def_branch" HEAD 2>/dev/null || echo "")
  fi
  head_commit=$(git -C "$ppath" rev-parse HEAD 2>/dev/null || echo "")

  if [ -n "$base_commit" ] && [ "$base_commit" != "$head_commit" ]; then
    diff_type="branch_commits"
    commit_count=$(git -C "$ppath" rev-list --count "${base_commit}..HEAD" 2>/dev/null || echo "0")
    scope_desc="Branch Commits (${commit_count} ahead of ${def_branch})"
    stat_summary=$(git -C "$ppath" diff "${base_commit}...HEAD" --shortstat 2>/dev/null || true)
    stat_summary=$(printf '%s' "$stat_summary" | tr -s ' ' | sed 's/^[[:space:]]*//')
    diff_stat=$(git -C "$ppath" diff "${base_commit}...HEAD" --stat --color=always 2>/dev/null || true)
  else
    diff_type="latest_commit"
    commit_log=$(git -C "$ppath" log -1 --format='%h · %s (%cr)' 2>/dev/null || echo "clean")
    scope_desc="Latest Commit (${commit_log})"
    stat_summary=$(git -C "$ppath" show --shortstat --format="" HEAD 2>/dev/null || true)
    stat_summary=$(printf '%s' "$stat_summary" | tr -s ' ' | sed 's/^[[:space:]]*//')
    diff_stat=$(git -C "$ppath" show --stat --color=always --format="" HEAD 2>/dev/null || true)
  fi
fi

# Render Header Context Card
printf "${card_border}╭%s╮${R}\n" "${DASHES:0:$(( W - 2 ))}"
_box_line "${BOLD}󰈈 Mode:${R}   ${C_CYAN}${BOLD}󰊢 LIVE GIT DIFF (Side-by-Side)${R} ${DIM}[v toggles preview]${R}"
if [ -n "$agent_name" ] && [ "$agent_name" != "-" ]; then
  _box_line "${BOLD}󰑮 Agent:${R}  ${C_YELLOW}${agent_name}${R}"
fi

clean_scope="$scope_desc"
max_sc=$(( W - 14 ))
if (( ${#clean_scope} > max_sc )); then
  clean_scope="${clean_scope:0:$(( max_sc - 1 ))}…"
fi
_box_line "${BOLD}󰜘 Scope:${R}  ${C_FG}${clean_scope}${R}"

clean_branch="$branch"
max_br=$(( W - 14 ))
if (( ${#clean_branch} > max_br )); then
  clean_branch="${clean_branch:0:$(( max_br - 1 ))}…"
fi
_box_line "${BOLD}󰊢 Branch:${R} ${C_BLUE}${clean_branch}${R}"

if [ -n "$stat_summary" ]; then
  raw_stat="$stat_summary"
  max_st=$(( W - 14 ))
  if (( ${#raw_stat} > max_st )); then
    raw_stat="${raw_stat:0:$(( max_st - 1 ))}…"
  fi
  colored_stat="$raw_stat"
  if [[ "$colored_stat" =~ ([0-9]+[[:space:]]+insertions?\(\+\)) ]]; then
    colored_stat="${colored_stat//${BASH_REMATCH[1]}/${C_CYAN}${BASH_REMATCH[1]}${R}}"
  fi
  if [[ "$colored_stat" =~ ([0-9]+[[:space:]]+deletions?\(-\)) ]]; then
    colored_stat="${colored_stat//${BASH_REMATCH[1]}/${C_RED}${BASH_REMATCH[1]}${R}}"
  fi
  _box_line "${BOLD}󰄧 Churn:${R}  ${colored_stat}"
else
  _box_line "${BOLD}󰄧 Churn:${R}  ${C_CYAN}Working tree clean${R}"
fi
printf "${card_border}╰%s╯${R}\n" "${DASHES:0:$(( W - 2 ))}"
printf "\n"

# Render Lazygitrs AI Review Notes Section (if any pending)
"$HOME/.config/tmux/cockpit-review-notes.sh" list "$ppath" 2>/dev/null || true

# Render Untracked Files Section
if [ -n "$untracked_files" ]; then
  printf "  %b󰄱 Untracked Files (%d):%b\n" "$C_YELLOW$BOLD" "$untracked_count" "$R"
  printf '%s\n' "$untracked_files" | head -n 6 | while IFS= read -r ufile; do
    [ -z "$ufile" ] && continue
    printf "    %b?%b %b%s%b\n" "$C_GRAY" "$R" "$C_YELLOW" "$ufile" "$R"
  done
  if (( untracked_count > 6 )); then
    printf "    %b... and %d more untracked files%b\n" "$C_GRAY" "$(( untracked_count - 6 ))" "$R"
  fi
  printf "\n"
fi

# Render File Diffstat Summary Section
if [ -n "$diff_stat" ]; then
  printf "  %b󰄧 File Breakdown:%b\n" "$C_BLUE$BOLD" "$R"
  printf '%s\n' "$diff_stat" | head -n 12 | sed 's/^/  /'
  stat_total_lines=$(printf '%s\n' "$diff_stat" | wc -l)
  if (( stat_total_lines > 12 )); then
    printf "    %b... and %d more files in diff%b\n" "$C_GRAY" "$(( stat_total_lines - 12 ))" "$R"
  fi
  printf "\n"
fi

# Render Divider and Side-by-Side Diff
sep_len=$(( preview_w - 20 ))
(( sep_len < 20 )) && sep_len=20
(( sep_len > 80 )) && sep_len=80
printf "%b─── 󰜘 Side-by-Side Diff %s%b\n\n" "$C_GRAY" "${DASHES:0:$(( sep_len - 24 ))}" "$R"

_render_stream() {
  if command -v delta >/dev/null 2>&1; then
    if (( preview_w >= 60 )); then
      delta --side-by-side --line-numbers --paging=never --width="$preview_w" --hunk-header-style omit
    else
      delta --line-numbers --paging=never --width="$preview_w" --hunk-header-style omit
    fi
  elif command -v bat >/dev/null 2>&1; then
    bat --paging=never --color=always --language=diff --style=plain
  else
    cat
  fi
}

has_diff_content=0

case "$diff_type" in
  uncommitted)
    if [ "$modified_count" -gt 0 ]; then
      raw_diff=$(git -C "$ppath" diff HEAD 2>/dev/null || true)
      if [ -n "$raw_diff" ]; then
        has_diff_content=1
        printf '%s\n' "$raw_diff" | _render_stream
      fi
    elif [ "$untracked_count" -gt 0 ]; then
      has_diff_content=1
      printf "  %bAll changes are newly created untracked files (listed above).%b\n" "$C_GRAY" "$R"
      printf "  %bStage files (%bgit add%b) or open Lazygitrs (%bg%b) to inspect contents.%b\n" "$C_GRAY" "$C_FG" "$C_GRAY" "$C_MAGENTA$BOLD" "$R" "$C_GRAY"
    fi
    ;;
  branch_commits)
    raw_diff=$(git -C "$ppath" diff "${base_commit}...HEAD" 2>/dev/null || true)
    if [ -n "$raw_diff" ]; then
      has_diff_content=1
      printf '%s\n' "$raw_diff" | _render_stream
    fi
    ;;
  latest_commit)
    raw_diff=$(git -C "$ppath" show HEAD --format="" 2>/dev/null || true)
    if [ -n "$raw_diff" ]; then
      has_diff_content=1
      printf '%s\n' "$raw_diff" | _render_stream
    fi
    ;;
esac

if [ "$has_diff_content" -eq 0 ]; then
  printf "  %b󰄬 No diff changes to display (working tree clean).%b\n\n" "$C_CYAN" "$R"
  printf "  %b• Press %bg%b%b to launch Lazygitrs (Dual-Diff)%b\n" "$C_GRAY" "$C_MAGENTA$BOLD" "$R" "$C_GRAY" "$R"
  printf "  %b• Press %bv%b%b to toggle back to live terminal snapshot%b\n" "$C_GRAY" "$C_CYAN$BOLD" "$R" "$C_GRAY" "$R"
fi
