#!/usr/bin/env bash
PROJECT_DIR=""
OPEN_COMMITS=0

for arg in "$@"; do
    case "$arg" in
        --commits)
            OPEN_COMMITS=1
            ;;
        *)
            if [ -z "$PROJECT_DIR" ]; then
                PROJECT_DIR="$arg"
            fi
            ;;
    esac
done

[ -z "$PROJECT_DIR" ] && PROJECT_DIR="."

if ! git -C "$PROJECT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    tmux display-message "Not in a git repository"
    exit 0
fi

if [ "$OPEN_COMMITS" -eq 0 ]; then
    # Smart detection: if working tree is clean, auto-switch to commits
    if [ -z "$(git -C "$PROJECT_DIR" status --porcelain 2>/dev/null)" ]; then
        OPEN_COMMITS=1
    fi
fi

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
_tmux_style="$HOME/.local/state/omarchy/current/theme/tmux-style.sh"
[ -f "$_tmux_style" ] || _tmux_style="$SCRIPT_DIR/tmux-style.sh"
# shellcheck source=/dev/null
. "$_tmux_style" 2>/dev/null || true
unset _tmux_style

LZG_BIN="$HOME/.cargo/bin/lazygitrs"
[ -x "$LZG_BIN" ] || LZG_BIN="$(command -v lazygitrs 2>/dev/null || echo "lazygitrs")"

LZG_CMD="$LZG_BIN -d -c popup"
if [ "$OPEN_COMMITS" -eq 1 ]; then
    LZG_CMD="$LZG_CMD --commits"
fi

GIT_POPUP_COLOR=$(grep -E '^\s*orange\s*=' "$HOME/.local/state/omarchy/current/theme/colors.toml" 2>/dev/null | sed -E 's/.*=\s*"([^"]+)".*/\1/')
[ -z "$GIT_POPUP_COLOR" ] && GIT_POPUP_COLOR="#e84d31"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ISOLATOR="$SCRIPT_DIR/tmux-popup-isolate.sh"
[ -x "$ISOLATOR" ] || ISOLATOR="$(command -v tmux-popup-isolate.sh 2>/dev/null || echo "$HOME/.config/tmux/tmux-popup-isolate.sh")"

exec "$ISOLATOR" \
  -S "fg=$GIT_POPUP_COLOR" \
  -s "fg=${TMUX_POPUP_TEXT_COLOR:-default}" \
  -b rounded \
  -T " 󰊢 " \
  -d "$PROJECT_DIR" \
  -E \
  -w 90% -h 88% \
  -- "$LZG_CMD"
