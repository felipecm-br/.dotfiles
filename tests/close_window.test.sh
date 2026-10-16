#!/usr/bin/env bash
# tests/close_window.test.sh — contract test for guarded window/pane termination.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ok() { echo "ok: $*"; }
bad() { echo "FAIL: $*" >&2; exit 1; }

SCRIPT="$ROOT/tmux/.config/tmux/close-window.sh"
CONF="$ROOT/tmux/.config/tmux/tmux.conf"
KEY_ITEMS="$ROOT/tmux/.config/tmux/keybindings-items.sh"

# 1. Script existence and bash syntax
[ -x "$SCRIPT" ] && bash -n "$SCRIPT" && ok "close-window.sh syntax and executable" || bad "close-window.sh syntax error"

# 2. Check help flag
"$SCRIPT" --help >/dev/null && ok "close-window.sh --help exits cleanly" || bad "close-window.sh --help failed"

# 3. Clean window/pane: must NOT require confirmation
tmux new-session -d -s "_test_win_clean"
OUT_CLEAN=$("$SCRIPT" --check "_test_win_clean:0")
tmux kill-session -t "_test_win_clean" 2>/dev/null || true
echo "$OUT_CLEAN" | grep -q "needs_confirm=0" && ok "clean window bypasses confirmation" || bad "clean window required confirmation"

# 4. Window with active AI agent: MUST require confirmation
tmux new-session -d -s "_test_win_agent"
tmux set-option -w -t "_test_win_agent:0" @ai_agent_state_raw "busy"
tmux set-option -w -t "_test_win_agent:0" @ai_agent_title "Refactoring parser"
OUT_AGENT=$("$SCRIPT" --check "_test_win_agent:0")
tmux kill-session -t "_test_win_agent" 2>/dev/null || true
echo "$OUT_AGENT" | grep -q "needs_confirm=1" && ok "AI agent window triggers confirmation" || bad "AI agent missed confirmation"
echo "$OUT_AGENT" | grep -q "agent_count=1" && ok "AI agent count reported accurately" || bad "incorrect agent count"

# 5. Direct execution closes clean window immediately
tmux new-session -d -s "_test_win_clean_kill"
tmux new-window -t "_test_win_clean_kill"
WIN2_ID=$(tmux list-windows -t "_test_win_clean_kill" -F '#{window_id}' | tail -n1)
"$SCRIPT" "$WIN2_ID"
# Verify window was closed
WIN_COUNT=$(tmux list-windows -t "_test_win_clean_kill" 2>/dev/null | wc -l)
tmux kill-session -t "_test_win_clean_kill" 2>/dev/null || true
[ "$WIN_COUNT" -eq 1 ] && ok "clean window terminated directly without prompt" || bad "clean window not terminated"

# 6. Force flag terminates guarded window immediately
tmux new-session -d -s "_test_win_force"
tmux new-window -t "_test_win_force"
WIN2_AGENT=$(tmux list-windows -t "_test_win_force" -F '#{window_id}' | tail -n1)
tmux set-option -w -t "$WIN2_AGENT" @ai_agent_state_raw "busy"
"$SCRIPT" --force "$WIN2_AGENT"
WIN_COUNT_AFTER=$(tmux list-windows -t "_test_win_force" 2>/dev/null | wc -l)
tmux kill-session -t "_test_win_force" 2>/dev/null || true
[ "$WIN_COUNT_AFTER" -eq 1 ] && ok "force kill terminated guarded window" || bad "force kill failed"

# 7. Check tmux.conf bindings
grep -qE 'bind-key x run-shell ".*close-window\.sh' "$CONF" && ok "tmux.conf binds x to close-window.sh" || bad "tmux.conf missing x bind"
grep -qE 'bind -r w run-shell ".*close-window\.sh' "$CONF" && ok "tmux.conf binds w to close-window.sh" || bad "tmux.conf missing w bind"

# 8. Check keybindings catalog items
grep -qE 'Prefix \+ w / x.*close-window\.sh' "$KEY_ITEMS" && ok "keybindings-items.sh references close-window.sh" || bad "keybindings-items.sh missing close-window.sh"

echo "=== All close-window safeguards tests passed! ==="
