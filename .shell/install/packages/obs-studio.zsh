#!/usr/bin/env zsh
# Install OBS Studio (Screen recorder & live streaming)
# https://obsproject.com

if command -v obs &>/dev/null; then
  print -P "  %F{cyan}✓%f %Bobs-studio%b already installed"
  return 0
fi

if command -v yay &>/dev/null; then
  print -P "%F{blue}  →%f Installing %Bobs-studio%b via yay..."
  if pkg_install obs-studio && command -v obs &>/dev/null; then
    return 0
  fi
elif command -v pacman &>/dev/null; then
  print -P "%F{blue}  →%f Installing %Bobs-studio%b via pacman..."
  if pkg_install obs-studio && command -v obs &>/dev/null; then
    return 0
  fi
fi

if command -v obs &>/dev/null; then
  print -P "  %F{green}✓%f %Bobs-studio%b is installed"
else
  print -P "  %F{red}✗%f %Bobs-studio%b installation failed"
  return 1
fi
