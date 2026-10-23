#!/usr/bin/env sh
# theme-helper.sh — Single source of truth for theme resolution & color parsing.
#
# Resolution order:
#   1. Environment variable: $THEME_COLORS_FILE / $TMUX_THEME_COLORS_FILE / $OMARCHY_COLORS_FILE
#   2. Tmux global option:   @theme_colors_file
#   3. Local config file:    ~/.config/tmux/theme.path (accepts file or directory path)
#   4. Omarchy active theme: ~/.local/state/omarchy/current/theme/colors.toml
#   5. Static fallback:      ~/.config/tmux/colors.toml
#
# Usage (sourced in sh/bash/zsh):
#   . "$HOME/.config/tmux/theme-helper.sh"
#   COLOR=$(get_theme_color "cyan" "#89dceb")
#
# Usage (executed directly):
#   theme-helper.sh --path        # Print resolved colors.toml path
#   theme-helper.sh --apply-tmux  # Apply resolved theme to running tmux server

THEME_COLORS_TOML=""
_THEME_IS_CUSTOM=0

_check_theme_path() {
  [ -n "${1:-}" ] || return 1
  _ctp="$1"
  case "$_ctp" in
    \~*) _ctp="$HOME${_ctp#\~}" ;;
  esac
  if [ -d "$_ctp" ] && [ -f "$_ctp/colors.toml" ]; then
    THEME_COLORS_TOML="$_ctp/colors.toml"
    return 0
  elif [ -f "$_ctp" ]; then
    THEME_COLORS_TOML="$_ctp"
    return 0
  fi
  return 1
}

_resolve_theme_colors_toml() {
  # 1. Environment variables
  for _var in "${THEME_COLORS_FILE:-}" "${TMUX_THEME_COLORS_FILE:-}" "${OMARCHY_COLORS_FILE:-}" "${ZVM_OMARCHY_COLORS_FILE:-}"; do
    if _check_theme_path "$_var"; then
      _THEME_IS_CUSTOM=1
      return 0
    fi
  done

  # 2. Tmux option (@theme_colors_file)
  if [ -n "${TMUX:-}" ]; then
    _tmux_opt=$(tmux show-option -gqv @theme_colors_file 2>/dev/null || true)
    if _check_theme_path "$_tmux_opt"; then
      _THEME_IS_CUSTOM=1
      return 0
    fi
  fi

  # 3. Local config pointer file (~/.config/tmux/theme.path) — zero-fork read
  if [ -f "$HOME/.config/tmux/theme.path" ]; then
    IFS= read -r _cfg_line < "$HOME/.config/tmux/theme.path" 2>/dev/null || true
    _cfg_line="${_cfg_line#"${_cfg_line%%[![:space:]]*}"}"
    _cfg_line="${_cfg_line%"${_cfg_line##*[![:space:]]}"}"
    if _check_theme_path "$_cfg_line"; then
      _THEME_IS_CUSTOM=1
      return 0
    fi
  fi

  # 4. Omarchy active theme
  if _check_theme_path "$HOME/.local/state/omarchy/current/theme/colors.toml"; then
    return 0
  fi
  if _check_theme_path "$HOME/.config/omarchy/current/theme/colors.toml"; then
    return 0
  fi

  # 5. Static dotfiles fallback
  _check_theme_path "$HOME/.config/tmux/colors.toml" || true
}

_load_theme_colors() {
  [ -n "$THEME_COLORS_TOML" ] && [ -f "$THEME_COLORS_TOML" ] || return 0
  while IFS='=' read -r _k _v || [ -n "$_k" ]; do
    case "$_k" in
      ''|\#*) continue ;;
    esac
    _k="${_k#"${_k%%[![:space:]]*}"}"
    _k="${_k%"${_k##*[![:space:]]}"}"
    case "$_k" in
      ''|*[!a-zA-Z0-9_]*) continue ;;
    esac
    _v="${_v#*\"}"
    _v="${_v%%\"*}"
    _v="${_v#*\'}"
    _v="${_v%%\'*}"
    _v="${_v#"${_v%%[![:space:]]*}"}"
    _v="${_v%"${_v##*[![:space:]]}"}"
    eval "_THEME_COLOR_${_k}=\"\$_v\""
  done < "$THEME_COLORS_TOML"

  # Normalize ANSI color0..15 <-> semantic names so both schemas work transparently
  : "${_THEME_COLOR_color0:=${_THEME_COLOR_background:-}}"
  : "${_THEME_COLOR_color1:=${_THEME_COLOR_red:-}}"
  : "${_THEME_COLOR_color2:=${_THEME_COLOR_green:-}}"
  : "${_THEME_COLOR_color3:=${_THEME_COLOR_yellow:-}}"
  : "${_THEME_COLOR_color4:=${_THEME_COLOR_blue:-}}"
  : "${_THEME_COLOR_color5:=${_THEME_COLOR_magenta:-}}"
  : "${_THEME_COLOR_color6:=${_THEME_COLOR_cyan:-}}"
  : "${_THEME_COLOR_color7:=${_THEME_COLOR_foreground:-}}"
  : "${_THEME_COLOR_color8:=${_THEME_COLOR_muted:-}}"
  : "${_THEME_COLOR_color9:=${_THEME_COLOR_bright_red:-${_THEME_COLOR_red:-}}}"
  : "${_THEME_COLOR_color10:=${_THEME_COLOR_bright_green:-${_THEME_COLOR_green:-}}}"
  : "${_THEME_COLOR_color11:=${_THEME_COLOR_bright_yellow:-${_THEME_COLOR_yellow:-}}}"
  : "${_THEME_COLOR_color12:=${_THEME_COLOR_bright_blue:-${_THEME_COLOR_blue:-}}}"
  : "${_THEME_COLOR_color13:=${_THEME_COLOR_bright_magenta:-${_THEME_COLOR_magenta:-}}}"
  : "${_THEME_COLOR_color14:=${_THEME_COLOR_bright_cyan:-${_THEME_COLOR_cyan:-}}}"
  : "${_THEME_COLOR_color15:=${_THEME_COLOR_bright_foreground:-${_THEME_COLOR_foreground:-}}}"
}

get_theme_colors_toml() {
  printf '%s' "$THEME_COLORS_TOML"
}

get_theme_color() {
  _gtc_val=""
  case "${1:-}" in
    ''|*[!a-zA-Z0-9_]*) ;;
    *) eval "_gtc_val=\"\${_THEME_COLOR_${1}:-}\"" ;;
  esac
  printf '%s' "${_gtc_val:-${2:-}}"
}

