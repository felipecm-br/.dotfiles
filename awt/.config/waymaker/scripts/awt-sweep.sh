#!/usr/bin/env bash
# awt-sweep.sh — Prune merged Git worktrees, clean branches, and terminate associated Tmux sessions
# Usage: awt sweep [-y|--yes] [-n|--dry-run] [--fetch] [base_branch]
set -euo pipefail

R='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'
C_CYAN='\033[38;2;131;192;146m'
C_YELLOW='\033[38;2;219;188;127m'
C_RED='\033[38;2;230;126;128m'
C_BLUE='\033[38;2;127;187;179m'
C_GRAY='\033[38;2;114;135;152m'

auto_yes=0
dry_run=0
do_fetch=0
base_branch_arg=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -y|--yes) auto_yes=1 ;;
    -n|--dry-run) dry_run=1 ;;
    --fetch) do_fetch=1 ;;
    -h|--help)
      cat << 'HELP'
awt sweep — Clean up merged worktrees in the current Git repository

USAGE:
    awt sweep [flags] [base_branch]

FLAGS:
    -y, --yes       Confirm and remove all merged worktrees without interactive prompt
    -n, --dry-run   List worktrees that would be swept without deleting anything
    --fetch         Fetch origin before checking branch merge status
    -h, --help      Show this help message
HELP
      exit 0
      ;;
    *)
      if [[ -z "$base_branch_arg" ]]; then
        base_branch_arg="$1"
      fi
      ;;
  esac
  shift
done

# Verify Git repository context
repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
if ! git -C "$repo_root" rev-parse --is-inside-work-tree >/dev/null 2>&1 && ! git -C "$repo_root" rev-parse --is-bare-repository >/dev/null 2>&1; then
  printf "${C_RED}󰅖 awt sweep: Not inside a Git repository.${R}\n"
  exit 1
fi

