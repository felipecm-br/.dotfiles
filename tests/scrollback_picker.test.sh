#!/usr/bin/env sh
# scrollback_picker.test.sh — focused test for the scrollback-picker flow.
# Run: sh .dotfiles/main/tests/scrollback_picker.test.sh (from $HOME)
# Checks: preset parses + key binds, extraction pipeline on fixture, tmux binds.
set -u

ROOT="${ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
FIX="$ROOT/tests/fixtures/scrollback_sample.txt"
PRESET="$ROOT/waymaker/.config/waymaker/presets/scrollback-picker.toml"
[[ -f "$PRESET" ]] || PRESET="$ROOT/waymaker/.config/waymaker/presets/scrollback.toml"
SCRIPT="$ROOT/tmux/.config/tmux/scrollback-picker.sh"
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
assert start_cmd == "cat /tmp/scrollback-picker-all.txt", "items via command (stdin stays on tty)"
assert "send-keys" in b["ctrl-v"], "insert action"
assert p["preview"]["show"] is True, "preview on"
assert "scrollback-picker-src" in p["preview"]["layout"][0]["command"], "preview context"
assert "scrollback-open.sh" in b["ctrl-e"], "open in filter"
assert "scrollback-open.sh" in nb["e"], "open in nav"
assert "scrollback-chrome.sh" in b["ctrl-b"], "chrome in filter"
assert "scrollback-chrome.sh" in nb["b"], "chrome in nav (b)"
assert "scrollback-chrome.sh" in nb["w"], "chrome in nav (w)"
assert p["exit"]["abort_empty"] is True, "abort_empty"
print("ok: preset parses with nav/filter/accept contract")
EOF
[ $? -eq 0 ] || bad "preset toml"

# 2. preset loads in the real wm/mm binary (catches unknown keys)
TEST_BIN="$(command -v wm 2>/dev/null || command -v mm 2>/dev/null || echo wm)"
if "$TEST_BIN" --dump-config -o scrollback-picker >/dev/null 2>&1 || "$TEST_BIN" --dump-config -o "$PRESET" >/dev/null 2>&1; then ok "wm/mm loads preset"; else bad "wm/mm rejects preset"; fi

# 3. extraction pipeline: bottom-up dedupe + true recent-first on fixture
got="$(python3 -c "
import re

with open('$FIX') as f:
    lines = [l.rstrip('\n') for l in f if l.strip()]
lines.reverse()

re_url = re.compile(r'https?://[^\s\"\'<>]+|git@[^\s\"\'<>]+|//[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}[^\s\"\'<>]*|www\.[a-zA-Z0-9.-]+[^\s\"\'<>]*')
re_path = re.compile(r'(?:~?/[A-Za-z0-9._~:/?#@!$&()*+,;=%-]+|\.\.?/[A-Za-z0-9._~:/?#@!$&()*+,;=%-]+)')
re_sha = re.compile(r'\b[0-9a-f]{7,40}\b|\b[0-9]{1,3}(?:\.[0-9]{1,3}){3}(?::[0-9]+)?\b')

def clean_tok(t):
    return re.sub(r'^[<\"\'(\[{\]]+|[][>\"\'})\s.,;:)]+$', '', t)

seen = set()
toks = []
for line in lines:
    for u in re_url.findall(line):
        cu = clean_tok(u)
        if len(cu) > 2 and cu not in seen:
            seen.add(cu)
            toks.append(cu)
    clean_p = re_url.sub('', line)
    for p in re_path.findall(clean_p):
        cp = clean_tok(p)
        if len(cp) > 2 and cp not in seen:
            seen.add(cp)
            toks.append(cp)
    for s in re_sha.findall(line):
        cs = clean_tok(s)
        if len(cs) >= 7 and cs not in seen:
            seen.add(cs)
            toks.append(cs)

for t in toks:
    print(t)
")"
want="$(printf 'https://api.exemplo.com/v2/jobs?x=1\n192.168.0.10:8080\n~/.config/tmux/tmux.conf\n./rel/path\n/tmp/x\nabc1234def5678\n~/projetos/api')"
if [ "$got" = "$want" ]; then ok "extraction bottom-up dedupe+order"; else bad "extraction output:"; printf '%s\n' "$got"; fi

# 3b. tool call command extraction (Claude/Gemini/Antigravity ● Bash(...) (ctrl+o to expand))
MOCK_BASH_LINE='● Bash(git log -p -n 3 tmux/.config/tmux/scrollback-picker.sh) (ctrl+o to expand)'
cmd_got="$(printf '%s\n' "$MOCK_BASH_LINE" | sed -nE '/^[[:space:]]*●[[:space:]]*Bash\(/ { s/[[:space:]]*\(ctrl\+o.*$//; s/^[[:space:]]*●[[:space:]]*Bash\(//; s/\)[[:space:]]*$//; p; }' | sed -E 's/[[:space:]]*\)[[:space:]]*\(ctrl\+o.*$//; s/[[:space:]]*\(ctrl\+o.*$//')"
[ "$cmd_got" = "git log -p -n 3 tmux/.config/tmux/scrollback-picker.sh" ] && ok "tool call command extraction" || bad "tool call command extraction"

