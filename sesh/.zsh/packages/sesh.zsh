function sesh-sessions() {
  {
    exec </dev/tty
    exec <&1
    local wm_bin="$HOME/.local/bin/wm"
    [ -x "$wm_bin" ] || wm_bin="$(command -v wm 2>/dev/null || command -v mm 2>/dev/null || echo "wm")"
    local chosen
    chosen=$("$wm_bin" session list --icons | grep -Ev '(_lazygitrs|_popups|[[:space:]]+\.)' | "$wm_bin" -o "$HOME/.config/tmux/session-picker.toml")
    zle reset-prompt > /dev/null 2>&1 || true
    chosen=$(echo "$chosen" | sed -E 's/\x1B\[[0-9;]*[a-zA-Z]//g' | sed -E 's/^[^a-zA-Z0-9/~._-]+//' | tr -d '\r' | xargs)
    [[ -z "$chosen" ]] && return
    "$wm_bin" connect "$chosen"
  }
}

zle     -N             sesh-sessions
bindkey -M emacs '\es' sesh-sessions
bindkey -M vicmd '\es' sesh-sessions
bindkey -M viins '\es' sesh-sessions
