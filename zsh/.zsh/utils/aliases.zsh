alias waybar-restart='killall waybar && hyprctl dispatch exec waybar'
alias walker-restart='pkill -f walker && walker &'
alias reload="source ~/.zshrc"
alias omc='/usr/bin/git --git-dir=/home/fecavmi/.omc --work-tree=/home/fecavmi'
alias code.omc='GIT_DIR=/home/fecavmi/.omc GIT_WORK_TREE=/home/fecavmi code /home/fecavmi'
alias code.='GIT_DIR=$PWD/.git GIT_WORK_TREE=$PWD code .'
alias install-packages='~/omc/install/install.zsh'
alias clear="clear && [ -n \"\$TMUX\" ] && tmux clear-history"
alias scrollback='tmux capture-pane -epS - > /tmp/tmux_scrollback.ansi && nvim -c "BaleiaColorize" -c "normal G" /tmp/tmux_scrollback.ansi'
alias adopt='bash $HOME/.dotfiles/main/.shell/sh/stow-adopt-path.sh'
alias oc='exec /usr/bin/opencode'
alias agy="$HOME/.dotfiles/main/antigravity/.gemini/hooks/agy-wrapper.sh"

# Quick parent directory traversal
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# Waymux Daemon helpers
alias waymux-restart='systemctl --user restart waymux.service'
alias waymux-stop='systemctl --user stop waymux.service'
alias waymux-start='systemctl --user start waymux.service'
alias waymux-status='systemctl --user status waymux.service'
alias waymux-logs='journalctl --user -u waymux.service -f'

# Zero-Friction File Transfer (pt, ptg, ptl, mt, mtg, mtl) and Frecency Jump (z, zi)
# aliases are defined canonically alongside their implementations in functions.zsh.

# Agent Worktree (AWT) Ergonomic Aliases
alias awc='awt -c'
alias awp='awt popup'

