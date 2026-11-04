# Portability Matrix: What Works Without Root or Without These Apps

Use this to decide what a **restricted host** can take from this repository. A restricted host here means:

- **no `sudo`**;
- **some applications are forbidden**, for example a corporate machine;
- **no Omarchy or Hyprland desktop**.

Read it together with [CHANGELOG](../CHANGELOG.md), which tags every change with the same labels, so you can follow what changed and whether it applies to you.

## Tags

| Tag | Meaning on a restricted host |
| :--- | :--- |
| `portable` | Config or scripts that need only the tool they configure, installed in your home directory. No root. |
| `needs: <app>` | Works once `<app>` is available. Every Rust tool here (`wm`, `waymux`, `lazygitrs`) is a single binary that runs from `~/.local/bin` without root. |
| `needs: root` | Writes outside `$HOME` (`/etc`, system services, `pacman`) or runs privileged commands. Skip it, or ask IT. |
| `host-only` | Specific to this machine or its accounts (Omarchy, Hyprland, Apple hardware, aarch64 binaries, personal AI accounts). Rarely useful elsewhere. |

User-level systemd units (`systemctl --user`) need no root. Without a user systemd, run the program in a tmux window instead (for example `waymux daemon`).

## Packages

Stow a package with `./stow.sh <package>` (see [stow.sh](../../stow.sh)); everything below lands in `$HOME`.

### Shell & terminal core

| Package | Tag | Needs | Without it / notes |
| :--- | :--- | :--- | :--- |
| `zsh` | `portable` | zsh; `wm` (`waymaker`) for `Tab` on an empty prompt, `j`/`ji` and the transfer helpers | Without `wm`, `Tab` on an empty prompt does nothing useful (there is no fallback; [binds.zsh](../../zsh/.zsh/utils/binds.zsh)); `Tab` mid-line still completes |
| `zsh-plugins` | `portable` | zsh, git (clones the plugins) | `.ai-jail` inside it only matters with `ai-jail` |
| `tmux` | `needs: tmux ≥ 3.8` | tmux; `wm` for every picker popup; `waymux` for the agent status, Cockpit and triage; `lazygitrs` for `Ctrl+G` | Theme: set `THEME_COLORS_FILE` to any `colors.toml` when Omarchy is absent ([theme-helper.sh](../../tmux/.config/tmux/theme-helper.sh)). The status bar and plain bindings work with tmux alone |
| `waymaker` | `needs: wm` | `wm` binary | Presets for every picker; nothing to do without `wm` |
| `waymux` | `needs: waymux` | `waymux` binary, user systemd (or a tmux window) | Agent states, Cockpit, triage, phone page, launcher, quota |
| `awt` | `needs: wm` | git, `wm`; `waymux` for `waymux wt` | Worktree orchestrator; pure git underneath |
| `starship` | `portable` | starship | The Omarchy preset switcher is `host-only`; the presets themselves are plain TOML |
| `atuin`, `duf`, `procs`, `figlet`, `lolcat`, `mise`, `fed`, `cargo` | `portable` | the tool itself | One zsh snippet each. [init.zsh](../../zsh/.zsh/init.zsh) loads them through `source_packages`, which skips a package whose command is missing, so stowing one without its tool is harmless (`fed` and `cargo` are sourced directly and only set paths) |
| `bat`, `eza` | `portable` | the tool itself | **Not loaded**: they are not in the `source_packages` list. The `ls` → `eza` alias you see on Omarchy comes from Omarchy's own zsh defaults, so a host without Omarchy keeps plain `ls`. Add the name to the list to opt in |
| `yazi` | `portable` | yazi | — |
| `nvim` | `portable` | neovim (LazyVim) | Live theme reload watches Omarchy's theme dir; without it the configured colorscheme stays |
| `git`, `gh` | `portable` | git, gh, gh-dash | `gc` / `sgc` need an AI CLI ([GC_SGC.md](../../git/GC_SGC.md)) |
| `lazygitrs` | `needs: lazygitrs` | lazygitrs | — |
| `lazycommit`, `worktrunk`, `herdr`, `intelli-shell` | `portable` | the tool itself | `intelli-shell` holds the command palette catalog |
| `ghostty`, `kitty`, `foot`, `alacritty` | `portable` | that terminal | GUI terminals may be the "forbidden app" on a managed machine; tmux config does not depend on which terminal runs it |
| `fonts` | `portable` | — | Installs into `~/.local/share/fonts` (no root) |
| `xcompose`, `xkb` | `portable` | X11/Wayland input that reads them | User-level keyboard tweaks |

