# ~/.zshenv - Always loaded (even for non-interactive shells)
# Put environment variables here that should be available everywhere
export PATH="$HOME/go/bin:$PATH"


# Agent CLIs (Claude Code, Codex, Devin) open their prompt draft in $VISUAL: ai-prompt shows it in a
# tmux popup (Prefix + v) and hands every other caller (git, crontab…) to $EDITOR unchanged
[ -x "$HOME/.local/bin/ai-prompt" ] && export VISUAL="$HOME/.local/bin/ai-prompt"

# A repository's own config can name a program for core.fsmonitor, which every `git status` runs
# (your prompt, lazygitrs, waymux). An agent that writes .git/config, even inside ai-jail, could
# run code here. Config from the environment outranks the repository's, so it is off for every
# git; nothing here uses fsmonitor. See docs/architecture/state-of-the-art-terminal-agent-workflow.md §2.3
[ -z "${GIT_CONFIG_COUNT-}" ] && export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.fsmonitor GIT_CONFIG_VALUE_0=false
