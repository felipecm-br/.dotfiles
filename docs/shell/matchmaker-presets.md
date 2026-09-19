# Matchmaker Presets Reference

Matchmaker (`mm`) uses TOML configuration presets located in `~/.config/matchmaker/presets/<name>.toml` to render specialized, purpose-built TUI interfaces invoked via `mm -o <name>`.

## Available Presets

| Preset | Invocation | Purpose | Key Actions |
| :--- | :--- | :--- | :--- |
| **jump** | `mm -o jump` | Frecency directory navigation with tree view, `nav_mode` (`h`/`l`), File Manager operations, and editor integration. | `Enter`: `cd` to directory<br>`e` / `Ctrl+E`: Open selected item(s) in Neovim (`Execute(nvim {+})`) with frecency boost<br>`Tab`: Multi-select files/directories<br>`l`: Drill down into child directory<br>`h`: Jump to parent directory<br>`u`: `@undo` (File Manager UndoStack)<br>`Ctrl+U`: Ancestor hierarchy jump (up to `/`)<br>`y` / `x` / `p` / `P`: Yank, Cut, Paste, Paste into |
| **files** | `mm -o files` / `files-picker.sh` | Fast workspace file picker & inspection for markdown, code, media, and Mermaid diagrams with borderless inline rendering. | `Enter`: Toggle 60% / 100% fullscreen preview<br>`Tab` / `Shift+Tab`: Cycle data sources (Local -> Frecency -> Bookmarks)<br>`s` (nav) / `Ctrl+S`: Toggle modal diagram preview (nearest diagram focus)<br>`Ctrl+Shift+J` / `Ctrl+Shift+K` (or `J` / `K`): Preview scroll<br>`Ctrl+V`: Insert file path into origin tmux pane<br>`e` / `Ctrl+E`: Open in editor<br>`y` / `Ctrl+Y`: Copy selected path to clipboard |
| **rg** | `mm -o rg` / `grep-picker.sh` | Live workspace full-text search with ripgrep, debounced query reload, and line-synced `bat` preview. Default: always case-insensitive. | `Enter`: Open in Neovim at line (`nvim +{line} {file}`)<br>`Ctrl+V`: Insert `{file}:{line}` into origin tmux pane<br>`Ctrl+/`: Toggle 55% / 100% fullscreen preview<br>`y` / `Ctrl+Y`: Copy `{file}:{line}` to clipboard<br>`Ctrl+S`: Toggle **Match Case** (`[Aa]` badge, yellow prompt — S for Sensitive)<br>`Ctrl+W`: Toggle **Whole Word** (`[W]` badge — W for Word)<br>Modes: default `ic` (ignore-case) → `cs` (case-sensitive) → `ww` (word+ic) → `cs+ww` (word+case). Toggles persist across query reloads via `MM_STORE`. |
| **ftb** | `mm -o ftb` | Multi-column tab completion engine for ZSH `fzf-tab` with Nucleo fuzzy matching. | `Tab`: Select item<br>`Shift-Tab`: Previous item<br>`Ctrl+P`: Toggle preview |
| **wt** | `mm -o wt` | Interactive Git Worktree switcher integrated with `worktrunk`. Live preview of `git status -s` and recent commit log. | `Enter`: Selects and returns worktree path |
| **kill** | `mm -o kill` | Interactive TCP listening port & process terminator with live connection preview. | `Enter`: Send `SIGTERM` (15)<br>`Ctrl+X`: Force `SIGKILL` (-9) |
| **memory** | `mm -o memory` | Fast explorer for project rules, `AGENTS.md`, agent skills, and durable memory. | `Enter`: Open selected file |
| **sesh-picker** | `mm -o sesh-picker` | Tmux session picker grouped by status and Nerd Font icons. | `Enter`: Connect to session via `sesh connect` |
| **window-picker** | `mm -o window-picker` | Cross-session Tmux window picker with dynamic ACPD agent indicators and live previews. | `Enter`: Switch to selected window |
| **borders** | `mm -o borders` / `hypr-border` | Interactive live Hyprland border gradient switcher with real-time preview and multi-theme template persistence. | `j` / `k`: Live-render gradient on active window<br>`Enter`: Persist style across all themes |
| **animations** | `mm -o animations` / `hypr-anim` | Interactive live Hyprland window animation switcher with instant visual preview. | `j` / `k`: Live-apply animation curve<br>`Enter`: Persist animation style |

## Headless Filter Mode (`mm -f <query>` / `mm --filter <query>`)

Matchmaker can run headlessly without initializing a terminal UI. It filters stdin streams or the current directory tree using its native Nucleo fuzzy matcher and ranked frecency scoring, printing matching results directly to stdout:

```bash
# Filter standard input stream
echo -e "apple\nbanana\ncherry" | mm -f "ban"

# Headless directory filtering
mm -f "src"
```

