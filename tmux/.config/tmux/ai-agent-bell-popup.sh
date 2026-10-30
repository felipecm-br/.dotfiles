#!/usr/bin/env sh
# ai-agent-bell-popup.sh — Reactive popup over the AI agents waiting for attention (Prefix + i)
#
# Thin entry point: the implementation lives in `waymux triage --popup`. This path stays because
# bindings, Waymaker presets and other scripts call it.

if [ -x "$HOME/.local/bin/waymux" ]; then
  exec "$HOME/.local/bin/waymux" triage --popup "$@"
elif command -v waymux >/dev/null 2>&1; then
  exec waymux triage --popup "$@"
fi

msg="ai-agent-bell-popup.sh: waymux not found (install it, then run: waymux doctor)"
echo "$msg" >&2
[ -n "${TMUX:-}" ] && tmux display-message "$msg" 2>/dev/null
exit 127
