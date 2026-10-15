#!/usr/bin/env sh
# cockpit-picker.sh — Fleet & Window Cockpit HUD powered by Matchmaker
# Displays prioritized agent states, waiting age, git branch/churn, and contextual previews.

REAL_SCRIPT=$(readlink -f "$0" 2>/dev/null || realpath "$0")

if [ "$1" = "--fullscreen" ]; then
  if ! [ -t 1 ]; then
    exec tmux split-window -Z "$REAL_SCRIPT" --fullscreen
  fi
elif [ -z "${TMUX_POPUP:-}" ]; then
  ORIG_SESS=$(tmux display-message -p '#{session_name}')
  ORIG_WIN=$(tmux display-message -p '#{window_index}')
  export TMUX_ORIGIN_SESSION="$ORIG_SESS"
  export TMUX_ORIGIN_WINDOW="$ORIG_WIN"

  COCKPIT_POPUP_COLOR=$(grep -E '^\s*orange\s*=' "$HOME/.local/state/omarchy/current/theme/colors.toml" 2>/dev/null | sed -E 's/.*=\s*"([^"]+)".*/\1/')
  [ -z "$COCKPIT_POPUP_COLOR" ] && COCKPIT_POPUP_COLOR="#e09d7f"

  exec tmux display-popup \
    -S "fg=$COCKPIT_POPUP_COLOR" \
    -s "fg=${TMUX_POPUP_TEXT_COLOR:-default}" \
    -b rounded \
    -T " 󱂬 " \
    -w 85% -h 75% \
    -E \
    "TMUX_POPUP=1 TMUX_ORIGIN_SESSION='$ORIG_SESS' TMUX_ORIGIN_WINDOW='$ORIG_WIN' '$REAL_SCRIPT'"
fi

SCRIPT_DIR=$(dirname "$REAL_SCRIPT")
ITEMS_SCRIPT="${SCRIPT_DIR}/cockpit-picker-items.sh"
_tmux_style="$HOME/.local/state/omarchy/current/theme/tmux-style.sh"
[ -f "$_tmux_style" ] || _tmux_style="${SCRIPT_DIR}/tmux-style.sh"
# shellcheck source=/dev/null
. "$_tmux_style" 2>/dev/null || true
unset _tmux_style

ACPD_SPINNER=$(tmux show-option -gqv @ai_agent_spinner 2>/dev/null)
[ -z "$ACPD_SPINNER" ] && ACPD_SPINNER="minidot"
TMUX_SPINNER_NAME="$ACPD_SPINNER"

ORIG_SESS="${TMUX_ORIGIN_SESSION:-$(tmux display-message -p '#S')}"
ORIG_WIN="${TMUX_ORIGIN_WINDOW:-$(tmux display-message -p '#I')}"

SAVED_SESS=""
SAVED_IDX=""

