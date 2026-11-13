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

# 9. Persistent stash stack: every take is recorded (0600), the toggle pops it, presets stay pinned
STORE="$HOME/.local/state/waymux/prompt-stash.jsonl"
rm -f "$STORE"
tmux send-keys -t "$P" Enter; sleep 0.2         # submit what is there: empty composer
tmux send-keys -t "$P" -l "first stash"; sleep 0.2
ai-prompt -t "$P" stash 2>/dev/null
[ "$(jq -s length "$STORE")" = 1 ] && [ "$(jq -r -s '.[0].text' "$STORE")" = "first stash" ] &&
  [ "$(stat -c %a "$STORE")" = 600 ] && ok "take is recorded on the stack, 0600" || bad "stack: $(cat "$STORE")"
id=$(jq -r -s '.[0].id' "$STORE")
ai-prompt -t "$P" stash 2>/dev/null
[ "$(line "$P")" = "› first stash" ] && [ "$(jq -s length "$STORE")" = 0 ] &&
  ok "the toggle restores and pops the entry" || bad "pop: $(cat "$STORE") line=$(line "$P")"

# 10. A stash survives the runtime dir (reboot) and goes into another agent's pane
ai-prompt -t "$P" take
id=$(jq -r -s '.[-1].id' "$STORE")
rm -rf "$RUN"
O=$(start other "$HOME/.local/bin/ai-prompt")
ai-prompt -t "$O" send "$id"
[ "$(line "$O")" = "› first stash" ] && [ "$(jq -s length "$STORE")" = 0 ] &&
  ok "send puts a persisted stash into another pane and pops it" || bad "send: line=$(line "$O")"

# 11. Presets 0-9: save, list first, put without popping; a new pin takes the slot
printf 'run the tests\nthen summarize' | ai-prompt save 3
ai-prompt save 3 "replaced preset" 2>/dev/null
ai-prompt save 1 "review the diff" 2>/dev/null
[ "$(ai-prompt list | cut -f1 | head -2 | tr '\n' ' ')" = "[1] [3] " ] && ok "presets list first, by slot" || bad "list: $(ai-prompt list)"
[ "$(jq -r -s 'map(select(.pinned_slot == 3)) | length' "$STORE")" = 1 ] && ok "one entry per slot" || bad "slot dup"
tmux send-keys -t "$O" Enter; sleep 0.2
ai-prompt -t "$O" preset 1
[ "$(line "$O")" = "› review the diff" ] && [ "$(jq -r -s 'map(select(.pinned_slot == 1)) | length' "$STORE")" = 1 ] &&
  ok "preset puts the text and stays pinned" || bad "preset: $(line "$O")"
set +e; ai-prompt -t "$O" preset 7 2>/dev/null; rc=$?; set -e
[ "$rc" -eq 1 ] && ok "empty slot -> exit 1" || bad "empty slot rc=$rc"

# 12. Invisible characters never reach the stack; the cap keeps 50 unpinned entries
printf 'a​b‮c' | ai-prompt save 5
[ "$(jq -r -s 'map(select(.pinned_slot == 5)) | .[0].text' "$STORE")" = "abc" ] && ok "invisible chars stripped" || bad "strip"
for i in $(seq 55); do printf 'h%s' "$i" >"$HOME/h"; AI_PROMPT_STASH_CAP=50 ai-prompt save 9 "x" 2>/dev/null; done
before=$(jq -s 'map(select(.pinned_slot == null)) | length' "$STORE")
[ "$before" -le 50 ] && ok "unpinned history capped ($before)" || bad "cap $before"

# 13. Picker rows: header per mode, stash rows carry the id in column 7
"$HOME/.config/tmux/prompt-stash-picker.sh" --rows stash | head -1 | grep -q 'STASH' && ok "picker stash header" || bad "picker header"
[ "$("$HOME/.config/tmux/prompt-stash-picker.sh" --rows stash | sed -n 2p | awk -F'\t' '{print NF}')" = 7 ] &&
  ok "picker rows have 7 columns" || bad "picker cols"

# 14. OpenCode: <leader>e = Ctrl+X E hands the draft to $VISUAL
oc="$HOME/.local/bin/opencode"
sed 's/\$'"'"'\\a'"'"') "\$VISUAL" "\$f" ;;/$'"'"'\\x18'"'"') read -rsn1 c2; [ "$c2" = e ] \&\& "$VISUAL" "$f" ;;/' "$fake" >"$oc"
chmod +x "$oc"
tmux new-session -d -s oc -x 120 -y 20 "HOME='$HOME' XDG_RUNTIME_DIR='$XDG_RUNTIME_DIR' VISUAL='$HOME/.local/bin/ai-prompt' '$oc'"
sleep 0.4
C=$(tmux display-message -p -t oc: '#{pane_id}')
tmux send-keys -t "$C" -l "oc draft"; sleep 0.2
ai-prompt -t "$C" take && [ "$(line "$C")" = "›" ] && ai-prompt -t "$C" put && [ "$(line "$C")" = "› oc draft" ] &&
  ok "opencode: take / put through Ctrl+X E" || bad "opencode: line=$(line "$C")"

# 15. stash --after-cmd: once waymux sees the pane busy then idle, the draft comes back by itself
mkdir -p "$HOME/fakebin"
printf '#!/bin/sh\n[ "$1" = wait ] && exit 0\nexit 1\n' >"$HOME/fakebin/waymux"
chmod +x "$HOME/fakebin/waymux"
tmux send-keys -t "$O" Enter; sleep 0.2
tmux send-keys -t "$O" -l "auto back"; sleep 0.2
PATH="$HOME/fakebin:$PATH" ai-prompt -t "$O" stash --after-cmd 2>/dev/null
for _ in $(seq 30); do [ "$(line "$O")" = "› auto back" ] && break; sleep 0.1; done
[ "$(line "$O")" = "› auto back" ] && [ ! -e "$RUN/${O#%}.stash" ] && ok "--after-cmd restores after busy -> idle" ||
  bad "autorestore: line=$(line "$O")"

# 16. Stash picker end to end: Enter on the first stash row puts it into the origin pane
if command -v wm >/dev/null 2>&1; then
  : >"$STORE"
  printf 'picked from the list' >"$HOME/pick"
  tmux send-keys -t "$O" Enter; sleep 0.2
  tmux send-keys -t "$O" -l "picked from the list"; sleep 0.2
  ai-prompt -t "$O" take
  rm -rf "$RUN"   # a restart: only the stack has it
  tmux new-window -d -t other: -n picker "HOME='$HOME' XDG_RUNTIME_DIR='$XDG_RUNTIME_DIR' TMUX_POPUP=1 '$HOME/.config/tmux/prompt-stash-picker.sh' '$O'"
  sleep 1.2
  tmux send-keys -t other:picker Enter
  for _ in $(seq 30); do [ "$(line "$O")" = "› picked from the list" ] && [ "$(jq -s length "$STORE")" = 0 ] && break; sleep 0.1; done
  [ "$(line "$O")" = "› picked from the list" ] && [ "$(jq -s length "$STORE")" = 0 ] &&
    ok "picker: Enter puts the stash into the pane and pops it" || bad "picker enter: line=$(line "$O") pane=$(tmux capture-pane -p -t "$O" | tail -3) store=$(cat "$STORE") picker=$(tmux capture-pane -p -t other:picker 2>&1 | head -5)"
else
  echo "skip: wm not installed (picker end to end)"
fi