common_git_dir=$(git -C "$repo_root" rev-parse --git-common-dir 2>/dev/null || git -C "$repo_root" rev-parse --git-dir 2>/dev/null)
if [[ -n "$common_git_dir" && "$common_git_dir" != /* ]]; then
  common_git_dir="$(cd "$repo_root/$common_git_dir" 2>/dev/null && pwd)"
fi

# Determine base branch
if [[ -n "$base_branch_arg" ]]; then
  base_branch="$base_branch_arg"
else
  # Try remote HEAD first
  base_branch=$(git -C "$repo_root" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "")
  if [[ -z "$base_branch" ]]; then
    # Fallback to local main or master
    if git -C "$repo_root" show-ref --verify --quiet refs/heads/main; then
      base_branch="main"
    elif git -C "$repo_root" show-ref --verify --quiet refs/heads/master; then
      base_branch="master"
    else
      base_branch="main"
    fi
  fi
fi

if [[ $do_fetch -eq 1 ]]; then
  printf "${DIM}Fetching origin references...${R}\n"
  git -C "$repo_root" fetch --prune origin 2>/dev/null || true
fi

printf "${BOLD}󰈈 Scanning worktrees in %s (base: %s)...${R}\n\n" "$(basename "$(dirname "$repo_root")")/$(basename "$repo_root")" "$base_branch"

# Parse worktree list
declare -a candidate_paths=()
declare -a candidate_branches=()
declare -a candidate_reasons=()

cur_path=""
cur_head=""
cur_branch=""
is_bare=0

while IFS= read -r line; do
  if [[ "$line" =~ ^worktree[[:space:]]+(.*) ]]; then
    cur_path="${BASH_REMATCH[1]}"
    cur_head=""
    cur_branch=""
    is_bare=0
  elif [[ "$line" == "bare" ]]; then
    is_bare=1
  elif [[ "$line" =~ ^HEAD[[:space:]]+([0-9a-f]+) ]]; then
    cur_head="${BASH_REMATCH[1]}"
  elif [[ "$line" =~ ^branch[[:space:]]+refs/heads/(.*) ]]; then
    cur_branch="${BASH_REMATCH[1]}"
  elif [[ -z "$line" && -n "$cur_path" ]]; then
    # Process previous worktree record
    if [[ $is_bare -eq 0 && -n "$cur_branch" && "$cur_branch" != "$base_branch" && "$cur_branch" != "master" && "$cur_branch" != "main" ]]; then
      merged=0
      reason=""

      # 1. Check local ancestor
      if git -C "$repo_root" show-ref --verify --quiet "refs/heads/$base_branch" && \
         git -C "$repo_root" merge-base --is-ancestor "refs/heads/$cur_branch" "refs/heads/$base_branch" 2>/dev/null; then
        merged=1
        reason="Merged locally into ${base_branch}"
      # 2. Check remote tracking ancestor
      elif git -C "$repo_root" show-ref --verify --quiet "refs/remotes/origin/$base_branch" && \
           git -C "$repo_root" merge-base --is-ancestor "refs/heads/$cur_branch" "refs/remotes/origin/$base_branch" 2>/dev/null; then
        merged=1
        reason="Merged upstream into origin/${base_branch}"
      # 3. Check GitHub PR state if gh CLI is available (catches squash/rebase merges)
      elif command -v gh >/dev/null 2>&1; then
        pr_state=$(cd "$cur_path" 2>/dev/null && gh pr view "$cur_branch" --json state -q .state 2>/dev/null || echo "")
        if [[ "$pr_state" == "MERGED" ]]; then
          merged=1
          pr_num=$(cd "$cur_path" 2>/dev/null && gh pr view "$cur_branch" --json number -q .number 2>/dev/null || echo "")
          reason="PR #${pr_num} Merged on GitHub"
        fi
      fi

      if [[ $merged -eq 1 ]]; then
        candidate_paths+=("$cur_path")
        candidate_branches+=("$cur_branch")
        candidate_reasons+=("$reason")
      fi
    fi
    cur_path=""
    cur_head=""
    cur_branch=""
    is_bare=0
  fi
done < <(git -C "$repo_root" worktree list --porcelain; printf '\n')

total_candidates=${#candidate_paths[@]}

if [[ $total_candidates -eq 0 ]]; then
  printf "${C_CYAN}✔ No merged worktrees found.${R} Everything is clean and synchronized.\n"
  exit 0
fi

# Print table of candidates
printf "${C_YELLOW}${BOLD}Found %d merged worktree(s) eligible for sweep:${R}\n\n" "$total_candidates"
for i in "${!candidate_paths[@]}"; do
  c_br="${candidate_branches[$i]}"
  c_pt="${candidate_paths[$i]}"
  c_rs="${candidate_reasons[$i]}"
  printf "  ${C_RED}󰆴 %-28s${R} ${C_GRAY}%s${R}  ${C_CYAN}(%s)${R}\n" "$c_br" "$c_pt" "$c_rs"
done
printf "\n"

if [[ $dry_run -eq 1 ]]; then
  printf "${DIM}[Dry run mode: no worktrees or sessions were removed]${R}\n"
  exit 0
fi

# Confirmation prompt
if [[ $auto_yes -eq 0 ]]; then
  if command -v gum >/dev/null 2>&1; then
    if ! gum confirm --prompt.foreground="214" "Delete these $total_candidates merged worktree(s) and their Tmux sessions?"; then
      printf "${DIM}Sweep aborted.${R}\n"
      exit 0
    fi
  else
    read -r -p "Delete these $total_candidates merged worktree(s) and their Tmux sessions? [y/N] " confirm </dev/tty
    if [[ "$confirm" != [yY]* ]]; then
      printf "${DIM}Sweep aborted.${R}\n"
      exit 0
    fi
  fi
fi

# Execute cleanup
swept_count=0
for i in "${!candidate_paths[@]}"; do
  c_br="${candidate_branches[$i]}"
  c_pt="${candidate_paths[$i]}"
  printf "${DIM}Sweeping %s...${R} " "$c_br"

  # Invoke awt rm directly
  if awt rm "$c_br" -f >/dev/null 2>&1; then
    printf "${C_CYAN}✔ removed${R}\n"
    ((swept_count++))
  else
    # Fallback to direct worktree remove if awt rm fails
    git -C "$repo_root" worktree remove --force "$c_pt" >/dev/null 2>&1 || rm -rf "$c_pt" 2>/dev/null || true
    git -C "$repo_root" branch -D "$c_br" >/dev/null 2>&1 || true
    printf "${C_YELLOW}⚠ purged fallback${R}\n"
    ((swept_count++))
  fi
done

git -C "$repo_root" worktree prune 2>/dev/null || true

printf "\n${C_CYAN}${BOLD}✔ Successfully swept %d worktree(s).${R}\n" "$swept_count"
exit 0
