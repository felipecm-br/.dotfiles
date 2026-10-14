#!/usr/bin/env zsh
# Install tmux 3.8 (Terminal multiplexer)
# https://github.com/tmux/tmux

if command -v tmux &>/dev/null; then
  local current_ver="$(tmux -V 2>/dev/null | awk '{print $2}')"
  if [[ "$current_ver" == 3.8* ]]; then
    print -P "  %F{cyan}✓%f %Btmux%b already up-to-date (%F{green}v${current_ver}%f)"
    return 0
  fi
fi

local TMUX_VERSION="3.8"
local TARBALL="tmux-${TMUX_VERSION}.tar.gz"
local URL="https://github.com/tmux/tmux/releases/download/${TMUX_VERSION}/${TARBALL}"

print -P "%F{blue}  →%f Downloading and building %Btmux ${TMUX_VERSION}%b from release..."

local tmp_dir="$(mktemp -d -t tmux-build-XXXXXX)"
if [[ ! -d "$tmp_dir" ]]; then
  print -P "  %F{red}✗%f Failed to create temporary build directory"
  return 1
fi

if ! curl -fsSL "$URL" -o "${tmp_dir}/${TARBALL}"; then
  print -P "  %F{red}✗%f Failed to download tmux ${TMUX_VERSION} from ${URL}"
  rm -rf "$tmp_dir"
  return 1
fi

if ! tar -xzf "${tmp_dir}/${TARBALL}" -C "$tmp_dir"; then
  print -P "  %F{red}✗%f Failed to extract ${TARBALL}"
  rm -rf "$tmp_dir"
  return 1
fi

local src_dir="${tmp_dir}/tmux-${TMUX_VERSION}"
if [[ ! -d "$src_dir" ]]; then
  print -P "  %F{red}✗%f Source directory not found: ${src_dir}"
  rm -rf "$tmp_dir"
  return 1
fi

(
  cd "$src_dir" || exit 1
  ./configure --prefix="${HOME}/.local" --enable-sixel --enable-systemd --enable-utempter || exit 1
  make -j"$(nproc 2>/dev/null || echo 2)" || exit 1
  make install || exit 1
)

local build_status=$?
rm -rf "$tmp_dir"

if (( build_status != 0 )); then
  print -P "  %F{red}✗%f Failed to compile/install %Btmux ${TMUX_VERSION}%b"
  return 1
fi

if [[ -x "${HOME}/.local/bin/tmux" ]]; then
  print -P "  %F{green}✓%f %Btmux%b %F{green}v3.8%f successfully installed to %B~/.local/bin/tmux%b"
  return 0
else
  print -P "  %F{red}✗%f %Btmux%b binary not found in ~/.local/bin"
  return 1
fi