while true; do
  ITEMS=$("$ITEMS_SCRIPT" "$ORIG_SESS" "$ORIG_WIN")

  START_IDX=""
  if [ -n "$SAVED_SESS" ]; then
    if [ -n "$SAVED_IDX" ] && [ "$SAVED_IDX" != "-" ]; then
      START_IDX=$(printf '%s\n' "$ITEMS" | awk -F'\t' -v s="$SAVED_SESS" -v i="$SAVED_IDX" '
        BEGIN { n = 0 }
        !/^#/ {
          if ($4 == s && $2 == i) {
            print n
            exit
          }
          n++
        }
      ')
    else
      START_IDX=$(printf '%s\n' "$ITEMS" | awk -F'\t' -v s="$SAVED_SESS" '
        BEGIN { n = 0 }
        !/^#/ {
          if ($4 == s) {
            print n
            exit
          }
          n++
        }
      ')
    fi
    SAVED_SESS=""
    SAVED_IDX=""
  fi

  if [ -z "$START_IDX" ]; then
    # Adaptive start position:
    # If an agent needs urgent attention (permission 󱅭 or question 󱜻), start at top (index 0).
    # Otherwise, focus on the current active window (row containing •).
    has_urgent=$(printf '%s\n' "$ITEMS" | grep -m1 -E '(󱅭|󱜻)' || true)
    if [ -n "$has_urgent" ]; then
      START_IDX=0
    else
      START_IDX=$(printf '%s\n' "$ITEMS" | awk 'BEGIN { n = 0 } !/^#/ { if ($0 ~ /•/) { print n; exit } n++ }')
      [ -z "$START_IDX" ] && START_IDX=0
    fi
  fi

  MM_BIN="$HOME/.local/bin/wm"
  [ -x "$MM_BIN" ] || MM_BIN="$(command -v wm 2>/dev/null || command -v mm 2>/dev/null || echo "wm")"

  chosen=$(printf '%s\n' "$ITEMS" | "$MM_BIN" \
    -o "$SCRIPT_DIR/cockpit-picker.toml" \
    "start.cmd=$ITEMS_SCRIPT" \
    results.spinner="$TMUX_SPINNER_NAME" \
    --pos "$START_IDX" \
    --color "spinner:$TMUX_SPINNER_COLOR" \
    --color "$TMUX_COLOR_SPEC" \
    --group-prefix '#')

  case "$chosen" in
    __CREATE_WINDOW__*)
      raw_item="${chosen#__CREATE_WINDOW__}"
      new_target=$(printf '%s\n' "$raw_item" | "$SCRIPT_DIR/window-picker-create.sh")
      if [ -n "$new_target" ]; then
        tmux switch-client -t "$new_target" 2>/dev/null || true
      fi
      exit 0
      ;;
  __NEW_WORKTREE__*)
    raw_item="${chosen#__NEW_WORKTREE__}"
    first_line=$(printf '%s' "$raw_item" | head -n1)
    target_path=""

    row_path=$(printf '%s' "$first_line" | cut -f6)
    if [ -n "$row_path" ] && [ -d "$row_path" ]; then
      target_path="$row_path"
    fi

    if [ -z "$target_path" ]; then
      sess=$(printf '%s' "$first_line" | cut -f4)
      if [ -z "$sess" ] || [ "$sess" = "$first_line" ]; then
        sess=$(printf '%s' "$first_line" | sed -E 's/^#[[:space:]]*//')
      fi
      if [ -n "$sess" ]; then
        target_path=$(tmux display-message -t "${sess}:" -p '#{pane_current_path}' 2>/dev/null || true)
      fi
    fi

    if [ -z "$target_path" ] || [ ! -d "$target_path" ]; then
      target_path="${TMUX_ORIGIN_SESSION:+$(tmux display-message -t "${TMUX_ORIGIN_SESSION}:" -p '#{pane_current_path}' 2>/dev/null || true)}"
    fi
    [ -z "$target_path" ] && target_path="$PWD"

    if ! git -C "$target_path" rev-parse --is-inside-work-tree >/dev/null 2>&1 && ! git -C "$target_path" rev-parse --is-bare-repository >/dev/null 2>&1; then
      tmux display-message "Not in a git repository: $target_path"
      exit 0
    fi

    AWT_BIN=$(command -v awt 2>/dev/null || echo "$HOME/.local/bin/awt")
    cd "$target_path" || true
    exec "$AWT_BIN" new
    ;;
  __SHIP_WORKTREE__*)
    raw_item="${chosen#__SHIP_WORKTREE__}"
    first_line=$(printf '%s' "$raw_item" | head -n1)
    target_path=""

    row_path=$(printf '%s' "$first_line" | cut -f6)
    if [ -n "$row_path" ] && [ -d "$row_path" ]; then
      target_path="$row_path"
    fi

    if [ -z "$target_path" ]; then
      sess=$(printf '%s' "$first_line" | cut -f4)
      if [ -z "$sess" ] || [ "$sess" = "$first_line" ]; then
        sess=$(printf '%s' "$first_line" | sed -E 's/^#[[:space:]]*//')
      fi
      if [ -n "$sess" ]; then
        target_path=$(tmux display-message -t "${sess}:" -p '#{pane_current_path}' 2>/dev/null || true)
      fi
    fi

    if [ -z "$target_path" ] || [ ! -d "$target_path" ]; then
      target_path="${TMUX_ORIGIN_SESSION:+$(tmux display-message -t "${TMUX_ORIGIN_SESSION}:" -p '#{pane_current_path}' 2>/dev/null || true)}"
    fi
    [ -z "$target_path" ] && target_path="$PWD"

    if ! git -C "$target_path" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      tmux display-message "Not in a git repository: $target_path"
      exit 0
    fi

    branch=$(git -C "$target_path" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
    if [ -z "$branch" ] || [ "$branch" = "main" ] || [ "$branch" = "master" ] || [ "$branch" = "HEAD" ]; then
      tmux display-message "Cannot ship default branch '$branch' (not a feature worktree)"
      exit 0
    fi

    AWT_BIN=$(command -v awt 2>/dev/null || echo "$HOME/.local/bin/awt")
    cd "$target_path" || true
    exec "$AWT_BIN" ship "$branch"
    ;;
  __SWEEP_WORKTREES__*)
    raw_item="${chosen#__SWEEP_WORKTREES__}"
    first_line=$(printf '%s' "$raw_item" | head -n1)
    target_path=""

    row_path=$(printf '%s' "$first_line" | cut -f6)
    if [ -n "$row_path" ] && [ -d "$row_path" ]; then
      target_path="$row_path"
    fi

    if [ -z "$target_path" ]; then
      sess=$(printf '%s' "$first_line" | cut -f4)
      if [ -z "$sess" ] || [ "$sess" = "$first_line" ]; then
        sess=$(printf '%s' "$first_line" | sed -E 's/^#[[:space:]]*//')
      fi
      if [ -n "$sess" ]; then
        target_path=$(tmux display-message -t "${sess}:" -p '#{pane_current_path}' 2>/dev/null || true)
      fi
    fi

    if [ -z "$target_path" ] || [ ! -d "$target_path" ]; then
      target_path="${TMUX_ORIGIN_SESSION:+$(tmux display-message -t "${TMUX_ORIGIN_SESSION}:" -p '#{pane_current_path}' 2>/dev/null || true)}"
    fi
    [ -z "$target_path" ] && target_path="$PWD"

    AWT_BIN=$(command -v awt 2>/dev/null || echo "$HOME/.local/bin/awt")
    cd "$target_path" || true
    exec "$AWT_BIN" sweep
    ;;
  __REAP_AGENTS__*)
    target_path="${TMUX_ORIGIN_SESSION:+$(tmux display-message -t "${TMUX_ORIGIN_SESSION}:" -p '#{pane_current_path}' 2>/dev/null || true)}"
    [ -z "$target_path" ] && target_path="$PWD"

    AWT_BIN=$(command -v awt 2>/dev/null || echo "$HOME/.local/bin/awt")
    cd "$target_path" || true
    exec "$AWT_BIN" reap
    ;;
  __LAZYGIT__*)
    raw_item="${chosen#__LAZYGIT__}"
    first_line=$(printf '%s' "$raw_item" | head -n1)
    target_path=""

    case "$first_line" in
      \#*)
        target_sess=$(printf '%s' "$first_line" | sed -E 's/^#[[:space:]]*//' | awk '{print $1}')
        target_idx=""
        target_path=""
        ;;
      *)
        target_sess=$(printf '%s' "$first_line" | cut -f4)
        target_idx=$(printf '%s' "$first_line" | cut -f2)
        row_path=$(printf '%s' "$first_line" | cut -f6)
        if [ -n "$row_path" ] && [ -d "$row_path" ]; then
          target_path="$row_path"
        fi
        ;;
    esac

    # If target_path not resolved from row: resolve session cwd
    if [ -z "$target_path" ] && [ -n "$target_sess" ]; then
      target_path=$(tmux display-message -t "${target_sess}:" -p '#{pane_current_path}' 2>/dev/null || true)
    fi

    # Fallback to origin session cwd or current directory
    if [ -z "$target_path" ] || [ ! -d "$target_path" ]; then
      target_path="${TMUX_ORIGIN_SESSION:+$(tmux display-message -t "${TMUX_ORIGIN_SESSION}:" -p '#{pane_current_path}' 2>/dev/null || true)}"
    fi
    if [ -z "$target_path" ] || [ ! -d "$target_path" ]; then
      target_path="$PWD"
    fi

    if ! git -C "$target_path" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      tmux display-message "Not in a git repository: $target_path"
      exit 0
    fi

    LZG_BIN="$HOME/.local/bin/lazygitrs"
    [ -x "$LZG_BIN" ] || LZG_BIN="$HOME/.cargo/bin/lazygitrs"
    [ -x "$LZG_BIN" ] || LZG_BIN="$(command -v lazygitrs 2>/dev/null || echo "lazygitrs")"

    open_commits=0
    if [ -z "$(git -C "$target_path" status --porcelain 2>/dev/null)" ]; then
      open_commits=1
    fi

    SAVED_SESS="$target_sess"
    SAVED_IDX="$target_idx"

    (
      cd "$target_path" || exit 1
      export LAZYGITRS_COCKPIT=1
      if [ "$open_commits" -eq 1 ]; then
        "$LZG_BIN" -d -c popup --commits
      else
        "$LZG_BIN" -d -c popup
      fi
    )
    lzg_rc=$?

    if [ "$lzg_rc" -eq 10 ]; then
      continue
    fi
    exit 0
    ;;
  __SWITCH_AWT__*)
    raw_item="${chosen#__SWITCH_AWT__}"
    first_line=$(printf '%s' "$raw_item" | head -n1)
    target_path=""

    row_path=$(printf '%s' "$first_line" | cut -f6)
    if [ -n "$row_path" ] && [ -d "$row_path" ]; then
      target_path="$row_path"
    fi

    if [ -z "$target_path" ]; then
      sess=$(printf '%s' "$first_line" | cut -f4)
      if [ -z "$sess" ] || [ "$sess" = "$first_line" ]; then
        sess=$(printf '%s' "$first_line" | sed -E 's/^#[[:space:]]*//')
      fi
      if [ -n "$sess" ]; then
        target_path=$(tmux display-message -t "${sess}:" -p '#{pane_current_path}' 2>/dev/null || true)
      fi
    fi

    if [ -z "$target_path" ] || [ ! -d "$target_path" ]; then
      target_path="${TMUX_ORIGIN_SESSION:+$(tmux display-message -t "${TMUX_ORIGIN_SESSION}:" -p '#{pane_current_path}' 2>/dev/null || true)}"
    fi
    [ -z "$target_path" ] && target_path="$PWD"

    AWT_POPUP="$HOME/.config/tmux/awt-popup.sh"
    [ -x "$AWT_POPUP" ] || AWT_POPUP="$SCRIPT_DIR/awt-popup.sh"
    exec "$AWT_POPUP" "$target_path"
    ;;
  __SWITCH_SESSION__)
    if [ "$1" = "--fullscreen" ]; then
      exec "$SCRIPT_DIR/session-picker.sh" --fullscreen
    else
      exec "$SCRIPT_DIR/session-picker.sh"
    fi
    ;;
  *)
    if [ -n "$chosen" ]; then
      case "$chosen" in
        *"no active AI agents"*) exit 0 ;;
      esac
      session=$(printf '%s' "$chosen" | head -n1 | cut -f4)
      idx=$(printf '%s' "$chosen" | head -n1 | cut -f2)
      if [ -n "$session" ] && [ -n "$idx" ] && [ "$idx" != "-" ]; then
        tmux switch-client -t "${session}:${idx}" 2>/dev/null || true
      fi
    fi
    exit 0
    ;;
esac
done

exit 0
