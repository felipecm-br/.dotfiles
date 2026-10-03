# Tmux Clipboard & Scrollback Capture

Notable clipboard, selection, and history buffer inspection behaviors wired into tmux.

---

## 1. Click-and-Hold to Copy Text Inside Tmux

Clicking and dragging (click-and-hold) the mouse over text inside a tmux pane selects it and copies it to the system clipboard.

Enabled in [`tmux/.config/tmux/tmux.conf`](../../tmux/.config/tmux/tmux.conf):

1. **Global Mouse Support**:
   ```tmux
   set -g mouse on
   ```
   With `mouse on`, a click-drag inside a pane enters `copy-mode-vi` and starts a visual selection.

2. **System Clipboard Pipe on Release (`MouseDragEnd1Pane`)**:
   ```tmux
   bind -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "xclip -in -selection clipboard"
   ```

3. **Keyboard Copy (`y`)**:
   ```tmux
   bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "xclip -in -selection clipboard"
   ```

While a selection is active, tmux signals it visually: the active pane border switches to the `@COPY_COLOR` color (see `pane-active-border-style` in `tmux.conf`), and the status bar pill recolors via `pane_in_mode`.

> **Note:** Requires `xclip` (`pacman -S xclip`).

---

## 2. Scrollback Capture to Neovim (`Prefix + E`)

You can capture the full scrollback history of the current tmux pane (with ANSI colors preserved) and open it directly in Neovim for searching, copying, or inspection.

### Keybinding (`Prefix + E`)

In [`tmux/.config/tmux/tmux.conf`](../../tmux/.config/tmux/tmux.conf), pressing `Prefix` (`Ctrl+Space`) then `Shift+e` (`E`) captures the active pane's scrollback buffer:

```tmux
bind-key "E" run-shell "~/.config/tmux/scrollback-view.sh"
```

**How it works:**
1. `tmux capture-pane -epJS -` exports (`-J` rejoins wrapped lines) the full pane scrollback history, retaining ANSI color escape codes.
2. Drops empty lines (`sed '/^$/d'`), saving to `/tmp/tmux_scrollback.ansi`. (The old prompt-glyph `grep -vE` stage was removed: its non-zero exit status aborted the `&&` chain and silently killed the binding.)
3. Spawns a new tmux window running Neovim, colorizing ANSI escape sequences with [`baleia.nvim`](../../nvim/.config/nvim/lua/plugins/baleia.lua) via `:BaleiaColorize` (guarded by `silent!`, so a missing/slow plugin can never break the binding), setting the buffer as read-only (`nomodified nomodifiable`), and jumping to the bottom (`G`). Failures are visible by design: a failed capture shows a `display-message` and logs to `/tmp/scrollback-view.err` (the old inline version died silently).

### Shell alias (`scrollback`)

A zsh alias is provided in [`zsh/.zsh/utils/aliases.zsh`](../../zsh/.zsh/utils/aliases.zsh):

```zsh
alias scrollback='tmux capture-pane -epS - > /tmp/tmux_scrollback.ansi && nvim -c "BaleiaColorize" -c "normal G" /tmp/tmux_scrollback.ansi'
```

### History Limit & Vi Mode

- `set-option -g history-limit 10000`: Expands scrollback buffer to 10,000 lines per pane.
- `setw -g mode-keys vi`: Enables Vi navigation keybindings in copy mode.


---

## 3. Token & Command Extract to Clipboard (`Prefix + y` / `Prefix + C-y`)

Fuzzy copy/insert of structured tokens and commands (Linux CLI commands, paths, URLs, git hashes, IPs) from the full scrollback via `wm`, extrakto-style — no editor round-trip.

Bind ([`tmux.conf`](../../tmux/.config/tmux/tmux.conf)): `Prefix` then `y` or `C-y` (scrollback picker / token & link extract) runs [`scrollback-picker.sh`](../../tmux/.config/tmux/scrollback-picker.sh) with the origin pane id. The script opens a themed popup itself (rounded border in theme green, pure icon badge ` 󰅍 `, golden `75% x 60%`). When an agent is streaming (`@ai_agent_state_raw` = busy/working), it opens over a frozen snapshot backdrop instead, per Issue B in `popup-isolation-and-debounce.md`:

1. `tmux capture-pane -pJS - -t <origin>` exports the origin pane explicitly (never the popup), joining wrapped lines (`-J`) so split commands and URLs survive; full text kept in `/tmp/scrollback-picker-src.txt`.
2. Token files per filter precomputed (`-all/-cmd/-path/-url/-sha.txt`), bottom-up deduped and recent-first. Commands are extracted from prompt-prefixed lines (`❯`, `$`, `#`, `>`), AI tool execution logs (`● Bash(...)`), and common Linux CLI verbs (`pacman`, `yay`, `rm`, `mv`, `git`, `cargo`, `just`, `systemctl`, etc.). In `all` mode, tokens are interleaved chronologically so the most recent screen outputs (URLs, paths, commands) appear at index 0.
3. `wm -o scrollback-picker` (canonical preset [`scrollback-picker.toml`](../../waymaker/.config/waymaker/presets/scrollback-picker.toml): nav mode starting in filter, jump-style keymap) with items from `[start] command`. Keys: `Enter` copies, `Ctrl+V` inserts the current token/command directly into the origin pane (`MM_ORIGIN_PANE`), `Ctrl+E` (filter) / `e` (nav) opens a `path[:line[:col]]` token in `$EDITOR` via [`scrollback-open.sh`](../../tmux/.config/tmux/scrollback-open.sh), `Ctrl+B` (filter) / `b` / `w` / `x` (nav) opens URLs directly in Google Chrome via [`scrollback-chrome.sh`](../../tmux/.config/tmux/scrollback-chrome.sh) (also auto-delegated by `scrollback-open.sh` if invoked on URLs), `Tab`/`Shift-Tab` cycle explicit filter modes (all→cmd→path→url→sha→all), `Space` multi-selects, `Esc` cascades filter→nav→quit, `Ctrl+P` / `P` cycles between 60% and 95% full-modal preview.
4. Copy tail runs detached (`trap '' HUP`, `&`) to `wl-copy` (fallback `xclip`, then tmux buffer) with a `tmux display-message` confirm, so the popup closes the instant `Enter` is pressed; stages are timestamped in `/tmp/scrollback-picker-mm.log`. Covered by `tests/scrollback_picker.test.sh`.

