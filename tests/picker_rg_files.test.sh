#!/usr/bin/env sh
# picker_rg_files.test.sh — comprehensive verification suite for:
#   1. files.toml tri-modal data source cycling (Tab / Shift+Tab)
#   2. rg.toml live ripgrep with debounced query reload, 45/55 foveal layout, bat preview, nvim Enter, ctrl-v insert
#   3. files-picker.sh and grep-picker.sh popup scripts & symlinks
#   4. tmux.conf keybindings (prefix+e/C-e and prefix+/)
#   5. intelli-shell command palette synchronization
# Run: sh tests/picker_rg_files.test.sh (from repository root)

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FAILURES=0

ok() { echo "  ✔ PASS: $1"; }
bad() { echo "  ✖ FAIL: $1"; FAILURES=$((FAILURES + 1)); }

echo "=== Running Picker Harmonization & Ripgrep Live Search Test Suite ==="

# ── 1. Validate workspace.toml Contract ──
echo -e "\n[1/6] Validating workspace.toml Preset & Data Source Cycling..."
WORKSPACE_PRESET="$ROOT/waymaker/.config/waymaker/presets/workspace.toml"
[[ -f "$WORKSPACE_PRESET" ]] || WORKSPACE_PRESET="$ROOT/matchmaker/.config/matchmaker/presets/workspace.toml"
python3 - "$WORKSPACE_PRESET" <<'EOF'
import sys, tomllib

with open(sys.argv[1], "rb") as f:
    cfg = tomllib.load(f)

# ui.nav check
assert cfg["ui"]["nav"]["active"] is True, "ui.nav.active must be true"

# Data source mode prompts
assert "local" in cfg["query"], "query.local prompt missing"
assert "frecency" in cfg["query"], "query.frecency prompt missing"
assert "bookmarks" in cfg["query"], "query.bookmarks prompt missing"

# Data sources additional commands
start_cmd = cfg["start"]["command"]
add_cmds = start_cmd.get("additional") or cfg["start"].get("additional_commands", [])
assert len(add_cmds) >= 3, f"Expected at least 3 data sources, got {len(add_cmds)}"
assert add_cmds[0] == "", "Source 0 must be local empty string"
assert ("wm list" in add_cmds[1] or "mm list" in add_cmds[1]), "Source 1 must be frecency wm/mm list"
assert ("wm list --bookmarks" in add_cmds[2] or "mm list --bookmarks" in add_cmds[2]), "Source 2 must be bookmarks wm/mm list"

# Binds contract
binds = cfg["binds"]
nav_binds = cfg["ui"]["nav"]["binds"]

assert binds.get("tab") == "@reloadnext", "binds.tab must be @reloadnext"
assert nav_binds.get("tab") == "@reloadnext", "nav_binds.tab must be @reloadnext"

for key in ["shift-backtab", "backtab", "shift-tab"]:
    assert binds.get(key) == "@reloadprev", f"binds.{key} must be @reloadprev"
    assert nav_binds.get(key) == "@reloadprev", f"nav_binds.{key} must be @reloadprev"

assert "@dirs" in binds and "@bookmarks" in binds, "Semantic triggers @dirs and @bookmarks must be defined"
assert nav_binds.get("y") == "Accept" and nav_binds.get("ctrl-y") == "Accept", "Nav y and ctrl-y must be Accept"
assert "send-keys" in binds["ctrl-v"], "binds.ctrl-v must insert to tmux"
assert "send-keys" in nav_binds["ctrl-v"], "nav_binds.ctrl-v must insert to tmux"
assert binds.get("enter") == "CyclePreview", "binds.enter must be CyclePreview"
print("workspace.toml python validation ok")
EOF
if [ $? -eq 0 ]; then ok "workspace.toml schema & bindings contract"; else bad "workspace.toml schema & bindings contract"; fi

TEST_BIN="$(command -v wm 2>/dev/null || command -v mm 2>/dev/null || echo wm)"

if "$TEST_BIN" --dump-config -o workspace >/dev/null 2>&1 || "$TEST_BIN" --dump-config -o "$WORKSPACE_PRESET" >/dev/null 2>&1; then
  ok "wm/mm loads workspace preset without errors"
