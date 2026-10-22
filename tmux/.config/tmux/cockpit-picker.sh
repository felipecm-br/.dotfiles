#!/usr/bin/env sh
# cockpit-picker.sh — Fleet & Window Cockpit HUD powered by Waymaker
# Displays prioritized agent states, waiting age, git branch/churn, and contextual previews.

if [ -x "$HOME/.local/bin/waymux" ]; then
  exec "$HOME/.local/bin/waymux" cockpit "$@"
elif command -v waymux >/dev/null 2>&1; then
  exec waymux cockpit "$@"
fi

REAL_SCRIPT=$(readlink -f "$0" 2>/dev/null || realpath "$0")
SCRIPT_DIR=$(dirname "$REAL_SCRIPT")
# shellcheck source=/dev/null
. "$SCRIPT_DIR/theme-helper.sh"

if [ "$1" = "--fullscreen" ]; then
  if ! [ -t 1 ]; then
    exec tmux split-window -Z "$REAL_SCRIPT" --fullscreen
  fi
elif [ -z "${TMUX_POPUP:-}" ]; then
  ORIG_SESS=$(tmux display-message -p '#{session_name}')
  ORIG_WIN=$(tmux display-message -p '#{window_index}')
  export TMUX_ORIGIN_SESSION="$ORIG_SESS"
  export TMUX_ORIGIN_WINDOW="$ORIG_WIN"

  COCKPIT_POPUP_COLOR=$(get_theme_color "orange" "${TMUX_POPUP_BORDER_COLOR:-#e09d7f}")

  exec tmux display-popup \
    -S "fg=$COCKPIT_POPUP_COLOR" \
    -s "fg=${TMUX_POPUP_TEXT_COLOR:-default}" \
    -b rounded \
    -T " 󱂬 " \
    $(popup_gradient_flags WM_BORDER_GRADIENT) -e "WM_BORDER_TITLE= 󱂬 " \
    -w 85% -h 75% \
    -E \
    "TMUX_POPUP=1 TMUX_ORIGIN_SESSION='$ORIG_SESS' TMUX_ORIGIN_WINDOW='$ORIG_WIN' '$REAL_SCRIPT'"
fi

ITEMS_SCRIPT="${SCRIPT_DIR}/cockpit-picker-items.sh"

WAYMUX_SPINNER=$(tmux show-option -gqv @ai_agent_spinner 2>/dev/null)
[ -z "$WAYMUX_SPINNER" ] && WAYMUX_SPINNER="minidot"
TMUX_SPINNER_NAME="$WAYMUX_SPINNER"

ORIG_SESS="${TMUX_ORIGIN_SESSION:-$(tmux display-message -p '#S')}"
ORIG_WIN="${TMUX_ORIGIN_WINDOW:-$(tmux display-message -p '#I')}"

SAVED_SESS=""
SAVED_IDX=""

