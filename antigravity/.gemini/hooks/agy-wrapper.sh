#!/usr/bin/env bash
#
# agy-wrapper.sh
# 
# Wraps the Antigravity CLI to ensure Tmux state is cleared gracefully on exit.
# This prevents stale UI states in Tmux when the CLI is closed via /exit or Ctrl+C
# since the native hook sometimes fails to fire during abrupt process termination.

# Setup the trap if we are running inside Tmux
if [ -n "$TMUX_PANE" ]; then
  trap '
    waymux hook tmux SessionEnd </dev/null >/dev/null 2>&1 || true
    waymux hook lazygit Unregister </dev/null >/dev/null 2>&1 || true
    tmux set-option -w -t "'"$TMUX_PANE"'" -u @lazygitrs_icon > /dev/null 2>&1 || true
    tmux set-window-option -t "'"$TMUX_PANE"'" automatic-rename on > /dev/null 2>&1 || true
    tmux refresh-client -S > /dev/null 2>&1 || true
  ' EXIT INT TERM
  tmux rename-window -t "$TMUX_PANE" "$(waymux icon agy)" > /dev/null 2>&1 || true
  # Antigravity opens its prompt draft (Ctrl+G) in $EDITOR only (ignores $VISUAL): route it
  # through ai-prompt so Prefix + v and Ctrl + S stash work even when mise's agy outranks ~/.local/bin/agy.
  if [ -x "$HOME/.local/bin/ai-prompt" ]; then
    export AI_PROMPT_EDITOR="${AI_PROMPT_EDITOR:-$EDITOR}" EDITOR="$HOME/.local/bin/ai-prompt"
  fi
fi

# Execute the actual CLI, passing all arguments transparently
command agy "$@"
