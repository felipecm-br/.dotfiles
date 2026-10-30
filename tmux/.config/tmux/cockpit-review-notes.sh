#!/usr/bin/env sh
# cockpit-review-notes.sh — Bridge between Lazygitrs review comments (.lines.json) and AI agents in Cockpit HUD
#
# Thin entry point: the implementation lives in `waymux review-notes`. This path stays because
# bindings, Waymaker presets and other scripts call it.

if [ -x "$HOME/.local/bin/waymux" ]; then
  exec "$HOME/.local/bin/waymux" review-notes "$@"
elif command -v waymux >/dev/null 2>&1; then
  exec waymux review-notes "$@"
fi

msg="cockpit-review-notes.sh: waymux not found (install it, then run: waymux doctor)"
echo "$msg" >&2
[ -n "${TMUX:-}" ] && tmux display-message "$msg" 2>/dev/null
exit 127
