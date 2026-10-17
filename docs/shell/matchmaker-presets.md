# Waymaker / Matchmaker Presets Reference

Waymaker (`wm`, with compatibility symlink `mm`) uses TOML configuration presets located in `~/.config/waymaker/presets/<name>.toml` (and `~/.config/tmux/*.toml`) to render specialized, purpose-built TUI interfaces invoked via `wm -o <name>`.

## Available Presets

| Preset | Invocation | Purpose | Key Actions |
| :--- | :--- | :--- | :--- |
| **jump** | `wm -o jump` | Frecency directory & file navigation with tree view, `nav_mode` (`h`/`l`), File Manager operations, and editor integration. | `Enter`: `cd` to directory or insert path<br>`e` / `Ctrl+E`: Open selected item(s) in Neovim (`Execute(nvim {+})`) with frecency boost<br>`Tab` / `Shift+Tab`: Cycle data sources (Local -> Frecency -> Bookmarks)<br>`Space`: Multi-select files/directories<br>`l` / `Ctrl+L`: Drill down into child directory<br>`h` / `Ctrl+H`: Jump to parent directory<br>`u`: `@undo` (File Manager UndoStack)<br>`Ctrl+U`: Ancestor hierarchy jump (up to `/`)<br>`y` / `x` / `p` / `P`: Yank, Cut, Paste, Paste into |
| **workspace** | `wm -o workspace` / `workspace-picker.sh` | Fast workspace file picker & inspection for markdown, code, media, and Mermaid diagrams with borderless inline rendering. | `Enter`: Toggle 60% / 100% fullscreen preview<br>`Tab` / `Shift+Tab`: Cycle data sources (Local -> Frecency -> Bookmarks)<br>`s` (nav) / `Ctrl+S`: Toggle modal diagram preview (nearest diagram focus)<br>`Ctrl+Shift+J` / `Ctrl+Shift+K` (or `J` / `K`): Preview scroll<br>`Ctrl+V`: Insert file path into origin tmux pane<br>`e` / `o` / `Ctrl+E`: Open in Golden Ratio split Neovim pane (62% × 38%) beside AI session<br>`y` / `Ctrl+Y`: Copy selected path to clipboard |
| **scrollback-picker** | `wm -o scrollback-picker` / `scrollback-picker.sh` | Fast regex token and command extraction from Tmux scrollback (extrakto-style) with bottom-up recency order and multi-filter tabs. | `Enter`: Copy to clipboard<br>`Ctrl+V`: Insert directly into origin pane<br>`e` / `Ctrl+E`: Open file/line token in `$EDITOR`<br>`b` / `w` / `Ctrl+B`: Open link directly in Google Chrome<br>`Tab` / `Shift-Tab`: Cycle filter modes (all → cmd → path → url → sha → all)<br>`Space`: Multi-select |
| **rg** | `wm -o rg` / `grep-picker.sh` | Live workspace full-text search with ripgrep, debounced query reload, and line-synced `bat` preview. Default: always case-insensitive. | `Enter`: Open in Neovim at line (`nvim +{line} {file}`)<br>`Ctrl+V`: Insert `{file}:{line}` into origin tmux pane<br>`Ctrl+/`: Toggle 55% / 100% fullscreen preview<br>`y` / `Ctrl+Y`: Copy `{file}:{line}` to clipboard<br>`Ctrl+S`: Toggle **Match Case** (`[Aa]` badge, yellow prompt — S for Sensitive)<br>`Ctrl+W`: Toggle **Whole Word** (`[W]` badge — W for Word)<br>Modes: default `ic` (ignore-case) → `cs` (case-sensitive) → `ww` (word+ic) → `cs+ww` (word+case). Toggles persist across query reloads via `MM_STORE`. |
| **ftb** | `wm -o ftb` / `wm-ftb` | Multi-column tab completion engine for ZSH `fzf-tab` with Nucleo fuzzy matching. | `Tab`: Select item<br>`Shift-Tab`: Previous item<br>`Ctrl+P`: Toggle preview |
| **cockpit-picker** | `cockpit-picker.sh` (`Prefix + Space`) | Unified AI Fleet & Tmux Window HUD with tri-modal preview (`Live Terminal`, `? Help/Heatmap`, `v Git Diff`). | `Enter`: Jump to window<br>`y` / `n`: Approve / Deny agent permission<br>`r`: Dispatch code review notes<br>`i`: Inline reply prompt<br>`v`: Toggle side-by-side Git diff<br>`g`: Open Lazygitrs<br>`a`: Filter AI agents<br>`Tab`: Switch to AWT Worktrees (`awt-popup.sh`) |
| **awt** (`+ awt-pr`, `awt-ai`, `awt-base`, `awt-type`, `awt-prompt`) | `wm -o awt` / `awt-popup.sh` (`Prefix + g` / `Tab`) | Autonomous Git Worktree Orchestrator & 5-step creation wizard with GitHub PR checkout (`P`). | `Enter`: Switch to worktree<br>`Tab`: Return to Cockpit<br>`c`: New worktree wizard<br>`S`: Ship (push + PR)<br>`m`: Merge locally<br>`R`: Rebase<br>`P`: Checkout GitHub PR<br>`d`: Delete worktree |
| **pr** | `wm -o pr` / `pr-picker.sh` (`Prefix + P`) | Interactive GitHub Pull Request browser with diff/overview preview and worktree checkout. | `Enter`: Checkout PR into isolated worktree<br>`Tab`: Cycle Open / Mine / Review-Requested<br>`Ctrl+E` / `o`: Open PR in browser<br>`Ctrl+D` / `v`: Toggle overview vs diff preview |
| **session-picker** | `wm -o session-picker` / `session-picker.sh` (`Prefix + s`) | Tmux session & frecency directory picker grouped by status and Nerd Font icons. | `Enter`: Connect to session via `wm connect`<br>`c`: Switch to Cockpit<br>`Tab` / `Shift+Tab`: Cycle data sources (All -> Tmux -> Dirs)<br>`d` / `Ctrl+D`: Kill session |
| **window-picker** | `window-picker.sh` | Cross-session Tmux window picker with dynamic ACPD agent indicators and live previews. | `Enter`: Switch to selected window<br>`t` / `Ctrl+T`: Switch to Session Picker<br>`n`: New window<br>`d`: Kill window |
| **keybindings** | `wm -o keybindings` / `keybindings-picker.sh` (`Prefix + ?`) | Interactive dotfiles keybindings & workflow HUD across Tmux, Shell, Frecency, and Hyprland with native Markdown documentation. | `Enter`: Execute runnable workflow / notify<br>`Tab` / `Shift-Tab`: Cycle categories (all → tmux → shell → frecency → hypr → all)<br>`y` / `Ctrl+Y`: Copy keybinding to clipboard<br>`Ctrl+V`: Insert into origin pane<br>`Esc` / `q`: Quit |
| **nvim** | `wm -o nvim` | Fast Neovim recent/project file picker with `bat` syntax preview. | `Enter`: Open selected file in Neovim |
| **downloads** | `wm -o downloads` | Recent `~/Downloads` picker sorted by modification time with image/file preview. | `Enter`: Select or open downloaded file |
| **wt** | `wm -o wt` | Interactive Git Worktree switcher with live preview of `git status -s` and recent commit log. | `Enter`: Selects and returns worktree path |
| **kill** | `wm -o kill` | Interactive TCP listening port & process terminator with live connection preview. | `Enter`: Send `SIGTERM` (15)<br>`Ctrl+X`: Force `SIGKILL` (-9) |
| **memory** | `wm -o memory` | Fast explorer for project rules, `AGENTS.md`, agent skills, and durable memory. | `Enter`: Open selected file |
| **borders** | `wm -o borders` / `hypr-border` | Interactive live Hyprland border gradient switcher with real-time preview and multi-theme template persistence. | `j` / `k`: Live-render gradient on active window<br>`Enter`: Persist style across all themes |
| **animations** | `wm -o animations` / `hypr-anim` | Interactive live Hyprland window animation switcher with instant visual preview. | `j` / `k`: Live-apply animation curve<br>`Enter`: Persist animation style |
| **backgrounds** | `wm -o backgrounds` | Interactive Omarchy desktop wallpaper switcher with Kitty Graphics preview. | `Enter`: Set active desktop background |
| **sounds** | `wm -o sounds` / `ai-sound-switcher` | Interactive ACPD auditory telemetry sound pack & event previewer. | `Enter`: Set sound<br>`p` / `Space`: Replay audio sample |
| **starship-presets** | `wm -o starship-presets` | Interactive Starship prompt theme switcher with live prompt preview. | `Enter`: Apply Starship preset |

## Headless Filter Mode (`wm -f <query>` / `wm --filter <query>`)

Waymaker can run headlessly without initializing a terminal UI. It filters stdin streams or the current directory tree using its native Nucleo fuzzy matcher and ranked frecency scoring, printing matching results directly to stdout:

```bash
# Filter standard input stream
echo -e "apple\nbanana\ncherry" | wm -f "ban"

# Headless directory filtering
wm -f "src"
```

