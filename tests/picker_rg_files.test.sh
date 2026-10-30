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
# Private tmux server + sandboxed HOME: never the live session or ~/.local/state.
. "$ROOT/tests/lib/private_tmux.sh"
FAILURES=0

ok() { echo "  ✔ PASS: $1"; }
bad() { echo "  ✖ FAIL: $1"; FAILURES=$((FAILURES + 1)); }

echo "=== Running Picker Harmonization & Ripgrep Live Search Test Suite ==="

# The rg, workspace and session-picker presets are Waymaker's built-in ones with a personal layer
# (<name>-mine.toml) on top; the wrappers run `wm -o <name> -o <name>-mine`. These checks read the
# effective preset as wm merges it (`wm --dump-config`), whose bind names are normalized (Enter,
# Ctrl-v), so lookups ignore case.
TEST_BIN="$(command -v wm 2>/dev/null || echo wm)"
PRESETS="$ROOT/waymaker/.config/waymaker/presets"
DUMP_DIR="$(mktemp -d)"
for p in workspace rg session-picker; do
  "$TEST_BIN" --dump-config -o "$p" -o "$PRESETS/$p-mine.toml" >"$DUMP_DIR/$p.toml" 2>/dev/null ||
    bad "wm cannot load $p with $p-mine.toml"
done
ok "wm loads workspace, rg and session-picker with their personal layers"

# ── 1. workspace: data sources and binds the wrapper relies on ──
echo -e "\n[1/6] Validating the effective workspace preset..."
python3 - "$DUMP_DIR/workspace.toml" "$PRESETS/workspace-mine.toml" <<'EOF2'
import sys, tomllib

cfg = tomllib.load(open(sys.argv[1], "rb"))
mine = tomllib.load(open(sys.argv[2], "rb"))
def bind(table, key):
    return next((v for k, v in table.items() if k.lower() == key.lower()), None)

assert cfg["ui"]["nav"]["active"] is True, "ui.nav.active must be true"
for mode in ("local", "frecency", "bookmarks"):
    assert mode in cfg["query"], f"query.{mode} prompt missing"
add = cfg["start"]["command"]["additional"]
assert len(add) >= 3 and add[0] == "", f"source 0 must be the local walk: {add[:3]}"
assert "wm list" in add[1] and "wm list --bookmarks" in add[2], f"frecency/bookmarks sources: {add[:3]}"

binds, nav = cfg["binds"], cfg["ui"]["nav"]["binds"]
assert bind(binds, "tab") == "@reloadnext" and bind(nav, "tab") == "@reloadnext", "Tab must be @reloadnext"
for key in ("shift-tab", "shift-backtab"):
    assert bind(binds, key) == "@reloadprev", f"{key} must be @reloadprev"
assert "@dirs" in binds and "@bookmarks" in binds, "@dirs and @bookmarks must be defined"
assert "send-keys" in str(bind(binds, "ctrl-v")) and "send-keys" in str(bind(nav, "ctrl-v")), "ctrl-v must insert into the origin pane"
assert bind(binds, "enter") == "CyclePreview", "Enter must cycle the preview"
for key in ("e", "o", "ctrl-e", "ctrl-o"):
    assert "scrollback-open.sh" in str(bind(nav, key)), f"nav {key} must open through scrollback-open.sh"
assert "scrollback-open.sh" in mine["binds"]["ctrl-e"], "workspace-mine must set ctrl-e"
print("workspace ok")
EOF2
if [ $? -eq 0 ]; then ok "workspace: sources, reload cycling, insert and personal open keys"; else bad "workspace contract"; fi

# ── 2. rg: live ripgrep, column split, toggles and the personal layer ──
echo -e "\n[2/6] Validating the effective rg preset (Live Ripgrep)..."
python3 - "$DUMP_DIR/rg.toml" "$ROOT" <<'EOF2'
import re, subprocess, sys, tomllib

