#!/usr/bin/env sh
# ai-agent-triage-jump.sh - Direct, zero-modal focus jump to next AI agent requiring attention
# Cycles through panes in question/permission/error/working state across all Tmux sessions.
#
# Thin entry point: the implementation lives in `waymux triage --jump`. This path stays because
# bindings, Waymaker presets and other scripts call it.

if [ -x "$HOME/.local/bin/waymux" ]; then
  exec "$HOME/.local/bin/waymux" triage --jump "$@"
elif command -v waymux >/dev/null 2>&1; then
  exec waymux triage --jump "$@"
fi

msg="ai-agent-triage-jump.sh: waymux not found (install it, then run: waymux doctor)"
echo "$msg" >&2
[ -n "${TMUX:-}" ] && tmux display-message "$msg" 2>/dev/null
exit 127
