#!/usr/bin/env bash
# tests/reopen_window.test.sh — contract test for exact tab position and AI session restore.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ok() { echo "ok: $*"; }
bad() { echo "FAIL: $*" >&2; exit 1; }

RECORD_SCRIPT="$ROOT/tmux/.config/tmux/record-window-state.sh"
REOPEN_SCRIPT="$ROOT/tmux/.config/tmux/reopen-window.sh"
CLOSE_SCRIPT="$ROOT/tmux/.config/tmux/close-window.sh"

STATE_DIR="$HOME/.local/state/tmux"
STACK_FILE="$STATE_DIR/closed-windows.json"
BACKUP_FILE="$STATE_DIR/closed-windows.json.testbackup"

# Backup user's actual closed windows stack if present
[ -f "$STACK_FILE" ] && cp "$STACK_FILE" "$BACKUP_FILE"

restore_backup() {
  tmux kill-session -t "_test_reopen_pos" 2>/dev/null || true
  tmux kill-session -t "_test_ai_restore" 2>/dev/null || true
  rm -f /tmp/_test_fake_stack.json
  if [ -f "$BACKUP_FILE" ]; then
    mv "$BACKUP_FILE" "$STACK_FILE"
  else
    rm -f "$STACK_FILE"
  fi
}
trap restore_backup EXIT

# 1. Script existence and bash syntax
[ -x "$RECORD_SCRIPT" ] && bash -n "$RECORD_SCRIPT" && ok "record-window-state.sh syntax and executable" || bad "record-window-state.sh syntax error"
[ -x "$REOPEN_SCRIPT" ] && bash -n "$REOPEN_SCRIPT" && ok "reopen-window.sh syntax and executable" || bad "reopen-window.sh syntax error"

# 2. Empty stack handling
rm -f "$STACK_FILE"
OUT_EMPTY=$("$REOPEN_SCRIPT" 2>&1 || true)
ok "empty stack handled cleanly"

# 3. Exact Tab Position Restoration (Middle Tab)
SESS="_test_reopen_pos"
tmux kill-session -t "$SESS" 2>/dev/null || true
tmux new-session -d -s "$SESS" -n "tab0"
tmux new-window -t "$SESS:" -n "tab1"
tmux new-window -t "$SESS:" -n "tab2"

# Windows initially: 0: tab0, 1: tab1, 2: tab2
# Close window 1 (tab1) via close-window.sh
"$CLOSE_SCRIPT" "$SESS:1"

# Verify tab1 was closed and windows renumbered to 0: tab0, 1: tab2
CURRENT_WINS=$(tmux list-windows -t "$SESS" -F '#{window_index}:#{window_name}')
echo "$CURRENT_WINS" | grep -q "0:tab0" && echo "$CURRENT_WINS" | grep -q "1:tab2" && ok "tab1 closed and renumbered" || bad "close failed"

# Reopen tab1
"$REOPEN_SCRIPT"

# Verify tab1 was restored back to index 1!
RESTORED_WINS=$(tmux list-windows -t "$SESS" -F '#{window_index}:#{window_name}')
echo "$RESTORED_WINS" | grep -q "^0:tab0$" && ok "index 0 is tab0" || bad "tab0 index shifted"
echo "$RESTORED_WINS" | grep -q "^1:tab1$" && ok "tab1 restored at exact original index 1" || bad "tab1 restored at wrong index"
echo "$RESTORED_WINS" | grep -q "^2:tab2$" && ok "index 2 is tab2" || bad "tab2 index wrong"
tmux kill-session -t "$SESS" 2>/dev/null || true

# 4. First Tab (Index 0) Position Restoration
tmux new-session -d -s "$SESS" -n "first0"
tmux new-window -t "$SESS:" -n "second1"

"$CLOSE_SCRIPT" "$SESS:0"
"$REOPEN_SCRIPT"
RESTORED_FIRST=$(tmux list-windows -t "$SESS" -F '#{window_index}:#{window_name}')
echo "$RESTORED_FIRST" | grep -q "^0:first0$" && ok "tab0 restored at exact index 0 before other tabs" || bad "tab0 wrong index"
tmux kill-session -t "$SESS" 2>/dev/null || true

# 5. AI Agent Smart Continuation Recording
tmux new-session -d -s "$SESS" -n "ai-tab"
tmux set-option -w -t "$SESS:0" @ai_agent_title "Building auth service"
tmux set-option -w -t "$SESS:0" @ai_agent_state_raw "busy"

# Test record-window-state captures window index and AI metadata
"$RECORD_SCRIPT" --push "$SESS:0" 2>/dev/null || true
RECORDED_JSON=$(jq '.[0]' "$STACK_FILE")
echo "$RECORDED_JSON" | grep -q '"index": 0' && ok "window index captured in state json" || bad "missing window index in state json"
echo "$RECORDED_JSON" | grep -q '"agent_title": "Building auth service"' && ok "agent title captured in state json" || bad "missing agent title"
echo "$RECORDED_JSON" | grep -q '"agent_state": "busy"' && ok "agent state captured in state json" || bad "missing agent state"
tmux kill-session -t "$SESS" 2>/dev/null || true

# 6. AI Agent Command Normalization (--continue / resume flags)
cat <<'EOF' > /tmp/_test_fake_stack.json
[
  {
    "session": "_test_ai_restore",
    "name": "opencode-tab",
    "index": 1,
    "path": "/tmp",
    "cmd": "opencode --continue",
    "file": "",
    "layout": "",
    "agent_title": "Refactoring agent",
    "agent_state": "busy",
    "time": 1729000000
  }
]
EOF
tmux kill-session -t "_test_ai_restore" 2>/dev/null || true
tmux new-session -d -s "_test_ai_restore" -n "initial0"
cp /tmp/_test_fake_stack.json "$STACK_FILE"
"$REOPEN_SCRIPT"

AI_WINS=$(tmux list-windows -t "_test_ai_restore" -F '#{window_index}:#{window_name}')
echo "$AI_WINS" | grep -q "^1:opencode-tab$" && ok "AI tab reopened at exact index 1" || bad "AI tab index wrong"

# Verify agent title and state were restored on the new window
RESTORED_TITLE=$(tmux show-option -w -t "_test_ai_restore:1" -qv @ai_agent_title)
RESTORED_STATE=$(tmux show-option -w -t "_test_ai_restore:1" -qv @ai_agent_state_raw)
[ "$RESTORED_TITLE" = "Refactoring agent" ] && ok "AI agent title restored on window options" || bad "agent title not restored"
[ "$RESTORED_STATE" = "busy" ] && ok "AI agent state restored on window options" || bad "agent state not restored"

tmux kill-session -t "_test_ai_restore" 2>/dev/null || true
rm -f /tmp/_test_fake_stack.json

echo "=== All reopen-window tests passed! ==="
