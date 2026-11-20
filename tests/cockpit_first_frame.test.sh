#!/usr/bin/env bash
# tests/cockpit_first_frame.test.sh — the Cockpit's own first frame: from starting
# `waymux cockpit` (as its popup runs it, TMUX_POPUP=1) to its last row on screen.
#
# Runs on a private tmux server with 8 windows in this repository (git metadata included) and a
# probe window. No daemon is reachable (WAYMUX_PORT is unusable), so rows carry no agent state;
# the time is the Cockpit's data path plus Waymaker's first frame. Each run is closed with `Esc`
# and waited for, so one run never measures the shutdown of the last.
#
#   tests/cockpit_first_frame.test.sh           N=15 runs, budget p50 ≤ 100 ms
#   N=40 BUDGET_MS=80 tests/cockpit_first_frame.test.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ok() { echo "ok: $*"; }
command -v waymux >/dev/null 2>&1 || { echo "skip: waymux not installed"; exit 0; }
command -v wm >/dev/null 2>&1 || { echo "skip: wm not installed"; exit 0; }
WAYMUX=$(command -v waymux)

# shellcheck source=lib/private_tmux.sh
. "$ROOT/tests/lib/private_tmux.sh"
N=${N:-15}
BUDGET_MS=${BUDGET_MS:-100}

for i in 1 2 3 4 5 6 7 8; do tmux new-window -d -t _test_bootstrap: -n "ckwin$i" -c "$ROOT" "sleep 600"; done
tmux new-window -d -t _test_bootstrap: -n probe "sleep 600"
tmux resize-window -t _test_bootstrap:probe -x 200 -y 50 2>/dev/null || true
pane=$(tmux display-message -p -t _test_bootstrap:probe '#{pane_id}')

first_frame_ms() {
  local start now ms=3000 i=0
  start=$(date +%s%N)
  tmux respawn-pane -k -t "$pane" "TMUX_POPUP=1 '$WAYMUX' cockpit; exec sleep 600"
  while :; do
    if tmux capture-pane -p -t "$pane" 2>/dev/null | grep -q ckwin8; then
      now=$(date +%s%N); ms=$(((now - start) / 1000000)); break
    fi
    now=$(date +%s%N)
    [ $(((now - start) / 1000000)) -lt 3000 ] || break
  done
  sleep 0.2
  tmux send-keys -t "$pane" Escape
  while [ "$(tmux display-message -p -t "$pane" '#{pane_current_command}')" != sleep ] && [ $i -lt 300 ]; do
    sleep 0.01; i=$((i + 1))
  done
  echo "$ms"
}

pct() { sort -n | awk -v p="$1" '{a[NR]=$1} END {i=int((NR-1)*p/100)+1; print a[i]}'; }

first_frame_ms >/dev/null # warm the binaries and the page cache
samples=()
for _ in $(seq "$N"); do samples+=("$(first_frame_ms)"); done
p50=$(printf '%s\n' "${samples[@]}" | pct 50)
p95=$(printf '%s\n' "${samples[@]}" | pct 95)
if [ "$p50" -le "$BUDGET_MS" ]; then
  ok "cockpit first frame p50 ${p50} ms, p95 ${p95} ms (budget p50 ≤ ${BUDGET_MS} ms)"
else
  echo "FAIL: cockpit first frame p50 ${p50} ms, p95 ${p95} ms (budget p50 ≤ ${BUDGET_MS} ms)" >&2
  exit 1
fi
