#!/usr/bin/env bash
# tests/pr_workflow.test.sh — comprehensive verification suite for GitHub PR review workflow
# Tests:
#   1. TOML Preset contracts: pr.toml and awt-pr.toml
#   2. Launcher script contract: pr-picker.sh (Golden Ratio 75%x60%, backdrop protection)
#   3. Auxiliary action scripts: pr-open-chrome.sh and pr-diff.sh
#   4. Tmux keybindings: tmux.conf Prefix + P
#   5. Keybindings HUD integration: keybindings-items.sh and keybindings-preview.sh
#   6. IntelliShell command catalog sync
#   7. Live wm preset loader verification

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAILURES=0

pass() { echo -e "\033[1;32m✔ PASS:\033[0m $1"; }
fail() { echo -e "\033[1;31m✖ FAIL:\033[0m $1"; FAILURES=$((FAILURES + 1)); }

echo "=== Running GitHub PR Review Workflow Test Suite ==="

# ── 1. Validate TOML Presets (pr.toml & awt-pr.toml) ──
echo -e "\n[1/6] Validating TOML Presets (pr.toml & awt-pr.toml)..."
python3 - <<EOF
import os, tomllib

# 1.1 pr.toml
pr_path = "$ROOT/waymaker/.config/waymaker/presets/pr.toml"
with open(pr_path, "rb") as f:
    pr = tomllib.load(f)

# Navigation mode & columns
assert pr.get("ui", {}).get("nav", {}).get("active") is True, "pr.toml ui.nav.active must be True"
col_names = [col["name"] for col in pr["columns"]["names"]]
for req_col in ["number", "branch", "author", "updated", "title"]:
    assert req_col in col_names, f"missing column {req_col} in pr.toml"

# Multi-tab cycling commands
start_cmd = pr.get("start", {}).get("command", {})
if isinstance(start_cmd, str):
    add_cmds = pr.get("start", {}).get("additional", [])
else:
    add_cmds = start_cmd.get("additional") or pr.get("start", {}).get("additional_commands", [])

assert len(add_cmds) >= 2, f"Expected at least 2 additional commands for tabs, got {len(add_cmds)}"

# Preview layouts
layouts = pr.get("preview", {}).get("layout", [])
assert len(layouts) >= 2, f"Expected at least 2 preview layouts (view + diff), got {len(layouts)}"
assert "gh pr view" in layouts[0]["command"], "Layout 0 must preview gh pr view"
assert "gh pr diff" in layouts[1]["command"], "Layout 1 must preview gh pr diff"

# Binds contract
binds = pr.get("binds", {})
assert binds.get("tab") == "ReloadNext" or binds.get("nav^^tab") == "ReloadNext", "Tab must trigger ReloadNext"
assert binds.get("shift-tab") == "ReloadPrev" or binds.get("nav^^shift-tab") == "ReloadPrev", "Shift-Tab must trigger ReloadPrev"
assert "pr-open-chrome.sh" in binds.get("ctrl-e", "") or "pr-open-chrome.sh" in binds.get("nav^^e", ""), "Ctrl-E must trigger pr-open-chrome.sh"
assert "pr-diff.sh" in binds.get("ctrl-d", "") or "pr-diff.sh" in binds.get("nav^^d", ""), "Ctrl-D must trigger pr-diff.sh"

# 1.2 awt-pr.toml
awt_pr_path = "$ROOT/awt/.config/waymaker/presets/awt-pr.toml"
with open(awt_pr_path, "rb") as f:
    awt_pr = tomllib.load(f)

assert awt_pr.get("ui", {}).get("nav", {}).get("active") is True, "awt-pr.toml ui.nav.active must be True"
print("TOML presets contract validated successfully.")
EOF

if [ $? -eq 0 ]; then
    pass "Waymaker TOML presets (pr.toml, awt-pr.toml) satisfy schema, columns, tabs, and actions"
else
    fail "TOML presets validation failed"
fi

# ── 2. Validate Launcher Script (pr-picker.sh) ──
echo -e "\n[2/6] Validating pr-picker.sh launcher..."
PR_PICKER="$ROOT/tmux/.config/tmux/pr-picker.sh"

[ -x "$PR_PICKER" ] || fail "pr-picker.sh is not executable"
bash -n "$PR_PICKER" || fail "pr-picker.sh bash syntax error"
sh -n "$PR_PICKER" || fail "pr-picker.sh POSIX sh syntax error"

