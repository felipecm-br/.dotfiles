#!/usr/bin/env bash
# tests/cockpit_restore.test.sh — contract test for `cockpit snapshot` / `cockpit restore`: every
# pane of a window comes back in order, live agents resume their session the way ai-launch started
# them, stale or unsafe tags are dropped, and cockpit-shutdown-save snapshots on shutdown only.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Private tmux server + sandboxed HOME: never the live session or ~/.local/state.
. "$ROOT/tests/lib/private_tmux.sh"
ok() { echo "ok: $*"; }
bad() { echo "FAIL: $*" >&2; exit 1; }

SNAP="$ROOT/tmux/.config/tmux/cockpit-snapshot.py"
WORK="$HOME/work"; TOPO="$HOME/topo.json"; LOG="$HOME/launch.log"
mkdir -p "$WORK/proj" "$HOME/stub"
# Stubs: `claude` is a live agent process; `ai-launch` and `claude` log how restore starts them.
# (no exec: the process must stay named claude)
printf '#!/bin/sh\n[ "$#" -gt 0 ] && echo "claude $*" >>"%s"\nsleep 300\n' "$LOG" >"$HOME/stub/claude"
printf '#!/bin/sh\necho "ai-launch $*" >>"%s"\nexec sleep 300\n' "$LOG" >"$HOME/stub/ai-launch"
chmod +x "$HOME/stub/"*
export PATH="$HOME/stub:$PATH" SHELL=/bin/sh
tmux set -g default-shell /bin/sh

# A three-pane window (horizontal, then vertical) and two agent windows.
tmux new-session -d -s work -n edit -c "$WORK/proj" -x 200 -y 50
tmux split-window -h -t work:0 -c "$WORK/proj"
tmux split-window -v -t work:0.1 -c "$WORK"
tmux new-window -d -t work:1 -n jailed -c "$WORK/proj"
tmux new-window -d -t work:2 -n host -c "$WORK/proj"
J=$(tmux display -p -t work:1 '#{pane_id}'); H=$(tmux display -p -t work:2 '#{pane_id}')
tmux send-keys -t "$J" claude Enter; tmux send-keys -t "$H" claude Enter
tmux set -p -t "$J" @ai_session claude:0d5f3c1e-8a2b-4c6d-9e0f-1a2b3c4d5e6f
tmux set -p -t "$J" @ai_launch 'jail-claude-ask --model opus'
tmux set -p -t "$H" @ai_session claude:11111111-2222-3333
tmux set -p -t "$H" @ai_launch 'devin'                               # another harness: not used
tmux set -p -t work:0.1 @ai_session claude:44444444-dead            # no agent running any more
tmux set -p -t work:0.2 @ai_session 'claude:bad;id-touch-x'         # unsafe id
for _ in 1 2 3 4 5 6 7 8 9 10; do
  [ "$(tmux display -p -t "$H" '#{pane_current_command}')" = claude ] && break; sleep 0.2
done

# The last pane tmux lists, with every tag empty, must not lose its trailing fields.
tmux new-session -d -s zz-last -c "$WORK"
python3 "$SNAP" snapshot --file "$TOPO" --quiet
jq -e '.sessions[] | select(.name == "zz-last")' "$TOPO" >/dev/null && ok "untagged last pane captured" || bad "last pane dropped"
resumes=$(jq -c '[.sessions[] | select(.name == "work") | .windows[] | .panes[] | .resume]' "$TOPO")
[ "$resumes" = '[null,null,null,{"agent":"claude","id":"0d5f3c1e-8a2b-4c6d-9e0f-1a2b3c4d5e6f","launch":["jail-claude-ask","--model","opus"]},{"agent":"claude","id":"11111111-2222-3333","launch":[]}]' ] \
  && ok "live agents saved with their session; dead and unsafe tags dropped" || bad "resumes: $resumes"

# Reboot: the session is gone; restore rebuilds it.
tmux kill-session -t work
python3 "$SNAP" restore --file "$TOPO" >/dev/null
for _ in 1 2 3 4 5 6 7 8 9 10; do [ -f "$LOG" ] && [ "$(wc -l <"$LOG")" -ge 2 ] && break; sleep 0.2; done
panes=$(tmux list-panes -t work:0 -F '#{b:pane_current_path}' | tr '\n' ' ')
[ "$panes" = "proj proj work " ] && ok "every pane back, in order" || bad "panes: $panes"
[ "$(tmux list-panes -t work:0 -F '#{pane_width}' | head -1)" = 100 ] && ok "layout applied at the saved size" || bad "layout"
grep -qx 'ai-launch jail-claude-ask --model opus --resume 0d5f3c1e-8a2b-4c6d-9e0f-1a2b3c4d5e6f' "$LOG" \
  && ok "jailed agent resumed through ai-launch" || bad "jailed resume: $(cat "$LOG")"
grep -qx 'claude --resume 11111111-2222-3333' "$LOG" \
  && ok "another harness's launch tag ignored: plain claude --resume" || bad "host resume: $(cat "$LOG")"

# A window missing from a live session is rebuilt the same way (the last one: renumber-windows).
: >"$LOG"; tmux kill-window -t work:2
python3 "$SNAP" restore --file "$TOPO" >/dev/null
for _ in 1 2 3 4 5 6 7 8 9 10; do [ -s "$LOG" ] && break; sleep 0.2; done
[ "$(cat "$LOG")" = 'claude --resume 11111111-2222-3333' ] \
  && ok "missing window rebuilt and resumed" || bad "missing window: $(cat "$LOG")"

# A tampered snapshot never reaches the shell.
jq '(.sessions[].windows[].panes[] | select(.resume != null) | .resume.id) = "x; touch pwned"' "$TOPO" >"$TOPO.bad"
tmux kill-session -t work; : >"$LOG"
python3 "$SNAP" restore --file "$TOPO.bad" >/dev/null; sleep 1
[ ! -s "$LOG" ] && ok "tampered session id not typed" || bad "tampered: $(cat "$LOG")"

# cockpit-shutdown-save: snapshots on PrepareForShutdown(true), not on sleep, then exits.
printf '#!/bin/sh\necho "x: org.freedesktop.login1.Manager.PrepareForSleep (true,)"\necho "x: org.freedesktop.login1.Manager.PrepareForShutdown (true,)"\n' >"$HOME/stub/gdbus"
# systemd-inhibit stub: drop its --options, run the command (no real lock in tests)
printf '#!/bin/sh\nwhile [ "${1#--}" != "$1" ]; do shift; done\nexec "$@"\n' >"$HOME/stub/systemd-inhibit"
printf '#!/bin/sh\necho "cockpit $*" >>"%s/cockpit.log"\n' "$HOME" >"$HOME/.local/bin/cockpit-stub"
chmod +x "$HOME/stub/gdbus" "$HOME/stub/systemd-inhibit" "$HOME/.local/bin/cockpit-stub"
rm -f "$HOME/.local/bin/cockpit"; mv "$HOME/.local/bin/cockpit-stub" "$HOME/.local/bin/cockpit"
PATH="$HOME/stub:$PATH" timeout 10 "$ROOT/utils/.local/bin/cockpit-shutdown-save" \
  && ok "watcher exits after the shutdown snapshot" || bad "watcher exit"
[ "$(cat "$HOME/cockpit.log")" = "cockpit snapshot --quiet" ] && ok "one snapshot, on shutdown only" || bad "watcher: $(cat "$HOME/cockpit.log")"
