#!/usr/bin/env sh
# scrollback-view.sh — full scrollback -> markdown & mermaid inspector in a high-density popup (Prefix + E).
# Captures terminal scrollback with ANSI into /tmp/tmux_scrollback.md and opens in a floating
# Neovim popup (90% x 88% Golden Ratio) with full Treesitter markdown highlighting, Snacks.image
# Mermaid diagram rendering, diagram hopping (n/N), chart yank (yc), and instant dismissal (q/Esc).
set -u

ERRLOG=/tmp/scrollback-view.err
OUT=/tmp/tmux_scrollback.md

[ -n "${TMUX:-}" ] || { echo "scrollback-view: fora do tmux" >&2; exit 1; }

ORIGIN="${1:-}"
if [ -z "$ORIGIN" ]; then
  ORIGIN="$(tmux display-message -p '#{pane_id}' 2>/dev/null || true)"
fi

TARGET_FLAG=""
if [ -n "$ORIGIN" ]; then
  TARGET_FLAG="-t $ORIGIN"
fi

if ! tmux capture-pane -epJS - $TARGET_FLAG 2>"$ERRLOG" | sed '/^$/d' > "$OUT"; then
  tmux display-message "scrollback: capture-pane falhou (ver $ERRLOG)"
  exit 1
fi
if [ ! -s "$OUT" ]; then
  tmux display-message "scrollback: pane vazio, nada para abrir"
  exit 1
fi

SCRIPT_DIR=$(dirname "$(readlink -f "$0" 2>/dev/null || realpath "$0")")
# shellcheck source=/dev/null
. "$SCRIPT_DIR/theme-helper.sh"

ACCENT=$(get_theme_color accent "#7aa2f7")

tmux set -p allow-passthrough all 2>/dev/null || true
tmux set -g allow-passthrough all 2>/dev/null || true

# Open in Golden Ratio Layer 2 floating popup (90% x 88%)
exec tmux display-popup \
  -S "fg=$ACCENT" \
  -s "fg=default" \
  -b rounded \
  -T " 󰄧 " \
  -w 90% -h 88% \
  -E \
  nvim \
    -c "silent! BaleiaColorize" \
    -c "lua require('config.scrollback').setup()" \
    -c "normal G" \
    "$OUT"