# Check Golden Ratio dimensions (75% x 60%)
if grep -q "\-w 75%" "$PR_PICKER" && grep -q "\-h 60%" "$PR_PICKER"; then
    pass "pr-picker.sh applies Golden Ratio dimensions (75% × 60%)"
else
    fail "pr-picker.sh missing 75% × 60% dimensions"
fi

# Check isolator delegation and backdrop protection
if grep -q "tmux-popup-isolate\.sh" "$PR_PICKER"; then
    pass "pr-picker.sh delegates to tmux-popup-isolate.sh"
else
    fail "pr-picker.sh missing tmux-popup-isolate.sh delegation"
fi

# Check dynamic Omarchy theme color integration
if grep -q "colors\.toml" "$PR_PICKER"; then
    pass "pr-picker.sh integrates dynamic theme colors from colors.toml"
else
    fail "pr-picker.sh missing colors.toml integration"
fi

# ── 3. Validate Auxiliary Action Scripts ──
echo -e "\n[3/6] Validating pr-open-chrome.sh and pr-diff.sh..."
CHROME_SCRIPT="$ROOT/waymaker/.config/waymaker/scripts/pr-open-chrome.sh"
DIFF_SCRIPT="$ROOT/waymaker/.config/waymaker/scripts/pr-diff.sh"

[ -x "$CHROME_SCRIPT" ] && bash -n "$CHROME_SCRIPT" && pass "pr-open-chrome.sh is executable and valid syntax" || fail "pr-open-chrome.sh invalid"
[ -x "$DIFF_SCRIPT" ] && bash -n "$DIFF_SCRIPT" && pass "pr-diff.sh is executable and valid syntax" || fail "pr-diff.sh invalid"

# ── 4. Validate Tmux Keybindings ──
echo -e "\n[4/6] Validating tmux.conf Prefix + P binding..."
TMUX_CONF="$ROOT/tmux/.config/tmux/tmux.conf"

if grep -qE 'bind-key "P" run-shell ".*pr-picker\.sh' "$TMUX_CONF"; then
    pass "tmux.conf binds Prefix + P to pr-picker.sh"
else
    fail "tmux.conf missing Prefix + P binding"
fi

# ── 5. Validate Keybindings HUD Integration ──
echo -e "\n[5/6] Validating Keybindings HUD items & preview..."
ITEMS_SCRIPT="$ROOT/tmux/.config/tmux/keybindings-items.sh"
PREVIEW_SCRIPT="$ROOT/tmux/.config/tmux/keybindings-preview.sh"

if "$ITEMS_SCRIPT" tmux | grep -q "Prefix + P.*pr-picker\.sh"; then
    pass "keybindings-items.sh includes Prefix + P GitHub PR Review Picker"
else
    fail "keybindings-items.sh missing Prefix + P"
fi

PREVIEW_OUT="$("$PREVIEW_SCRIPT" "  Prefix + P" "GitHub Pull Request Review Picker" "tmux" "tmux-pr" "~/.config/tmux/pr-picker.sh")"
if echo "$PREVIEW_OUT" | grep -q "GitHub Pull Request Review Picker" && echo "$PREVIEW_OUT" | grep -q "75% × 60%"; then
    pass "keybindings-preview.sh renders rich preview for tmux-pr"
else
    fail "keybindings-preview.sh missing or invalid preview for tmux-pr"
fi

# ── 6. Validate IntelliShell Custom Commands ──
echo -e "\n[6/6] Validating IntelliShell custom.commands catalog..."
CUSTOM_CMDS="$ROOT/intelli-shell/.config/intelli-shell/custom.commands"

if grep -q "pr-picker\.sh" "$CUSTOM_CMDS"; then
    pass "intelli-shell custom.commands contains pr-picker.sh"
else
    fail "intelli-shell custom.commands missing pr-picker.sh"
fi

# ── Live wm preset loading ──
echo -e "\nValidating Waymaker preset loading with wm binary..."
TEST_BIN="$(command -v wm 2>/dev/null || command -v mm 2>/dev/null || echo wm)"
if "$TEST_BIN" --dump-config -o "$ROOT/waymaker/.config/waymaker/presets/pr.toml" >/dev/null 2>&1; then
    pass "wm successfully loads pr.toml"
else
    fail "wm failed to load pr.toml"
fi

if [ "$FAILURES" -eq 0 ]; then
    echo -e "\n\033[1;32m=== All GitHub PR Review Workflow tests passed! (6/6) ===\033[0m"
    exit 0
else
    echo -e "\n\033[1;31m=== $FAILURES test(s) failed! ===\033[0m"
    exit 1
fi
