#!/bin/sh
# rg-toggle-case.sh — Toggles match-case mode for the mm rg preset.
# Reads MM_STORE (ic / cs / ww / cs+ww), flips case-sensitivity,
# then emits Store / SetStyledPrompt / Reload actions to mm Transform.
#
# Called by: ctrl-s bind in rg.toml  (`Transform(sh ~/.config/matchmaker/scripts/rg-toggle-case.sh)`)

MODE="${MM_STORE:-ic}"
case "$MODE" in
  cs)    NEW="ic";    PROMPT="{cyan: rg> }" ;;
  ww)    NEW="cs+ww"; PROMPT="{yellow,bold: rg [Aa][W]> }" ;;
  cs+ww) NEW="ww";    PROMPT="{cyan: rg [W]> }" ;;
  *)     NEW="cs";    PROMPT="{yellow,bold: rg [Aa]> }" ;;
esac

printf 'Store(%s)\n' "$NEW"
printf 'SetStyledPrompt(%s)\n' "$PROMPT"
printf 'Reload\n'
