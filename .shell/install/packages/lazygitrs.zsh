#!/usr/bin/env zsh
# Install lazygitrs (`lazygitrs`): git TUI fork behind gc, sgc and Ctrl+G.
# https://github.com/felipecm-br/lazygitrs

if command -v lazygitrs &>/dev/null; then
  print -P "  %F{cyan}✓%f %Blazygitrs%b already installed"
  return 0
fi

if ! command -v cargo &>/dev/null; then
  print -P "  %F{red}✗%f Cargo is required to build %Blazygitrs%b"
  return 1
fi

print -P "%F{blue}  →%f Building %Blazygitrs%b from GitHub via cargo..."
if ! cargo install --locked --force --git https://github.com/felipecm-br/lazygitrs lazygitrs; then
  print -P "  %F{red}✗%f Failed to build %Blazygitrs%b via cargo"
  return 1
fi

mkdir -p "$HOME/.local/bin"
[[ -f "$HOME/.cargo/bin/lazygitrs" ]] && ln -sf "$HOME/.cargo/bin/lazygitrs" "$HOME/.local/bin/lazygitrs"
print -P "  %F{green}✓%f %Blazygitrs%b installed successfully"
