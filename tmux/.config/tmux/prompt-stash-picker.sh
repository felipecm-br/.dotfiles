#!/usr/bin/env bash
# prompt-stash-picker.sh — Prompt Stash & Presets popup (Golden Ratio 75% × 60%, 40/60 split).
# Every draft Prefix + V stashed, from any agent, plus the presets pinned at 0–9; Tab switches to
# the waymux delivery queue of the pane. Enter puts the entry into the pane's prompt (even one
# stashed from another agent), 0–9 put a preset, e edits, s pins, d drops.
#   prompt-stash-picker.sh ['#{pane_id}']        open the popup over the pane
#   prompt-stash-picker.sh --rows <stash|queue>  rows for wm (Reload)
#   prompt-stash-picker.sh --act <verb> <id>     a key's action, run by wm inside the popup
set -u

REAL_SCRIPT=$(readlink -f "$0" 2>/dev/null || realpath "$0")
SCRIPT_DIR=$(dirname "$REAL_SCRIPT")
AI_PROMPT="$HOME/.local/bin/ai-prompt"
WAYMUX=$(command -v waymux 2>/dev/null || echo "$HOME/.local/bin/waymux")

rows() { # <stash|queue>: slot, agent, age, lines, where, text, id
  case $1 in
    queue)
      printf ' 󰇮\tQUEUE\t%s\t\t\t%s\t\n' "${WM_ORIGIN_PANE:-}" "Tab: stash & presets"
      "$WAYMUX" queue ls "${WM_ORIGIN_PANE:-}" 2>/dev/null |
        while IFS=$'\t' read -r pane id status by text; do
          printf 'Q%s\t%s\t%s\t%s\t%s\t%s\tq:%s:%s\n' "$id" "$by" "$status" "" "$pane" "$text" "$pane" "$id"
        done
      ;;
    *)
      printf ' 󰆓\tSTASH\t\t\t\t%s\t\n' "Tab: delivery queue"
      "$AI_PROMPT" list
      ;;
  esac
}

act() { # <verb> <id>
  local verb=$1 id=${2:-} pane=${WM_ORIGIN_PANE:-} slot text q qpane qid
  case $id in
    q:*)
      q=${id#q:}
      qpane=${q%%:*} qid=${q##*:}
      case $verb in
        drop) "$WAYMUX" queue rm "$qpane" "$qid" >/dev/null ;;
        send)
          # waymux > 0.13: type it now, over a draft hold
          out=$("$WAYMUX" queue send "$qpane" "$qid" 2>&1)
          tmux display-message "${out%%$'\n'*}" 2>/dev/null
          ;;
        edit)
          text=$(mktemp --suffix=.md)
          "$WAYMUX" api call queue/list "{\"pane_id\":\"$qpane\"}" 2>/dev/null |
            jq -r --argjson id "$qid" '.[] | .[]? | select(.id == $id) | .text' >"$text"
          if [ -s "$text" ] && nvim -c 'set filetype=markdown' "$text" && [ -s "$text" ]; then
            # In place (waymux > 0.13), else drop and push again: it then waits at the end
            "$WAYMUX" queue edit "$qpane" "$qid" - <"$text" >/dev/null 2>&1 ||
              { "$WAYMUX" queue rm "$qpane" "$qid" >/dev/null && "$WAYMUX" queue add "$qpane" "$(cat "$text")" >/dev/null; }
          fi
          rm -f "$text"
          ;;
      esac
      return 0
      ;;
    "") [ "$verb" = preset ] || return 0 ;;
  esac
  case $verb in
    send) "$AI_PROMPT" -t "$pane" send "$id" ;;
    preset) "$AI_PROMPT" -t "$pane" preset "$id" ;;
    edit) "$AI_PROMPT" edit-entry "$id" ;;
    pin)
      printf '\n  󰐃 Pin as preset · slot 0-9 (Esc cancels): '
      read -rsn1 slot
      [[ $slot =~ ^[0-9]$ ]] && "$AI_PROMPT" pin "$id" "$slot" 2>/dev/null
      ;;
    unpin) "$AI_PROMPT" unpin "$id" ;;
    drop)
      # A pinned preset asks first; history goes at once
      if "$AI_PROMPT" list | awk -F'\t' -v id="$id" '$7 == id && $1 ~ /^\[/ {f = 1} END {exit !f}'; then
        printf '\n  󰆴 Drop this preset? y/N '
        read -rsn1 slot
        [ "$slot" = y ] || return 0
      fi
      "$AI_PROMPT" drop "$id"
      ;;
  esac
}

case ${1:-} in
  --rows) rows "${2:-stash}"; exit 0 ;;
  --act) shift; act "$@"; exit 0 ;;
esac

if [ -z "${TMUX_POPUP:-}" ]; then
  ORIGIN_ARG="${1:-${TMUX_PANE:-$(tmux display-message -p '#{pane_id}' 2>/dev/null)}}"
  # shellcheck source=/dev/null
  . "$SCRIPT_DIR/theme-helper.sh"
  COLOR=$(get_theme_color magenta "#cba6f7")
  # shellcheck disable=SC2046
  tmux display-popup \
    -S "fg=$COLOR" \
    -s "fg=default" \
    -b rounded \
    -T " 󰆓 " \
    $(popup_gradient_flags WM_BORDER_GRADIENT) -e "WM_BORDER_TITLE= 󰆓 " \
    -w 75% -h 60% \
    -E \
    "TMUX_POPUP=1 '$REAL_SCRIPT' '$ORIGIN_ARG'" || true
  exit 0
fi

ORIGIN="${1:-}"
[ -n "$ORIGIN" ] || ORIGIN="$(tmux display-message -p -t '{last}' '#{pane_id}' 2>/dev/null || true)"
export WM_ORIGIN_PANE="$ORIGIN" MM_ORIGIN_PANE="$ORIGIN"

WM_BIN="$HOME/.local/bin/wm"
[ -x "$WM_BIN" ] || WM_BIN="$(command -v wm 2>/dev/null || echo wm)"

id=$("$WM_BIN" -o prompt-stash 2>/dev/null)
# wm shell-quotes the template's column: '<id>'
id=${id#\'}
id=${id%\'}
[ -n "$id" ] || exit 0
case $id in
  q:*) act edit "$id" ;;
  *) act send "$id" ;;
esac