# 4. script syntax + uses preset + clipboard path
sh -n "$SCRIPT" && ok "script syntax" || bad "script syntax"
grep -qE -- '-o scrollback-picker' "$SCRIPT" && ok "script uses preset" || bad "script preset"
grep -q '| *"\$MM_BIN"' "$SCRIPT" && bad "piped stdin (kills keyboard)" || ok "no piped stdin"
grep -q 'wl-copy' "$SCRIPT" && ok "clipboard path" || bad "clipboard path"
grep -q "trap '' HUP" "$SCRIPT" && grep -q 'scrollback-picker-mm.log' "$SCRIPT" && ok "detached tail+log" || bad "detached tail+log"

# 5. tmux.conf: wrapper bind with origin pane
grep -qE "scrollback-picker\.sh '#{pane_id}'" "$CONF" && ok "bind prefix+y+origin" || bad "bind prefix+y+origin"
grep -q 'tmux-popup-isolate' "$SCRIPT" && ok "popup isolator" || bad "popup isolator"
grep -q 'MM_ORIGIN_PANE' "$SCRIPT" && grep -q 'scrollback-picker-url.txt' "$SCRIPT" && ok "origin+filter files" || bad "origin+filter files"
grep -q 'bind-key "E" run-shell "~/.config/tmux/scrollback-view.sh"' "$CONF" && ok "bind prefix+E view" || bad "bind prefix+E view"
VSCRIPT="$ROOT/tmux/.config/tmux/scrollback-view.sh"
[ -x "$VSCRIPT" ] && sh -n "$VSCRIPT" && ok "view script" || bad "view script"
OSCRIPT="$ROOT/tmux/.config/tmux/scrollback-open.sh"
[ -x "$OSCRIPT" ] && sh -n "$OSCRIPT" && ok "open script syntax" || bad "open script syntax"
[ "$("$OSCRIPT" --check 'src/api.ts:42:13')" = "src/api.ts|42|13|0" ] && ok "open parser file:line:col" || bad "open parser file:line:col"
[ "$("$OSCRIPT" --check '/tmp/x')" = "/tmp/x|1|1|0" ] && ok "open parser plain" || bad "open parser plain"
[ "$("$OSCRIPT" --check 'https://a.b/c')" = "https://a.b/c|1|1|0" ] && ok "open parser url-safe" || bad "open parser url-safe"
CSCRIPT="$ROOT/tmux/.config/tmux/scrollback-chrome.sh"
[ -x "$CSCRIPT" ] && sh -n "$CSCRIPT" && ok "chrome script syntax" || bad "chrome script syntax"
[ "$("$CSCRIPT" --check 'https://github.com/fcmiranda/waymaker).')" = "https://github.com/fcmiranda/waymaker" ] && ok "chrome parser punctuation strip" || bad "chrome parser punctuation strip"
[ "$("$CSCRIPT" --check 'git@github.com:foo/bar.git')" = "https://github.com/foo/bar" ] && ok "chrome parser git ssh url" || bad "chrome parser git ssh url"
[ "$("$CSCRIPT" --check 'localhost:3000/api')" = "http://localhost:3000/api" ] && ok "chrome parser localhost url" || bad "chrome parser localhost url"
[ "$("$CSCRIPT" --check '//akitaonrails.com/2026/03/01/ai-jail-sandbox-para-agentes-de-ia-de-shell-script-a-ferramenta-real/,')" = "https://akitaonrails.com/2026/03/01/ai-jail-sandbox-para-agentes-de-ia-de-shell-script-a-ferramenta-real/" ] && ok "chrome parser // protocol-relative url with trailing comma" || bad "chrome parser // protocol-relative url with trailing comma"
[ "$("$CSCRIPT" --check 'https://akitaonrails.com/2026/03/01/ai-jail-sandbox-para-agentes-de-ia-de-shell-script-a-ferramenta-real/,')" = "https://akitaonrails.com/2026/03/01/ai-jail-sandbox-para-agentes-de-ia-de-shell-script-a-ferramenta-real/" ] && ok "chrome parser https url with trailing comma" || bad "chrome parser https url with trailing comma"
PSCRIPT="$ROOT/tmux/.config/tmux/workspace-picker.sh"
[[ -f "$PSCRIPT" ]] || PSCRIPT="$ROOT/tmux/.config/tmux/files-picker.sh"
[ -x "$PSCRIPT" ] && sh -n "$PSCRIPT" && ok "workspace-picker script syntax" || bad "workspace-picker script syntax"
grep -qE 'workspace-picker\.sh' "$CONF" && grep -q 'tmux-popup-isolate' "$PSCRIPT" && ok "workspace-picker bind+backdrop" || bad "workspace-picker bind+backdrop"
grep -qE "bind-key \"y\" run-shell \".*scrollback-picker\.sh '#{pane_id}'" "$CONF" && ok "bind prefix+y extract" || bad "bind prefix+y extract"
grep -qE "bind-key \"e\" run-shell \".*workspace-picker\.sh '#{pane_id}'" "$CONF" && grep -qE "bind-key C-e run-shell \".*workspace-picker\.sh '#{pane_id}'" "$CONF" && ok "bind prefix+e/C-e workspace-picker" || bad "bind prefix+e/C-e workspace-picker"
("$TEST_BIN" --dump-config -o workspace >/dev/null 2>&1 || "$TEST_BIN" --dump-config -o "$ROOT/waymaker/.config/waymaker/presets/workspace.toml" >/dev/null 2>&1) && ok "wm/mm loads workspace preset" || bad "wm/mm loads workspace preset"
grep -q "sainnhe/tmux-fzf\|fcsonline/tmux-thumbs" "$CONF" && bad "orphan plugin lines" || ok "no orphan plugin lines"

exit $fail
