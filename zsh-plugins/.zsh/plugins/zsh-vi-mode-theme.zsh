# Dynamic theme colors for zsh-vi-mode prompt indicator
# Resolves colors via theme-helper.sh (supports ZVM_OMARCHY_COLORS_FILE, THEME_COLORS_FILE,
# ~/.config/tmux/theme.path, Omarchy active theme, and ~/.config/tmux/colors.toml fallback).

if [[ -f "$HOME/.config/tmux/theme-helper.sh" ]]; then
  source "$HOME/.config/tmux/theme-helper.sh"
  : ${ZVM_VI_MODE_INSERT_COLOR:=$(get_theme_color color2 "#9ece6a")}
  : ${ZVM_VI_MODE_NORMAL_COLOR:=$(get_theme_color accent "#7aa2f7")}
  : ${ZVM_VI_MODE_VISUAL_COLOR:=$(get_theme_color color5 "#ad8ee6")}
else
  : ${ZVM_VI_MODE_INSERT_COLOR:=#9ece6a}
  : ${ZVM_VI_MODE_NORMAL_COLOR:=#7aa2f7}
  : ${ZVM_VI_MODE_VISUAL_COLOR:=#ad8ee6}
fi
