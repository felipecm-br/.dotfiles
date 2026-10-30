#!/usr/bin/env sh
# cockpit-picker.sh — Fleet & Window Cockpit HUD powered by Waymaker
# Displays prioritized agent states, waiting age, git branch/churn, and contextual previews.
#
# Thin entry point: the implementation lives in `waymux cockpit`. This path stays because
# bindings, Waymaker presets and other scripts call it.

if [ -x "$HOME/.local/bin/waymux" ]; then
  exec "$HOME/.local/bin/waymux" cockpit "$@"
elif command -v waymux >/dev/null 2>&1; then
  exec waymux cockpit "$@"
fi

msg="cockpit-picker.sh: waymux not found (install it, then run: waymux doctor)"
echo "$msg" >&2
[ -n "${TMUX:-}" ] && tmux display-message "$msg" 2>/dev/null
exit 127
