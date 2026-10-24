#!/usr/bin/env zsh
# ai-quota: quota telemetry for the agent launch popups. The scripts ship in the `utils` stow
# package; this installer only enables the user timer that keeps the Antigravity cache warm.

if ! command -v ai-quota &>/dev/null; then
  print -P "  %F{red}✗%f %Bai-quota%b not on PATH (run ./stow.sh -r utils)"
  return 1
fi

if ! systemctl --user is-enabled ai-quota-refresh.timer &>/dev/null; then
  print -P "  %F{blue}→%f Enabling %Bai-quota-refresh.timer%b systemd user timer..."
  systemctl --user daemon-reload 2>/dev/null || true
  systemctl --user enable --now ai-quota-refresh.timer 2>/dev/null || true
  print -P "  %F{green}✓%f %Bai-quota-refresh.timer%b enabled"
else
  print -P "  %F{cyan}✓%f %Bai-quota-refresh.timer%b already enabled"
fi
