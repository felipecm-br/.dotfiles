#!/usr/bin/env sh
# scrollback-open.sh — open a file[:line[:col]] token in $EDITOR (extrakto edit).
# Usage: scrollback-open.sh <token> [cwd] | scrollback-open.sh --check <token> [cwd]
# --check only prints resolution (used by tests): "file|line|col|exists".
set -u

CHECK=0
if [ "${1:-}" = "--check" ]; then CHECK=1; shift; fi
t="${1:-}"
cwd="${2:-}"

file="$t"; line=1; col=1
if printf '%s' "$t" | grep -qE ':[0-9]+(:[0-9]+)?$'; then
  suffix="$(printf '%s' "$t" | grep -oE ':[0-9]+(:[0-9]+)?$')"
  file="${t%"$suffix"}"
  line="$(printf '%s' "$suffix" | cut -d: -f2)"
  col="$(printf '%s' "$suffix" | cut -d: -f3)"
  [ -n "$col" ] || col=1
fi
case "$file" in '~'*) file="$HOME${file#'~'}";; esac

exists=0
if [ -n "$cwd" ]; then
  [ -f "$cwd/$file" ] && exists=1 && file="$cwd/$file"
elif [ -f "$file" ]; then
  exists=1
fi

if [ "$CHECK" = "1" ]; then
  printf '%s|%s|%s|%s\n' "$file" "$line" "$col" "$exists"
  exit 0
fi
if [ "$exists" != "1" ]; then
  tmux display-message "scrollback: não é arquivo: $file" 2>/dev/null || true
  exit 0
fi

# When inside a tmux popup (workspace-picker, yank-picker), open in split pane beside origin pane
# to preserve visual concurrency with AI agent / terminal sessions and prevent modal trapping.
if [ -n "${TMUX:-}" ] && { [ -n "${TMUX_POPUP:-}" ] || [ -n "${MM_ORIGIN_PANE:-}" ]; }; then
  origin_pane="${MM_ORIGIN_PANE:-}"
  if [ -z "$origin_pane" ]; then
    origin_pane="$(tmux display-message -p -t '{last}' '#{pane_id}' 2>/dev/null || true)"
  fi
  if [ -z "$origin_pane" ]; then
    origin_pane="$(tmux display-message -p '#{pane_id}' 2>/dev/null || true)"
  fi

  origin_win="$(tmux display-message -t "$origin_pane" -p '#{window_id}' 2>/dev/null || true)"
  [ -z "$cwd" ] && cwd="$(tmux display-message -t "$origin_pane" -p '#{pane_current_path}' 2>/dev/null || echo "$PWD")"

  # Check if Neovim is already running in any pane of the origin window
  nvim_pane=""
  nvim_pid=""
  panes_list="$(tmux list-panes -t "$origin_win" -F '#{pane_id} #{pane_pid} #{pane_current_command}' 2>/dev/null || true)"
  if [ -n "$panes_list" ]; then
    while IFS=' ' read -r p_id p_pid p_cmd; do
      if [ "$p_cmd" = "nvim" ] || [ "$p_cmd" = "vim" ]; then
        nvim_pane="$p_id"
        nvim_pid="$p_pid"
        break
      fi
    done <<EOF
$panes_list
EOF
  fi

  if [ -n "$nvim_pane" ]; then
    # Neovim is already open: load file into existing buffer and focus pane
    sock="/run/user/$(id -u)/nvim.$nvim_pid.0"
    if [ -S "$sock" ] && command -v nvim >/dev/null 2>&1; then
      nvim --server "$sock" --remote-send "<C-\\><C-n>:e $(printf '%q' "$file")<CR>" 2>/dev/null || true
      if [ "$line" -gt 1 ]; then
        nvim --server "$sock" --remote-send ":${line}<CR>" 2>/dev/null || true
      fi
    else
      tmux send-keys -t "$nvim_pane" Escape ":e $(printf '%q' "$file")" Enter 2>/dev/null || true
      if [ "$line" -gt 1 ]; then
        tmux send-keys -t "$nvim_pane" ":${line}" Enter 2>/dev/null || true
      fi
    fi
    tmux select-pane -t "$nvim_pane" 2>/dev/null || true
  else
    # Neovim not running: open split on the left (Golden Ratio 62% Neovim / 38% origin AI pane on right)
    new_pane="$(tmux split-window -d -h -b -l 62% -P -F '#{pane_id}' -t "$origin_pane" -c "$cwd" "${EDITOR:-nvim} +\"call cursor($line,$col)\" $(printf '%q' "$file")" 2>/dev/null || true)"
    if [ -n "$new_pane" ]; then
      tmux select-pane -t "$new_pane" 2>/dev/null || true
    fi
  fi

  # Close popup overlay cleanly
  tmux display-popup -C 2>/dev/null || true
  rm -f "/tmp/tmux-active-popup-${USER:-default}" 2>/dev/null || true
  exit 0
fi

exec ${EDITOR:-nvim} +"call cursor($line,$col)" -- "$file"
