# Utils & useful commands

This repo ships a small set of helpers in `utils/.local/bin/` (stowed to `~/.local/bin/`), plus a
much larger set provided by Omarchy under `~/.local/share/omarchy/bin/`. The most useful ones:

## Repo helpers (`~/.local/bin/`)

These come from the [`utils`](../utils), [`awt`](../awt), [`acpd`](../acpd), [`waymaker`](../waymaker), [`git`](../git), and [`battery`](../battery) stow packages.

| Command | Purpose |
|---------|---------|
| `cockpit` | Open the AI Fleet & Tmux Window Cockpit HUD (`cockpit-picker.sh`) from any terminal pane. |
| `cockpit-snapshot [--quiet]` | Capture active Tmux sessions, windows, panes, CWDs, and running AI agent commands to `~/.local/state/cockpit/snapshot.json`. |
| `cockpit-restore [--dry-run] [--resurrect-agents]` | Reconstruct Tmux session/window/pane topology from the latest Cockpit snapshot. |
| `flow-telemetry` | Query `~/.local/state/acpd/telemetry.jsonl` to display deep work blocks, interruption heatmaps, and agent triage metrics. |
| `acpd-cli <subcommand>` | CLI client for the `acpd` daemon (`health`, `list`, `approve`, `deny`, `input`, `kill`, `window-new`, `pane-split`, `pane-capture`, `pane-send`, `popup`, `status`). |
| `awt` / `awc` / `awp` / `awtc` | Agent Worktree Orchestrator (`awt`), 5-step creation wizard (`awc`), floating worktree popup (`awp`), and `.bare` repository cloner (`awtc`). |
| `wm` / `mm` / `wm-ftb` | Waymaker Rust TUI picker engine (`wm`), compatibility alias (`mm`), and zero-fork `fzf-tab` completion binary (`wm-ftb`). |
| `sesh` | Drop-in compatibility wrapper delegating `sesh connect`, `sesh list`, and `sesh last` to native `wm session`. |
| `gc` / `sgc` / `gtest` | AI-assisted conventional commit generator (`gc`), smart multi-commit splitter (`sgc`), and automated pre-commit test/lint runner (`gtest`). |
| `agy` / `agyy` | Antigravity CLI wrapper (`agy`, cleans up Tmux/Lazygitrs icons on exit) and secondary isolated profile/account launcher (`agyy`). |
| `update-ai-workflow` / `ai-update` | Comprehensive CLI manager to audit and update all AI workflow dependencies (`tmux`, Nerd Fonts, `codex`, `agy`, `antigravity-ide`, `claude`, `opencode`, `acpd`, `ai-suite`, `worktrunk`, `mise`). Supports `--check`, `--update`, `--all`, and `--only <comp>`. |
| `ai-memory-clean [--apply]` | Audit and prune stale observations, orphan sessions, and duplicate entries in `ai-memory`. |
| `ai-sound-switcher` / `ai-sound-pack-install` / `ai-sound-generate` | Interactive TUI switcher (`wm -o sounds`), pack installer, and synthesizer for ACPD auditory telemetry alerts. |
| `chime-at-breakpoint` | Emit an auditory chime when a debugger or background pipeline hits a breakpoint. |
| `hypr-border` / `hypr-anim` | Live interactive Hyprland border gradient (`wm -o borders`) and window animation curve (`wm -o animations`) switchers. |
| `stow-it <path> [package]` | Adopt an existing file or dir into the dotfiles repo and stow it. Resolves the real path, moves it under `~/.dotfiles/main/<package>/...`, and runs `stow.sh -a <package>`. |
| `battery-threshold [pct]` | Set hardware battery charge threshold (e.g., `80`) to extend battery lifespan (`battery` package). |
| `perf-toggle` | Toggle CPU energy performance profile between performance, balanced, and power-saver (`battery` package). |
| `battery-health` | Display battery health stats, current capacity, and cycle count (`battery` package). |
| `gpucheck [--fix] [--watch]` | NVIDIA / Intel GPU, driver, and energy-performance diagnostics. |
| `gpu-toggle` | Switch between NVIDIA dedicated and Intel integrated GPU via EnvyControl. Requires sudo and a reboot. |
| `killothers [--dry-run] [--force] [--signal SIGNAL]` | Kill processes owned by *other* users while preserving the current user's session. |
| `memtop [--kill] [--report] [--watch] [--top N]` | Interactive memory analyzer and process killer. |

