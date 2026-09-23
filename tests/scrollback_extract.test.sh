#!/usr/bin/env sh
# scrollback_extract.test.sh — focused test for the mm extrakto flow.
# Run: sh .dotfiles/main/tests/scrollback_extract.test.sh (from $HOME)
# Checks: preset parses + key binds, extraction pipeline on fixture, tmux binds.
set -u

ROOT="$HOME/.dotfiles/main"
FIX="$ROOT/tests/fixtures/scrollback_sample.txt"
PRESET="$ROOT/matchmaker/.config/matchmaker/presets/scrollback.toml"
SCRIPT="$ROOT/tmux/.config/tmux/scrollback-extract.sh"
CONF="$ROOT/tmux/.config/tmux/tmux.conf"
fail=0

ok() { echo "ok: $1"; }
bad() { echo "FALHOU: $1"; fail=1; }

# 1. preset TOML parses and carries the nav/filter/accept contract
python3 - "$PRESET" <<'EOF' || exit 1
import sys, tomllib
p = tomllib.load(open(sys.argv[1], "rb"))
nav_active = p["ui"].get("nav_mode", p["ui"].get("nav", {}).get("active", False))
assert nav_active is True, "nav_mode"
focus = p["ui"].get("nav_focus_on_start", p["ui"].get("nav", {}).get("focus_on_start", ""))
assert str(focus).lower() == "filter", "focus filter"
b = p["binds"]
nb = p["ui"].get("nav_binds") or p["ui"].get("nav", {}).get("binds", {})
assert b["enter"] == "Accept" and nb["enter"] == "Accept", "enter"
assert b["esc"] == "ToggleFocus", "esc cascade"
assert nb["esc"] == "Quit" and nb["q"] == "Quit", "esc quit"
assert b["tab"][0] == "SetPrompt(cmd> )", "tab->cmd prompt"
assert b["all^^tab"][2].startswith("Reload(") and b["all^^tab"][3] == "SetMode(cmd)", "all->cmd state"
assert b["cmd^^tab"][3] == "SetMode(path)", "cmd->path state"
assert b["path^^tab"][3] == "SetMode(url)", "path->url state"
assert b["url^^tab"][3] == "SetMode(sha)", "url->sha state"
assert b["sha^^tab"][3] == "SetMode(all)", "sha->all state"
assert b["sha^^shift-backtab"][3] == "SetMode(url)", "reverse state"
assert b["cmd^^shift-backtab"][3] == "SetMode(all)", "cmd reverse state"
assert nb[" "] == "Toggle", "space multi"
assert p["query"]["prompt"] == "> ", "prompt minimal"
add_cmds = p["start"].get("additional_commands") or p["start"].get("command", {}).get("additional", [])
assert len(add_cmds) == 5, "5 filters"
start_cmd = p["start"].get("command") if isinstance(p["start"].get("command"), str) else p["start"].get("command", {}).get("command")
assert start_cmd == "cat /tmp/scrollback-extract-all.txt", "items via command (stdin stays on tty)"
assert "send-keys" in b["ctrl-v"], "insert action"
assert p["preview"]["show"] is True, "preview on"
assert "scrollback-extract-src" in p["preview"]["layout"][0]["command"], "preview context"
assert "scrollback-open.sh" in b["ctrl-e"], "open in filter"
assert "scrollback-open.sh" in nb["e"], "open in nav"
assert p["exit"]["abort_empty"] is True, "abort_empty"
print("ok: preset parses with nav/filter/accept contract")
EOF
[ $? -eq 0 ] || bad "preset toml"

# 2. preset loads in the real wm/mm binary (catches unknown keys)
TEST_BIN="$(command -v wm 2>/dev/null || command -v mm 2>/dev/null || echo wm)"
if "$TEST_BIN" --dump-config -o scrollback >/dev/null 2>&1; then ok "wm/mm loads preset"; else bad "wm/mm rejects preset"; fi

# 3. extraction pipeline: dedupe + recent-first on fixture
got="$(grep -oE 'https?://[^[:space:]"'"'"'<>]+|(~?/[A-Za-z0-9._~:/?#@!$&()*+,;=%-]+|\./[A-Za-z0-9._~:/?#@!$&()*+,;=%-]+)|\b[0-9a-f]{7,40}\b|\b[0-9]{1,3}(\.[0-9]{1,3}){3}(:[0-9]+)?\b' "$FIX" | awk '!seen[$0]++ && length($0)>2 { lines[n++]=$0 } END { for (i=n-1;i>=0;i--) print lines[i] }')"
want="$(printf '192.168.0.10:8080\n/tmp/x\n./rel/path\n~/.config/tmux/tmux.conf\nhttps://api.exemplo.com/v2/jobs?x=1\nabc1234def5678\n~/projetos/api')"
if [ "$got" = "$want" ]; then ok "extraction dedupe+order"; else bad "extraction output:"; printf '%s\n' "$got"; fi