Rule of thumb: `Prefix + E` = **read** (long-form inspection in Neovim), `Prefix + e` / `Prefix + C-e` = **explore** (workspace files popup), `Prefix + y` / `Prefix + C-y` = **scrollback-picker** (tokens, links & shell commands to clipboard or prompt in ~3 keystrokes).

---

## 4. Workspace Files Peek (`Prefix + e` / `Prefix + C-e`)

Browse workspace files and AI-generated code in a popup via `mm -o workspace` (or alias `mm -o files`) — inspect files with syntax-highlighted previews, tree, and native Markdown, Mermaid diagrams & Photos rendering without leaving the AI chat window.

Bind ([`tmux.conf`](../../tmux/.config/tmux/tmux.conf)):
- `Prefix + e` / `Prefix + C-e`: Opens Golden Ratio popup (`75% × 60%`) via inward roll (`e` = Explorer).

Architecture ([`workspace-picker.sh`](../../tmux/.config/tmux/workspace-picker.sh) / [`files-picker.sh`](../../tmux/.config/tmux/files-picker.sh) and canonical preset [`workspace.toml`](../../waymaker/.config/waymaker/presets/workspace.toml), with compatibility alias [`files.toml`](../../waymaker/.config/waymaker/presets/files.toml)):
1. **Themed Popup & Pure Icon Badge**: Uses theme blue/cyan border with pure icon badge ` 󰈞 󰄧 󰋩 ` (Explorer, Mermaid diagrams, and Photos), with frozen backdrop protection when an agent streams.
2. **Native Markdown, Mermaid & Photos Rendering**: Automatically routes `.md`, `.markdown`, `.mmd`, `.png`, `.jpg`, `.webp` through native media and diagram pipelines with Kitty Graphics Protocol passthrough.
3. **Diagram & Photo Zoom Controls & HUD Icons**:
   - `s`: Toggles diagram inspector modal (`󰄧`).
   - `+` / `ctrl-+`: Zooms in (`󰍉`).
   - `-` / `ctrl--`: Zooms out (`󰍋`).
   - `0` / `ctrl-0`: Resets zoom to 100% 1:1 (`󰑐`).
   - `n` / `N`: Jumps to next/previous diagram in markdown (`󰒭`).
4. **Dynamic Exclusive Fullscreen Preview (`Enter` / `Esc`)**:
   - Layout 0: Standard Golden Ratio split (**40% list / 60% preview**).
   - Layout 1: Exclusive 100% fullscreen preview mode (**0% list / 100% preview**) displaying only the preview content and dedicated navigation shortcuts in the footer.
   - Pressing `Esc` or `Enter` immediately returns to the normal split view.
5. **Origin Pane & AI Prompt Insertion (`Ctrl+V` / `y`)**:
   - `y` / `Ctrl+Y`: Copies path(s) to system clipboard and closes modal.
   - `Enter`: Expands to exclusive 100% fullscreen preview modal.
   - `Ctrl+V`: Injects the path directly into the origin pane (`MM_ORIGIN_PANE`) — instant referencing into the active AI prompt.
   - `Ctrl+E` / `e` / `o`: Opens the selected file in `$EDITOR` (Neovim) in a Golden Ratio left split pane (`62% × 38%`, `split-window -h -b -l 62%`) beside the origin pane (or loads into an existing Neovim pane), closing the popup immediately to preserve visual concurrency with the AI session.
   - `l` / `h`: Drills down or navigates up directory levels seamlessly.
   - `Tab` / `Shift+Tab`: Cycles data sources (Local files -> Frecency -> Bookmarks).

---

## 🔍 Live Ripgrep Full-Text Search (`grep-picker.sh`)

Instant full-text workspace search using Matchmaker and ripgrep, featuring debounced query reloads, line-synced `bat` preview, and 1-touch navigation into Neovim.

Bind ([`tmux.conf`](../../tmux/.config/tmux/tmux.conf)):
- `Prefix + /`: Opens centered modal (`85% × 75%`) via universal `/` search mnemonic.

Architecture ([`grep-picker.sh`](../../tmux/.config/tmux/grep-picker.sh) and preset [`rg.toml`](../../waymaker/.config/waymaker/presets/rg.toml)):
1. **Live Query Reload**: Search updates in real-time as you type, aborting previous processes automatically on input changes.
2. **45/55 Foveal Layout**: 45% candidate match column on the left and 55% syntax-highlighted code preview on the right.
3. **Line-Synced `bat` Preview**: Automatically centers and highlights the matched line number using `bat --highlight-line`.
4. **Direct Navigation (`Enter`)**: Opens Neovim directly at the matched line (`nvim +{line} {file}`).
5. **AI Prompt Injection (`Ctrl+V`)**: Injects `{file}:{line}` directly into the active terminal pane (`MM_ORIGIN_PANE`).