## Zsh Shell Helpers

Defined in [`zsh/.zsh/utils/functions.zsh`](../zsh/.zsh/utils/functions.zsh):

| Command / Function | Purpose |
|-------------------|---------|
| `j [query]` / `ji` | **Waymaker Frecency Jump**: Fast directory jump (`j`) or interactive tree picker (`ji` / `wm -o jump`) backed by `wm_smart_chpwd`. |
| `ptl` / `ptg` / `pt` | **Polymorphic Copy (`pasteto`)**: Copy files using local directory picker (`ptl`), global frecency picker (`ptg`), or bidirectional Smart Flow (`pt`). |
| `mtl` / `mtg` / `mt` | **Polymorphic Move (`moveto`)**: Move files using local directory picker (`mtl`), global frecency picker (`mtg`), or bidirectional Smart Flow (`mt`). |
| `killport <port>` | Find and terminate any process or Docker container listening on specified TCP port (e.g. `killport 3000`). |
| `dotadd <package> [files...]` | Copy file(s) into `~/.dotfiles/main/<package>/` with correct stow structure and trigger restow automatically. |
| `wtr [old-name] <new-name>` | Rename a git worktree directory and its branch atomically. |
| `wtj` | Interactively select and jump (`cd`) into a Git Worktree via Waymaker (`wm -o wt`). |
| `bd <parent-dir>` | Jump directly to an ancestor directory by name without counting `cd ../..` levels. |
| `ai-fix [note]` | **360° AI Error Dispatch**: Captures last command, exit code, terminal scrollback (45 lines), active Git branch/worktree, `git status`, and recent uncommitted `git diff`, dispatching directly to `opencode`, `agy`, or `claude`. |

## Waymaker Presets (`wm -o <preset>`)

Specialized TUI pickers configured in [`waymaker/.config/waymaker/presets/`](../waymaker/.config/waymaker/presets/) and [`awt/.config/waymaker/presets/`](../awt/.config/waymaker/presets/):
* `wm -o jump` — Interactive directory & file navigation with frecency, bookmarks, and File Manager (`nav_mode`).
* `wm -o workspace` — Workspace file explorer with native Markdown, Mermaid diagram, and image rendering (`Prefix + e`).
* `wm -o scrollback-picker` — Extrakto-style token, command, path, and URL extractor from Tmux scrollback (`Prefix + y`).
* `wm -o rg` — Live full-text ripgrep search with line-synced `bat` preview (`Prefix + /`).
* `wm -o pr` — Interactive GitHub Pull Request browser and worktree checkout (`Prefix + P`).
* `wm -o awt` — Agent Worktree Manager dashboard with 3-tab live Git previews (`Prefix + g` / `awp`).
* `wm -o keybindings` — Interactive dotfiles keybindings & workflow HUD (`Prefix + ?`).
* `wm -o ftb` — High-performance multi-column tab completion for `fzf-tab` (`wm-ftb`).
* `wm -o kill` — Interactive TCP listening port & process terminator (`Enter` for SIGTERM, `Ctrl+X` for SIGKILL).
* `wm -o memory` — AI memory, `AGENTS.md`, and project rules explorer.
* `wm -o borders` / `hypr-border` — Interactive Hyprland border gradient switcher with real-time live preview (`SUPER + ALT + B`).
* `wm -o animations` / `hypr-anim` — Interactive Hyprland window animation switcher (`SUPER + SHIFT + A`).
* `wm -o sounds` / `ai-sound-switcher` — Interactive ACPD audio pack & sound alert switcher.
* `wm -o backgrounds` — Interactive Omarchy wallpaper switcher.
* `wm -o starship-presets` — Interactive Starship prompt preset switcher.

See [matchmaker-presets.md](shell/matchmaker-presets.md) for full documentation.

## Hardware & Keyboard Ergonomics (Home Row Optimization)

* **Caps Lock Mapping**: Dual-function key — **`Esc` on tap** (instant Normal Mode in Neovim/Zsh) and **`Ctrl` on hold** (Home Row anchor at position `(0, 0)`).
* **Biomechanics / KLM Cost ($H = 0$)**: Because the left pinky rests on the Home Row, chords like `Ctrl+Space` (Tmux Prefix), `Ctrl+G` (Lazygitrs), `Ctrl+F` (Matchmaker Jump), and `Ctrl+N` (Matchmaker Branch Completion) execute in under 50ms with zero wrist abduction.

