#!/usr/bin/env zsh
# prompt-art shared core: picks a recolored variant of the active Starship config before each
# prompt and points STARSHIP_CONFIG at it. Sourced by sky-clock.zsh and repo-hue.zsh; not
# meant to be sourced on its own.
#
# Each module registers a resolver in prompt_art_resolvers. Before every prompt the resolvers
# run in order and the first one that sets REPLY (e.g. "hue:135" or "sky:dusk") wins; when none
# does, the base config is used unchanged. repo-hue goes first, so a repo keeps its color and
# sky-clock tints everything outside repos.
#
# Cost per prompt: a few builtin file tests. prompt-palette-transform (python) runs only when a
# variant is missing or older than the base config, e.g. right after picking a new preset.

(( ${+_prompt_art_loaded} )) && return
typeset -g _prompt_art_loaded=1

typeset -g PROMPT_ART_BASE_CONFIG=${PROMPT_ART_BASE_CONFIG:-${STARSHIP_CONFIG:-$HOME/.local/state/omarchy/current/theme/starship.toml}}
typeset -g PROMPT_ART_CACHE=${PROMPT_ART_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/prompt-art}
typeset -ga prompt_art_resolvers

autoload -Uz add-zsh-hook

_prompt_art_precmd() {
  local fn spec="" variant
  for fn in $prompt_art_resolvers; do
    REPLY=""
    $fn && [[ -n $REPLY ]] && { spec=$REPLY; break }
  done

  if [[ -z $spec || ! -r $PROMPT_ART_BASE_CONFIG ]]; then
    export STARSHIP_CONFIG=$PROMPT_ART_BASE_CONFIG
    return
  fi

  variant=$PROMPT_ART_CACHE/${spec/:/-}.toml
  if [[ ! -f $variant || $PROMPT_ART_BASE_CONFIG -nt $variant ]]; then
    command prompt-palette-transform --${spec%%:*} ${spec#*:} "$PROMPT_ART_BASE_CONFIG" "$variant" 2>/dev/null || {
      export STARSHIP_CONFIG=$PROMPT_ART_BASE_CONFIG
      return
    }
  fi
  export STARSHIP_CONFIG=$variant
}

add-zsh-hook precmd _prompt_art_precmd

# prompt-art [status|off|clear-cache]
prompt-art() {
  case ${1:-status} in
    status)
      print "base:      $PROMPT_ART_BASE_CONFIG"
      print "active:    $STARSHIP_CONFIG"
      print "resolvers: ${prompt_art_resolvers:-none}"
      ;;
    off)
      add-zsh-hook -d precmd _prompt_art_precmd
      export STARSHIP_CONFIG=$PROMPT_ART_BASE_CONFIG
      print "prompt-art: off for this shell (base config restored)"
      ;;
    clear-cache)
      [[ -d $PROMPT_ART_CACHE ]] && command rm -f -- $PROMPT_ART_CACHE/*.toml(N)
      ;;
    *)
      print -u2 "usage: prompt-art [status|off|clear-cache]"
      return 2
      ;;
  esac
}
