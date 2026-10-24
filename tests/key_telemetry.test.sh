#!/usr/bin/env bash
# tests/key_telemetry.test.sh — key-telemetry.py wraps tmux bindings once, keeps them working,
# logs each press, and turns logged habits into faster-path suggestions.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# Private tmux server + sandboxed HOME: never the live session or ~/.local/state.
. "$DOTFILES_DIR/tests/lib/private_tmux.sh"
KT="$DOTFILES_DIR/tmux/.config/tmux/key-telemetry.py"

echo "=== Running Key Telemetry Tests ==="

export XDG_STATE_HOME="$HOME/.local/state"
CALLS="$HOME/keylog.calls"
# Stub waymux: record the keylog arguments instead of the real binary.
cat > "$HOME/.local/bin/waymux" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$CALLS"
EOF
chmod +x "$HOME/.local/bin/waymux"

tmux bind-key X set -g @pressed yes
tmux bind-key -n F9 set -g @root_pressed yes

notes_before=$(tmux list-keys -N | wc -l)
python3 "$KT" install
python3 "$KT" install
binding=$(tmux list-keys -T prefix X)
[ "$(grep -o keylog <<<"$binding" | wc -l)" -eq 1 ] || { echo "FAIL: X wrapped $(grep -o keylog <<<"$binding" | wc -l) times: $binding" >&2; exit 1; }
echo "PASS: A second install does not wrap twice"

# Rebinding drops a key's note unless -N is passed again; `list-keys -N` must stay complete.
notes_after=$(tmux list-keys -N | wc -l)
[ "$notes_after" -eq "$notes_before" ] || { echo "FAIL: notes $notes_before -> $notes_after" >&2; exit 1; }
echo "PASS: Binding notes survive the wrap"

# Run the wrapped command the way a key press would.
cmd_file="$HOME/press.tmux"
# `\;` inside a binding is a separator escaped for bind-key; run directly it is a bare `;`.
sed -E 's/^bind-key +(-[a-zA-Z] +)*-T +prefix +X +//; s/ \\; / ; /' <<<"$binding" > "$cmd_file"
tmux source-file "$cmd_file"
for _ in $(seq 1 50); do [ -s "$CALLS" ] && break; sleep 0.05; done
[ "$(tmux show -gv @pressed)" = "yes" ] || { echo "FAIL: the original command did not run" >&2; exit 1; }
grep -q "^keylog tmux prefix:X  " "$CALLS" || { echo "FAIL: press not logged: $(cat "$CALLS" 2>/dev/null)" >&2; exit 1; }
echo "PASS: A wrapped binding still runs and logs the press"

# Clicks are wrapped with the mouse target; scroll and drag are left alone.
tmux list-keys -T root MouseDown1Pane | grep -q 'keylog.*window_active' || { echo "FAIL: pane click not wrapped" >&2; exit 1; }
tmux list-keys -T root WheelUpPane | grep -q keylog && { echo "FAIL: scroll wrapped" >&2; exit 1; }
tmux list-keys -T root MouseDrag1Pane | grep -q keylog && { echo "FAIL: drag wrapped" >&2; exit 1; }
echo "PASS: Clicks are wrapped, scroll and drag are not"

# A real click: an outer tmux runs a client attached to the private server and receives raw
# SGR mouse sequences, so the private server sees the same event a terminal click produces.
tmux set -g mouse on
tmux new-session -d -s clicks -x 80 -y 20 'sleep 60'
tmux split-window -h -t clicks 'sleep 60'
tmux select-pane -t clicks:0.0
OUTER="outer-$$"
command tmux -L "$OUTER" -f /dev/null new-session -d -s outer -x 80 -y 21 \
  "TMUX= tmux -S '${TMUX%%,*}' attach -t clicks"
trap 'command tmux -L "$OUTER" kill-server 2>/dev/null; private_tmux_cleanup' EXIT
sleep 1.5
: > "$CALLS"
command tmux -L "$OUTER" send-keys -t outer -l $'\e[<0;60;5M'
command tmux -L "$OUTER" send-keys -t outer -l $'\e[<0;60;5m'
for _ in $(seq 1 50); do [ -s "$CALLS" ] && break; sleep 0.05; done
[ "$(tmux display -p -t clicks '#{pane_index}')" = "1" ] || { echo "FAIL: the click did not focus the right pane" >&2; exit 1; }
grep -q "^keylog tmux root:MouseDown1Pane pane clicks:0" "$CALLS" || { echo "FAIL: click not logged as a pane change: $(cat "$CALLS")" >&2; exit 1; }
echo "PASS: A real click still focuses the pane and is logged as a pane change"

tmux list-keys -T root F9 | grep -q keylog || { echo "FAIL: root binding not wrapped" >&2; exit 1; }
tmux set -g @key_telemetry off
tmux bind-key Z set -g @z yes
python3 "$KT" install
tmux list-keys -T prefix Z | grep -q keylog && { echo "FAIL: @key_telemetry off still wrapped" >&2; exit 1; }
echo "PASS: Root bindings are wrapped and @key_telemetry off disables it"

# Habits with a shorter path: Enter on a waiting agent, g on the window the Cockpit came from.
now=$(date +%s)
mkdir -p "$XDG_STATE_HOME/flow"
{
  printf '%s\ttmux\tprefix:Space\t\ts:0\t\n' "$now"
  printf '%s\tcockpit\tenter\tpermission\ts:1\ts:0\n' "$now"
  printf '%s\tcockpit\tg\tidle\ts:0\ts:0\n' "$now"
  printf '%s\tcockpit\tg\tidle\ts:2\ts:0\n' "$now"
  printf '%s\ttmux\troot:MouseDown1Status\twindow\ts:0\t\n' "$now"
  printf '%s\ttmux\troot:MouseDown1Pane\tpane\ts:0\t\n' "$now"
  printf '%s\ttmux\troot:MouseDown1Pane\tsame\ts:0\t\n' "$now"
} > "$XDG_STATE_HOME/flow/keys.tsv"
out=$(python3 "$KT" report --days 1)
grep -q "1× Cockpit → Enter on an agent waiting for you: Prefix + I" <<<"$out" || { echo "FAIL: no Prefix + I tip:\n$out" >&2; exit 1; }
grep -q "1× Cockpit → g on the window you came from: Ctrl + G" <<<"$out" || { echo "FAIL: no Ctrl + G tip:\n$out" >&2; exit 1; }
grep -q "tmux and plugin defaults never pressed" <<<"$out" || { echo "FAIL: unused defaults not counted:\n$out" >&2; exit 1; }
grep -q "Mouse: 3 clicks, 2 of them to change pane or window" <<<"$out" || { echo "FAIL: no click summary:\n$out" >&2; exit 1; }
grep -q "1× Click on a window tab: Prefix + f" <<<"$out" || { echo "FAIL: no tab-click tip:\n$out" >&2; exit 1; }
grep -q "1× Click to focus another pane: Ctrl + h/j/k/l" <<<"$out" || { echo "FAIL: no pane-click tip:\n$out" >&2; exit 1; }
echo "PASS: Report counts usage, lists unused bindings and suggests faster paths"

echo "=== All Key Telemetry Tests Passed ==="