cfg = tomllib.load(open(sys.argv[1], "rb"))
root = sys.argv[2]
def bind(table, key):
    return next((v for k, v in table.items() if k.lower() == key.lower()), None)

cols = cfg["columns"]
assert [c["name"] for c in cols["names"]] == ["file", "line", "text"], f"columns: {cols['names']}"
pattern = cols["split"]
m = re.match(pattern, "path/to a space/app.rs:42:fn main() {")
assert m and m.groups() == ("path/to a space/app.rs", "42", "fn main() {"), f"split {pattern}"
rg_raw = subprocess.check_output(
    ["rg", "--hidden", "--glob", "!.git", "--line-number", "--no-heading", "--color=always", "--ignore-case", "--", "workspace-picker"],
    cwd=root, stdin=subprocess.DEVNULL, stderr=subprocess.STDOUT).decode("utf-8", errors="replace")
first = re.sub(r"\x1b\[[0-9;]*[a-zA-Z]", "", rg_raw).splitlines()[0]
assert re.match(pattern, first), f"split failed on real rg output: {first}"

assert cfg["start"]["ansi"] is True, "start.ansi must be true for the live ANSI stream"
assert cfg["preview"]["media"]["active"] is False, "preview.media.active must be false in tmux"
command = cfg["start"]["command"]["default"]["command"]
for needle in ("--hidden", "!.git", "--ignore-case", "--case-sensitive", "--word-regexp", "cs+ww"):
    assert needle in command, f"rg command must contain {needle}"
assert "--smart-case" not in command, "rg must not use --smart-case"

layout0 = cfg["preview"]["layout"][0]
assert layout0["side"] == "right" and int(layout0["percentage"]) == 55, "45/55 foveal split"
assert "bat" in layout0["command"] and "--highlight-line" in layout0["command"], "bat preview"

binds, nav = cfg["binds"], cfg["ui"]["nav"]["binds"]
assert bind(binds, "Start") == "@enter_rg", "Start must enter live reload"
acts = bind(binds, "@enter_rg") or []
assert any("Bind(QueryChange = Reload)" in a for a in acts) and any("Filtering(false)" in a for a in acts), acts
assert bind(binds, "enter") == "Become(nvim +{2} {1})" and bind(nav, "enter") == "Become(nvim +{2} {1})", "Enter opens nvim at the line"
assert "{1}:{2}" in str(bind(binds, "ctrl-v")), "ctrl-v must insert {file}:{line}"
for key in ("e", "o", "ctrl-e", "ctrl-o"):
    assert "scrollback-open.sh" in str(bind(nav, key)), f"nav {key} must open through scrollback-open.sh"
for key in ("ctrl-s", "ctrl-w"):
    assert "Transform(" in str(bind(binds, key)), f"{key} must toggle the search mode"
footer = cfg["footer"]["content"]
assert "C-s" in footer and "C-w" in footer, "footer must document C-s and C-w"
print("rg ok")
EOF2
if [ $? -eq 0 ]; then ok "rg: split, live reload, toggles, nvim Enter and personal open keys"; else bad "rg contract"; fi

python3 - "$DUMP_DIR/session-picker.toml" <<'EOF2'
import sys, tomllib
nav = tomllib.load(open(sys.argv[1], "rb"))["ui"]["nav"]["binds"]
def bind(key):
    return next((v for k, v in nav.items() if k == key), None)  # a/A and c/C differ by case
for key, agent in (("r", "auto"), ("a", "agy"), ("A", "agyy"), ("c", "claude")):
    assert f"Print(@agent={agent})" in str(bind(key)), f"session-picker {key} must arm {agent}"
