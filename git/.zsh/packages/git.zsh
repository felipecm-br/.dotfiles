# ─────────────────────────────────────────────────────────────────────────────
# Git Aliases and Functions
# ─────────────────────────────────────────────────────────────────────────────

# ─────────────────────────────────────────────────────────────────────────────
# Status & Info
# ─────────────────────────────────────────────────────────────────────────────

alias gs='git status --short --branch'
alias gst='git status'
alias gl='git log --oneline --graph --decorate'
alias glp='git log --oneline --graph --decorate --patch'
alias gll='git log --oneline --graph --decorate --all'
alias gld='git log --oneline --graph --decorate --date=short --pretty=format:"%C(auto)%h %C(green)%ad %C(auto)%s %C(cyan)%d"'
alias gshow='git show --stat --pretty=format:"%C(auto)%H%n%C(green)Author: %an <%ae>%n%C(green)Date:   %ad%n%C(auto)%n%s%n%n%b"'

# ─────────────────────────────────────────────────────────────────────────────
# Branch Management
# ─────────────────────────────────────────────────────────────────────────────

alias gb='git branch --verbose'
alias gba='git branch --all --verbose'
alias gbd='git branch --delete'
alias gbD='git branch --delete --force'
alias gbm='git branch --move'
alias gbr='git branch --remotes'

# Checkout
alias gco='git checkout'
alias gcb='git checkout -b'
alias gcd='git checkout develop'

# ─────────────────────────────────────────────────────────────────────────────
# Staging & Committing
# ─────────────────────────────────────────────────────────────────────────────

alias gadd='git add'
alias gaa='git add --all'
alias gap='git add --patch'
alias gai='git add --interactive'

alias gca='git commit --amend'
alias gcan='git commit --amend --no-edit'
alias gcf='git commit --fixup'

# ─────────────────────────────────────────────────────────────────────────────
# Remote Operations
# ─────────────────────────────────────────────────────────────────────────────

alias gf='git fetch'
alias gfa='git fetch --all'
alias gfp='git fetch --prune'

alias gp='git push'
alias gpf='git push --force-with-lease'
alias gpo='git push origin'
alias gpot='git push origin --tags'
alias gpu='git push upstream'

alias gl='git pull'
alias glr='git pull --rebase'
alias glra='git pull --rebase --autostash'

# ─────────────────────────────────────────────────────────────────────────────
# Diff & Comparison
# ─────────────────────────────────────────────────────────────────────────────

alias gdiff='git diff'
alias gds='git diff --staged'
alias gdw='git diff --word-diff'
alias gdc='git diff --cached'

alias gdt='git difftool'
alias gmt='git mergetool'

# ─────────────────────────────────────────────────────────────────────────────
# Stashing
# ─────────────────────────────────────────────────────────────────────────────

alias gsta='git stash push'
alias gstp='git stash pop'
alias gstl='git stash list'
alias gsts='git stash show --patch'
alias gstd='git stash drop'
alias gstc='git stash clear'

# ─────────────────────────────────────────────────────────────────────────────
# Rebasing & Merging
# ─────────────────────────────────────────────────────────────────────────────

alias grb='git rebase'
alias grbi='git rebase --interactive'
alias grbc='git rebase --continue'
alias grba='git rebase --abort'
alias grbs='git rebase --skip'

alias gm='git merge'
alias gma='git merge --abort'
alias gmc='git merge --continue'

# ─────────────────────────────────────────────────────────────────────────────
# Working Directory
# ─────────────────────────────────────────────────────────────────────────────

alias gcl='git clean'
alias gclf='git clean --force'
alias gcli='git clean --interactive'

alias grs='git reset'
alias grsh='git reset --hard'
alias grss='git reset --soft'
alias grsm='git reset --mixed'

alias grm='git rm'
alias grmc='git rm --cached'

# ─────────────────────────────────────────────────────────────────────────────
# Advanced Operations
# ─────────────────────────────────────────────────────────────────────────────

alias gcp='git cherry-pick'
alias gcpc='git cherry-pick --continue'
alias gcpa='git cherry-pick --abort'

alias grv='git revert'
alias grvc='git revert --continue'
alias grva='git revert --abort'

alias gbl='git blame'
alias gbs='git bisect'
alias gbsg='git bisect good'
alias gbsb='git bisect bad'
alias gbsr='git bisect reset'

