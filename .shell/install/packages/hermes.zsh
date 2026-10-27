#!/usr/bin/env zsh
# Install Hermes Agent (Nous Research terminal agent).
# https://hermes-agent.nousresearch.com

if command -v hermes &>/dev/null || [[ -x "$HOME/.local/bin/hermes" ]]; then
  print -P "  %F{cyan}✓%f %Bhermes%b already installed"
  return 0
fi

print -P "%F{blue}  →%f Installing %Bhermes%b via official installer..."
if curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash; then
  print -P "  %F{green}✓%f %Bhermes%b installed successfully"
  return 0
else
  print -P "  %F{red}✗%f Failed to install %Bhermes%b"
  return 1
fi