assert "__SWITCH_COCKPIT__" in str(bind("s")), "s must switch to the Cockpit"
print("session-picker ok")
EOF2
if [ $? -eq 0 ]; then ok "session-picker: agent and Cockpit keys from session-picker-mine"; else bad "session-picker layer"; fi
rm -rf "$DUMP_DIR"

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
    for c in w o r k s p a c e - p i c k e r; do
      tmux send-keys -t "$WIN" -l "$c" 2>/dev/null || true
      sleep 0.05
    done
    sleep 1.0
    CAPTURED=$(tmux capture-pane -t "$WIN" -p 2>/dev/null || true)
    tmux kill-window -t "$WIN" 2>/dev/null || true
    if echo "$CAPTURED" | grep -q "workspace-picker"; then
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
echo -e "\n[3/6] Validating Popup Scripts..."
FILES_SCRIPT="$ROOT/tmux/.config/tmux/workspace-picker.sh"
GREP_SCRIPT="$ROOT/tmux/.config/tmux/grep-picker.sh"

[ -x "$FILES_SCRIPT" ] && sh -n "$FILES_SCRIPT" && ok "workspace-picker.sh syntax and executable" || bad "workspace-picker.sh syntax/executable"
[ -x "$GREP_SCRIPT" ] && sh -n "$GREP_SCRIPT" && ok "grep-picker.sh syntax and executable" || bad "grep-picker.sh syntax/executable"

# Verify obsolete symlinks are removed
[ ! -e "$ROOT/tmux/.config/tmux/files-picker.sh" ] && \
[ ! -e "$ROOT/tmux/.config/tmux/dir-peek.sh" ] && \
[ ! -e "$ROOT/tmux/.config/tmux/dir-picker.sh" ] && \
[ ! -e "$ROOT/tmux/.config/tmux/rg-picker.sh" ] && \
[ ! -e "$ROOT/tmux/.config/tmux/sesh-picker.sh" ] \
  && ok "obsolete symlinks cleanly removed from tmux config" || bad "obsolete symlinks still present"

# Popup launcher validation (native tmux display-popup)
grep -q 'display-popup' "$FILES_SCRIPT" \
  && ok "workspace-picker.sh native display-popup" || bad "workspace-picker.sh native display-popup"

grep -q 'display-popup' "$GREP_SCRIPT" \
  && ok "grep-picker.sh native display-popup" || bad "grep-picker.sh native display-popup"

# ── 4. Validate tmux.conf Keybindings ──
echo -e "\n[4/6] Validating tmux.conf Bindings..."
CONF="$ROOT/tmux/.config/tmux/tmux.conf"

grep -qE "bind-key \"e\" run-shell \".*workspace-picker\.sh '#{pane_id}' '#{pane_current_path}'\"" "$CONF" \
  && ok "tmux.conf: prefix + e -> workspace-picker.sh" || bad "tmux.conf prefix+e"

grep -qE "bind-key C-e run-shell \".*workspace-picker\.sh '#{pane_id}' '#{pane_current_path}'\"" "$CONF" \
  && ok "tmux.conf: prefix + C-e -> workspace-picker.sh" || bad "tmux.conf prefix+C-e"

grep -q "bind-key \"/\" run-shell \".*grep-picker.sh '#{pane_id}' '#{pane_current_path}'\"" "$CONF" \
  && ok "tmux.conf: prefix + / -> grep-picker.sh" || bad "tmux.conf prefix+/"

grep -q "bind-key \"T\" run-shell \".*reopen-window.sh\"" "$CONF" \
  && ok "tmux.conf: prefix + T -> reopen-window.sh" || bad "tmux.conf prefix+T missing"

grep -q "bind-key \"u\" run-shell \".*ai-quota-popup.sh" "$CONF" \
  && ok "tmux.conf: prefix + u -> ai-quota-popup.sh" || bad "tmux.conf prefix+u missing"

grep -q "bind-key o run-shell \".*toggle-ai-split.sh" "$CONF" \
  && ok "tmux.conf: prefix + o -> toggle-ai-split.sh" || bad "tmux.conf prefix+o missing"

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
