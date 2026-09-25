#!/usr/bin/env sh
# keybindings-run.sh — execute or display telemetry for selected keybinding in HUD.
# Usage: keybindings-run.sh <action> [key] [name]
set -u

ACTION="${1:-}"
KEY="${2:-}"
NAME="${3:-}"

# Copy key to clipboard
if [ -n "$KEY" ]; then
  if command -v wl-copy >/dev/null 2>&1; then
    printf '%s' "$KEY" | wl-copy 2>/dev/null || true
  elif command -v xclip >/dev/null 2>&1; then
    printf '%s' "$KEY" | xclip -in -selection clipboard 2>/dev/null || true
  fi
fi

if [ -z "$ACTION" ] || [ "$ACTION" = "info" ]; then
  tmux display-message "󰌌 $KEY: $NAME (use diretamente no terminal/Hyprland)" 2>/dev/null || true
  exit 0
fi

# Expand home path
case "$ACTION" in
  '~'*) ACTION="$HOME${ACTION#'~'}" ;;
esac

# For runnable tmux scripts or commands, close keybindings popup and dispatch
if [ -n "${TMUX:-}" ]; then
  # Close current keybindings popup
  tmux display-popup -C 2>/dev/null || true
  rm -f "/tmp/tmux-active-popup-${USER:-default}" 2>/dev/null || true

  # Dispatch target action cleanly
  tmux run-shell -b "$ACTION" 2>/dev/null || true
else
  # Running outside tmux (direct shell)
  if command -v setsid >/dev/null 2>&1; then
    setsid $ACTION >/dev/null 2>&1 &
  else
    eval "$ACTION" >/dev/null 2>&1 &
  fi
fi

exit 0
