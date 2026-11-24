#!/usr/bin/env bash
# tests/ai_launch_exec_jail_git.test.sh — ai-launch-exec pins .git (linked worktrees) and
# git config/hooks read-only inside ai-jail (P1b hardening).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXEC="$ROOT/utils/.local/bin/ai-launch-exec"
ok() { echo "ok: $*"; }
bad() { echo "FAIL: $*" >&2; exit 1; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

BIN="$TMP/bin"
mkdir -p "$BIN"
cat >"$BIN/ai-jail" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@"
EOF
chmod +x "$BIN/ai-jail"

# Use an isolated HOME with no .ai-jail inside the test dir and no waymux daemon noise.
FAKE_HOME="$TMP/home"
mkdir -p "$FAKE_HOME/.claude"

run_in() {
  local dir=$1
  (
    cd "$dir"
    env -u TMUX_PANE -u WAYMUX_HOOK_TOKEN -u AI_LAUNCH_CONTINUE \
      HOME="$FAKE_HOME" PATH="$BIN:/usr/bin:/bin" \
      "$EXEC" jail-claude-ask --model sonnet
  )
}

# 1. Normal repo: maps .git/config and .git/hooks read-only, no --worktree
repo="$TMP/repo"
git init -q "$repo"
git -C "$repo" config user.email "t@t"
git -C "$repo" config user.name "t"
echo hi >"$repo/a.txt"
git -C "$repo" add a.txt && git -C "$repo" commit -q -m init

out=$(run_in "$repo")
grep -qxF -- "$repo/.git/config" <<<"$out" || bad "normal repo missing .git/config map: $out"
grep -qxF -- "$repo/.git/hooks" <<<"$out" || bad "normal repo missing .git/hooks map: $out"
grep -qxF -- "--worktree" <<<"$out" && bad "normal repo should not pass --worktree: $out"
ok "normal repo maps .git/config and .git/hooks read-only"

# 2. Linked worktree (.bare layout like awt): passes --worktree, pins .git file, common config & hooks
bare="$TMP/bareproj/.bare"
wt="$TMP/bareproj/feat"
mkdir -p "$TMP/bareproj"
git init -q --bare "$bare"
echo "gitdir: ./.bare" >"$TMP/bareproj/.git"
git -C "$repo" push -q "$bare" HEAD:refs/heads/main
git --git-dir="$bare" symbolic-ref HEAD refs/heads/main
git --git-dir="$bare" worktree add -q -b feat "$wt" main

out=$(run_in "$wt")
grep -qxF -- "--worktree" <<<"$out" || bad "worktree missing --worktree: $out"
grep -qxF -- "$wt/.git" <<<"$out" || bad "worktree missing .git pin: $out"
grep -qxF -- "$bare/config" <<<"$out" || bad "worktree missing common config map: $out"
grep -qxF -- "$bare/hooks" <<<"$out" || bad "worktree missing common hooks map: $out"
ok "linked worktree passes --worktree and pins .git, common config, and hooks"

# 3. Non-git directory: no git maps added
nongit="$TMP/plain"
mkdir -p "$nongit"
out=$(run_in "$nongit")
grep -qE '(--worktree|/\.git)' <<<"$out" && bad "non-git dir should have no git maps: $out"
ok "non-git dir adds no git maps"
