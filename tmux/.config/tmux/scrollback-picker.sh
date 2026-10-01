#!/usr/bin/env sh
# scrollback-picker.sh — token copy/insert/open from tmux scrollback via wm.
# Invoke: prefix+y -> run-shell "scrollback-picker.sh '#{pane_id}' '#{pane_current_path}'"
# Wrapper opens a themed popup (sesh-picker pattern, golden 75%x60%); inside,
# the ORIGIN pane is captured, tokens are extracted in bottom-up recency order
# (newest text on screen appears first), and loaded into wm scrollback-picker preset.
set -u

SRC=/tmp/scrollback-picker-src.txt
TOK_ALL=/tmp/scrollback-picker-all.txt
TOK_CMD=/tmp/scrollback-picker-cmd.txt
TOK_PATH=/tmp/scrollback-picker-path.txt
TOK_URL=/tmp/scrollback-picker-url.txt
TOK_SHA=/tmp/scrollback-picker-sha.txt
LOG=/tmp/scrollback-picker-mm.log

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

[ -n "${TMUX:-}" ] || { echo "scrollback-picker: fora do tmux" >&2; exit 1; }
ORIGIN="${1:-}"
if [ -z "$ORIGIN" ]; then
  ORIGIN="$(tmux display-message -p -t '{last}' '#{pane_id}' 2>/dev/null || true)"
fi
export MM_ORIGIN_PANE="$ORIGIN"
export MM_ORIGIN_CWD="${2:-}"

MM_BIN="$HOME/.local/bin/wm"
[ -x "$MM_BIN" ] || MM_BIN="$(command -v wm 2>/dev/null || command -v mm 2>/dev/null || echo mm)"

if ! tmux capture-pane -pJS - -t "$ORIGIN" 2>/dev/null | sed '/^$/d' > "$SRC"; then
  tmux display-message "scrollback: capture-pane falhou ($ORIGIN)"
  exit 1
fi

# High-performance single-pass bottom-up token extraction (<20ms for 2000 lines)
python3 - "$SRC" "$TOK_ALL" "$TOK_CMD" "$TOK_PATH" "$TOK_URL" "$TOK_SHA" <<'PYEOF'
import sys, re

src_file, tok_all_f, tok_cmd_f, tok_path_f, tok_url_f, tok_sha_f = sys.argv[1:7]

with open(src_file, 'r', encoding='utf-8', errors='ignore') as f:
    lines = [line.rstrip('\n') for line in f if line.strip()]

# Reverse order so the most recent screen output appears first (item 0)
lines.reverse()

verbs = set('sudo doas pacman yay paru apt apt-get dnf yum brew flatpak snap rm mv cp mkdir rmdir touch ln chmod chown git gh cargo rustc just make systemctl journalctl docker podman kubectl curl wget ssh scp rsync tar unzip gzip nvim vim bat cat rg grep find fd wm mm awt sesh tmux kill pkill python python3 node npm pnpm bun uv zig go'.split())

re_url = re.compile(r'https?://[^\s\"\'<>]+|git@[^\s\"\'<>]+|//[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}[^\s\"\'<>]*|www\.[a-zA-Z0-9.-]+[^\s\"\'<>]*')
re_path = re.compile(r'(?:~?/[A-Za-z0-9._~:/?#@!$&()*+,;=%-]+|\.\.?/[A-Za-z0-9._~:/?#@!$&()*+,;=%-]+)')
re_sha = re.compile(r'\b[0-9a-f]{7,40}\b|\b[0-9]{1,3}(?:\.[0-9]{1,3}){3}(?::[0-9]+)?\b')
re_prompt = re.compile(r'^[#$%>❯➜→]\s+(.+)$')
re_bash = re.compile(r'●\s*Bash\((.+?)\)(?:\s*\(ctrl\+o.*)?$')

seen_all = set()
seen_cmd = set()
seen_path = set()
seen_url = set()
seen_sha = set()

tok_all = []
tok_cmd = []
tok_path = []
tok_url = []
tok_sha = []

def clean_tok(t):
    return re.sub(r'^[<\"\'(\[{\]]+|[][>\"\'})\s.,;:)]+$', '', t)

for line in lines:
    # 1. URLs in this line (highest priority for web/PR workflows)
    for u in re_url.findall(line):
        cu = clean_tok(u)
        if cu.startswith('//'): cu = 'https:' + cu
        if len(cu) > 4:
            if cu not in seen_url:
                seen_url.add(cu)
                tok_url.append(cu)
            if cu not in seen_all:
                seen_all.add(cu)
                tok_all.append(cu)

    # 2. Commands in this line
    cmd = None
    mb = re_bash.search(line)
    if mb:
        cmd = mb.group(1).strip()
    else:
        mp = re_prompt.search(line)
        if mp:
            cmd = mp.group(1).strip()
        else:
            first = line.split()[0] if line.split() else ''
            if first in verbs:
                cmd = line.strip()
    if cmd and len(cmd) >= 3 and not cmd.isdigit():
        cmd = re.sub(r'\s*\(ctrl\+o.*$', '', cmd).strip()
        if cmd not in seen_cmd:
            seen_cmd.add(cmd)
            tok_cmd.append(cmd)
        if cmd not in seen_all:
            seen_all.add(cmd)
            tok_all.append(cmd)

    # 3. Paths in this line (exclude URLs to prevent path fragments)
    clean_line_paths = re_url.sub('', line)
    for p in re_path.findall(clean_line_paths):
        cp = clean_tok(p)
        if len(cp) > 2:
            if cp not in seen_path:
                seen_path.add(cp)
                tok_path.append(cp)
            if cp not in seen_all:
                seen_all.add(cp)
                tok_all.append(cp)

    # 4. Git SHAs and IP addresses in this line
    for s in re_sha.findall(line):
        cs = clean_tok(s)
        if len(cs) >= 7:
            if cs not in seen_sha:
                seen_sha.add(cs)
                tok_sha.append(cs)
            if cs not in seen_all:
                seen_all.add(cs)
                tok_all.append(cs)

with open(tok_all_f, 'w', encoding='utf-8') as f:
    f.write('\n'.join(tok_all) + ('\n' if tok_all else ''))
with open(tok_cmd_f, 'w', encoding='utf-8') as f:
    f.write('\n'.join(tok_cmd) + ('\n' if tok_cmd else ''))
with open(tok_path_f, 'w', encoding='utf-8') as f:
    f.write('\n'.join(tok_path) + ('\n' if tok_path else ''))
with open(tok_url_f, 'w', encoding='utf-8') as f:
    f.write('\n'.join(tok_url) + ('\n' if tok_url else ''))
with open(tok_sha_f, 'w', encoding='utf-8') as f:
    f.write('\n'.join(tok_sha) + ('\n' if tok_sha else ''))
PYEOF

if [ ! -s "$TOK_ALL" ]; then
  tmux display-message "scrollback: nada extraível (cmd/path/URL/hash)"
  exit 0
fi

# Items come from [start] command (file), never from a pipe
chosen="$("$MM_BIN" -o scrollback-picker)" || exit 0
[ -n "$chosen" ] || exit 0

# Clipboard + confirm run detached from the popup: the popup closes immediately
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
