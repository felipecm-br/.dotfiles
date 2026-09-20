# Source fzf-tab plugin (must load after compinit and zsh-vi-mode)
if [ -f "${HOME}/.zsh-plugins/fzf-tab/fzf-tab.plugin.zsh" ]; then
    source "${HOME}/.zsh-plugins/fzf-tab/fzf-tab.plugin.zsh"

    # Use Matchmaker (mm-ftb) as the exclusive completion UI engine
    zstyle ':fzf-tab:*' fzf-command mm-ftb

    # Switch between tab groups with < and >
    zstyle ':fzf-tab:*' switch-group '<' '>'

    # Include hidden files in completion candidates (e.g. .config, .env)
    zstyle ':completion:*' file-patterns '%p(D):globbing-flags' '*(/D):directories' '*(D):all-files'

    # Disable sort when completing git branches
    zstyle ':completion:*:git-checkout:*' sort false

    enable-fzf-tab
fi
