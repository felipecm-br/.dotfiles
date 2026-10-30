#!/usr/bin/env sh
# cockpit-picker-items.sh — emit prioritized agent triage, windows, and fleet overview items
#
# Thin entry point: the implementation lives in `waymux cockpit-items`. This path stays because
# bindings, Waymaker presets and other scripts call it.

if [ -x "$HOME/.local/bin/waymux" ]; then
  exec "$HOME/.local/bin/waymux" cockpit-items "$@"
elif command -v waymux >/dev/null 2>&1; then
  exec waymux cockpit-items "$@"
fi

msg="cockpit-picker-items.sh: waymux not found (install it, then run: waymux doctor)"
echo "$msg" >&2
[ -n "${TMUX:-}" ] && tmux display-message "$msg" 2>/dev/null
exit 127