else
  bad "wm/mm rejected workspace preset"
fi

# ── 2. Validate rg.toml Contract ──
echo -e "\n[2/6] Validating rg.toml Preset (Live Ripgrep)..."
RG_PRESET="$ROOT/waymaker/.config/waymaker/presets/rg.toml"
[[ -f "$RG_PRESET" ]] || RG_PRESET="$ROOT/matchmaker/.config/matchmaker/presets/rg.toml"
python3 - "$RG_PRESET" <<'EOF'
import sys, re, subprocess, tomllib

with open(sys.argv[1], "rb") as f:
    cfg = tomllib.load(f)

# Matcher & columns
assert cfg["matcher"]["ansi"] is True, "matcher.ansi must be true"
col = cfg["columns"]
assert col["names"] == ["file", "line", "text"], f"columns.names should be file, line, text, got {col['names']}"

# Test regex split with spaces and complex paths
pattern = col["split"]
m = re.match(pattern, "path/to a space/app.rs:42:fn main() {")
assert m is not None, f"Regex {pattern} failed to match"
assert m.groups() == ("path/to a space/app.rs", "42", "fn main() {"), f"Unexpected groups: {m.groups()}"

# Test regex split against real stripped ripgrep output
repo_root = sys.argv[1].split("/waymaker/")[0] if "/waymaker/" in sys.argv[1] else sys.argv[1].split("/matchmaker/")[0]
rg_raw = subprocess.check_output(
    ["rg", "--hidden", "--glob", "!.git", "--line-number", "--no-heading", "--color=always", "--ignore-case", "--", "files-picker"],
    cwd=repo_root,
    stdin=subprocess.DEVNULL,
    stderr=subprocess.STDOUT
).decode("utf-8", errors="replace")
ansi_clean = re.sub(r'\x1b\[[0-9;]*[a-zA-Z]', '', rg_raw)
assert len(ansi_clean.splitlines()) > 0, "Real rg output was empty"
first_line = ansi_clean.splitlines()[0]
m_real = re.match(pattern, first_line)
assert m_real is not None, f"Regex {pattern} failed to match real rg line: {first_line}"

# Verify rg cmd and command include hidden flag and exclude .git, and start.ansi is true
assert cfg.get("start", {}).get("ansi") is True, "start.ansi must be true for matchmaker live stream ANSI handling"
assert cfg.get("preview", {}).get("media", {}).get("active") is False, "preview.media.active must be false to prevent hanging on graphics probe in tmux"
cmd_str = cfg["start"]["command"].get("cmd") or ""
command_str = cfg["start"]["command"].get("command") or ""
assert "--hidden" in cmd_str and "--hidden" in command_str, "rg command must search hidden directories"
assert "!.git" in cmd_str and "!.git" in command_str, "rg command must exclude .git"

# Default must be --ignore-case, NOT --smart-case
assert "--ignore-case" in cmd_str, "rg default must use --ignore-case (not --smart-case)"
assert "--ignore-case" in command_str, "rg command default must use --ignore-case (not --smart-case)"
assert "--smart-case" not in cmd_str, "rg must NOT use --smart-case (breaks uppercase queries)"
assert "--smart-case" not in command_str, "rg must NOT use --smart-case"

# MM_STORE mode parsing must handle all 4 modes
for mode_key in ["cs", "ww", "cs+ww"]:
    assert mode_key in cmd_str, f"cmd must handle MM_STORE mode '{mode_key}'"
    assert mode_key in command_str, f"command must handle MM_STORE mode '{mode_key}'"
assert "--case-sensitive" in cmd_str, "cmd must use --case-sensitive for cs mode"
assert "--word-regexp" in cmd_str, "cmd must use --word-regexp for ww mode"

# Preview & 45/55 foveal layout
prev = cfg["preview"]
assert prev["show"] is True, "preview.show must be true"
assert prev["scroll"]["percentage"] == 50, "preview.scroll.percentage must be 50"
assert prev["scroll"]["index"] == "line", "preview.scroll.index must be line"