# popup_gradient_flags VAR — display-popup flags for an app that draws its own
# gradient frame: "-B -e VAR=<palette>" while `border-gradient` is on, and
# "-e VAR=" when off (an empty value also overrides a gradient set in the app's
# own config, e.g. lazygitrs gui.borderGradient). Expand it unquoted inside the
# display-popup call:
#   tmux display-popup $(popup_gradient_flags WM_BORDER_GRADIENT) ...
popup_gradient_flags() {
  border_gradient_palette
  if [ -n "$BORDER_GRADIENT_PALETTE" ]; then
    printf -- '-B -e %s=%s' "$1" "$BORDER_GRADIENT_PALETTE"
  else
    printf -- '-e %s=' "$1"
  fi
}

# border_gradient_palette — sets BORDER_GRADIENT_PALETTE to the active palette
# while `border-gradient` is on, empty when off (zero forks).
border_gradient_palette() {
  _bgp_state=""
  BORDER_GRADIENT_PALETTE=""
  [ -r "${XDG_STATE_HOME:-$HOME/.local/state}/border-gradient/state" ] \
    && read -r _bgp_state BORDER_GRADIENT_PALETTE < "${XDG_STATE_HOME:-$HOME/.local/state}/border-gradient/state"
  [ "$_bgp_state" = "on" ] || BORDER_GRADIENT_PALETTE=""
  return 0
}

_resolve_theme_colors_toml
THEME_DIR="${THEME_COLORS_TOML%/*}"
_load_theme_colors

# Direct CLI execution modes
case "${1:-}" in
  --path)
    printf '%s\n' "$THEME_COLORS_TOML"
    exit 0
    ;;
  --apply-tmux)
    # If using Omarchy's default theme and tmux-colors.conf exists, source-file -q in tmux.conf already loaded it
    if [ "$_THEME_IS_CUSTOM" -eq 0 ] && [ -f "$THEME_DIR/tmux-colors.conf" ]; then
      exit 0
    fi
    if [ -f "$THEME_DIR/tmux-colors.conf" ]; then
      exec tmux source-file "$THEME_DIR/tmux-colors.conf"
    fi
    # Otherwise, derive and apply all tmux color options directly from colors.toml
    _c_bg=$(get_theme_color background "#1a1b26")
    _c_fg=$(get_theme_color foreground "#a9b1d6")
    _c_accent=$(get_theme_color accent "#7aa2f7")
    _c_c3=$(get_theme_color color3 "#e0af68")
    _c_c4=$(get_theme_color color4 "#7aa2f7")
    _c_c8=$(get_theme_color color8 "#414868")
    _c_c13=$(get_theme_color color13 "#bb9af7")
    _c_c14=$(get_theme_color color14 "#0db9d7")
    exec tmux \
      set -g message-command-style "bg=default,fg=$_c_c3" \; \
      set -g message-style "bg=default,fg=$_c_c3" \; \
      set -g mode-style "bg=default,fg=$_c_c3" \; \
      set -g status-style "bg=default,fg=$_c_fg" \; \
      set -g pane-border-style "fg=$_c_c8,bg=default" \; \
      set -g @CURRENT_COLOR "$_c_c14" \; \
      set -g @PREFIX_COLOR "$_c_c13" \; \
      set -g @COPY_COLOR "$_c_c3" \; \
      set -g @SESSION_COLOR "$_c_c4" \; \
      set -g @SESSION_ACTIVE_FG "$_c_bg" \; \
      set -g @HOST_COLOR "$_c_c4" \; \
      set -g @ACTIVE_BORDER_COLOR "$_c_c4" \; \
      set -g @SEGMENT_BG "$_c_c8" \; \
      set -g @FG "$_c_fg" \; \
      set -g @ACCENT_COLOR "$_c_accent" \; \
      set -g @POPUP_BORDER_COLOR "$_c_accent" \; \
      set -g @POPUP_TEXT_COLOR "$_c_c14" \; \
      set -g popup-style "bg=default,fg=default" \; \
      set -g popup-border-style "fg=$_c_accent,bg=default"
    ;;
esac

# Populate tmux-style variables directly from parsed colors (zero forks)
TMUX_POPUP_BORDER_COLOR="${_THEME_COLOR_accent:-magenta}"
TMUX_POPUP_TEXT_COLOR="${_THEME_COLOR_color14:-#0db9d7}"
TMUX_POPUP_WIDTH="80%"
TMUX_POPUP_HEIGHT="80%"
TMUX_COLOR_SPEC="list-border:${_THEME_COLOR_color8:-#414868},group-header:${_THEME_COLOR_foreground:-#a9b1d6},selected-prefix:${_THEME_COLOR_accent:-#7aa2f7},selected-fg:${_THEME_COLOR_foreground:-#a9b1d6}"
TMUX_SPINNER_NAME="minidot"
TMUX_SPINNER_COLOR="${_THEME_COLOR_accent:-#7aa2f7}"
