#!/usr/bin/env zsh
# Install Tailscale and configure tailscaled daemon

if pkg_is_installed tailscale; then
  print -P "  %F{cyan}✓%f %Btailscale%b already installed"
  if ! systemctl is-active --quiet tailscaled 2>/dev/null; then
    print -P "  %F{blue}:: %BEnabling and starting tailscaled.service...%b%f"
    sudo systemctl enable --now tailscaled 2>/dev/null || true
  fi
  return 0
fi

print -P "  %F{yellow}→%f Installing %Btailscale%b via package manager..."
if ! pkg_install tailscale; then
  print -P "  %F{red}✗%f Failed to install %Btailscale%b"
  return 1
fi

print -P "  %F{blue}:: %BEnabling and starting tailscaled.service%b%f"
if sudo systemctl enable --now tailscaled 2>/dev/null; then
  print -P "  %F{green}✓%f %Btailscaled.service%b enabled and active"
else
  print -P "  %F{yellow}⚠%f Could not enable tailscaled automatically. Run: sudo systemctl enable --now tailscaled"
fi

print -P "  %F{cyan}ℹ%f To authenticate and enable Tailscale SSH, run: %Bsudo tailscale up --ssh%b"
return 0
