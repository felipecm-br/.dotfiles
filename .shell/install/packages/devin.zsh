#!/usr/bin/env zsh
# Install Devin CLI (Cognition AI terminal coding agent).
# https://cli.devin.ai

if command -v devin &>/dev/null || [[ -x "$HOME/.local/bin/devin" ]]; then
  print -P "  %F{cyan}✓%f %Bdevin%b already installed"
  return 0
fi

print -P "%F{blue}  →%f Installing %Bdevin%b via official installer..."
if curl -fsSL https://cli.devin.ai/install.sh | sed '/"\$VERSION_DIR\/bin\/\$COMPILED_BIN_NAME" setup/d' | bash; then
  print -P "  %F{green}✓%f %Bdevin%b installed successfully"
  return 0
else
  print -P "  %F{red}✗%f Failed to install %Bdevin%b"
  return 1
fi
