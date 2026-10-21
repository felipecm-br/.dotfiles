#!/usr/bin/env zsh
# Install Claude Code CLI (Anthropic terminal coding agent).
# https://claude.ai

if command -v claude &>/dev/null || [[ -x "$HOME/.local/bin/claude" ]]; then
  print -P "  %F{cyan}✓%f %Bclaude%b already installed"
  return 0
fi

print -P "%F{blue}  →%f Installing %Bclaude%b via official installer..."
if curl -fsSL https://claude.ai/install.sh | bash; then
  print -P "  %F{green}✓%f %Bclaude%b installed successfully"
  return 0
else
  print -P "  %F{red}✗%f Failed to install %Bclaude%b"
  return 1
fi
