#!/usr/bin/env bash
# focus_hook_async.test.sh — verification suite for the pane-focus-in hook:
#   1. tmux.conf backgrounds every run-shell in the hook (no ~190 ms block per focus change)
#   2. record-window-state.sh --track <pane> records the focused pane
#   3. a background --track run for a pane that already lost focus writes nothing
# Uses a private tmux server (-L) and a sandboxed HOME; never touches the live session.
# Run: bash tests/focus_hook_async.test.sh (from repository root)

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONF="$ROOT/tmux/.config/tmux/tmux.conf"
SCRIPT="$ROOT/tmux/.config/tmux/record-window-state.sh"
FAILURES=0

ok() { echo "  ✔ PASS: $1"; }
bad() { echo "  ✖ FAIL: $1"; FAILURES=$((FAILURES + 1)); }

echo "=== Running Focus Hook Async Test Suite ==="

echo -e "\n[1/3] Validating pane-focus-in hook in tmux.conf..."
hook=$(grep -E '^set-hook -g pane-focus-in' "$CONF")
total=$(grep -o 'run-shell' <<<"$hook" | wc -l)
background=$(grep -o 'run-shell -b' <<<"$hook" | wc -l)
if [ "$total" -gt 0 ] && [ "$total" -eq "$background" ]; then
  ok "all $total run-shell commands use -b"
else
  bad "pane-focus-in has $((total - background)) blocking run-shell command(s)"
fi
if grep -qF -- '--track #{pane_id}' <<<"$hook"; then
  ok "--track receives the focused pane id"
else
  bad "--track does not receive #{pane_id}"
fi

SOCK="focus-hook-test-$$"
SANDBOX="$(mktemp -d)"
cleanup() {
  tmux -L "$SOCK" kill-server 2>/dev/null || true
  # kill-server leaves the socket file behind in /tmp/tmux-$UID
  rm -f "${SOCKET_PATH:-}"
  rm -rf "$SANDBOX"
}
trap cleanup EXIT

tmux -L "$SOCK" -f /dev/null new-session -d -s focus_test -n first
tmux -L "$SOCK" new-window -t focus_test:1 -n second
SOCKET_PATH=$(tmux -L "$SOCK" display-message -p '#{socket_path}')
SECOND_PANE=$(tmux -L "$SOCK" display-message -p -t focus_test:1 '#{pane_id}')
ACTIVE_FILE="$SANDBOX/.local/state/tmux/last-active-window.json"

track() {
  env -u TMUX_PANE TMUX="$SOCKET_PATH,0,0" HOME="$SANDBOX" bash "$SCRIPT" --track "$1"
}

echo -e "\n[2/3] Recording the focused pane..."
track "$SECOND_PANE"
if [ -s "$ACTIVE_FILE" ] && jq -e '.name == "second"' "$ACTIVE_FILE" >/dev/null; then
  ok "--track recorded window 'second'"
else
  bad "focused pane was not recorded: $(cat "$ACTIVE_FILE" 2>/dev/null)"
fi

echo -e "\n[3/3] Dropping a late run for a pane that lost focus..."
# Focus moves to 'first' while a background run for 'second' is still in flight.
tmux -L "$SOCK" select-window -t focus_test:0
track "$SECOND_PANE"
if jq -e '.name == "second"' "$ACTIVE_FILE" >/dev/null 2>&1; then
  ok "late run left the record untouched"
else
  bad "late run rewrote the record: $(cat "$ACTIVE_FILE" 2>/dev/null)"
fi

echo
if [ "$FAILURES" -eq 0 ]; then
  echo "All focus hook tests passed."
else
  echo "$FAILURES test(s) failed."
  exit 1
fi
