#!/usr/bin/env bash
# tests/popup_render_perf.test.sh — time from starting a Waymaker picker to its first drawn row.
#
# The Cockpit data path is measured elsewhere (tests/cockpit_hud_perf.test.sh); this measures the
# render: `wm -o <preset>` starts in a pane of a private tmux server, and the clock stops when the
# first candidate shows in `capture-pane`. Polling adds up to one tmux round trip (~2–4 ms), so
# the numbers are an upper bound. A tmux popup adds its own frame on top; the picker inside it is
# what this times.
#
#   tests/popup_render_perf.test.sh              N=20 runs per preset, budget p50 ≤ 100 ms
#   N=40 BUDGET_MS=80 tests/popup_render_perf.test.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ok() { echo "ok: $*"; }
bad() { echo "FAIL: $*" >&2; exit 1; }
command -v wm >/dev/null 2>&1 || { echo "skip: wm not installed"; exit 0; }

# shellcheck source=lib/private_tmux.sh
. "$ROOT/tests/lib/private_tmux.sh"
N=${N:-20}
BUDGET_MS=${BUDGET_MS:-100}
ITEMS=$(mktemp)
trap 'private_tmux_cleanup; rm -f "$ITEMS"' EXIT
for i in $(seq -w 1 2000); do echo "zzitem$i"; done >"$ITEMS"

tmux new-window -d -t _test_bootstrap: -n bench
tmux resize-window -t _test_bootstrap:bench -x 200 -y 50 2>/dev/null || true
pane=$(tmux display-message -p -t _test_bootstrap:bench '#{pane_id}')

first_frame_ms() { # <preset>: ms from respawn to the first candidate on screen
  local preset=$1 start now
  start=$(date +%s%N)
  tmux respawn-pane -k -t "$pane" "wm -o $preset <'$ITEMS'"
  while :; do
    if tmux capture-pane -p -t "$pane" 2>/dev/null | grep -q 'zzitem'; then
      now=$(date +%s%N)
      echo $(((now - start) / 1000000))
      return 0
    fi
    now=$(date +%s%N)
    [ $(((now - start) / 1000000)) -lt 3000 ] || { echo 3000; return 1; }
  done
}

pct() { # <p> : percentile of the numbers on stdin
  sort -n | awk -v p="$1" '{a[NR]=$1} END {i=int((NR-1)*p/100)+1; print a[i]}'
}

fail=0
for preset in ftb keybindings session-picker-mine ai-launch; do
  [ -f "$HOME/.config/waymaker/presets/$preset.toml" ] || { echo "skip: no preset $preset"; continue; }
  first_frame_ms "$preset" >/dev/null || true # warm the binary and the page cache
  samples=()
  for _ in $(seq "$N"); do samples+=("$(first_frame_ms "$preset" || true)"); done
  p50=$(printf '%s\n' "${samples[@]}" | pct 50)
  p95=$(printf '%s\n' "${samples[@]}" | pct 95)
  if [ "$p50" -le "$BUDGET_MS" ]; then
    ok "$preset first frame p50 ${p50} ms, p95 ${p95} ms (budget p50 ≤ ${BUDGET_MS} ms)"
  else
    echo "FAIL: $preset first frame p50 ${p50} ms, p95 ${p95} ms (budget p50 ≤ ${BUDGET_MS} ms)" >&2
    fail=1
  fi
done
tmux kill-window -t _test_bootstrap:bench 2>/dev/null || true
[ "$fail" = 0 ] || exit 1
echo "popup_render_perf: all presets within budget"
