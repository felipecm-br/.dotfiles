#!/usr/bin/env bash
# btw-popup.sh — Ephemeral side question (/btw) over any pane (Golden Ratio 75% × 60%, Prefix + b).
# Asks a one-off question about what the pane is doing without touching it: the agent keeps
# working, nothing is typed into it and no session is saved. Context is read-only: the pane's
# last 120 lines, `git status -sb` and the branch. The answer comes from a headless, hook-free run
# of the agent with quota (claude -p on a fast model, codex exec --ephemeral, agy -p).
# Keys after the answer: y yank · i queue it into the pane's agent · Enter ask again · Esc close.
#   btw-popup.sh ['#{pane_id}']    open the popup over the pane
#   BTW_AGENT=claude|codex|agy     skip the quota pick; BTW_MODEL overrides the fast model
set -u

REAL_SCRIPT=$(readlink -f "$0" 2>/dev/null || realpath "$0")
SCRIPT_DIR=$(dirname "$REAL_SCRIPT")

if [ -z "${TMUX_POPUP:-}" ]; then
  ORIGIN="${1:-${TMUX_PANE:-$(tmux display-message -p '#{pane_id}' 2>/dev/null)}}"
  CWD=$(tmux display-message -p -t "$ORIGIN" '#{pane_current_path}' 2>/dev/null || echo "$PWD")
  # shellcheck source=/dev/null
  . "$SCRIPT_DIR/theme-helper.sh"
  COLOR=$(get_theme_color cyan "#89dceb")
  # shellcheck disable=SC2046
  tmux display-popup \
    -S "fg=$COLOR" \
    -s "fg=default" \
    -b rounded \
    -T " 󰭹 " \
    $(popup_gradient_flags WM_BORDER_GRADIENT) -e "WM_BORDER_TITLE= 󰭹 " \
    -d "$CWD" \
    -w 75% -h 60% \
    -E \
    "TMUX_POPUP=1 '$REAL_SCRIPT' '$ORIGIN' '$CWD'" || true
  exit 0
fi

ORIGIN=${1:-}
CWD=${2:-$PWD}
CYAN=$'\e[36;1m' DIM=$'\e[90m' OFF=$'\e[0m'

# Which agent answers: BTW_AGENT, else the family ai-launch recommends by quota, else what exists
pick_agent() {
  local rec
  if [ -n "${BTW_AGENT:-}" ]; then echo "$BTW_AGENT"; return; fi
  rec=$("$HOME/.local/bin/ai-launch" --peek --auto 2>/dev/null)
  case $rec in
    *claude*) command -v claude >/dev/null && { echo claude; return; } ;;
    agy* | agyy*) command -v agy >/dev/null && { echo agy; return; } ;;
    codex*) command -v codex >/dev/null && { echo codex; return; } ;;
  esac
  for a in claude codex agy; do command -v "$a" >/dev/null && { echo "$a"; return; }; done
}

context() {
  local agent
  agent=$(tmux display-message -p -t "$ORIGIN" '#{pane_current_command}' 2>/dev/null)
  printf 'You are answering a quick side question (a "by the way") about a terminal pane where a\n'
  printf 'coding agent or a shell is running. Answer briefly, in Markdown. You cannot act; only explain.\n\n'
  printf '## Pane\nprogram: %s · cwd: %s · branch: %s\n\n' "$agent" "$CWD" \
    "$(git -C "$CWD" branch --show-current 2>/dev/null || echo '-')"
  printf '## git status -sb\n```\n%s\n```\n\n' "$(git -C "$CWD" status -sb 2>/dev/null | head -40)"
  printf '## Last lines of the pane\n```\n%s\n```\n\n' \
    "$(tmux capture-pane -p -J -t "$ORIGIN" -S -120 2>/dev/null | sed 's/[[:space:]]*$//' | cat -s)"
}

ask() { # <agent> <prompt file>: the answer on stdout; never the origin pane's hooks or session
  local model
  case $1 in
    claude)
      model=${BTW_MODEL:-haiku}
      env -u TMUX -u TMUX_PANE claude -p --no-session-persistence --model "$model" --tools "" \
        --settings '{"disableAllHooks":true}' <"$2" ;;
    codex)
      env -u TMUX -u TMUX_PANE codex exec --ephemeral --skip-git-repo-check -s read-only \
        ${BTW_MODEL:+-m "$BTW_MODEL"} - <"$2" 2>/dev/null ;;
    agy)
      env -u TMUX -u TMUX_PANE agy -p "$(cat "$2")" ${BTW_MODEL:+--model "$BTW_MODEL"} --disable-slash-commands ;;
    *) echo "No agent CLI found (claude, codex, agy)"; return 1 ;;
  esac
}

render() { # <file>
  if command -v glow >/dev/null 2>&1; then
    glow -s auto -w "$(($(tput cols) - 2))" "$1"
  elif command -v bat >/dev/null 2>&1; then
    bat --style=plain --color=always --paging=never -l markdown "$1"
  else
    cat "$1"
  fi
}

copy() {
  if command -v wl-copy >/dev/null 2>&1; then wl-copy <"$1"
  elif command -v xclip >/dev/null 2>&1; then xclip -in -selection clipboard <"$1"
  else tmux load-buffer "$1"; fi
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
agent=$(pick_agent)
while :; do
  clear
  printf '%s 󰭹 btw%s %s· %s · read-only, the pane is not touched%s\n\n' "$CYAN" "$OFF" "$DIM" "${agent:-none}" "$OFF"
  IFS= read -r -e -p "  ? " question || exit 0
  [ -n "${question// /}" ] || exit 0
  { context; printf '## Question\n%s\n' "$question"; } >"$tmp/prompt"
  printf '\n  %s󰔟 asking %s…%s' "$DIM" "$agent" "$OFF"
  # stderr only when there is no answer: CLIs warn there (sign-in expiry, update notices)
  ask "$agent" "$tmp/prompt" >"$tmp/answer" 2>"$tmp/err"
  [ -s "$tmp/answer" ] || cp "$tmp/err" "$tmp/answer"
  printf '\r\e[K\n'
  if [ "$(render "$tmp/answer" | wc -l)" -gt $(($(tput lines) - 6)) ]; then
    render "$tmp/answer" | less -R
  else
    render "$tmp/answer"
  fi
  printf '\n  %sy%s %syank%s  %si%s %squeue into the pane%s  %sEnter%s %sask again%s  %sEsc%s %sclose%s ' \
    "$CYAN" "$OFF" "$DIM" "$OFF" "$CYAN" "$OFF" "$DIM" "$OFF" "$CYAN" "$OFF" "$DIM" "$OFF" "$CYAN" "$OFF" "$DIM" "$OFF"
  IFS= read -rsn1 key
  case $key in
    y) copy "$tmp/answer"; tmux display-message "󰭹 Answer copied"; exit 0 ;;
    i) waymux queue add "$ORIGIN" "$(cat "$tmp/answer")" >/dev/null 2>&1 &&
         tmux display-message "󰇮 Answer queued for the agent: typed when it is at rest"; exit 0 ;;
    '') continue ;;
    *) exit 0 ;;
  esac
done