layout0 = prev["layout"][0]
assert layout0["side"] == "right", "layout.side must be right"
assert layout0["percentage"] == 55, "layout.percentage must be 55 (45/55 foveal split)"
assert 'file={1}' in layout0["command"] and 'line={2}' in layout0["command"], "layout0 command must bind {1} and {2}"
assert "bat" in layout0["command"] and "--highlight-line" in layout0["command"], "preview command must use bat --highlight-line"

layout1 = prev["layout"][1]
assert layout1["percentage"] == 100, "layout1 must be fullscreen 100%"
assert 'file={1}' in layout1["command"], "layout1 must define preview command for fullscreen"

# Live query reload binds
binds = cfg["binds"]
nav_binds = cfg["ui"]["nav"]["binds"]

assert binds.get("Start") == "@enter_rg", "Start event must bind to @enter_rg"
rg_actions = binds.get("@enter_rg", [])
assert any("Bind(QueryChange = Reload)" in act for act in rg_actions), "Missing QueryChange = Reload"
assert any("Filtering(false)" in act for act in rg_actions), "Missing Filtering(false)"

assert "Become(nvim +{2} {1})" in binds.get("enter", ""), "Enter must open nvim +{line} {file}"
assert "Become(nvim +{2} {1})" in nav_binds.get("enter", ""), "Nav Enter must open nvim +{line} {file}"

assert "send-keys" in binds.get("ctrl-v", "") and "{1}:{2}" in binds.get("ctrl-v", ""), "ctrl-v must insert {file}:{line}"
assert "send-keys" in nav_binds.get("ctrl-v", "") and "{1}:{2}" in nav_binds.get("ctrl-v", ""), "nav ctrl-v must insert {file}:{line}"

assert "ctrl-y" in binds, "ctrl-y must be bound to copy"
assert "y" in nav_binds, "y must be bound to copy in nav mode"

# Case / Word toggles
assert "ctrl-s" in binds, "ctrl-s must be bound (match-case toggle)"
assert "ctrl-w" in binds, "ctrl-w must be bound (whole-word toggle)"
# ctrl-s and ctrl-w use Transform which is only supported in [binds] (not [ui.nav.binds]);
# the [binds] fallback makes them available in nav mode too.
assert "Transform(" in binds.get("ctrl-s", ""), "ctrl-s must use Transform to update state"
assert "Transform(" in binds.get("ctrl-w", ""), "ctrl-w must use Transform to update state"
# Transform delegate scripts must emit Store, SetStyledPrompt, Reload
import os
scripts_dir = os.path.join(os.path.expanduser("~"), ".config", "waymaker", "scripts")
if not os.path.isdir(scripts_dir):
    scripts_dir = os.path.join(os.path.expanduser("~"), ".config", "matchmaker", "scripts")
for fname, label in [("rg-toggle-case.sh", "match-case"), ("rg-toggle-word.sh", "whole-word")]:
    script_path = os.path.join(scripts_dir, fname)
    assert os.path.isfile(script_path), f"Toggle script {fname} must exist at {script_path}"
    with open(script_path) as sf:
        script_body = sf.read()
    assert "Store(" in script_body or "printf 'Store" in script_body or 'printf "Store' in script_body, \
        f"{fname} must emit Store() to persist mode"
    assert "SetStyledPrompt(" in script_body or "printf 'SetStyledPrompt" in script_body or 'printf "SetStyledPrompt' in script_body, \
        f"{fname} must emit SetStyledPrompt() for visual feedback"
    assert "Reload" in script_body, f"{fname} must emit Reload to re-run rg with new flags"

# Footer must document Ctrl+S and Ctrl+W
footer = cfg.get("footer", {}).get("content", "")
assert "C-s" in footer, "footer must document Ctrl+S (match-case toggle)"
assert "C-w" in footer, "footer must document Ctrl+W (whole-word toggle)"

print("rg.toml python validation ok")
EOF
if [ $? -eq 0 ]; then ok "rg.toml schema & bindings contract"; else bad "rg.toml schema & bindings contract"; fi

if "$TEST_BIN" --dump-config -o rg >/dev/null 2>&1; then
  ok "wm/mm loads rg preset without errors"
else
  bad "wm/mm rejected rg preset"
fi

