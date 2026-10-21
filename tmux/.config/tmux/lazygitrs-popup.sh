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
    # Smart detection: fast check if working tree is clean, auto-switch to commits
    if git -C "$PROJECT_DIR" diff --quiet 2>/dev/null && \
       git -C "$PROJECT_DIR" diff --cached --quiet 2>/dev/null && \
       [ -z "$(git -C "$PROJECT_DIR" ls-files --others --exclude-standard 2>/dev/null | head -n1)" ]; then
        OPEN_COMMITS=1
    fi
fi

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=/dev/null
. "$SCRIPT_DIR/theme-helper.sh"

resolve_lzg() {
    local candidate
    for candidate in "$HOME/.local/bin/lazygitrs" "$(command -v lazygitrs 2>/dev/null)" "$HOME/.cargo/bin/lazygitrs"; do
        [ -n "$candidate" ] && [ -x "$candidate" ] || continue
        if "$candidate" --help 2>&1 | grep -q -- '--commits'; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    return 1
}

LZG_BIN="$(resolve_lzg)" || {
    tmux display-message "lazygitrs with --commits support not found in PATH"
    exit 0
}

LZG_CMD="$LZG_BIN -d -c popup"
if [ "$OPEN_COMMITS" -eq 1 ]; then
    LZG_CMD="$LZG_CMD --commits"
fi

GIT_POPUP_COLOR=$(get_theme_color orange "#e84d31")

FLOW_LOG="$SCRIPT_DIR/flow-log.sh"
[ -x "$FLOW_LOG" ] || FLOW_LOG="$(command -v flow-log 2>/dev/null || echo "$HOME/.config/tmux/flow-log.sh")"

[ -x "$FLOW_LOG" ] && "$FLOW_LOG" review_start "$PROJECT_DIR" >/dev/null 2>&1 || true

# Lines under review (uncommitted changes, or the HEAD commit when the tree is clean), so
# flow-telemetry can report a review rate in lines per minute.
if [ "$OPEN_COMMITS" -eq 1 ]; then
    REVIEW_STAT=$(git -C "$PROJECT_DIR" show --shortstat --format= HEAD 2>/dev/null)
else
    REVIEW_STAT=$(git -C "$PROJECT_DIR" diff --shortstat HEAD 2>/dev/null)
fi
REVIEW_LINES=$(printf '%s\n' "$REVIEW_STAT" | awk '{for (i = 1; i < NF; i++) if ($(i + 1) ~ /^(insertion|deletion)/) n += $i} END {print n + 0}')
[ -x "$FLOW_LOG" ] && "$FLOW_LOG" review_size "$PROJECT_DIR" "$REVIEW_LINES" >/dev/null 2>&1 || true

# Opening the review clears the Cockpit's "done, not reviewed" state for this worktree.
REVIEW_GIT_DIR=$(git -C "$PROJECT_DIR" rev-parse --absolute-git-dir 2>/dev/null) && : > "$REVIEW_GIT_DIR/waymux-reviewed"

ORIGIN_SESSION=$(tmux display-message -p '#{session_name}' 2>/dev/null || echo "")
ORIGIN_WINDOW=$(tmux display-message -p '#{window_index}' 2>/dev/null || echo "")
ORIGIN_PANE=$(tmux display-message -p '#{pane_id}' 2>/dev/null || echo "")

tmux display-popup \
  -S "fg=$GIT_POPUP_COLOR" \
  -s "fg=${TMUX_POPUP_TEXT_COLOR:-default}" \
  -b rounded \
  -T " 󰊢 " \
  -d "$PROJECT_DIR" \
  -E \
  -w 90% -h 88% \
  "TMUX_ORIGIN_SESSION='$ORIGIN_SESSION' TMUX_ORIGIN_PANE='$ORIGIN_PANE' TMUX_ORIGIN_WINDOW='$ORIGIN_WINDOW' $LZG_CMD"
rc=$?

[ -x "$FLOW_LOG" ] && "$FLOW_LOG" review_end "$PROJECT_DIR" >/dev/null 2>&1 || true
exit $rc
