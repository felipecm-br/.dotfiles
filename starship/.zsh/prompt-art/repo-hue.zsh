#!/usr/bin/env zsh
# repo-hue: every project gets its own color. A hash of the repo picks a hue rotation for the
# active Starship palette (24 steps of 15 degrees), so dotfiles, waymux and lazygitrs each keep a
# fixed tint and you know where you are before reading the path. Lightness is kept, so contrast
# holds. All worktrees of one repo share the hue: a worktree is keyed by its common git dir.
#
# Opt-in: source it after the starship package, e.g. at the end of ~/.zshrc:
#   source ~/.zsh/prompt-art/repo-hue.zsh
#
# Pin a hue (degrees) for a repo by its directory name before sourcing:
#   typeset -gA PROMPT_ART_REPO_HUES=(dotfiles 0 waymux 200)
# Outside a repo the base preset is used (or sky-clock, if also sourced).

source ${${(%):-%x}:A:h}/lib.zsh

typeset -gA PROMPT_ART_REPO_HUES
typeset -g _repo_hue_dir="" _repo_hue_spec=""

# Walk up from $PWD to the first .git (dir or worktree file), builtins only.
_repo_hue_key() {
  local dir=$PWD gitfile
  while [[ -n $dir ]]; do
    if [[ -d $dir/.git ]]; then
      REPLY=$dir
      return 0
    elif [[ -f $dir/.git ]]; then
      gitfile=$(<$dir/.git)
      gitfile=${${gitfile#gitdir: }%%$'\n'*}
      [[ $gitfile != /* ]] && gitfile=$dir/$gitfile
      # <common>/worktrees/<name> -> <common>; the common dir names the project
      REPLY=${gitfile%/worktrees/*}
      return 0
    fi
    [[ $dir == / ]] && break
    dir=${dir:h}
  done
  return 1
}

_repo_hue_resolve() {
  # Recompute only when the directory changes.
  if [[ $PWD == $_repo_hue_dir ]]; then
    REPLY=$_repo_hue_spec
    return
  fi
  _repo_hue_dir=$PWD _repo_hue_spec=""

  _repo_hue_key || { REPLY=""; return 1 }
  local key=$REPLY name
  # Display name: repo dir, or the parent of a bare/common dir (~/.dotfiles/.bare -> .dotfiles)
  name=${key:t}
  [[ $name == (.bare|.git) ]] && name=${key:h:t}
  name=${name#.}

  local -i hue
  if (( ${+PROMPT_ART_REPO_HUES[$name]} )); then
    hue=${PROMPT_ART_REPO_HUES[$name]}
  else
    # FNV-1a over the key, then one of 24 hue steps
    local -i h=2166136261 i
    local c
    for (( i = 1; i <= ${#key}; i++ )); do
      c=${key[i]}
      (( h = ((h ^ #c) * 16777619) & 0xffffffff ))
    done
    (( hue = (h % 24) * 15 ))
  fi

  (( hue % 360 )) && _repo_hue_spec=hue:$(( hue % 360 ))
  REPLY=$_repo_hue_spec
}

prompt_art_resolvers=(_repo_hue_resolve ${prompt_art_resolvers:#_repo_hue_resolve})
