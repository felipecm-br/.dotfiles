#!/usr/bin/env bash
# tests/ai_effort_gauge.test.sh — the effort gauge of the ai-launch menu (Ctrl+H / Ctrl+L, ← / →).
#
# Static: both menu presets carry the `Effort` footer label and the five binds. Live (when the
# installed waymux has `launch --effort`): a private tmux runs `waymux launch --pick --menu` with
# fixed rows (WAYMUX_LAUNCH_FILTER prints them), steps the gauge and checks the footer and the pick.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
P="$ROOT/waymaker/.config/waymaker/presets"
ok() { echo "ok: $*"; }
bad() { echo "FAIL: $*" >&2; exit 1; }

for f in ai-launch.toml ai-switch.toml; do
  menu=launch; [ "$f" = ai-switch.toml ] && menu=switch
  grep -q '{cyan,bold:C-h/l} {darkgray:Effort}' "$P/$f" || bad "$f: footer lacks the Effort label"
  for b in '"CursorChange" = "Transform(waymux '"$menu"' --effort 0 {})"' \
    '"ctrl-h" = "Transform(waymux '"$menu"' --effort -1 {})"' '"left"   = "Transform(waymux '"$menu"' --effort -1 {})"' \
    '"ctrl-l" = "Transform(waymux '"$menu"' --effort 1 {})"' '"right"  = "Transform(waymux '"$menu"' --effort 1 {})"'; do
    grep -qF -- "$b" "$P/$f" || bad "$f: missing bind $b"
  done
done
grep -q '{cyan,bold:C-h/l} {darkgray:Effort}' "$P/ai-launch-pick.toml" || bad "ai-launch-pick.toml: footer lacks the Effort label"
ok "presets carry the Effort label and the five binds"

command -v waymux >/dev/null && waymux launch --help 2>&1 | grep -q -- '--effort' ||
  { echo "skip: installed waymux has no launch --effort"; exit 0; }
command -v wm >/dev/null || { echo "skip: wm not installed"; exit 0; }

# shellcheck source=lib/private_tmux.sh
. "$ROOT/tests/lib/private_tmux.sh"
TMP=$(mktemp -d)
trap 'private_tmux_cleanup; rm -rf "$TMP"' EXIT
cat >"$TMP/rows.json" <<'EOF'
[{"agent":"claude","args":"--model opus","icon":"C","cli":"Claude Code","model":"Opus","tier":"$$$","quota":"5h 1%","level":"green","rec":true},
 {"agent":"agy","args":"--model gemini-4-argon-medium","icon":"A","cli":"Antigravity","model":"Gemini 4 Argon","tier":"$$$$","quota":"90% left","level":"green",
  "efforts":[{"level":"low","args":"--model gemini-4-argon-low"},{"level":"medium","args":"--model gemini-4-argon-medium"},{"level":"high","args":"--model gemini-4-argon-high"}]},
 {"agent":"devin","args":"","icon":"D","cli":"Devin","model":"default","tier":"-","quota":"no quota data","level":"unknown"}]
EOF
printf '#!/bin/sh\ncat %s\n' "$TMP/rows.json" >"$TMP/rows"
chmod +x "$TMP/rows"
# The test's own Claude settings, so the default level does not depend on this machine.
mkdir -p "$TMP/claude"
echo '{"modelSettings":{"claude-opus-5-5":{"effortLevel":"medium"}}}' >"$TMP/claude/settings.json"

ms() { local t; t=$(date +%s%N); while [ $(( ($(date +%s%N) - t) / 1000000 )) -lt "$1" ]; do :; done; }
footer() { tmux capture-pane -p -t "$pane" | grep -o 'Effort .\{0,12\}' | sed 's/ *$//'; }
wait_footer() { # <text>
  for _ in $(seq 150); do [ "$(footer)" = "$1" ] && return 0; ms 20; done
  bad "footer: want '$1', got '$(footer)'"
}

tmux new-window -d -t _test_bootstrap: -n gauge
tmux resize-window -t _test_bootstrap:gauge -x 120 -y 12
pane=$(tmux display-message -p -t _test_bootstrap:gauge '#{pane_id}')
start() {
  tmux respawn-pane -k -t "$pane" "env CLAUDE_CONFIG_DIR='$TMP/claude' WAYMUX_LAUNCH_FILTER='$TMP/rows' \
    WAYMUX_LAUNCH_PRESET='$P/ai-launch.toml' waymux launch --pick --menu >'$TMP/pick'; sleep 30"
}

start
wait_footer "Effort ━●─── medium"
ok "opens on the cursor row's default (Claude Opus: medium)"
tmux send-keys -t "$pane" C-l; wait_footer "Effort ━━●── high"
tmux send-keys -t "$pane" Right Right Right; wait_footer "Effort ━━━━● max"
tmux send-keys -t "$pane" Left; wait_footer "Effort ━━━●─ xhigh"
ok "C-l / → step up and hold at max; ← steps down"
tmux send-keys -t "$pane" Down; wait_footer "Effort ━●─   medium"
ok "an agent with its own 3 levels starts at its args (medium), padded to the 5-level width"
tmux send-keys -t "$pane" Down; wait_footer "Effort ───── none"
ok "an agent without levels shows an empty track"
tmux send-keys -t "$pane" Up C-l Enter
for _ in $(seq 150); do [ -s "$TMP/pick" ] && break; ms 20; done
[ "$(cat "$TMP/pick")" = "agy --model gemini-4-argon-high" ] || bad "agy pick: $(cat "$TMP/pick")"
ok "agy starts with the chosen level's model id"

start
wait_footer "Effort ━●─── medium"
tmux send-keys -t "$pane" C-h Enter
for _ in $(seq 150); do [ -s "$TMP/pick" ] && break; ms 20; done
[ "$(cat "$TMP/pick")" = "claude --model opus --effort low" ] || bad "claude pick: $(cat "$TMP/pick")"
ok "Claude starts with --effort low"

start
wait_footer "Effort ━●─── medium"
tmux send-keys -t "$pane" Enter
for _ in $(seq 150); do [ -s "$TMP/pick" ] && break; ms 20; done
[ "$(cat "$TMP/pick")" = "claude --model opus" ] || bad "untouched pick: $(cat "$TMP/pick")"
ok "an untouched gauge passes no flag"
echo "ai_effort_gauge: all checks passed"
