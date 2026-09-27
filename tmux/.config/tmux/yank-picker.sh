#!/usr/bin/env sh
# yank-picker.sh (aliased as scrollback-extract.sh) — extrakto-style token copy/insert from tmux scrollback via wm.
# Invoke: prefix+y -> run-shell "yank-picker.sh '#{pane_id}'" (origin pane!).
# Wrapper opens a themed popup (sesh-picker pattern, golden 75%x60%); inside,
# the ORIGIN pane is captured explicitly, one token file per filter plus the
# full text (preview context) is precomputed, the all-list is piped to mm,
# and the clipboard tail runs detached so the popup closes on Enter.
set -u

SRC=/tmp/scrollback-extract-src.txt
TOK_ALL=/tmp/scrollback-extract-all.txt
TOK_CMD=/tmp/scrollback-extract-cmd.txt
TOK_PATH=/tmp/scrollback-extract-path.txt
TOK_URL=/tmp/scrollback-extract-url.txt
TOK_SHA=/tmp/scrollback-extract-sha.txt
LOG=/tmp/scrollback-mm.log

if [ -z "${TMUX_POPUP:-}" ]; then
  ORIGIN_ARG="${1:-}"
  CWD_ARG="${2:-}"
  GREEN=$(grep -E '^\s*green\s*=' "$HOME/.local/state/omarchy/current/theme/colors.toml" 2>/dev/null | sed -E 's/.*=\s*"([^"]+)".*/\1/')
  [ -n "$GREEN" ] || GREEN="#a6e3a1"

  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  ISOLATOR="$SCRIPT_DIR/tmux-popup-isolate.sh"
  [ -x "$ISOLATOR" ] || ISOLATOR="$(command -v tmux-popup-isolate.sh 2>/dev/null || echo "$HOME/.config/tmux/tmux-popup-isolate.sh")"

  "$ISOLATOR" \
    -S "fg=$GREEN" \
    -s "fg=default" \
    -b rounded \
    -T " 󰅍 " \
    -w 75% -h 60% \
    -E \
    -- "TMUX_POPUP=1 '$0' '$ORIGIN_ARG' '$CWD_ARG'" || true
  exit 0
fi

[ -n "${TMUX:-}" ] || { echo "yank-picker: fora do tmux" >&2; exit 1; }
ORIGIN="${1:-}"
if [ -z "$ORIGIN" ]; then
  ORIGIN="$(tmux display-message -p -t '{last}' '#{pane_id}' 2>/dev/null || true)"
fi
export MM_ORIGIN_PANE="$ORIGIN"
export MM_ORIGIN_CWD="${2:-}"

MM_BIN="$HOME/.local/bin/wm"
[ -x "$MM_BIN" ] || MM_BIN="$(command -v wm 2>/dev/null || command -v mm 2>/dev/null || echo mm)"

P_URL='https?://[^[:space:]"'"'"'<>]+|git@[^[:space:]"'"'"'<>]+|//[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}[^[:space:]"'"'"'<>]*|www\.[a-zA-Z0-9.-]+[^[:space:]"'"'"'<>]*'
P_PATH='(~?/[A-Za-z0-9._~:/?#@!$&()*+,;=%-]+|\.\.?/[A-Za-z0-9._~:/?#@!$&()*+,;=%-]+)'
P_SHA='\b[0-9a-f]{7,40}\b|\b[0-9]{1,3}(\.[0-9]{1,3}){3}(:[0-9]+)?\b'
CMD_VERBS='sudo|doas|pacman|yay|paru|apt|apt-get|dnf|yum|brew|flatpak|snap|rm|mv|cp|mkdir|rmdir|touch|ln|chmod|chown|git|gh|cargo|rustc|just|make|systemctl|journalctl|docker|podman|kubectl|curl|wget|ssh|scp|rsync|tar|unzip|gzip|nvim|vim|bat|cat|rg|grep|find|fd|wm|mm|awt|sesh|tmux|kill|pkill|python|python3|node|npm|pnpm|bun|uv|zig|go'

