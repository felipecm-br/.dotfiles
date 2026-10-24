#!/usr/bin/env bash
# tests/cockpit_hud_perf.test.sh — reproducible latency contract for the waymux Cockpit HUD data path.
#
# Measures wall-clock p50/p95 of the commands that gate the Cockpit popup and fails when p50 exceeds
# the budget (Doherty threshold margin). Numbers are machine-dependent: run on the target host.
#
# Env: N (iterations, default 40), ITEMS_BUDGET_MS (default 50), HEALTH_BUDGET_MS (default 20),
#      KEYLOG_BUDGET_MS (default 10), CTRLG_BUDGET_MS (default 150)
set -euo pipefail

ok() { echo "ok: $*"; }
bad() { echo "FAIL: $*" >&2; exit 1; }

N="${N:-40}"
ITEMS_BUDGET_MS="${ITEMS_BUDGET_MS:-50}"
HEALTH_BUDGET_MS="${HEALTH_BUDGET_MS:-20}"
KEYLOG_BUDGET_MS="${KEYLOG_BUDGET_MS:-10}"
CTRLG_BUDGET_MS="${CTRLG_BUDGET_MS:-150}"
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

command -v waymux >/dev/null 2>&1 || bad "waymux binary not found in PATH"
waymux health >/dev/null 2>&1 || bad "waymux daemon is not healthy (systemctl --user status waymux)"

# bench <label> <budget_ms> <cmd...> — prints p50/p95 in ms, returns non-zero when p50 > budget.
bench() {
  local label="$1" budget="$2"
  shift 2
  local -a ts=()
  local i s e
  for ((i = 0; i < N; i++)); do
    s="${EPOCHREALTIME/./}"
    "$@" >/dev/null 2>&1 || true
    e="${EPOCHREALTIME/./}"
    ts+=("$(((e - s) / 1000))")
  done
  local sorted p50 p95
  sorted="$(printf '%s\n' "${ts[@]}" | sort -n)"
  p50="$(sed -n "$(((N + 1) / 2))p" <<<"$sorted")"
  p95="$(sed -n "$(((N * 95 + 99) / 100))p" <<<"$sorted")"
  echo "     $label: p50=${p50}ms p95=${p95}ms (budget p50<=${budget}ms, n=${N})"
  ((p50 <= budget))
}

bench "waymux cockpit-items" "$ITEMS_BUDGET_MS" waymux cockpit-items &&
  ok "cockpit-items p50 within ${ITEMS_BUDGET_MS}ms" || bad "cockpit-items p50 exceeded ${ITEMS_BUDGET_MS}ms"

bench "waymux health" "$HEALTH_BUDGET_MS" waymux health &&
  ok "health probe p50 within ${HEALTH_BUDGET_MS}ms" || bad "health probe p50 exceeded ${HEALTH_BUDGET_MS}ms"

# Key telemetry runs on every wrapped press (in the background); keep it far below a frame.
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
if waymux keylog >/dev/null 2>&1; then
  bench "waymux keylog" "$KEYLOG_BUDGET_MS" env XDG_STATE_HOME="$SANDBOX" waymux keylog bench k &&
    ok "keylog p50 within ${KEYLOG_BUDGET_MS}ms" || bad "keylog p50 exceeded ${KEYLOG_BUDGET_MS}ms"
else
  echo "     waymux keylog: skipped (installed waymux predates keylog)"
fi

# Ctrl+G up to the popup: lazygitrs-popup.sh with a tmux whose display-popup returns at once, so
# this is the script's own work (git checks, lazygitrs probe, telemetry) before lazygitrs draws.
mkdir -p "$SANDBOX/bin"
printf '#!/bin/sh\nexit 0\n' > "$SANDBOX/bin/tmux"
chmod +x "$SANDBOX/bin/tmux"
if command -v lazygitrs >/dev/null 2>&1 || [ -x "$HOME/.local/bin/lazygitrs" ]; then
  bench "Ctrl+G to popup (lazygitrs-popup.sh)" "$CTRLG_BUDGET_MS" \
    env PATH="$SANDBOX/bin:$PATH" XDG_STATE_HOME="$SANDBOX" \
    "$DOTFILES_DIR/tmux/.config/tmux/lazygitrs-popup.sh" "$DOTFILES_DIR" &&
    ok "Ctrl+G pre-popup p50 within ${CTRLG_BUDGET_MS}ms" || bad "Ctrl+G pre-popup p50 exceeded ${CTRLG_BUDGET_MS}ms"
else
  echo "     Ctrl+G to popup: skipped (lazygitrs not installed)"
fi

echo "All cockpit HUD latency checks passed."
