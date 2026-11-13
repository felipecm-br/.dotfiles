#!/usr/bin/env zsh
# Install waymaker (`wm`): fuzzy picker behind every popup, preset and Tab widget.
# https://github.com/felipecm-br/waymaker

if command -v wm &>/dev/null; then
  print -P "  %F{cyan}✓%f %Bwaymaker%b already installed"
  return 0
fi

if ! command -v cargo &>/dev/null; then
  print -P "  %F{red}✗%f Cargo is required to build %Bwaymaker%b"
  return 1
fi

print -P "%F{blue}  →%f Building %Bwaymaker%b from GitHub via cargo..."
if ! cargo install --locked --force --git https://github.com/felipecm-br/waymaker waymaker-cli; then
  print -P "  %F{red}✗%f Failed to build %Bwaymaker%b via cargo"
  return 1
fi

mkdir -p "$HOME/.local/bin"
[[ -f "$HOME/.cargo/bin/wm" ]] && ln -sf "$HOME/.cargo/bin/wm" "$HOME/.local/bin/wm"
print -P "  %F{green}✓%f %Bwaymaker%b installed successfully"
