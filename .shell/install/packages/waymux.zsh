#!/usr/bin/env zsh
# Install waymux (single-binary terminal AI cockpit, orchestrator and control-plane daemon).
# Replaces the legacy standalone `acpd` daemon.
# https://github.com/felipecm-br/waymux

if command -v waymux &>/dev/null; then
  print -P "  %F{cyan}✓%f %Bwaymux%b already installed"
  return 0
fi

print -P "%F{blue}  →%f Building %Bwaymux%b from GitHub via cargo..."
if command -v cargo &>/dev/null; then
  if cargo install --force --git https://github.com/felipecm-br/waymux waymux; then
    # Ensure binary is in ~/.local/bin/
    if [[ -f "$HOME/.cargo/bin/waymux" ]]; then
      mkdir -p "$HOME/.local/bin"
      ln -sf "$HOME/.cargo/bin/waymux" "$HOME/.local/bin/waymux"
    fi
    print -P "  %F{green}✓%f %Bwaymux%b installed successfully"
    return 0
  else
    print -P "  %F{red}✗%f Failed to build %Bwaymux%b via cargo"
    return 1
  fi
else
  print -P "  %F{red}✗%f Cargo is required to build %Bwaymux%b"
  return 1
fi
