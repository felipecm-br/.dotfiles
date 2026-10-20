# The Mystery of Tmux Tab Highlight (Window Activity Monitoring)

You might have noticed that when asking the AI a question using `agy` (Antigravity) while switched to another tab, the original `agy` tab highlighted (inverting the background color), whereas the same did not happen when using `oc` (OpenCode).

## Why Does This Happen?

This is neither a bug nor caused by our `waymux` daemon. It is a classic (and very useful) feature called **Tmux Window Activity Monitoring**.

### The Antigravity (`agy`) Case
Antigravity operates as a pure CLI tool. While processing a response or outputting a prompt (e.g., `"What would you like to do?"`), it sends standard text output (`stdout`) to the terminal screen.

When Tmux detects that a background tab has just received new text characters on screen, it identifies that the terminal in the background has updated and notifies you. Consequently, it inverts that tab's background color in the status bar to draw your attention.

### The OpenCode (`oc`) Case
OpenCode uses a TUI (Text User Interface) framework—similar to `htop`, `lazygit`, or `neovim`. Instead of outputting raw text lines, these applications actively manage screen drawing using alternate screen buffers and typically pause sending raw updates when waiting for user input. Because no continuous raw text is printed to standard terminal output, Tmux does not trigger the activity monitor.

## Configuration (Disabled by Default in Favor of `waymux`)

Because our `waymux` daemon provides structured, per-pane semantic status pills (`@ai_agent_state` and `@ai_agent_state_color`), native Tmux activity monitoring is disabled in [`tmux/.config/tmux/tmux.conf`](../../tmux/.config/tmux/tmux.conf) to prevent noisy stdout tab inversions:

```tmux
# Window Activity Monitoring
setw -g monitor-activity off
set -g visual-activity off
```

- `setw -g monitor-activity off` -> Disables generic stdout activity highlighting so only semantic `waymux` agent state transitions colorize background tabs.
- `setw -g monitor-activity on` -> Re-enables generic tab highlighting on any background stdout output.
- `set -g visual-activity off` -> Prevents Tmux from displaying text messages at the bottom status line (e.g., `"Activity in window 0"`).

> **To reload the configuration:**
> Press `Ctrl+Space` followed by `r` in Tmux to source `tmux.conf`.