# ─────────────────────────────────────────────────────────────────────────────
# Git Flow / Workflow
# ─────────────────────────────────────────────────────────────────────────────

# Quick commit with message
gcq() {
    git add --all && git commit --message "$*"
}

# Amend last commit with current changes
gcaa() {
    git add --all && git commit --amend --no-edit
}

# Push current branch
gpp() {
    git push origin "$(git branch --show-current)"
}

# Force push current branch (with lease)
gppf() {
    git push --force-with-lease origin "$(git branch --show-current)"
}

# Create and switch to new branch
gnb() {
    if [[ -z "$1" ]]; then
        echo "Usage: gnb <branch-name>"
        return 1
    fi
    git checkout -b "$1"
}

# Delete merged branches
gbdm() {
    git branch --merged | grep -vE "(^\*|master|main|develop)" | xargs -r git branch --delete
}

# Show git stats
gstats() {
    echo "=== Git Statistics ==="
    echo "Commits: $(git rev-list --count HEAD)"
    echo "Contributors: $(git shortlog -sn --no-merges | wc -l)"
    echo "Files: $(git ls-files | wc -l)"
    echo "Size: $(git ls-files | xargs du -ch | tail -1 | cut -f1)"
}


# ─────────────────────────────────────────────────────────────────────────────
# Utility Functions
# ─────────────────────────────────────────────────────────────────────────────

# Get current branch name
gcbn() {
    git branch --show-current 2>/dev/null || git rev-parse --abbrev-ref HEAD
}

# Check if working directory is clean
gis_clean() {
    [[ -z "$(git status --porcelain)" ]]
}

# Get repository root
groot() {
    git rev-parse --show-toplevel 2>/dev/null
}

