#!/usr/bin/env sh
# pr-picker.sh — GitHub Pull Request review workflow popup in Tmux (Golden Ratio: 75% × 60%)
# Usage: pr-picker.sh ['#{pane_id}'] ['#{pane_current_path}']
set -u

REAL_SCRIPT=$(readlink -f "$0" 2>/dev/null || realpath "$0")

if [ -z "${TMUX_POPUP:-}" ]; then
  # Parse arguments with backwards compatibility
  if [ -n "${1:-}" ] && [ "${1#%}" != "$1" ]; then
    ORIGIN_ARG="$1"
    PROJECT_DIR="${2:-$PWD}"
  else
    ORIGIN_ARG=""
    PROJECT_DIR="${1:-$PWD}"
  fi

  if ! git -C "$PROJECT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1 && ! git -C "$PROJECT_DIR" rev-parse --is-bare-repository >/dev/null 2>&1; then
    if [ -n "${TMUX:-}" ]; then
      tmux display-message "pr-picker: Not inside a Git repository"
    else
      echo "pr-picker: Not inside a Git repository" >&2
    fi
    exit 0
  fi

  SCRIPT_DIR=$(dirname "$REAL_SCRIPT")
  _tmux_style="$HOME/.local/state/omarchy/current/theme/tmux-style.sh"
  [ -f "$_tmux_style" ] || _tmux_style="$SCRIPT_DIR/tmux-style.sh"
  # shellcheck source=/dev/null
  . "$_tmux_style" 2>/dev/null || true
  unset _tmux_style

  PR_POPUP_COLOR=$(grep -E '^\s*blue\s*=' "$HOME/.local/state/omarchy/current/theme/colors.toml" 2>/dev/null | sed -E 's/.*=\s*"([^"]+)".*/\1/')
  [ -z "$PR_POPUP_COLOR" ] && PR_POPUP_COLOR="${TMUX_POPUP_BORDER_COLOR:-#7aa2f7}"

  ISOLATOR="$SCRIPT_DIR/tmux-popup-isolate.sh"
  [ -x "$ISOLATOR" ] || ISOLATOR="$(command -v tmux-popup-isolate.sh 2>/dev/null || echo "$HOME/.config/tmux/tmux-popup-isolate.sh")"

  exec "$ISOLATOR" \
    -S "fg=$PR_POPUP_COLOR" \
    -s "fg=${TMUX_POPUP_TEXT_COLOR:-default}" \
    -b rounded \
    -T "   Pull Requests " \
    -d "$PROJECT_DIR" \
    -w 75% -h 60% \
    -E \
    -- "TMUX_POPUP=1 '$REAL_SCRIPT' '$ORIGIN_ARG' '$PROJECT_DIR'"
fi

[ -n "${TMUX:-}" ] || { echo "pr-picker: not inside tmux" >&2; exit 1; }

ORIGIN="${1:-}"
if [ -z "$ORIGIN" ]; then
  ORIGIN="$(tmux display-message -p -t '{last}' '#{pane_id}' 2>/dev/null || true)"
fi
PROJECT_DIR="${2:-$PWD}"

export MM_ORIGIN_PANE="$ORIGIN"
export MM_ORIGIN_CWD="$PROJECT_DIR"

MM_BIN="$HOME/.local/bin/wm"
[ -x "$MM_BIN" ] || MM_BIN="$(command -v wm 2>/dev/null || command -v mm 2>/dev/null || echo "wm")"

# Prefer pr preset, fallback to awt-pr
if "$MM_BIN" --dump-config -o pr >/dev/null 2>&1; then
  PRESET="pr"
elif "$MM_BIN" --dump-config -o awt-pr >/dev/null 2>&1; then
  PRESET="awt-pr"
elif [ -f "$HOME/.config/waymaker/presets/pr.toml" ]; then
  PRESET="$HOME/.config/waymaker/presets/pr.toml"
else
  PRESET="pr"
fi

output=$(cd "$PROJECT_DIR" && "$MM_BIN" -o "$PRESET" tui.percentage=100 tui.max=9999 2>/dev/null)
[ -z "$output" ] && exit 0

IFS=$'\t' read -r pr_raw head_branch <<< "$output"
pr_num="${pr_raw#\#}"
[ -z "$pr_num" ] && exit 0

# Check out PR in worktree via awt pr <num>
AWT_BIN="$HOME/.local/bin/awt"
[ -x "$AWT_BIN" ] || AWT_BIN="$(command -v awt 2>/dev/null || echo "awt")"

if command -v "$AWT_BIN" >/dev/null 2>&1 || [ -x "$AWT_BIN" ]; then
  exec "$AWT_BIN" pr "$pr_num"
elif [ -x "$HOME/.config/waymaker/scripts/awt-pr.sh" ]; then
  exec "$HOME/.config/waymaker/scripts/awt-pr.sh" "$pr_num"
else
  git -C "$PROJECT_DIR" fetch origin "pull/$pr_num/head:pr/$pr_num" --force 2>/dev/null || true
  git -C "$PROJECT_DIR" checkout "pr/$pr_num" 2>/dev/null || true
fi
