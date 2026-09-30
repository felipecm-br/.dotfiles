# Tmux configuration
alias tmux='tmux -2'
# Enable 256 color support
export TERM=screen-256color

# ─────────────────────────────────────────────────────────────────────────────
# Session Picker ZLE Widget (Alt+s)
# ─────────────────────────────────────────────────────────────────────────────
function tmux-sessions() {
  {
    exec </dev/tty
    exec <&1
    local wm_bin="$HOME/.local/bin/wm"
    [ -x "$wm_bin" ] || wm_bin="$(command -v wm 2>/dev/null || command -v mm 2>/dev/null || echo "wm")"
    local preset="$HOME/.config/waymaker/presets/session-picker.toml"
    [ -f "$preset" ] || preset="$HOME/.config/tmux/session-picker.toml"
    local chosen
    chosen=$("$wm_bin" session list --icons | grep -Ev '(_lazygitrs|_popups|[[:space:]]+\.)' | "$wm_bin" -o "$preset")
    zle reset-prompt > /dev/null 2>&1 || true
    chosen=$(echo "$chosen" | sed -E 's/\x1B\[[0-9;]*[a-zA-Z]//g' | sed -E 's/^[^a-zA-Z0-9/~._-]+//' | tr -d '\r' | xargs)
    [[ -z "$chosen" ]] && return
    "$wm_bin" connect "$chosen"
  }
}

sesh-sessions() { tmux-sessions "$@"; }

zle     -N             tmux-sessions
zle     -N             sesh-sessions
bindkey -M emacs '\es' tmux-sessions
bindkey -M vicmd '\es' tmux-sessions
bindkey -M viins '\es' tmux-sessions