# Open repository in default editor
gedit() {
    local root
    root=$(groot)
    if [[ -n "$root" ]]; then
        ${EDITOR:-vim} "$root"
    else
        echo "Not in a git repository"
        return 1
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Configuration Helpers
# ─────────────────────────────────────────────────────────────────────────────

# Set git user name and email
guser() {
    if [[ $# -ne 2 ]]; then
        echo "Usage: guser 'Your Name' 'your.email@example.com'"
        return 1
    fi
    git config user.name "$1"
    git config user.email "$2"
    echo "Git user set to: $1 <$2>"
}

# Show current git configuration
gconfig() {
    echo "=== Git Configuration ==="
    echo "User: $(git config user.name) <$(git config user.email)>"
    echo "Editor: $(git config core.editor)"
    echo "Default branch: $(git config init.defaultBranch)"
    echo "Auto-correction: $(git config help.autocorrect)"
    echo "Push default: $(git config push.default)"
    echo "Pull rebase: $(git config pull.rebase)"
}

# Initialize a new git repository with sensible defaults
ginit() {
    git init
    git config init.defaultBranch main
    git config core.editor "${EDITOR:-vim}"
    git config help.autocorrect 1
    git config push.default simple
    git config pull.rebase false
    echo "Git repository initialized with sensible defaults"
}

# ─────────────────────────────────────────────────────────────────────────────
# AI commits: gc / sgc (implemented natively in lazygitrs)
# ─────────────────────────────────────────────────────────────────────────────
# Both share lazygitrs' AI command (git.commit.smartCommitCommand, falling back
# to generateCommand → ai-commit-msg), .sgcignore, diff compression, commitlint
# rules and the content-hash plan cache. Docs: git/GC_SGC.md, `lazygitrs gc -h`.
#
#   gc            stage all, generate, pre-fill `git commit -m …` for review
#   gc -s         only the already-staged changes
#   gc -o         print the message instead of pre-filling the prompt
#   gc -g 3 -e    pick one of 3 candidates, with a gitmoji
#   gc hook install|uninstall|status   prepare-commit-msg hook
#   sgc           review an AI split of every change into atomic commits
#   sgc -y        commit the whole plan without review

# sgc — smart multi-commit (flags: lazygitrs sgc -h)
sgc() { command lazygitrs sgc "$@"; }

# gc — one AI commit message; extra flags pass through to `lazygitrs gc`
gc() {
  if [[ "$1" == hook ]]; then
    command lazygitrs gc "$@"
    return
  fi
  local stage=1 print_only=0 arg
  local -a args
  for arg in "$@"; do
    case "$arg" in
      -s|--staged-only)  stage=0 ;;
      -o|--message-only) print_only=1 ;;
      -q|--no-loading)   ;;  # lazygitrs only reports progress on a terminal
      -p|--provider)     args+=(-P) ;;  # old zsh flag; value follows as-is
      *)                 args+=("$arg") ;;
    esac
  done
  (( stage )) && args=(-a "${args[@]}")
  [[ "${GC_EMOJI:-0}" == 1 ]] && args+=(-e)

  local msg
  msg=$(command lazygitrs gc "${args[@]}") || return
  [[ -z "$msg" ]] && return 0  # -n with nothing to commit
  if (( print_only )) || [[ ! -o interactive ]]; then
    print -r -- "$msg"
  else
    print -z -- "git commit -m ${(qq)msg}"
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Test Badge & Quality Gate Helper: gtest
# ─────────────────────────────────────────────────────────────────────────────
# Runs tests and, if passing, amends HEAD with 'Test-Status: pass (<summary>)'
# so that TUIs (lazygitrs, git log) render green pass badges on the commit.
gtest() {
  local root
  root=$(git rev-parse --show-toplevel 2>/dev/null)
  if [[ -z "$root" ]]; then
    echo "gtest: not in a git repository" >&2
    return 1
  fi

  local test_cmd="$*"
  local summary=""
  local output=""
  local exit_code=0

  if [[ -n "$test_cmd" ]]; then
    echo "Running custom test command: $test_cmd..."
    output=$(eval "$test_cmd" 2>&1)
    exit_code=$?
    summary="pass ($test_cmd)"
  elif [[ -f "$root/Justfile" || -f "$root/justfile" ]] && command -v just >/dev/null 2>&1 && (cd "$root" && just --summary 2>/dev/null | grep -qw "check"); then
    echo "Running 'just check' in $(basename "$root")..."
    output=$(cd "$root" && just check 2>&1)
    exit_code=$?
    summary="pass (just check)"
  elif [[ -f "$root/Cargo.toml" ]] && command -v cargo >/dev/null 2>&1; then
    echo "Running 'cargo test' in $(basename "$root")..."
    output=$(cd "$root" && cargo test 2>&1)
    exit_code=$?
    local count
    count=$(echo "$output" | grep -E "test result: ok\." | sed -E 's/.*ok\.[[:space:]]*([0-9]+)[[:space:]]*passed.*/\1/' | head -n1)
    if [[ -n "$count" && "$count" =~ ^[0-9]+$ ]]; then
      summary="pass ($count/$count)"
    else
      summary="pass (cargo test)"
    fi
  elif [[ -f "$root/package.json" ]] && command -v npm >/dev/null 2>&1 && grep -q '"test"' "$root/package.json"; then
    echo "Running 'npm test' in $(basename "$root")..."
    output=$(cd "$root" && npm test 2>&1)
    exit_code=$?
    summary="pass (npm test)"
  else
    echo "gtest: no recognized test runner found (Justfile check, Cargo.toml, or package.json)" >&2
    echo "Usage: gtest [custom-test-command...]" >&2
    return 1
  fi

  if [[ $exit_code -ne 0 ]]; then
    echo -e "\033[1;31m✘ Tests failed (exit code $exit_code):\033[0m" >&2
    echo "$output" | tail -n 25 >&2
    return $exit_code
  fi

  echo "$output" | tail -n 10
  echo -e "\033[1;32m✔ Tests passed!\033[0m"

  # Check if HEAD exists and working copy is clean before amending
  if ! git -C "$root" rev-parse HEAD >/dev/null 2>&1; then
    return 0
  fi

  if ! git -C "$root" diff --quiet 2>/dev/null || ! git -C "$root" diff --cached --quiet 2>/dev/null; then
    echo "Note: working directory has uncommitted changes; skipping commit amend."
    return 0
  fi

  git -C "$root" commit --amend --no-edit --trailer "Test-Status: $summary" >/dev/null 2>&1 || true
  local short_sha
  short_sha=$(git -C "$root" rev-parse --short HEAD 2>/dev/null)
  echo -e "\033[1;32m✔ Stamped 'Test-Status: $summary' on commit $short_sha.\033[0m"
}

