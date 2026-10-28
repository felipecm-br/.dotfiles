#!/usr/bin/env bash
# tests/ai_prompt.test.sh — contract test for ai-prompt: the $VISUAL entrypoint (plain editor for
# non-agent callers), take / put / stash through the agent's editor key, and ai-switch keeping a draft.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Private tmux server + sandboxed HOME: never the live session or ~/.local/state.
. "$ROOT/tests/lib/private_tmux.sh"
ok() { echo "ok: $*"; }
bad() { echo "FAIL: $*" >&2; exit 1; }

CONF="$ROOT/tmux/.config/tmux/tmux.conf"
export XDG_RUNTIME_DIR="$HOME/run"
RUN="$XDG_RUNTIME_DIR/ai-prompt"

# 1. Script parses, bindings exist, $VISUAL is exported
bash -n "$(command -v ai-prompt)" && ok "script parses" || bad "syntax"
grep -q "^bind-key v run-shell \"~/.local/bin/ai-prompt -t '#{pane_id}' edit" "$CONF" && ok "Prefix + v bound" || bad "v binding"
grep -q "^bind-key V run-shell \"~/.local/bin/ai-prompt -t '#{pane_id}' stash" "$CONF" && ok "Prefix + V bound" || bad "V binding"
! grep -qE "^unbind(-key)? +'?[vV]'?\$" "$CONF" && ok "no later unbind drops v / V" || bad "v / V unbound later in tmux.conf"
grep -q 'export VISUAL="$HOME/.local/bin/ai-prompt"' "$ROOT/zsh/.zshenv" && ok "VISUAL exported" || bad "zshenv"

# 2. A caller that is not an agent on a terminal (git, crontab…) gets $EDITOR untouched
f="$HOME/draft.txt"
printf 'commit message' >"$f"
[ "$(EDITOR=cat ai-prompt "$f" </dev/null)" = "commit message" ] && ok "non-agent caller -> \$EDITOR" || bad "fallback"
[ "$(AI_PROMPT_EDITOR=cat EDITOR=ai-prompt ai-prompt "$f" </dev/null)" = "commit message" ] &&
  ok "AI_PROMPT_EDITOR wins, no recursion" || bad "AI_PROMPT_EDITOR"

# 3. Fake agent: a `devin` (script name = process name) with a Codex-style composer. Keys build the
#    draft, Ctrl+G hands it to $VISUAL and reads it back, Enter submits to $HOME/agent.in
fake="$HOME/.local/bin/devin"
cat >"$fake" <<'EOF'
#!/bin/bash
f=$(mktemp)
draw() { printf '\r\e[K› %s' "$(tr '\n' '|' <"$f")"; }
draw
while IFS= read -rsn1 c; do
  case $c in
    $'\a') "$VISUAL" "$f" ;;
    '') cat "$f" >>"$HOME/agent.in"; echo >>"$HOME/agent.in"; : >"$f" ;;
    *) printf '%s' "$c" >>"$f" ;;
  esac
  draw
done
EOF
chmod +x "$fake"
start() { # <session> [VISUAL]: agent pane, prints its pane id
  tmux new-session -d -s "$1" -x 120 -y 20 \
    "HOME='$HOME' XDG_RUNTIME_DIR='$XDG_RUNTIME_DIR' VISUAL='${2:-}' '$fake'"
  sleep 0.4
  tmux display-message -p -t "$1:" '#{pane_id}'
}
line() { tmux capture-pane -p -t "$1" | grep '›' | tail -1; }

P=$(start agent "$HOME/.local/bin/ai-prompt")
tmux send-keys -t "$P" -l "half draft ✓"
sleep 0.3
ai-prompt -t "$P" --ready && ok "agent started with VISUAL=ai-prompt is ready" || bad "--ready"
ai-prompt -t "$P" take && [ "$(line "$P")" = "›" ] && [ "$(cat "$RUN/${P#%}.stash")" = "half draft ✓" ] &&
  ok "take empties the prompt, stash holds the exact draft" || bad "take: '$(line "$P")'"
ai-prompt -t "$P" put && [ "$(line "$P")" = "› half draft ✓" ] && [ ! -e "$RUN/${P#%}.stash" ] &&
  ok "put restores it" || bad "put: '$(line "$P")'"

# 4. Stash toggle around a /command: the command runs alone, the draft comes back
rm -f "$HOME/agent.in"
ai-prompt -t "$P" stash 2>/dev/null
tmux send-keys -t "$P" -l "/compact"
tmux send-keys -t "$P" Enter
sleep 0.2
ai-prompt -t "$P" stash 2>/dev/null
[ "$(cat "$HOME/agent.in")" = "/compact" ] && [ "$(line "$P")" = "› half draft ✓" ] &&
  ok "stash, /compact alone, stash brings the draft back" || bad "toggle: sent=$(cat "$HOME/agent.in") line=$(line "$P")"

# 5. Text typed and not sent while stashed stays, after the restored draft
ai-prompt -t "$P" take
tmux send-keys -t "$P" -l "more"
sleep 0.2
ai-prompt -t "$P" put
[ "$(line "$P")" = "› half draft ✓||more" ] && ok "put keeps text typed since" || bad "merge: '$(line "$P")'"

# 6. ai-switch with a draft: taken out, /model sent alone, put back
rm -f "$HOME/agent.in"
Q=$(start switch "$HOME/.local/bin/ai-prompt")
tmux send-keys -t "$Q" -l "keep me"
sleep 0.3
ai-switch -t "$Q" opus 2>/dev/null
sleep 0.3
[ "$(cat "$HOME/agent.in")" = "/model opus" ] && [ "$(line "$Q")" = "› keep me" ] &&
  ok "ai-switch keeps the draft around /model" || bad "switch: sent=$(cat "$HOME/agent.in" 2>/dev/null) line=$(line "$Q")"

# 7. An agent started without VISUAL=ai-prompt: nothing is moved, take says why
R=$(start old "")
tmux send-keys -t "$R" -l "draft"
sleep 0.3
set +e; ai-prompt -t "$R" take 2>/dev/null; rc=$?; set -e
[ "$rc" -eq 2 ] && [ "$(line "$R")" = "› draft" ] && ok "agent without ai-prompt: take refuses (rc 2)" || bad "old agent rc=$rc"
set +e; ai-switch -t "$R" opus 2>/dev/null; rc=$?; set -e
[ "$rc" -eq 3 ] && ok "ai-switch still stops on its draft" || bad "old agent switch rc=$rc"

# 8. A pane without an agent
tmux new-session -d -s plain -x 120 -y 20 "sleep 30"
set +e; ai-prompt -t "$(tmux display-message -p -t plain: '#{pane_id}')" stash 2>/dev/null; rc=$?; set -e
[ "$rc" -eq 1 ] && ok "no agent -> exit 1" || bad "plain pane rc=$rc"
