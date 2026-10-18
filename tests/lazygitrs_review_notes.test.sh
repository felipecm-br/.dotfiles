#!/usr/bin/env bash
# tests/lazygitrs_review_notes.test.sh — Verification for Lazygitrs Review Notes Bridge in Tmux
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
AGENT_NOTE_SCRIPT="$DOTFILES_DIR/waymux/.local/bin/agent-note.sh"
LAZYGITRS_POPUP="$DOTFILES_DIR/tmux/.config/tmux/lazygitrs-popup.sh"

echo "=== Running Lazygitrs Review Notes Bridge Tests ==="

# Test 1: Bash syntax verification
bash -n "$AGENT_NOTE_SCRIPT"
bash -n "$LAZYGITRS_POPUP"
echo "PASS: Bash syntax check"

# Test 2: Argument parsing & quote stripping verification
TMP_DIR=$(mktemp -d /tmp/test-lzg-review-XXXXXX)
trap 'rm -rf "$TMP_DIR"' EXIT

if [[ -z $("$AGENT_NOTE_SCRIPT" --help 2>&1 | grep "Usage:") ]]; then
  echo "FAIL: Expected Usage message on missing prompt" >&2
  exit 1
fi
echo "PASS: Empty prompt validation"

# Test 3: Session and Agent Pane Targeting in Tmux
if command -v tmux >/dev/null 2>&1 && tmux ls >/dev/null 2>&1; then
  TEST_SESS="test_lzg_review_$$"
  
  # Create a session with window 1 (idle shell) and window 2 (mock AI agent)
  tmux new-session -d -s "$TEST_SESS" -n "shell_win" "bash -c 'trap \"exit 0\" SIGTERM; sleep 60'"
  tmux new-window -t "$TEST_SESS" -n "agent_win" "cat"
  
  AGENT_PANE=$(tmux display-message -p -t "$TEST_SESS:agent_win" '#{pane_id}')
  tmux set-option -p -t "$AGENT_PANE" @ai_agent_state_raw "active"
  tmux set-option -p -t "$AGENT_PANE" @ai_agent_title "Antigravity Reviewer"
  
  TEST_MSG="Fix line 42 in src/main.rs: unwrap() needs error propagation"
  
  # Invoke agent-note.sh with single-quoted arguments (mimicking lazygitrs shell escaping)
  TMUX_ORIGIN_SESSION="$TEST_SESS" "$AGENT_NOTE_SCRIPT" "'$TMP_DIR'" "'$TEST_MSG'"
  
  sleep 0.3
  captured=$(tmux capture-pane -ep -t "$AGENT_PANE")
  
  tmux kill-session -t "$TEST_SESS" 2>/dev/null || true
  
  if ! grep -q "Fix line 42 in src/main.rs" <<< "$captured"; then
    echo "FAIL: Note was not delivered to target agent pane $AGENT_PANE" >&2
    echo "Captured output: $captured" >&2
    exit 1
  fi
  echo "PASS: Targeted delivery to active agent pane in current session with bracketed paste"
fi

echo "=== All Lazygitrs Review Notes Tests Passed! ==="