dedup_rev() { awk '!seen[$0]++ && length($0)>2 { lines[n++]=$0 } END { for (i=n-1;i>=0;i--) print lines[i] }'; }

clean_tokens() {
  sed -E 's/^[[:space:]<"'\''([{\[]+//; s/[][[:space:]>"'\''})]+$//; s/[.,;:)>]+$//' | dedup_rev
}

extract_commands() {
  {
    sed -nE 's/^[[:space:]]*[$#%❯➜→>][[:space:]]+//p' "$SRC"
    sed -nE '/^[[:space:]]*●[[:space:]]*Bash\(/ { s/[[:space:]]*\(ctrl\+o.*$//; s/^[[:space:]]*●[[:space:]]*Bash\(//; s/\)[[:space:]]*$//; p; }' "$SRC"
    grep -E "^[[:space:]]*($CMD_VERBS)\b" "$SRC" | sed -E 's/^[[:space:]]+//'
  } | sed -E 's/[[:space:]]*\)[[:space:]]*\(ctrl\+o.*$//; s/[[:space:]]*\(ctrl\+o.*$//' | \
    awk '!seen[$0]++ && length($0)>=3 && !/^[0-9]+$/ { lines[n++]=$0 } END { for (i=n-1;i>=0;i--) print lines[i] }'
}

if ! tmux capture-pane -pJS - -t "$ORIGIN" 2>/dev/null | sed '/^$/d' > "$SRC"; then
  tmux display-message "scrollback: capture-pane falhou ($ORIGIN)"
  exit 1
fi

extract_commands > "$TOK_CMD"
sed -E 's|https?://[^[:space:]"'\''<>]+||g; s|git@[^[:space:]"'\''<>]+||g; s|//[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}[^[:space:]"'\''<>]*||g; s|www\.[a-zA-Z0-9.-]+[^[:space:]"'\''<>]*||g' "$SRC" | \
  grep -oE "$P_PATH" | clean_tokens > "$TOK_PATH"
grep -oE "$P_URL" "$SRC" | sed -E 's/^[[:space:]<"'\''([{\[]+//; s/[][[:space:]>"'\''})]+$//; s/[.,;:)>]+$//; s|^//|https://|' | dedup_rev > "$TOK_URL"
grep -oE "$P_SHA" "$SRC" | clean_tokens > "$TOK_SHA"

{
  cat "$TOK_CMD" 2>/dev/null || true
  cat "$TOK_PATH" 2>/dev/null || true
  cat "$TOK_URL" 2>/dev/null || true
  cat "$TOK_SHA" 2>/dev/null || true
} | awk '!seen[$0]++ { print }' > "$TOK_ALL"

if [ ! -s "$TOK_ALL" ]; then
  tmux display-message "scrollback: nada extraível (cmd/path/URL/hash)"
  exit 0
fi

# Items come from [start] command (file), never from a pipe: mm reads keyboard
# from stdin via crossterm, so stdin must stay on the tty or no key works.
if "$MM_BIN" --dump-config -o yank >/dev/null 2>&1; then
  PRESET="yank"
else
  PRESET="scrollback"
fi
chosen="$("$MM_BIN" -o "$PRESET")" || exit 0
[ -n "$chosen" ] || exit 0

# Clipboard + confirm run detached from the popup: the popup must close the
# instant Enter is pressed, even if wl-copy/display-message ever blocks, and
# the tail must survive popup teardown (ignore HUP, no tty stdin).
trap '' HUP
{
  echo "$(date '+%T') mm exited, copying $(printf '%s' "$chosen" | wc -c) bytes"
  if command -v wl-copy >/dev/null 2>&1; then
    printf '%s' "$chosen" | wl-copy
  elif command -v xclip >/dev/null 2>&1; then
    printf '%s' "$chosen" | xclip -in -selection clipboard
  else
    printf '%s' "$chosen" | tmux load-buffer -
  fi
  echo "$(date '+%T') clipboard rc=$?"
  tmux display-message "yanked: $chosen"
  echo "$(date '+%T') done"
} >>"$LOG" 2>&1 </dev/null &
exit 0