### AI agents

| Package | Tag | Needs | Without it / notes |
| :--- | :--- | :--- | :--- |
| `claude` | `needs: claude` | Claude Code; `waymux` and `ai-memory` for the hooks in `settings.json` | Remove hook entries for tools you lack, or they print errors each turn |
| `opencode`, `devin`, `antigravity`, `codex` | `needs: <that CLI>` | the agent CLI | `antigravity`, `devin` and `codex` also need `waymux` for their hooks; `codex` keeps its `workmux` hooks beside them |
| `agents-skills` | `portable` | an agent that reads skills | Skill text only |
| `ai-memory` | `needs: ai-memory` | `ai-memory` server (user systemd) | Cross-session memory |
| `ai_usagebar` | `host-only` | waybar | Desktop bar widget |

### `utils` (`~/.local/bin` scripts): mixed

| Scripts | Tag | Needs |
| :--- | :--- | :--- |
| `ai-launch`, `ai-switch`, `ai-quota`, `ai-failover`, `ai-prompt`, `awt-fan`, `cockpit*`, `codex-hook`, `ai-launch-models`, `ai-switch-rows` | `needs: waymux` | `waymux`; `wm` for menus; `ai-memory` for `ai-failover` continuity; `jq` for `codex-hook` |
| `ai-launch-exec` jailed rows, `agent-sudo`, `agent-sudod` | `needs: ai-jail` · `agent-sudo` is `needs: root` by design | `ai-jail` (bubblewrap); `agent-sudo` runs what you approve with `sudo` |
| `agy`, `agyy`, `ai-quota-agy`, `ai-switch-agy` | `host-only` | Antigravity accounts of this machine |
| `dev-gc`, `stow-it`, `key-telemetry`, `flow-telemetry`, `chime-at-breakpoint` | `portable` | dev-gc: cargo-clean-all; telemetry: tmux |
| `killothers`, `memtop`, `gpucheck` | `portable` | Run as your user; they only *suggest* `sudo` for processes or settings you do not own |
| `gpu-toggle` | `needs: root` | EnvyControl + reboot |
| `update-ai-workflow` (`ai-update`) | `needs: root` | Installs through `yay` / `pacman` |
| `ai-upstream`, `ai-scout` | `needs: gh` | Authenticated `gh`, `git`, Python ≥ 3.11 |
| `hypr-anim`, `hypr-border`, `hypr-sound`, `border-gradient` | `host-only` | Hyprland |
| User units in `utils/.config/systemd/user` | `portable` | user systemd (`ai-quota-refresh`, `dev-gc`, `cockpit-shutdown-save`, `agent-sudod`) |

### Desktop & hardware

| Package | Tag | Why |
| :--- | :--- | :--- |
| `hypr`, `omarchy`, `omarchy-antigravity`, `desktop`, `tuikit`, `upscayl`, `sounds`, `fcitx5`, `bluetui` | `host-only` | Omarchy / Hyprland desktop, its menus and icons |
| `battery` | `needs: root` | `etc/sudoers.d/10-battery-threshold` and charge-threshold scripts |
| `vimium` | `portable` | Browser extension shortcut list, imported by hand |

### Outside the stow packages

| Item | Tag | Why |
| :--- | :--- | :--- |
| `keyd` (CapsLock = Esc tap / Ctrl hold, [installer](../../.shell/install/packages/keyd.zsh)) | `needs: root` | System daemon and `/etc/keyd`. Without root, map CapsLock in the terminal or OS settings if allowed; the [dual-profile doc](universal-keyboard-ergonomics-and-profiles.md) covers vanilla keyboards |
| [`.shell/install/install.zsh`](../../.shell/install/install.zsh) | `needs: root` | Installs packages through `yay` / `pacman`; on a restricted host, install the tools you need into `~/.local/bin` by hand |
| `.shell/sh/enable-autologin.sh`, `us-intl-locale.sh` | `needs: root` | System settings |

## Keeping it current

When a package gains or loses a dependency on root or on an app, update its row here in the same commit, and tag the [CHANGELOG](../CHANGELOG.md) entry accordingly.