# Live functional test: test wm -o rg inside tmux with query reload and item rendering
if [ -n "${TMUX:-}" ] && command -v tmux >/dev/null 2>&1; then
  WIN="test-rg-live-$$"
  if tmux new-window -n "$WIN" "$TEST_BIN --no-read -o rg" 2>/dev/null; then
    sleep 1.0
    for c in f i l e s - p i c k e r; do
      tmux send-keys -t "$WIN" -l "$c" 2>/dev/null || true
      sleep 0.05
    done
    sleep 1.0
    CAPTURED=$(tmux capture-pane -t "$WIN" -p 2>/dev/null || true)
    tmux kill-window -t "$WIN" 2>/dev/null || true
    if echo "$CAPTURED" | grep -q "files-picker"; then
      ok "live wm/mm -o rg streams ripgrep matches and splits columns"
    else
      bad "live wm/mm -o rg failed to display ripgrep matches"
    fi

    # Uppercase query test (ensure Filtering(false) prevents nucleo from filtering out case-insensitive rg results)
    WIN_UPPER="test-rg-upper-$$"
    if tmux new-window -n "$WIN_UPPER" "$TEST_BIN --no-read -o rg" 2>/dev/null; then
      sleep 1.0
      for c in F Z F; do
        tmux send-keys -t "$WIN_UPPER" -l "$c" 2>/dev/null || true
        sleep 0.05
      done
      sleep 1.0
      CAPTURED_UPPER=$(tmux capture-pane -t "$WIN_UPPER" -p 2>/dev/null || true)
      tmux kill-window -t "$WIN_UPPER" 2>/dev/null || true
      if echo "$CAPTURED_UPPER" | grep -q "fzf"; then
        ok "live wm/mm -o rg uppercase query works (FZF matches fzf)"
      else
        bad "live wm/mm -o rg uppercase query failed to display matches"
      fi
    fi
  else
    ok "live wm/mm -o rg test skipped (could not create tmux test window)"
  fi
fi

# Live headless mode test (ensure wm -f filters stdin streams directly)
if printf "alpha\nbeta\ngamma\n" | "$TEST_BIN" -f "bet" 2>/dev/null | grep -q "beta"; then
  ok "wm/mm --filter headless matching streams matches directly"
else
  bad "wm/mm --filter headless matching failed"
fi


# ── 3. Script Executability & Syntax ──
echo -e "\n[3/6] Validating Popup Scripts & Symlinks..."
FILES_SCRIPT="$ROOT/tmux/.config/tmux/workspace-picker.sh"
[[ -f "$FILES_SCRIPT" ]] || FILES_SCRIPT="$ROOT/tmux/.config/tmux/files-picker.sh"
GREP_SCRIPT="$ROOT/tmux/.config/tmux/grep-picker.sh"

[ -x "$FILES_SCRIPT" ] && sh -n "$FILES_SCRIPT" && ok "workspace-picker.sh syntax and executable" || bad "workspace-picker.sh syntax/executable"
[ -x "$GREP_SCRIPT" ] && sh -n "$GREP_SCRIPT" && ok "grep-picker.sh syntax and executable" || bad "grep-picker.sh syntax/executable"

# Check backward compatibility symlinks
[ -L "$ROOT/tmux/.config/tmux/files-picker.sh" ] && [ "$(readlink "$ROOT/tmux/.config/tmux/files-picker.sh")" = "workspace-picker.sh" ] \
  && ok "files-picker.sh -> workspace-picker.sh compatibility symlink" || bad "files-picker.sh symlink"

[ -L "$ROOT/tmux/.config/tmux/dir-peek.sh" ] && { [ "$(readlink "$ROOT/tmux/.config/tmux/dir-peek.sh")" = "workspace-picker.sh" ] || [ "$(readlink "$ROOT/tmux/.config/tmux/dir-peek.sh")" = "files-picker.sh" ]; } \
  && ok "dir-peek.sh -> workspace-picker.sh symlink" || bad "dir-peek.sh symlink"

[ -L "$ROOT/tmux/.config/tmux/dir-picker.sh" ] && { [ "$(readlink "$ROOT/tmux/.config/tmux/dir-picker.sh")" = "workspace-picker.sh" ] || [ "$(readlink "$ROOT/tmux/.config/tmux/dir-picker.sh")" = "files-picker.sh" ]; } \
  && ok "dir-picker.sh -> workspace-picker.sh symlink" || bad "dir-picker.sh symlink"

