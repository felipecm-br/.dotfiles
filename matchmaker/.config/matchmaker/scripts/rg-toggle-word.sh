#!/bin/sh
# rg-toggle-word.sh — Toggles whole-word mode for the mm rg preset.
# Reads MM_STORE (ic / cs / ww / cs+ww), flips word-regexp,
# then emits Store / SetStyledPrompt / Reload actions to mm Transform.
#
# Called by: ctrl-w bind in rg.toml  (`Transform(sh ~/.config/matchmaker/scripts/rg-toggle-word.sh)`)

MODE="${MM_STORE:-ic}"
case "$MODE" in
  ww)    NEW="ic";    PROMPT="{cyan: rg> }" ;;
  cs)    NEW="cs+ww"; PROMPT="{yellow,bold: rg [Aa][W]> }" ;;
  cs+ww) NEW="cs";    PROMPT="{yellow,bold: rg [Aa]> }" ;;
  *)     NEW="ww";    PROMPT="{cyan: rg [W]> }" ;;
esac

printf 'Store(%s)\n' "$NEW"
printf 'SetStyledPrompt(%s)\n' "$PROMPT"
printf 'Reload\n'
