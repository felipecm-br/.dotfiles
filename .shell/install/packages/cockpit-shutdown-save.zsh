#!/usr/bin/env zsh
# cockpit-shutdown-save: snapshots the tmux layout and agent sessions when the host shuts down
# (a logind delay lock). The script and unit ship in the `utils` stow package; this installer
# only enables the user service.

if ! command -v cockpit-shutdown-save &>/dev/null; then
  print -P "  %F{red}✗%f %Bcockpit-shutdown-save%b not on PATH (run ./stow.sh -r utils)"
  return 1
fi

if ! systemctl --user is-enabled cockpit-shutdown-save.service &>/dev/null; then
  print -P "  %F{blue}→%f Enabling %Bcockpit-shutdown-save.service%b systemd user service..."
  systemctl --user daemon-reload 2>/dev/null || true
  systemctl --user enable --now cockpit-shutdown-save.service 2>/dev/null || true
  print -P "  %F{green}✓%f %Bcockpit-shutdown-save.service%b enabled"
else
  print -P "  %F{cyan}✓%f %Bcockpit-shutdown-save.service%b already enabled"
fi