[ -L "$ROOT/tmux/.config/tmux/rg-picker.sh" ] && [ "$(readlink "$ROOT/tmux/.config/tmux/rg-picker.sh")" = "grep-picker.sh" ] \
  && ok "rg-picker.sh -> grep-picker.sh symlink" || bad "rg-picker.sh symlink"

# Backdrop isolation in scripts (delegates to tmux-popup-isolate.sh or inline)
(grep -q 'tmux-popup-isolate' "$FILES_SCRIPT" || (grep -q '@ai_agent_state_raw' "$FILES_SCRIPT" && grep -q 'tmux-backdrop' "$FILES_SCRIPT")) \
  && ok "workspace-picker.sh AI backdrop protection" || bad "workspace-picker.sh AI backdrop"

(grep -q 'tmux-popup-isolate' "$GREP_SCRIPT" || (grep -q '@ai_agent_state_raw' "$GREP_SCRIPT" && grep -q 'tmux-backdrop' "$GREP_SCRIPT")) \
  && ok "grep-picker.sh AI backdrop protection" || bad "grep-picker.sh AI backdrop"

# ── 4. Validate tmux.conf Keybindings ──
echo -e "\n[4/6] Validating tmux.conf Bindings..."
CONF="$ROOT/tmux/.config/tmux/tmux.conf"

grep -qE "bind-key \"e\" run-shell \".*(workspace-picker|files-picker)\.sh '#{pane_id}' '#{pane_current_path}'\"" "$CONF" \
  && ok "tmux.conf: prefix + e -> workspace-picker.sh" || bad "tmux.conf prefix+e"

grep -qE "bind-key C-e run-shell \".*(workspace-picker|files-picker)\.sh '#{pane_id}' '#{pane_current_path}'\"" "$CONF" \
  && ok "tmux.conf: prefix + C-e -> workspace-picker.sh" || bad "tmux.conf prefix+C-e"

grep -q "bind-key \"/\" run-shell \".*grep-picker.sh '#{pane_id}' '#{pane_current_path}'\"" "$CONF" \
  && ok "tmux.conf: prefix + / -> grep-picker.sh" || bad "tmux.conf prefix+/"

grep -q "bind-key \"T\" run-shell \".*reopen-window.sh\"" "$CONF" \
  && ok "tmux.conf: prefix + T -> reopen-window.sh" || bad "tmux.conf prefix+T missing"

grep -q "bind-key \"u\" run-shell \".*reopen-window.sh\"" "$CONF" \
  && ok "tmux.conf: prefix + u -> reopen-window.sh" || bad "tmux.conf prefix+u missing"

# ── 5. Validate IntelliShell Sync ──
echo -e "\n[5/6] Validating IntelliShell Custom Commands..."
INTELLI="$ROOT/intelli-shell/.config/intelli-shell/custom.commands"

grep -q 'workspace-picker.sh' "$INTELLI" && ok "intelli-shell contains workspace-picker.sh" || bad "intelli-shell missing workspace-picker.sh"
grep -q 'grep-picker.sh' "$INTELLI" && ok "intelli-shell contains grep-picker.sh" || bad "intelli-shell missing grep-picker.sh"

# ── 6. Documentation & Stow Integrity ──
echo -e "\n[6/6] Validating Docs Lint & Stow Health..."
if "$ROOT/scripts/docs-lint.sh" >/dev/null 2>&1; then
  ok "docs-lint.sh passed"
else
  bad "docs-lint.sh failed"
fi

STOW_PKG="waymaker"
[ -d "$ROOT/waymaker" ] || STOW_PKG="matchmaker"
MOCK_TARGET="$(mktemp -d)"
if STOW_TARGET="$MOCK_TARGET" "$ROOT/stow.sh" -n "$STOW_PKG" tmux >/dev/null 2>&1; then
  rm -rf "$MOCK_TARGET"
  ok "stow.sh -n $STOW_PKG tmux passed"
else
  rm -rf "$MOCK_TARGET"
  bad "stow.sh -n $STOW_PKG tmux failed"
fi

echo -e "\n=== Summary: $FAILURES failure(s) ==="
exit "$FAILURES"
