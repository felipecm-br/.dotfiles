#!/usr/bin/env bash
# checkpoint-picker.sh — Turn Checkpoints & Rewind popup (85% × 75%, 40/60 split) over any agent
# pane: what each agent turn left in the work tree (`waymux checkpoint`), newest first, its diff
# on the right. Enter / r restores a turn (confirm first; waymux saves the current tree as a safety
# checkpoint, so a restore is itself undoable), g opens lazygitrs on the work tree.
#   checkpoint-picker.sh ['#{pane_id}']        open the popup over the pane
#   checkpoint-picker.sh --rows                rows for wm (Reload)
#   checkpoint-picker.sh --diff <n>            preview: the turn's diff, through delta when present
#   checkpoint-picker.sh --restore <n>         confirm, then restore (asks again to --force mid-turn)
set -u

REAL_SCRIPT=$(readlink -f "$0" 2>/dev/null || realpath "$0")
SCRIPT_DIR=$(dirname "$REAL_SCRIPT")
WAYMUX=$(command -v waymux 2>/dev/null || echo "$HOME/.local/bin/waymux")
PANE=${WM_ORIGIN_PANE:-${TMUX_PANE:-}}

case ${1:-} in
  --rows)
    printf 'TURN\tAGE\tCOMMIT\tSTATE\n'
    now=$(date +%s)
    # waymux > 0.13 prints the time each turn ended (--time); older ones leave AGE empty
    { "$WAYMUX" checkpoint list --time -w "$PANE" 2>/dev/null || "$WAYMUX" checkpoint list -w "$PANE" 2>/dev/null; } |
      grep -P '^\d+\t' | tac |
      while IFS=$'\t' read -r n sha t subject; do
        if [[ $t =~ ^[0-9]+$ ]]; then
          d=$((now - t))
          if [ $d -lt 3600 ]; then age="$((d / 60))m"; elif [ $d -lt 86400 ]; then age="$((d / 3600))h"; else age="$((d / 86400))d"; fi
        else
          subject="$t${subject:+	$subject}" age=""
        fi
        subject=${subject#turn "$n" · }
        printf '%s\t%s\t%s\t%s\n' "$n" "$age" "$sha" "$subject"
      done
    exit 0 ;;
  --diff)
    [[ ${2:-} =~ ^[0-9]+$ ]] || exit 0
    if command -v delta >/dev/null 2>&1; then
      cols=${COLUMNS:-100}
      sbs=()
      [ "$cols" -ge 150 ] && sbs=(--side-by-side)
      "$WAYMUX" checkpoint diff "$2" -w "$PANE" 2>&1 | delta --paging=never --width "$cols" "${sbs[@]}"
    else
      "$WAYMUX" checkpoint diff "$2" -w "$PANE" 2>&1
    fi
    exit 0 ;;
  --restore)
    n=${2:-}
    [[ $n =~ ^[0-9]+$ ]] || exit 0
    modal="$SCRIPT_DIR/confirm-modal.sh"
    "$modal" "Restore the work tree to turn $n?" \
      "The files go back as that turn left them; the current tree is saved first, so this is undoable." \
      "Restore" "Keep" || exit 0
    if ! out=$("$WAYMUX" checkpoint restore "$n" -w "$PANE" 2>&1); then
      case $out in
        *--force*)
          "$modal" "The agent is mid-turn. Restore anyway?" "$out" "Force" "Wait" || exit 0
          out=$("$WAYMUX" checkpoint restore "$n" -w "$PANE" --force 2>&1) ;;
      esac
    fi
    tmux display-message -d 6000 "󰁯 ${out%%$'\n'*}" 2>/dev/null
    exit 0 ;;
esac

if [ -z "${TMUX_POPUP:-}" ]; then
  ORIGIN_ARG="${1:-${TMUX_PANE:-$(tmux display-message -p '#{pane_id}' 2>/dev/null)}}"
  CWD=$(tmux display-message -p -t "$ORIGIN_ARG" '#{pane_current_path}' 2>/dev/null || echo "$PWD")
  if ! git -C "$CWD" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    tmux display-message "󰁯 Not in a git work tree: no turn checkpoints here"
    exit 0
  fi
  # shellcheck source=/dev/null
  . "$SCRIPT_DIR/theme-helper.sh"
  COLOR=$(get_theme_color cyan "#89dceb")
  # shellcheck disable=SC2046
  tmux display-popup \
    -S "fg=$COLOR" \
    -s "fg=default" \
    -b rounded \
    -T " 󰁯 " \
    $(popup_gradient_flags WM_BORDER_GRADIENT) -e "WM_BORDER_TITLE= 󰁯 " \
    -d "$CWD" \
    -w 85% -h 75% \
    -E \
    "TMUX_POPUP=1 '$REAL_SCRIPT' '$ORIGIN_ARG' '$CWD'" || true
  exit 0
fi

ORIGIN="${1:-}"
[ -n "$ORIGIN" ] || ORIGIN="$(tmux display-message -p -t '{last}' '#{pane_id}' 2>/dev/null || true)"
export WM_ORIGIN_PANE="$ORIGIN" MM_ORIGIN_PANE="$ORIGIN" WM_ORIGIN_CWD="${2:-$PWD}"

WM_BIN="$HOME/.local/bin/wm"
[ -x "$WM_BIN" ] || WM_BIN="$(command -v wm 2>/dev/null || echo wm)"
exec "$WM_BIN" -o checkpoint
