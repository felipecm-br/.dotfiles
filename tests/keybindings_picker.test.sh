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
[[ "$PREV_OUT" == *"Workspace Files"* ]] && [[ "$PREV_OUT" == *"85% × 75%"* ]] && ok "preview output" || bad "preview output"

# 4. Check waymaker preset configuration
wm --dump-config -o keybindings >/dev/null 2>&1 && ok "wm loads keybindings preset" || bad "wm failed loading keybindings preset"

# 5. Check tmux.conf binding
grep -qE 'bind-key "\?" run-shell ".*keybindings-picker\.sh' "$CONF" && ok "tmux.conf binds Prefix + ?" || bad "tmux.conf missing Prefix + ? bind"

# 6. Command Palette (Ctrl + Shift + P): launcher, palette rows, preset layering, tmux bindings
PALETTE="$ROOT/tmux/.config/tmux/command-palette.sh"
PALETTE_PRESET="$ROOT/waymaker/.config/waymaker/presets/command-palette.toml"
[ -x "$PALETTE" ] && sh -n "$PALETTE" && ok "command-palette.sh syntax" || bad "command-palette.sh syntax"
[ -f "$PALETTE_PRESET" ] && ok "command-palette.toml exists" || bad "command-palette.toml missing"

PAL_ALL="$("$ITEMS" all palette)"
[ "$(printf '%s\n' "$PAL_ALL" | wc -l)" -gt "$ALL_COUNT" ] && ok "palette adds shortcut-less cmd rows" || bad "palette rows not larger than HUD rows"
CMD_COUNT="$("$ITEMS" cmd | wc -l)"
[ "$CMD_COUNT" -ge 10 ] && ok "cmd layer count ($CMD_COUNT)" || bad "cmd layer count too low"
[ "$("$ITEMS" all | grep -c $'\tcmd\t' || true)" -eq 0 ] && ok "HUD (non-palette) stays free of cmd rows" || bad "HUD leaked cmd rows"
# Palette order is name<TAB>key<TAB>layer<TAB>id<TAB>action.
printf '%s\n' "$PAL_ALL" | awk -F'\t' '$2=="Prefix + e" && $1 ~ /Workspace Files Picker/ && $3=="tmux" && $4=="tmux-workspace" {f=1} END{exit !f}' \
  && ok "palette row order (name, key, layer, id, action)" || bad "palette row order"
printf '%s\n' "$PAL_ALL" | awk -F'\t' 'NF!=5 {bad=1} END{exit bad}' && ok "palette rows keep 5 columns" || bad "palette row column count"
# WM_KB_PALETTE=1 must make plain filters behave as palette (Tab Reload commands rely on it)
[ "$(WM_KB_PALETTE=1 "$ITEMS" hypr | head -1 | cut -f2)" = "SUPER + B" ] && ok "WM_KB_PALETTE keeps name-first rows on Tab reload" || bad "WM_KB_PALETTE env"

# MRU: ids recorded by keybindings-run.sh float to the top of palette rows (most recent first), HUD order untouched
MRU_FILE="$(mktemp)"
printf 'hypr-browser\ntmux-grep\n' > "$MRU_FILE"
[ "$(PALETTE_RECENT_FILE="$MRU_FILE" "$ITEMS" all palette | head -2 | cut -f4 | paste -sd,)" = "tmux-grep,hypr-browser" ] && ok "palette lists most recently run commands first" || bad "palette MRU order"
[ "$(PALETTE_RECENT_FILE="$MRU_FILE" "$ITEMS" all palette | wc -l)" -eq "$(printf '%s\n' "$PAL_ALL" | wc -l)" ] && ok "MRU ordering keeps every row" || bad "MRU dropped rows"
TMUX='' PALETTE_RECENT_FILE="$MRU_FILE" "$RUNNER" info "" "Test" "tmux-test-id" >/dev/null 2>&1 || true
[ "$(tail -n1 "$MRU_FILE")" = "tmux-test-id" ] && ok "runner records palette id in MRU file" || bad "runner MRU record"
rm -f "$MRU_FILE" "$MRU_FILE.tmp"

PAL_PREV="$("$PREVIEW" "" "Rename Window" cmd cmd-rename-window "tmux command-prompt")"
[[ "$PAL_PREV" == *"Rename Window"* ]] && ok "preview for shortcut-less cmd rows" || bad "cmd preview"

wm --dump-config -o keybindings -o "$PALETTE_PRESET" 2>/dev/null | grep -q 'keybindings-preview.sh {2} {1} {3} {4} {5}' \
  && ok "wm layers command-palette over keybindings" || bad "wm failed layering command-palette preset"

grep -qE "bind-key -n 'C-S-p' run-shell \".*command-palette\\.sh" "$CONF" && grep -qE "bind-key -n 'C-S-P' run-shell \".*command-palette\\.sh" "$CONF" \
  && ok "tmux.conf binds Ctrl + Shift + P" || bad "tmux.conf missing Ctrl + Shift + P bind"
grep -qE "bind-key p run-shell \".*command-palette\\.sh" "$CONF" && ok "tmux.conf binds Prefix + p alias" || bad "tmux.conf missing Prefix + p alias"
grep -q 'ctrl-o = ' "$PALETTE_PRESET" && grep -q '"cmd^^ctrl-o"' "$PALETTE_PRESET" && ok "palette Ctrl + O cmd-layer toggle" || bad "palette Ctrl + O toggle"
"$ITEMS" tmux | grep -q $'\ttmux-palette\t' && ok "HUD catalog lists the palette" || bad "HUD catalog missing tmux-palette"

echo "=== All Keybindings HUD tests passed! ==="
