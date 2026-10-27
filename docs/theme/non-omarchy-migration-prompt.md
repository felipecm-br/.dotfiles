# Non-Omarchy Theme Migration Prompt

Use the self-contained prompt below with an AI coding agent on any machine running an older clone of `.dotfiles` where Omarchy theme paths (`~/.local/state/omarchy/current/theme/...` or `~/.config/omarchy/current/theme/...`) were previously replaced with custom hardcoded local paths.

---

## Agent Prompt

````markdown
Refactor theme and color resolution across the `tmux`, `awt`, and `zsh-plugins` packages in this GNU Stow `.dotfiles` repository.

### Context
This machine does NOT have Omarchy installed. Previously, hardcoded paths pointing to `~/.local/state/omarchy/current/theme/...` (or `~/.config/omarchy/current/theme/...`) in `tmux.conf`, `tmux/.config/tmux/*.sh`, `awt-popup.sh`, and `zsh-vi-mode-theme.zsh` were manually edited to point to a custom local path.

Migrate this repository to the centralized `theme-helper.sh` architecture (Zero Forks, Single Source of Truth), removing all hardcoded theme paths and inline `grep | sed` pipelines while preserving the machine's custom theme path in `~/.config/tmux/theme.path`.

Follow these exact steps:

---

### STEP 1: Discover and preserve the current custom theme path
1. Inspect `tmux/.config/tmux/tmux.conf`, `zsh-plugins/.zsh/plugins/zsh-vi-mode-theme.zsh`, and `tmux/.config/tmux/*.sh` to identify the custom path currently used for `colors.toml` (or theme directory).
2. If that path is neither `~/.config/tmux/colors.toml` nor the default Omarchy path (`~/.local/state/omarchy/current/theme/colors.toml`), write it (single line, file or directory path) to `~/.config/tmux/theme.path`.
3. Add these entries to `.gitignore` at the repository root (if not already present):
   ```gitignore
   tmux/.config/tmux/theme.path
   tmux/.config/tmux/theme.conf
   ```

---

### STEP 2: Create the centralized theme files

#### 2.1. Create `tmux/.config/tmux/colors.toml`:
```toml
# Static fallback palette for Tmux and dotfiles tools
# Used when Omarchy is not present or when no active system theme is found.
# Default theme: Tokyo Night Dark (high-contrast, WCAG 2.1 AA compliant)

mode = "dark"

accent = "#7aa2f7"
selection = "#292e42"
muted = "#414868"

background = "#1a1b26"
dark_background = "#13141c"
darker_background = "#0e0e14"
lighter_background = "#24283b"

foreground = "#a9b1d6"
dark_foreground = "#565f89"
light_foreground = "#b4bee6"
bright_foreground = "#c0caf5"

red = "#f7768e"
yellow = "#e0af68"
orange = "#eb927b"
green = "#9ece6a"
teal = "#449dab"
cyan = "#449dab"
blue = "#7aa2f7"
magenta = "#ad8ee6"
brown = "#75493d"

bright_red = "#ff7a93"
bright_yellow = "#ff9e64"
bright_green = "#b9f27c"
bright_cyan = "#0db9d7"
bright_blue = "#7da6ff"
bright_magenta = "#bb9af7"

color0 = "#1a1b26"
color1 = "#f7768e"
color2 = "#9ece6a"
color3 = "#e0af68"
color4 = "#7aa2f7"
color5 = "#ad8ee6"
color6 = "#449dab"
color7 = "#a9b1d6"
color8 = "#414868"
color9 = "#ff7a93"
color10 = "#b9f27c"
color11 = "#ff9e64"
color12 = "#7da6ff"
color13 = "#bb9af7"
color14 = "#0db9d7"
color15 = "#c0caf5"
```

#### 2.2. Create `tmux/.config/tmux/theme-helper.sh` (and run `chmod +x`):
```sh
#!/usr/bin/env sh
# theme-helper.sh — Single source of truth for theme resolution & color parsing.
#
# Resolution order:
#   1. Environment variable: $THEME_COLORS_FILE / $TMUX_THEME_COLORS_FILE / $OMARCHY_COLORS_FILE
#   2. Tmux global option:   @theme_colors_file
#   3. Local config file:    ~/.config/tmux/theme.path (accepts file or directory path)
#   4. Omarchy active theme: ~/.local/state/omarchy/current/theme/colors.toml
#   5. Static fallback:      ~/.config/tmux/colors.toml

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
  for _var in "${THEME_COLORS_FILE:-}" "${TMUX_THEME_COLORS_FILE:-}" "${OMARCHY_COLORS_FILE:-}" "${ZVM_OMARCHY_COLORS_FILE:-}"; do
    if _check_theme_path "$_var"; then
      _THEME_IS_CUSTOM=1
      return 0
    fi
  done

  if [ -n "${TMUX:-}" ]; then
    _tmux_opt=$(tmux show-option -gqv @theme_colors_file 2>/dev/null || true)
    if _check_theme_path "$_tmux_opt"; then
      _THEME_IS_CUSTOM=1
      return 0
    fi
  fi

  if [ -f "$HOME/.config/tmux/theme.path" ]; then
    IFS= read -r _cfg_line < "$HOME/.config/tmux/theme.path" 2>/dev/null || true
    _cfg_line="${_cfg_line#"${_cfg_line%%[![:space:]]*}"}"
    _cfg_line="${_cfg_line%"${_cfg_line##*[![:space:]]}"}"
    if _check_theme_path "$_cfg_line"; then
      _THEME_IS_CUSTOM=1
      return 0
    fi
  fi

  if _check_theme_path "$HOME/.local/state/omarchy/current/theme/colors.toml"; then
    return 0
  fi
  if _check_theme_path "$HOME/.config/omarchy/current/theme/colors.toml"; then
    return 0
  fi

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

_resolve_theme_colors_toml
THEME_DIR="${THEME_COLORS_TOML%/*}"
_load_theme_colors

case "${1:-}" in
  --path)
    printf '%s\n' "$THEME_COLORS_TOML"
    exit 0
    ;;
  --apply-tmux)
    if [ "$_THEME_IS_CUSTOM" -eq 0 ] && [ -f "$THEME_DIR/tmux-colors.conf" ]; then
      exit 0
    fi
    if [ -f "$THEME_DIR/tmux-colors.conf" ]; then
      exec tmux source-file "$THEME_DIR/tmux-colors.conf"
    fi
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

TMUX_POPUP_BORDER_COLOR="${_THEME_COLOR_accent:-magenta}"
TMUX_POPUP_TEXT_COLOR="${_THEME_COLOR_color14:-#0db9d7}"
TMUX_POPUP_WIDTH="80%"
TMUX_POPUP_HEIGHT="80%"
TMUX_COLOR_SPEC="list-border:${_THEME_COLOR_color8:-#414868},group-header:${_THEME_COLOR_foreground:-#a9b1d6},selected-prefix:${_THEME_COLOR_accent:-#7aa2f7},selected-fg:${_THEME_COLOR_foreground:-#a9b1d6}"
TMUX_SPINNER_NAME="minidot"
TMUX_SPINNER_COLOR="${_THEME_COLOR_accent:-#7aa2f7}"
```

