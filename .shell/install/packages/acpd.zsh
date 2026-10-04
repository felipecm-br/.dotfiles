#!/usr/bin/env zsh
# Install acpd (Agent Client Protocol Daemon)
# https://github.com/felipecm-br/acpd

if command -v acpd &>/dev/null; then
  print -P "  %F{cyan}✓%f %Bacpd%b already installed"
  return 0
fi

print -P "%F{blue}  →%f Building %Bacpd%b from GitHub via cargo..."
if command -v cargo &>/dev/null; then
  if cargo install --force --git https://github.com/felipecm-br/acpd acpd; then
    # Ensure binary is in ~/.local/bin/
    if [[ -f "$HOME/.cargo/bin/acpd" ]]; then
      mkdir -p "$HOME/.local/bin"
      ln -sf "$HOME/.cargo/bin/acpd" "$HOME/.local/bin/acpd"
    fi
    print -P "  %F{green}✓%f %Bacpd%b installed successfully"
    return 0
  else
    print -P "  %F{red}✗%f Failed to build %Bacpd%b via cargo"
    return 1
  fi
else
  print -P "  %F{red}✗%f Cargo is required to build %Bacpd%b"
  return 1
fi
