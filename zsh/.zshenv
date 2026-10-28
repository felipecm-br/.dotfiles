# ~/.zshenv - Always loaded (even for non-interactive shells)
# Put environment variables here that should be available everywhere
export PATH="$HOME/go/bin:$PATH"


# Agent CLIs (Claude Code, Codex, Devin) open their prompt draft in $VISUAL: ai-prompt shows it in a
# tmux popup (Prefix + v) and hands every other caller (git, crontab…) to $EDITOR unchanged
[ -x "$HOME/.local/bin/ai-prompt" ] && export VISUAL="$HOME/.local/bin/ai-prompt"
