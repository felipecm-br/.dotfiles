#!/usr/bin/env zsh
# Install OpenBot (CopilotKit open-source AI coworker template) as a local checkout.
# https://github.com/CopilotKit/openbot
# It is a clone-and-customize template, not a CLI: this only clones it and installs
# dependencies. Create .env (cp .env.example .env) and follow the README quick start.

local dest="${OPENBOT_DIR:-$HOME/.local/share/openbot}"

if [[ -d "$dest/.git" ]]; then
  print -P "  %F{cyan}✓%f %Bopenbot%b already cloned ($dest)"
  return 0
fi

if ! command -v bun &>/dev/null; then
  print -P "  %F{red}✗%f Bun is required to set up %Bopenbot%b"
  return 1
fi

print -P "%F{blue}  →%f Cloning %Bopenbot%b to $dest..."
mkdir -p "${dest:h}"
if git clone --depth 1 https://github.com/CopilotKit/openbot "$dest" && (cd "$dest" && bun install); then
  print -P "  %F{green}✓%f %Bopenbot%b ready (next: cp .env.example .env in $dest)"
  return 0
else
  print -P "  %F{red}✗%f Failed to set up %Bopenbot%b"
  return 1
fi
