#!/usr/bin/env zsh
# Install VHS (Terminal GIF recorder) & dependencies
# https://github.com/charmbracelet/vhs

# 1. Ensure ttyd dependency is installed
if ! command -v ttyd &>/dev/null; then
  print -P "%F{blue}  →%f Installing %Bttyd%b..."
  if command -v yay &>/dev/null; then
    pkg_install ttyd || true
  fi

  if ! command -v ttyd &>/dev/null; then
    local arch="$(uname -m)"
    print -P "%F{blue}  →%f Downloading prebuilt %Bttyd%b (${arch})..."
    mkdir -p "${HOME}/.local/bin"
    curl -fsSL "https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.${arch}" -o "${HOME}/.local/bin/ttyd" && chmod +x "${HOME}/.local/bin/ttyd"
  fi
fi

# 2. Check if VHS is already installed
if command -v vhs &>/dev/null; then
  print -P "  %F{cyan}✓%f %Bvhs%b already installed"
  return 0
fi

# 3. Try package manager
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

# 4. Fallback: go install
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