# 4. script syntax + uses preset + clipboard path
sh -n "$SCRIPT" && ok "script syntax" || bad "script syntax"
grep -q -- '-o scrollback' "$SCRIPT" && ok "script uses preset" || bad "script preset"
grep -q '| *"\$MM_BIN"' "$SCRIPT" && bad "piped stdin (kills keyboard)" || ok "no piped stdin"
grep -q 'wl-copy' "$SCRIPT" && ok "clipboard path" || bad "clipboard path"
grep -q "trap '' HUP" "$SCRIPT" && grep -q 'scrollback-mm.log' "$SCRIPT" && ok "detached tail+log" || bad "detached tail+log"

# 5. tmux.conf: wrapper bind with origin pane, removed plugins absent
grep -q "scrollback-extract.sh '#{pane_id}'" "$CONF" && ok "bind prefix+y+origin" || bad "bind prefix+y+origin"
(grep -q 'tmux-popup-isolate' "$SCRIPT" || (grep -q '@ai_agent_state_raw' "$SCRIPT" && grep -q 'tmux-backdrop' "$SCRIPT")) && ok "busy backdrop (Issue B)" || bad "busy backdrop (Issue B)"
grep -q 'MM_ORIGIN_PANE' "$SCRIPT" && grep -q 'scrollback-extract-url.txt' "$SCRIPT" && ok "origin+filter files" || bad "origin+filter files"
grep -q 'bind-key "E" run-shell "~/.config/tmux/scrollback-view.sh"' "$CONF" && ok "bind prefix+E view" || bad "bind prefix+E view"
VSCRIPT="$ROOT/tmux/.config/tmux/scrollback-view.sh"
[ -x "$VSCRIPT" ] && sh -n "$VSCRIPT" && ok "view script" || bad "view script"
OSCRIPT="$ROOT/tmux/.config/tmux/scrollback-open.sh"
[ -x "$OSCRIPT" ] && sh -n "$OSCRIPT" && ok "open script syntax" || bad "open script syntax"
[ "$("$OSCRIPT" --check 'src/api.ts:42:13')" = "src/api.ts|42|13|0" ] && ok "open parser file:line:col" || bad "open parser file:line:col"
[ "$("$OSCRIPT" --check '/tmp/x')" = "/tmp/x|1|1|0" ] && ok "open parser plain" || bad "open parser plain"
[ "$("$OSCRIPT" --check 'https://a.b/c')" = "https://a.b/c|1|1|0" ] && ok "open parser url-safe" || bad "open parser url-safe"
PSCRIPT="$ROOT/tmux/.config/tmux/files-picker.sh"
[ -x "$PSCRIPT" ] && sh -n "$PSCRIPT" && ok "files-picker script syntax" || bad "files-picker script syntax"
grep -q 'files-picker.sh' "$CONF" && (grep -q 'tmux-popup-isolate' "$PSCRIPT" || grep -q '@ai_agent_state_raw' "$PSCRIPT") && ok "files-picker bind+backdrop" || bad "files-picker bind+backdrop"
grep -q "bind-key \"y\" run-shell \".*scrollback-extract.sh '#{pane_id}'" "$CONF" && ok "bind prefix+y extract" || bad "bind prefix+y extract"
grep -q "bind-key \"e\" run-shell \".*files-picker.sh '#{pane_id}'" "$CONF" && grep -q "bind-key C-e run-shell \".*files-picker.sh '#{pane_id}'" "$CONF" && ok "bind prefix+e/C-e files-picker" || bad "bind prefix+e/C-e files-picker"
! grep -q 'bind-key "v"' "$CONF" && ! grep -q 'bind-key C-v' "$CONF" && ! grep -q 'bind-key "V"' "$CONF" && ok "prefix+v/C-v/V unbound" || bad "prefix+v/C-v/V still bound"
"$TEST_BIN" --dump-config -o files >/dev/null 2>&1 && ok "wm/mm loads files preset" || bad "wm/mm loads files preset"
grep -q "sainnhe/tmux-fzf\|fcsonline/tmux-thumbs" "$CONF" && bad "orphan plugin lines" || ok "no orphan plugin lines"

exit $fail
