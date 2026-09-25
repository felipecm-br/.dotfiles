#!/usr/bin/env bash
# tests/keybindings_picker.test.sh — contract test for Keybindings & Navigation HUD.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ok() { echo "ok: $*"; }
bad() { echo "FAIL: $*" >&2; exit 1; }

SCRIPT="$ROOT/tmux/.config/tmux/keybindings-picker.sh"
ITEMS="$ROOT/tmux/.config/tmux/keybindings-items.sh"
PREVIEW="$ROOT/tmux/.config/tmux/keybindings-preview.sh"
RUNNER="$ROOT/tmux/.config/tmux/keybindings-run.sh"
PRESET="$ROOT/waymaker/.config/waymaker/presets/keybindings.toml"
CONF="$ROOT/tmux/.config/tmux/tmux.conf"

# 1. Check file existence and executability
[ -x "$SCRIPT" ] && sh -n "$SCRIPT" && ok "keybindings-picker.sh syntax" || bad "keybindings-picker.sh syntax"
[ -x "$ITEMS" ] && sh -n "$ITEMS" && ok "keybindings-items.sh syntax" || bad "keybindings-items.sh syntax"
[ -x "$PREVIEW" ] && sh -n "$PREVIEW" && ok "keybindings-preview.sh syntax" || bad "keybindings-preview.sh syntax"
[ -x "$RUNNER" ] && sh -n "$RUNNER" && ok "keybindings-run.sh syntax" || bad "keybindings-run.sh syntax"

# 2. Check items generation across modes
ALL_COUNT="$("$ITEMS" all | wc -l)"
TMUX_COUNT="$("$ITEMS" tmux | wc -l)"
SHELL_COUNT="$("$ITEMS" shell | wc -l)"
FRECENCY_COUNT="$("$ITEMS" frecency | wc -l)"
HYPR_COUNT="$("$ITEMS" hypr | wc -l)"

[ "$ALL_COUNT" -ge 25 ] && ok "keybindings items all count ($ALL_COUNT)" || bad "keybindings items count too low"
[ "$TMUX_COUNT" -ge 10 ] && ok "keybindings items tmux count ($TMUX_COUNT)" || bad "tmux items count too low"
[ "$SHELL_COUNT" -ge 5 ] && ok "keybindings items shell count ($SHELL_COUNT)" || bad "shell items count too low"
[ "$FRECENCY_COUNT" -ge 5 ] && ok "keybindings items frecency count ($FRECENCY_COUNT)" || bad "frecency items count too low"
[ "$HYPR_COUNT" -ge 5 ] && ok "keybindings items hypr count ($HYPR_COUNT)" || bad "hypr items count too low"

# 3. Check preview generation
PREV_OUT="$("$PREVIEW" "󰈞  Prefix + e" "Workspace Files" "tmux" "tmux-workspace" "~/.config/tmux/workspace-picker.sh")"
[[ "$PREV_OUT" == *"Workspace Files"* ]] && [[ "$PREV_OUT" == *"75% × 60%"* ]] && ok "preview output" || bad "preview output"

# 4. Check waymaker preset configuration
wm --dump-config -o keybindings >/dev/null 2>&1 && ok "wm loads keybindings preset" || bad "wm failed loading keybindings preset"

# 5. Check tmux.conf binding
grep -qE 'bind-key "\?" run-shell ".*keybindings-picker\.sh' "$CONF" && ok "tmux.conf binds Prefix + ?" || bad "tmux.conf missing Prefix + ? bind"

echo "=== All Keybindings HUD tests passed! ==="
