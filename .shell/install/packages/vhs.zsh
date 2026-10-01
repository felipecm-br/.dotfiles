#!/usr/bin/env zsh
# Install VHS (Terminal GIF recorder)
# https://github.com/charmbracelet/vhs

if command -v vhs &>/dev/null; then
  print -P "  %F{cyan}✓%f %Bvhs%b already installed"
  return 0
fi

if command -v yay &>/dev/null; then
  print -P "%F{blue}  →%f Installing %Bvhs-bin%b via AUR..."
  if pkg_install vhs-bin && command -v vhs &>/dev/null; then
    return 0
  fi

  print -P "%F{blue}  →%f Installing %Bvhs%b via package manager..."
  if pkg_install vhs && command -v vhs &>/dev/null; then
    return 0
  fi
fi

if command -v go &>/dev/null; then
  print -P "%F{blue}  →%f Installing %Bvhs%b via go install..."
  if go install github.com/charmbracelet/vhs@latest && command -v vhs &>/dev/null; then
    print -P "  %F{green}✓%f %Bvhs%b is installed"
    return 0
  fi
fi

if command -v vhs &>/dev/null; then
  print -P "  %F{green}✓%f %Bvhs%b is installed"
else
  print -P "  %F{red}✗%f %Bvhs%b installation failed"
  return 1
fi
