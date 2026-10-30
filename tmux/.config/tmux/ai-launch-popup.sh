#!/usr/bin/env bash
# ai-launch-popup.sh - Floating AI agent launcher (CLI × model menu with live quota)
#
# Thin entry point: `ai-launch --popup` (waymux launch --popup) opens the `ai-launch` menu in a
# popup; the choice starts in a new window of the originating session, rooted at the pane's
# directory, through ai-launch's jail hooks. Esc closes the popup with no side effect.

exec "$HOME/.local/bin/ai-launch" --popup "${1:-$PWD}"
