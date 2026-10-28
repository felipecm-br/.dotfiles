#!/usr/bin/env bash
# tests/ai_switch.test.sh — contract test for ai-switch: per-agent model/effort rows, direct choices,
# pane agent detection, the draft guard, and the slash command typed into the agent pane.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Private tmux server + sandboxed HOME: never the live session or ~/.local/state.
. "$ROOT/tests/lib/private_tmux.sh"
ok() { echo "ok: $*"; }
bad() { echo "FAIL: $*" >&2; exit 1; }

POPUP="$ROOT/tmux/.config/tmux/ai-switch-popup.sh"
CONF="$ROOT/tmux/.config/tmux/tmux.conf"

# 1. Scripts parse, binding and preset exist
bash -n "$(command -v ai-switch)" && bash -n "$POPUP" && ok "scripts parse" || bad "syntax"
grep -q "^bind-key A run-shell \"~/.config/tmux/ai-switch-popup.sh '#{pane_id}'" "$CONF" && ok "Prefix + A bound" || bad "binding"
[ -f "$HOME/.config/waymaker/presets/ai-switch.toml" ] && ok "preset present" || bad "preset missing"

# 2. Rows per agent (AI_SWITCH_AGENT skips pane detection)
rows() { AI_SWITCH_AGENT=$1 ai-switch --peek | cut -f2 | tr '\n' ' '; }
[[ "$(rows claude)" == "/model fable /model opus /model sonnet /model haiku /effort low "*"/effort auto " ]] &&
  ok "claude: 4 models + effort levels" || bad "claude rows: $(rows claude)"
[[ "$(rows agy)" == "/model gemini-4-argon-medium "* ]] && ok "agy: model families" || bad "agy rows: $(rows agy)"
[ "$(rows devin)" = "/model opus /model sonnet /model codex /model fusion " ] && ok "devin: /model <name>" || bad "devin rows"
[ "$(rows codex)" = "/model " ] && ok "codex: its own picker" || bad "codex rows: $(rows codex)"

# 3. Direct choices map to the agent's slash command; unknown ones fail without typing
[ "$(AI_SWITCH_AGENT=claude ai-switch --peek high)" = $'claude\t/effort high' ] && ok "direct effort" || bad "direct effort"
[ "$(AI_SWITCH_AGENT=claude ai-switch --peek sonnet)" = $'claude\t/model sonnet' ] && ok "direct model" || bad "direct model"
set +e; AI_SWITCH_AGENT=claude ai-switch --peek nope 2>/dev/null; rc=$?; set -e
[ "$rc" -eq 2 ] && ok "unknown choice exits 2" || bad "unknown choice rc=$rc"

# 4. Live pane: a fake `claude` (script name = process name) draws a prompt and records its input
fake="$HOME/.local/bin/claude"
mkdir -p "$(dirname "$fake")"
# #!/bin/bash, not env: the kernel then names the process after the script, as with the real binary
cat >"$fake" <<'EOF'
#!/bin/bash
# Status line with the model, then a prompt; every submitted line lands in $HOME/claude.in
printf '  Opus 5.5 · ctx 1%%\n%s\n' "${FAKE_PROMPT:-❯ }"
while IFS= read -r line; do printf '%s\n' "$line" >>"$HOME/claude.in"; done
EOF
chmod +x "$fake"

tmux new-session -d -s agent -x 120 -y 20 "HOME='$HOME' '$fake'"
P=$(tmux display-message -p -t agent: '#{pane_id}')
sleep 0.5
[ "$(ai-switch -t "$P" --agent)" = $'claude\topus' ] && ok "detects claude and its current model" || bad "agent: $(ai-switch -t "$P" --agent)"
ai-switch -t "$P" haiku 2>/dev/null
sleep 0.5
[ "$(cat "$HOME/claude.in" 2>/dev/null)" = "/model haiku" ] && ok "types /model haiku and submits" || bad "sent: $(cat "$HOME/claude.in" 2>/dev/null)"

# 5. Draft guard: typed text after the marker blocks the switch; a dim placeholder does not
tmux new-session -d -s draft -x 120 -y 20 "HOME='$HOME' FAKE_PROMPT='❯ half typed' '$fake'"
D=$(tmux display-message -p -t draft: '#{pane_id}')
sleep 0.5
rm -f "$HOME/claude.in"
set +e; ai-switch -t "$D" sonnet 2>/dev/null; rc=$?; set -e
sleep 0.3
[ "$rc" -eq 3 ] && [ ! -s "$HOME/claude.in" ] && ok "draft blocks the switch" || bad "draft rc=$rc sent=$(cat "$HOME/claude.in" 2>/dev/null)"
tmux new-session -d -s placeholder -x 120 -y 20 "HOME='$HOME' FAKE_PROMPT=\$'❯ \e[2mTry something\e[0m' '$fake'"
H=$(tmux display-message -p -t placeholder: '#{pane_id}')
sleep 0.5
ai-switch -t "$H" high 2>/dev/null
sleep 0.5
[ "$(cat "$HOME/claude.in" 2>/dev/null)" = "/effort high" ] && ok "dim placeholder is not a draft" || bad "placeholder sent: $(cat "$HOME/claude.in" 2>/dev/null)"

# 6. A pane without an agent: exit 1, nothing typed
tmux new-session -d -s plain -x 120 -y 20 "sleep 30"
set +e; ai-switch -t "$(tmux display-message -p -t plain: '#{pane_id}')" --agent; rc=$?; set -e
[ "$rc" -eq 1 ] && ok "no agent -> exit 1" || bad "plain pane rc=$rc"
