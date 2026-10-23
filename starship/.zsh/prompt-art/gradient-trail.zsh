#!/usr/bin/env zsh
# gradient-trail: scrollback becomes a timeline. When a command is submitted, zsh-transient-prompt
# collapses the full prompt to a single ❯; this module colors that ❯ by the command's position
# in an OKLab gradient (aquamarine -> sky -> violet -> pink -> amber and back), so scrolling up
# reads as a continuous ribbon. A failed command leaves a crimson ▍✗ <code> mark under its
# output, so errors stand out in the history. The live prompt is not touched.
#
# Requires the zsh-transient-prompt plugin (already loaded by init.zsh).
# Opt-in: source it anywhere after init.zsh, e.g. at the end of ~/.zshrc:
#   source ~/.zsh/prompt-art/gradient-trail.zsh
#
# Settings (set before sourcing):
#   PROMPT_ART_TRAIL_GLYPH   symbol of the collapsed prompt (default ❯)
#   PROMPT_ART_TRAIL_FAIL    0 to skip the failure mark (default 1)
#   PROMPT_ART_TRAIL_COLORS  your own gradient stops (array of #rrggbb)
#
# Pure zsh, no forks: the 24 stops below were sampled in OKLab with
# .agents/skills/starship-glyph-stacking/scripts/gradient.py (#3ee8b5 #4dd2ff #9b6dff #ff6ad5
# #ffb238); every stop is at least 4.8:1 on a #1e1e2e background.

(( ${+_gradient_trail_loaded} )) && return
typeset -g _gradient_trail_loaded=1

typeset -g PROMPT_ART_TRAIL_GLYPH=${PROMPT_ART_TRAIL_GLYPH:-❯}
typeset -g PROMPT_ART_TRAIL_FAIL=${PROMPT_ART_TRAIL_FAIL:-1}
typeset -ga PROMPT_ART_TRAIL_COLORS
(( ${#PROMPT_ART_TRAIL_COLORS} )) || PROMPT_ART_TRAIL_COLORS=(
  '#3ee8b5' '#40e5c3' '#42e1d0' '#44dddd' '#47d9ea' '#4ad5f6'
  '#55ceff' '#6cbeff' '#7cadff' '#889cff' '#918aff' '#9877ff'
  '#a46efc' '#b66ff5' '#c770ee' '#d86fe6' '#ea6edf' '#fb6bd7'
  '#ff77c7' '#ff86b2' '#ff929c' '#ff9e83' '#ffa865' '#ffb238'
)
typeset -g _gradient_trail_idle='#6c7086'  # empty Enter: a dim step that does not advance
typeset -g _gradient_trail_fail='#d01f33'  # same crimson as chroma-reactive's status fire

typeset -gi _gradient_trail_n=0 _gradient_trail_ran=0

# Called by zsh-transient-prompt right before it swaps in the transient prompt.
TRANSIENT_PROMPT_PRETRANSIENT() {
  local color=$_gradient_trail_idle
  if [[ -n ${BUFFER//[[:space:]]/} ]]; then
    # Ping-pong through the stops so the ribbon never jumps from amber back to aquamarine.
    local -i count=${#PROMPT_ART_TRAIL_COLORS} period i
    (( period = count > 1 ? 2 * (count - 1) : 1 ))
    (( i = _gradient_trail_n % period, i = i < count ? i : period - i ))
    color=${PROMPT_ART_TRAIL_COLORS[i + 1]}
    (( _gradient_trail_n++ ))
  fi
  TRANSIENT_PROMPT_TRANSIENT_PROMPT="%F{$color}${PROMPT_ART_TRAIL_GLYPH}%f "
}

_gradient_trail_preexec() {
  _gradient_trail_ran=1
}

# Runs first in precmd so $? is still the command's status, and hands it on unchanged.
_gradient_trail_precmd() {
  local -i st=$?
  if (( _gradient_trail_ran && st && PROMPT_ART_TRAIL_FAIL )); then
    print -P "%F{$_gradient_trail_fail}▍✗ $st%f"
  fi
  _gradient_trail_ran=0
  return st
}

autoload -Uz add-zsh-hook
add-zsh-hook preexec _gradient_trail_preexec
precmd_functions=(_gradient_trail_precmd ${precmd_functions:#_gradient_trail_precmd})
