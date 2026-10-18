#!/usr/bin/env zsh

if ! command -v cargo-clean-all &>/dev/null; then
  print -P "  %F{green}→%f Installing %Bcargo-clean-all%b via cargo..."
  cargo install cargo-clean-all
fi

if command -v cargo-clean-all &>/dev/null; then
  print -P "  %F{green}✓%f %Bcargo-clean-all%b is installed"
else
  print -P "  %F{red}✗%f %Bcargo-clean-all%b installation failed"
  return 1
fi

if ! systemctl --user is-enabled dev-gc.timer &>/dev/null; then
  print -P "  %F{blue}→%f Enabling %Bdev-gc.timer%b systemd user timer..."
  systemctl --user daemon-reload 2>/dev/null || true
  systemctl --user enable --now dev-gc.timer 2>/dev/null || true
  print -P "  %F{green}✓%f %Bdev-gc.timer%b enabled"
else
  print -P "  %F{cyan}✓%f %Bdev-gc.timer%b already enabled"
fi
