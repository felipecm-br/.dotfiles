#!/usr/bin/env zsh

# Installer for JetBrainsMono Nerd Font Propo (used by Ghostty and Kitty).
# Omarchy ships ttf-jetbrains-mono-nerd-basic, which has no Propo variant and
# conflicts with the full package that omarchy-dev cannot do without, so the
# four Propo faces go to ~/.local/share/fonts instead (no root).

local nf_version="v3.5.1"
local nf_family="JetBrainsMono Nerd Font Propo"
local nf_dir="$HOME/.local/share/fonts/JetBrainsMonoNerdFontPropo"

if fc-list : family | grep -qF "$nf_family"; then
  print -P "  %F{cyan}✓%f %B${nf_family}%b already installed"
  return 0
fi

local tmp
tmp=$(mktemp -d) || return 1

print -P "  %F{yellow}→%f Downloading JetBrainsMono Nerd Font ${nf_version}..."
if ! curl -fsSL -o "$tmp/JetBrainsMono.tar.xz" \
  "https://github.com/ryanoasis/nerd-fonts/releases/download/${nf_version}/JetBrainsMono.tar.xz"; then
  print -P "  %F{red}✗%f Download failed"
  rm -rf "$tmp"
  return 1
fi

mkdir -p "$nf_dir"
tar -xJf "$tmp/JetBrainsMono.tar.xz" -C "$tmp" --wildcards 'JetBrainsMonoNerdFontPropo-*.ttf' \
  && cp "$tmp"/JetBrainsMonoNerdFontPropo-{Regular,Bold,Italic,BoldItalic}.ttf "$nf_dir"/
local rc=$?
rm -rf "$tmp"
(( rc == 0 )) || { print -P "  %F{red}✗%f Propo faces not found in the archive"; return 1; }

fc-cache -f "$nf_dir" >/dev/null
print -P "  %F{green}✓%f Installed %B${nf_family}%b to ${nf_dir}"