resolve_target_path() {
  item="$1"
  first_line=$(printf '%s' "$item" | head -n1)
  t_path=""
  t_sess=""

  case "$first_line" in
    \#*)
      t_sess=$(printf '%s' "$first_line" | sed -E 's/^#[[:space:]]*//' | awk '{print $1}')
      ;;
    *)
      t_sess=$(printf '%s' "$first_line" | cut -f4)
      r_path=$(printf '%s' "$first_line" | cut -f6)
      if [ -n "$r_path" ] && [ -d "$r_path" ]; then
        t_path="$r_path"
      fi
      ;;
  esac

  if [ -z "$t_path" ] && [ -n "$t_sess" ]; then
    t_path=$(tmux display-message -t "${t_sess}:" -p '#{pane_current_path}' 2>/dev/null || true)
  fi

  if [ -z "$t_path" ] || [ ! -d "$t_path" ]; then
    t_path="${TMUX_ORIGIN_SESSION:+$(tmux display-message -t "${TMUX_ORIGIN_SESSION}:" -p '#{pane_current_path}' 2>/dev/null || true)}"
  fi
  [ -z "$t_path" ] && t_path="$PWD"
  printf '%s' "$t_path"
}

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
  else
    # Find current active window in list
    START_IDX=$(printf '%s\n' "$ITEMS" | awk -F'\t' -v s="$ORIG_SESS" -v w="$ORIG_WIN" '
      BEGIN { n = 0 }
      !/^#/ {
        if ($4 == s && $2 == w) {
          print n
          exit
        }
        n++
      }
    ')
  fi

  if [ -z "$START_IDX" ]; then
    FIRST_PRIO=$(printf '%s\n' "$ITEMS" | awk -F'\t' '!/^#/ { print $1; exit }')
    case "$FIRST_PRIO" in
      1|2|3) START_IDX=0 ;;
      *) START_IDX=0 ;;
    esac
  fi

  WM_BIN="$HOME/.local/bin/wm"
  [ -x "$WM_BIN" ] || WM_BIN="$(command -v wm 2>/dev/null || command -v mm 2>/dev/null || echo "wm")"

  PRESET="$HOME/.config/waymaker/presets/cockpit-picker.toml"
  if [ -f "$PRESET" ]; then
    CONFIG_OPT=(--config "$PRESET")
  elif [ -f "$SCRIPT_DIR/cockpit-picker.toml" ]; then
    CONFIG_OPT=(--config "$SCRIPT_DIR/cockpit-picker.toml")
  else
    CONFIG_OPT=(-o cockpit-picker)
  fi

  chosen=$(printf '%s\n' "$ITEMS" | "$WM_BIN" \
    "${CONFIG_OPT[@]}" \
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
      target_path=$(resolve_target_path "$raw_item")

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
      target_path=$(resolve_target_path "$raw_item")

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
      exec "$AWT_BIN" ship "$branch" --confirm
      ;;
    __SWEEP_WORKTREES__*)
      raw_item="${chosen#__SWEEP_WORKTREES__}"
      target_path=$(resolve_target_path "$raw_item")

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
    __OPEN_PR__*)
      raw_item="${chosen#__OPEN_PR__}"
      target_path=$(resolve_target_path "$raw_item")
      SAVED_SESS=$(printf '%s' "$raw_item" | head -n1 | cut -f4)
      SAVED_IDX=$(printf '%s' "$raw_item" | head -n1 | cut -f2)

      if [ -n "$target_path" ] && git -C "$target_path" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        (cd "$target_path" && gh pr view --web 2>/dev/null || tmux display-message "No pull request found for current branch") &
      else
        tmux display-message "Not in a git repository: $target_path"
      fi
      continue
      ;;
    __OPEN_PR_CHECKS__*)
      raw_item="${chosen#__OPEN_PR_CHECKS__}"
      target_path=$(resolve_target_path "$raw_item")
      SAVED_SESS=$(printf '%s' "$raw_item" | head -n1 | cut -f4)
      SAVED_IDX=$(printf '%s' "$raw_item" | head -n1 | cut -f2)

      if [ -n "$target_path" ] && git -C "$target_path" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        (cd "$target_path" && gh pr checks --web 2>/dev/null || tmux display-message "No PR checks found for current branch") &
      else
        tmux display-message "Not in a git repository: $target_path"
      fi
      continue
      ;;
    __JUMP_LAST_AGENT__*)
      last_target=$(tmux show-option -gqv @cockpit_last_agent 2>/dev/null || true)
      current_target="${TMUX_ORIGIN_SESSION:-}:${TMUX_ORIGIN_WINDOW:-}"
      if [ -n "$current_target" ] && [ "$current_target" != ":" ]; then
        tmux set-option -g @cockpit_last_agent "$current_target"
      fi
      if [ -n "$last_target" ]; then
        tmux switch-client -t "$last_target" 2>/dev/null || tmux switch-client -l 2>/dev/null || true
      else
        tmux switch-client -l 2>/dev/null || true
      fi
      exit 0
      ;;
    __LAZYGIT__*)
      raw_item="${chosen#__LAZYGIT__}"
      target_path=$(resolve_target_path "$raw_item")
      target_sess=$(printf '%s' "$raw_item" | head -n1 | cut -f4)
      target_idx=$(printf '%s' "$raw_item" | head -n1 | cut -f2)

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
    __PATCH_MODE__*)
      raw_item="${chosen#__PATCH_MODE__}"
      target_path=$(resolve_target_path "$raw_item")
      target_sess=$(printf '%s' "$raw_item" | head -n1 | cut -f4)
      target_idx=$(printf '%s' "$raw_item" | head -n1 | cut -f2)

      if ! git -C "$target_path" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        tmux display-message "Not in a git repository: $target_path"
        continue
      fi

      LZG_BIN="$HOME/.local/bin/lazygitrs"
      [ -x "$LZG_BIN" ] || LZG_BIN="$HOME/.cargo/bin/lazygitrs"
      [ -x "$LZG_BIN" ] || LZG_BIN="$(command -v lazygitrs 2>/dev/null || echo "lazygitrs")"

      if [ -z "$(git -C "$target_path" status --porcelain 2>/dev/null)" ]; then
        tmux display-message "Working tree is clean: nothing to patch in $target_path"
        continue
      fi

      SAVED_SESS="$target_sess"
      SAVED_IDX="$target_idx"

      (
        cd "$target_path" || exit 1
        export LAZYGITRS_COCKPIT=1
        "$LZG_BIN" -d -c popup
      )
      lzg_rc=$?

      if [ "$lzg_rc" -eq 10 ]; then
        continue
      fi
      exit 0
      ;;
    __SWITCH_AWT__*)
      raw_item="${chosen#__SWITCH_AWT__}"
      target_path=$(resolve_target_path "$raw_item")

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
          current_target="${TMUX_ORIGIN_SESSION:-}:${TMUX_ORIGIN_WINDOW:-}"
          if [ -n "$current_target" ] && [ "$current_target" != ":" ]; then
            tmux set-option -g @cockpit_last_agent "$current_target"
          fi
          tmux switch-client -t "${session}:${idx}" 2>/dev/null || true
        fi
      fi
      exit 0
      ;;
  esac
done

exit 0
