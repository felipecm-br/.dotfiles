#!/usr/bin/env bash
# awt_switch_latency.test.sh — switching worktrees must not wait on the network:
#   1. awt-popup.sh fetches in the background instead of pulling before it connects
#   2. awt <existing-branch> returns at once even when origin hangs (was 2 × 3 s pull timeouts)
# Uses a throwaway repo whose origin is a fake SSH remote that hangs; never touches the network.
# Run: bash tests/awt_switch_latency.test.sh (from repository root)

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AWT="$ROOT/awt/.local/bin/awt"
POPUP="$ROOT/awt/.config/tmux/awt-popup.sh"
FAILURES=0

ok() { echo "  ✔ PASS: $1"; }
bad() { echo "  ✖ FAIL: $1"; FAILURES=$((FAILURES + 1)); }

echo "=== Running AWT Switch Latency Test Suite ==="

echo -e "\n[1/2] awt-popup.sh switch path..."
if grep -qE 'git .* pull' "$POPUP"; then
  bad "awt-popup.sh still pulls before switching"
else
  ok "no pull on the switch path"
fi
if grep -qE 'setsid -f .*git .* fetch' "$POPUP"; then
  ok "fetches in the background"
else
  bad "awt-popup.sh does not fetch in the background"
fi

echo -e "\n[2/2] awt <existing-branch> with a hanging origin..."
REPO="$(mktemp -d)"
MARKER="slow-ssh-$$"
cleanup() {
  pkill -f -- "$MARKER" 2>/dev/null || true
  pkill -f -- "$REPO/feat-x" 2>/dev/null || true
  rm -rf "$REPO"
}
trap cleanup EXIT

git init -q -b main "$REPO/main"
git -C "$REPO/main" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
git -C "$REPO/main" worktree add -q "$REPO/feat-x" -b feat/x
git -C "$REPO/main" remote add origin "ssh://git@slow.invalid/repo.git"

start=$EPOCHREALTIME
(cd "$REPO/main" && env -u TMUX -u TMUX_PANE GIT_SSH_COMMAND="sh -c 'sleep 5' $MARKER" HOME="$REPO" \
  bash "$AWT" feat/x --no-tmux >/dev/null 2>&1)
elapsed=$(awk -v s="$start" -v e="$EPOCHREALTIME" 'BEGIN{printf "%.2f", e - s}')
if awk -v t="$elapsed" 'BEGIN{exit !(t < 1.0)}'; then
  ok "connect returned in ${elapsed}s"
else
  bad "connect waited ${elapsed}s on the network"
fi

echo
if [ "$FAILURES" -eq 0 ]; then
  echo "All switch latency tests passed."
else
  echo "$FAILURES test(s) failed."
  exit 1
fi
