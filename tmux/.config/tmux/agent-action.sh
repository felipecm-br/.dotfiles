#!/usr/bin/env sh
# agent-action.sh — Guarded agent actions (approval, denial, prompt dispatch) for Cockpit HUD
#
# Thin entry point: the implementation lives in `waymux agent-action`. This path stays because
# bindings, Waymaker presets and other scripts call it.

if [ -x "$HOME/.local/bin/waymux" ]; then
  exec "$HOME/.local/bin/waymux" agent-action "$@"
elif command -v waymux >/dev/null 2>&1; then
  exec waymux agent-action "$@"
fi

msg="agent-action.sh: waymux not found (install it, then run: waymux doctor)"
echo "$msg" >&2
[ -n "${TMUX:-}" ] && tmux display-message "$msg" 2>/dev/null
exit 127
