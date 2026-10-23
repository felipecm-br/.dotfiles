#!/usr/bin/env zsh
# sky-clock: the active Starship preset follows the real sky. Its palette is tinted by the hour:
# moonlit blue at night, rose at dawn, untouched in the morning, most vivid at noon, amber in the
# golden hour and violet at dusk. Works with any preset picked in omarchy-starship-preset.
#
# Opt-in: source it after the starship package, e.g. at the end of ~/.zshrc:
#   source ~/.zsh/prompt-art/sky-clock.zsh
#
# Tune the bands with PROMPT_ART_SKY_BANDS ("start_hour:band", ascending) before sourcing.
# Inside a git repo repo-hue (if also sourced) wins over the sky.

source ${${(%):-%x}:A:h}/lib.zsh

zmodload -F zsh/datetime b:strftime p:EPOCHSECONDS

typeset -ga PROMPT_ART_SKY_BANDS
(( ${#PROMPT_ART_SKY_BANDS} )) || PROMPT_ART_SKY_BANDS=(
  0:night
  5:dawn
  8:morning
  11:noon
  15:golden
  18:dusk
  21:night
)

_sky_clock_resolve() {
  local hour
  local entry band=night
  strftime -s hour %H $EPOCHSECONDS
  hour=${hour#0}
  for entry in $PROMPT_ART_SKY_BANDS; do
    (( hour >= ${entry%%:*} )) && band=${entry#*:}
  done
  REPLY=sky:$band
}

prompt_art_resolvers=(${prompt_art_resolvers:#_sky_clock_resolve} _sky_clock_resolve)
