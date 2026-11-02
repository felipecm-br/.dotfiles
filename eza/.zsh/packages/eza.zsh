# Not loaded by default: Omarchy's zsh defaults already alias ls to eza; add `eza` to
# source_packages in zsh/.zsh/init.zsh to use these instead.
alias ls='eza --color=auto -lh --group-directories-first --icons=auto'
alias l='eza -lbF --git --icons'
alias ll='eza -lbGF --git --icons'
alias llm='eza -lbGd --git --sort=modified --icons'
alias lsa='ls -a'
alias lx='eza -lbhHigUmuSa@ --time-style=long-iso --git --color-scale --icons'
alias lS='eza -1 --color=never --icons'
alias lt='eza --tree --level=2 --icons'
alias lta='eza --tree --level=2 -a --icons'
