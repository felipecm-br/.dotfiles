#!/usr/bin/env bash
# tests/close_session.test.sh — contract test for smart guarded session termination.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ok() { echo "ok: $*"; }
bad() { echo "FAIL: $*" >&2; exit 1; }

SCRIPT="$ROOT/tmux/.config/tmux/close-session.sh"
CONF="$ROOT/tmux/.config/tmux/tmux.conf"
KEY_ITEMS="$ROOT/tmux/.config/tmux/keybindings-items.sh"
KEY_PREV="$ROOT/tmux/.config/tmux/keybindings-preview.sh"

# 1. Script existence and bash syntax
[ -x "$SCRIPT" ] && bash -n "$SCRIPT" && ok "close-session.sh syntax and executable" || bad "close-session.sh syntax error"

# 2. Check help flag
"$SCRIPT" --help >/dev/null && ok "close-session.sh --help exits cleanly" || bad "close-session.sh --help failed"

# 3. Clean session with <= 3 windows: must NOT require confirmation
tmux new-session -d -s "_test_sess_1w"
OUT_1W=$("$SCRIPT" --check "_test_sess_1w")
tmux kill-session -t "_test_sess_1w" 2>/dev/null || true
echo "$OUT_1W" | grep -q "needs_confirm=0" && ok "1 clean window bypasses confirmation" || bad "1 clean window required confirmation"

tmux new-session -d -s "_test_sess_3w"
tmux new-window -t "_test_sess_3w"
tmux new-window -t "_test_sess_3w"
OUT_3W=$("$SCRIPT" --check "_test_sess_3w")
tmux kill-session -t "_test_sess_3w" 2>/dev/null || true
echo "$OUT_3W" | grep -q "needs_confirm=0" && ok "3 clean windows bypass confirmation" || bad "3 clean windows required confirmation"

# 4. Clean session with > 3 windows: MUST require confirmation
tmux new-session -d -s "_test_sess_4w"
tmux new-window -t "_test_sess_4w"
tmux new-window -t "_test_sess_4w"
tmux new-window -t "_test_sess_4w"
OUT_4W=$("$SCRIPT" --check "_test_sess_4w")
tmux kill-session -t "_test_sess_4w" 2>/dev/null || true
echo "$OUT_4W" | grep -q "needs_confirm=1" && ok "4 clean windows triggers confirmation" || bad "4 clean windows missed confirmation"
echo "$OUT_4W" | grep -q "windows open (>3 threshold)" && ok "4 windows reports >3 threshold reason" || bad "missing >3 threshold reason"

# 5. Session with active AI agent: MUST require confirmation even with 1 window
tmux new-session -d -s "_test_sess_agent"
tmux set-option -w -t "_test_sess_agent:0" @ai_agent_state_raw "busy"
tmux set-option -w -t "_test_sess_agent:0" @ai_agent_title "Refactoring parser"
OUT_AGENT=$("$SCRIPT" --check "_test_sess_agent")
tmux kill-session -t "_test_sess_agent" 2>/dev/null || true
echo "$OUT_AGENT" | grep -q "needs_confirm=1" && ok "AI agent window triggers confirmation" || bad "AI agent missed confirmation"
echo "$OUT_AGENT" | grep -q "window(s) with active AI agents" && ok "AI agent reports active agent reason" || bad "missing AI agent reason"

# 6. Session with IDLE AI agent (<= 3 windows): must NOT require confirmation
tmux new-session -d -s "_test_sess_idle"
tmux set-option -w -t "_test_sess_idle:0" @ai_agent_state_raw "idle"
tmux set-option -w -t "_test_sess_idle:0" @ai_agent_title "Completed parser"
OUT_IDLE=$("$SCRIPT" --check "_test_sess_idle")
tmux kill-session -t "_test_sess_idle" 2>/dev/null || true
echo "$OUT_IDLE" | grep -q "needs_confirm=0" && ok "idle AI agent session bypasses confirmation" || bad "idle AI agent session required confirmation"

# 7. Direct execution closes clean session immediately
tmux new-session -d -s "_test_sess_clean_kill"
"$SCRIPT" "_test_sess_clean_kill"
! tmux has-session -t "_test_sess_clean_kill" 2>/dev/null && ok "clean session terminated directly without prompt" || bad "clean session not terminated"

# 8. Force flag terminates guarded session immediately
tmux new-session -d -s "_test_sess_force_kill"
tmux set-option -w -t "_test_sess_force_kill:0" @ai_agent_state_raw "busy"
"$SCRIPT" --force "_test_sess_force_kill"
! tmux has-session -t "_test_sess_force_kill" 2>/dev/null && ok "force kill terminated guarded session" || bad "force kill failed"

# 9. Check tmux.conf binding
grep -qE 'bind W run-shell ".*close-session\.sh' "$CONF" && ok "tmux.conf binds Prefix + W to close-session.sh" || bad "tmux.conf missing close-session.sh bind"

# 10. Check keybindings catalog items & preview
grep -qE 'Prefix \+ W.*close-session\.sh' "$KEY_ITEMS" && ok "keybindings-items.sh references close-session.sh" || bad "keybindings-items.sh missing close-session.sh"
grep -qE 'Smart Kill Session' "$KEY_PREV" && ok "keybindings-preview.sh documents Smart Kill Session" || bad "keybindings-preview.sh missing Smart Kill Session"

echo "=== All close-session safeguards tests passed! ==="
