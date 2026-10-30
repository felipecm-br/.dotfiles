#!/usr/bin/env bash
# ai-switch-popup.sh - In-place model / effort switcher for the AI agent in the current pane (Prefix + A)
#
# Thin entry point: `ai-switch --popup` (waymux switch --popup) opens the menu in a popup over the
# pane, titled with the agent and its model; the pick is typed into that agent as its own slash
# command (/model, /effort). Esc closes with no effect; a pane without an agent gets a status-line
# hint instead of an empty popup.

exec "$HOME/.local/bin/ai-switch" --popup "${1:-$TMUX_PANE}"
