#!/usr/bin/env bash
# nerd-font-icons-sync.sh — build tmux-nerd-font-window-name's config from the icon registry
#
# The plugin reads one YAML file. This script joins the base config (fallback icon, multi-pane
# icon, ...) with the `icons:` section exported by `waymux icons --format tmux`, the single
# source of truth for program/agent glyphs, and points the plugin at the result.
# Runs from tmux.conf before TPM; rerun (or reload tmux) after editing [icons].
set -uo pipefail

base="$HOME/.config/tmux/tmux-nerd-font-window-name.yml"
out="${XDG_CACHE_HOME:-$HOME/.cache}/tmux/tmux-nerd-font-window-name.yml"
plugin_cache="${XDG_CACHE_HOME:-$HOME/.cache}/tmux-nerd-font-window-name/config.sh"

if icons=$(waymux icons --format tmux 2>/dev/null) && [[ -n "$icons" ]]; then
  mkdir -p "${out%/*}"
  new=$(cat "$base"; printf '\n%s\n' "$icons")
  if [[ "$new" != "$(cat "$out" 2>/dev/null)" ]]; then
    printf '%s\n' "$new" >"$out.tmp" && mv "$out.tmp" "$out"
    # The plugin only rebuilds its cache when the config *path* changes, not its content
    rm -f "$plugin_cache"
  fi
fi

# Without waymux and without a previous build, fall back to the base config
[[ -f "$out" ]] || out="$base"
tmux set-option -g @tmux-nerd-font-window-name-config-file "$out"