#### 2.3. Replace `tmux/.config/tmux/tmux-style.sh` with:
```sh
#!/usr/bin/env sh
# tmux-style.sh — delegates to theme-helper.sh (single source of truth for theme & popup styles)
# shellcheck source=/dev/null
. "$HOME/.config/tmux/theme-helper.sh"
```

#### 2.4. Replace `zsh-plugins/.zsh/plugins/zsh-vi-mode-theme.zsh` with:
```zsh
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
```

---

### STEP 3: Refactor existing scripts in the repository

IMPORTANT: Modify ONLY the theme/color resolution logic in the files that exist on this machine, preserving all other script logic (do not alter `mm`/`wm` invocations or unrelated flags).

1. **`tmux/.config/tmux/tmux.conf`:**
   Replace the `source-file .../tmux-colors.conf` line with:
   ```tmux
   # Colors from active theme (Omarchy fast-path + theme-helper.sh for custom/fallback colors.toml)
   source-file -q ~/.local/state/omarchy/current/theme/tmux-colors.conf
   run-shell "~/.config/tmux/theme-helper.sh --apply-tmux"
   ```

2. **`tmux/.config/tmux/flow-telemetry.py` (if present):**
   Add `resolve_colors_toml()`:
   ```python
   def resolve_colors_toml() -> str:
       helper = os.path.join(os.path.dirname(os.path.abspath(__file__)), "theme-helper.sh")
       try:
           res = subprocess.run([helper, "--path"], capture_output=True, text=True, timeout=1)
           if res.returncode == 0 and res.stdout.strip():
               return res.stdout.strip()
       except Exception:
           pass
       return os.path.expanduser("~/.config/tmux/colors.toml")
   ```
   And set `colors_toml = resolve_colors_toml()` inside `load_theme_colors()`.

3. **Scripts in `tmux/.config/tmux/*.sh` and `awt/.config/tmux/awt-popup.sh`:**
   For every script that reads `colors.toml` or `tmux-style.sh`:
   - Ensure `SCRIPT_DIR` is defined at the top of the script and source `. "$SCRIPT_DIR/theme-helper.sh"` BEFORE any `if [ -z "${TMUX_POPUP:-}" ]` block.
   - Remove `_tmux_style=... / . "$_tmux_style"` boilerplate blocks (since `theme-helper.sh` already populates `TMUX_POPUP_BORDER_COLOR`, `TMUX_POPUP_TEXT_COLOR`, `TMUX_COLOR_SPEC`, `TMUX_SPINNER_NAME`, and `TMUX_SPINNER_COLOR`).
   - Replace all inline `grep ... colors.toml | sed ...` pipelines, local `_get_color` functions (`close-session.sh`, `close-window.sh`), and `while IFS='=' read ... < "$_colors_toml"` loops (`cockpit-picker-items.sh`, `cockpit-picker-diff.sh`) with direct calls to `get_theme_color "<key>" "<fallback>"`.
   - In `grep-picker.sh` (`teal|cyan|green`), use:
     `BORDER_COLOR=$(get_theme_color teal "$(get_theme_color cyan "$(get_theme_color green "#94e2d5")")")`
   - In `pr-picker.sh` (if present), keep a comment `# Dynamic theme colors from colors.toml via theme-helper.sh` for test suite compatibility.

---

### STEP 4: Restow and Validate
1. Run `./stow.sh -r tmux` to link `theme-helper.sh` and `colors.toml` into `~/.config/tmux/`.
2. Verify resolution in shell:
   `sh -c '. ~/.config/tmux/theme-helper.sh && echo "Path: $THEME_COLORS_TOML" && echo "Accent: $(get_theme_color accent "#000")"'`
3. Validate syntax across all modified shell scripts with `bash -n` / `sh -n`.
````