## Stow management

Run from `~/.dotfiles/main`:

```bash
./stow.sh                 # sync: show unstowed packages, prompt to stow
./stow.sh -s              # list currently stowed packages (from stow-lock.json)
./stow.sh -n              # dry run — report what would change
./stow.sh <pkg>           # stow a single package
./stow.sh -r <pkg>        # restow (refresh symlinks) a single package
./stow.sh -a <pkg>        # adopt existing files in $HOME into the repo
./stow.sh -d <pkg>        # unstow (remove symlinks)
```

`stow-lock.json` is generated state — never edit it manually.

## Refreshing Hyprland

After editing `~/.config/hypr/*.conf`, apply the change without restarting the session:

```bash
omarchy-refresh-hyprland       # overwrite ~/.config/hypr/* with Omarchy defaults, then reload
omarchy-restart-hyprctl        # just `hyprctl reload` — re-reads the existing config files
omarchy-refresh-config <rel>   # copy one file from ~/.local/share/omarchy/config/... to ~/.config/...
```

For a single edited file you can also just point `hyprctl` at it:

```bash
hyprctl reload
```

The `theme-set` hook (see [system-theme.md](theme/system-theme.md)) already calls
`omarchy-restart-hyprctl` after a theme swap, so you don't need to do this manually on theme
changes.

## Restarting other components

Omarchy ships focused restart helpers — useful after editing a config or when something wedges:

```bash
omarchy-restart-waybar
omarchy-restart-mako
omarchy-restart-fuzzel
omarchy-restart-walker
omarchy-restart-terminal         # signals the running terminal emulator to reload
omarchy-restart-tmux             # reload tmux config across running sessions
omarchy-restart-hypridle
omarchy-restart-hyprlock
omarchy-restart-hyprsunset
omarchy-restart-swayosd
omarchy-restart-btop
omarchy-restart-opencode
omarchy-restart-pipewire
omarchy-restart-bluetooth
omarchy-restart-wifi
omarchy-restart-trackpad
omarchy-restart-xcompose
```

## Hyprland monitor / window helpers

```bash
omarchy-hyprland-monitor-focused
omarchy-hyprland-monitor-internal
omarchy-hyprland-monitor-scaling-cycle
omarchy-hyprland-monitor-watch
omarchy-hyprland-toggle                       # enable/disable Hyprland monitor handling
omarchy-hyprland-window-pop
omarchy-hyprland-window-gaps-toggle
omarchy-hyprland-window-single-square-aspect-toggle
omarchy-hyprland-workspace-layout-toggle
omarchy-hyprland-active-window-transparency-toggle
omarchy-hyprland-window-close-all
```

## Theme commands

See [system-theme.md](theme/system-theme.md) for the full theme system. Quick reference:

```bash
omarchy-theme-list                # available themes
omarchy-theme-current             # active theme name
omarchy-theme-set <name>          # switch theme
omarchy-theme-refresh             # re-render current theme
omarchy-theme-bg-set <path>       # set wallpaper for current theme
omarchy-theme-bg-next             # next built-in wallpaper
```

## Hardware / system helpers

```bash
omarchy-capture-screenshot            # screenshot utility
omarchy-capture-screenrecording       # screen recording utility
omarchy-screensaver
omarchy-audio-output-switch         # switch audio output device
omarchy-audio-input-mute            # mute mic (variant per hardware)
omarchy-brightness-display       # display brightness control
omarchy-brightness-keyboard       # keyboard backlight
omarchy-battery-status           # battery info / present / remaining / capacity
omarchy-hibernation-available / omarchy-hibernation-setup / omarchy-hibernation-remove
omarchy-font-list / omarchy-font-set / omarchy-font-current
omarchy-emoji-picker
```

Discover all of them with `ls ~/.local/share/omarchy/bin/` (248+ scripts) or run any command with
`-h` / `--help` for usage.

## Adding a new helper

1. Drop a script under `~/.dotfiles/main/utils/.local/bin/<name>` (or the right stow package for
   the file path).
2. Make it executable: `chmod +x utils/.local/bin/<name>`.
3. Run `./stow.sh -r utils` to refresh the symlink into `~/.local/bin/`.