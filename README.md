# .dotfiles

My personal dotfiles for Arch Linux + Omarchy, managed with [GNU Stow](https://www.gnu.org/software/stow/).

## Overview

Each top-level directory is a [Stow](https://www.gnu.org/software/stow/) package that mirrors the
home-directory layout. Running `stow.sh` symlinks the package contents into `$HOME`.

```
~/.dotfiles/<package>/.config/<app>/...   -->   ~/.config/<app>/...
```

## Quick start

```bash
git clone https://github.com/fcmiranda/.dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./stow.sh            # sync: show unstowed packages and prompt to stow
./stow.sh -s         # show currently stowed packages
./stow.sh -r <pkg>   # restow a package (refresh symlinks)
./stow.sh -n         # dry run
```

Package and plugin installation is driven by `.shell/install/install.zsh`, with per-package
scripts in `.shell/install/packages/` and plugin scripts in `.shell/install/plugins/`. See
[.shell/install/README.md](.shell/install/README.md) for details.

## Stow packages

`agents-skills`, `ai-memory`, `ai_usagebar`, `alacritty`, `antigravity`, `atuin`, `awt`,
`bat`, `battery`, `bluetui`, `cargo`, `claude`, `desktop`, `duf`, `eza`, `fcitx5`, `fed`, `figlet`,
`fonts`, `foot`, `gh`, `ghostty`, `git`, `herdr`, `hibiki`, `hypr`, `intelli-shell`, `kitty`,
`lazycommit`, `lazygitrs`, `lolcat`, `mise`, `nvim`, `omarchy`, `omarchy-antigravity`, `opencode`,
`procs`, `sounds`, `starship`, `tmux`, `tuikit`, `upscayl`, `utils`, `vimium`, `waymaker`, `waymux`,
`worktrunk`, `xcompose`, `xkb`, `yazi`, `zsh`, `zsh-plugins`.

Non-stow directories: `.agents`, `.bare`, `.git`, `.github`, `.shell`, `assets`, `docs`, `scratch`, `scripts`, `tests`.

## Tooling

- **Shell:** zsh (with `zsh-vi-mode` and Smart Tab `wm-ftb`)
- **Terminal:** [Ghostty](https://ghostty.org/)
- **Multiplexer:** [tmux](https://github.com/tmux/tmux) 3.8+ (AI Fleet Cockpit HUD + `waymux` telemetry daemon)
- **TUI Picker & Session Engine:** `waymaker` (`wm` / `mm`)
- **Git TUI & AI Review Engine:** `lazygitrs` + `awt` (Agent Worktree Orchestrator)
- **AI Agents & Memory:** Antigravity (`agy` / `agyy`), Claude Code (`claude`), Codex (`codex`), Muse (`muse`), OpenCode (`opencode`), `ai-memory`, `ai-jail`
- **Editor:** Neovim
- **WM:** Hyprland (via Omarchy + Quickshell)
- **Package manager:** `yay` / `pacman` + `update-ai-workflow` (`ai-update`)

## Docs

See the [**Documentation Index (`docs/README.md`)**](docs/README.md) for the complete sitemap:

- 🏆 [**State-of-the-Art Terminal Agent Workflow (`docs/architecture/state-of-the-art-terminal-agent-workflow.md`)**](docs/architecture/state-of-the-art-terminal-agent-workflow.md) — Canonical 9.94/10 SOTA architecture (`awt` + `waymaker` + `tmux` + `waymux` + `lazygitrs`), competitor benchmarks (`workmux`, `herdr`, `zellij`), and empirical latency metrics.
- 🔬 [**Terminal Ergonomics & UX Manifesto (`docs/architecture/terminal-ergonomics-and-ux-manifesto.md`)**](docs/architecture/terminal-ergonomics-and-ux-manifesto.md) — Core HCI principles, KLM/GOMS ($H=0$), Doherty threshold (<100ms), pure icon badges, and dynamic Omarchy theme synchronization.
- ⌨️ [**Workflow Keybindings Matrix (`docs/architecture/workflow-keybindings-matrix.md`)**](docs/architecture/workflow-keybindings-matrix.md) — Comprehensive KLM biomechanical audit and 5-layer interaction matrix (Global, Tmux, Zsh, Waymaker, Lazygitrs).
- 🪟 [**Tmux Popups & Golden Ratio (`docs/tmux/popups-ergonomics-and-golden-ratio.md`)**](docs/tmux/popups-ergonomics-and-golden-ratio.md) — Hybrid Golden-Grid ($\phi$) popup geometry, 40/60 split, uniform bichromatic footers, and tri-layout Cockpit previews.
- 🤖 [**Tmux AI Status Bar (`docs/tmux/ai-status-bar.md`)**](docs/tmux/ai-status-bar.md) — Per-pane AI agent state pills, animated spinners, Vimium window hints (`Prefix + f`), and `waymux` daemon hooks.
- 📸 [**Cockpit Snapshot & Restore (`docs/architecture/cockpit-topology-snapshot-and-restore.md`)**](docs/architecture/cockpit-topology-snapshot-and-restore.md) — Automated session topology snapshots (`cockpit snapshot`), post-reboot restore (`cockpit restore`), and AI agent conversation resume.
- 📊 [**Flow Telemetry & Deep Work (`docs/architecture/evidence-based-telemetry-and-deep-work.md`)**](docs/architecture/evidence-based-telemetry-and-deep-work.md) — Evidence-based human response latency tracking, 24h deep work heatmaps, and `flow-telemetry`.
- 🐚 [**Shell & Completion (`docs/shell/completion.md`)**](docs/shell/completion.md) — Smart Tab completion (`_smart_tab`), Waymaker integration (`wm-ftb`), alias auto-spacing (`gco<Tab>`), and on-demand preview (`Ctrl+P`).
- 🚀 [**Zero-Friction File Transfer Benchmark (`docs/architecture/zero-friction-file-transfer-benchmark.md`)**](docs/architecture/zero-friction-file-transfer-benchmark.md) — Quantitative KLM-GOMS benchmark comparing 6 transfer paradigms (220ms `ptl` to 7200ms AI) and operational cheat-sheet (`pt`, `ptg`, `ptl`, `mt`, `mtg`, `mtl`, `j`, `ji`).
- 💊 [**Dynamic Workspace Pills (`docs/desktop/quickshell-workspace-pills.md`)**](docs/desktop/quickshell-workspace-pills.md) — Reactive Quickshell workspace pills with real-time app icon rewriting and title-aware webapp detection.
- 🎨 [**System Theme (`docs/theme/system-theme.md`)**](docs/theme/system-theme.md) — Omarchy theme rendering pipeline from `~/.local/state/omarchy/current/theme/colors.toml`.
- ⚡ [**Utils & Command Reference (`docs/utils.md`)**](docs/utils.md) — Repository helpers (`update-ai-workflow` / `ai-update`, `cockpit`, `flow-telemetry`, `stow-it`, `killport`, `dotadd`, `battery-threshold`, `perf-toggle`).

## Useful references

- [AGENTS.md](AGENTS.md) — working model for agents editing this repo
- [docs/GIT_WORKTREE_AGENTIC_WORKFLOW.md](docs/GIT_WORKTREE_AGENTIC_WORKFLOW.md) — worktree model and multi-agent workflow (`awt`)
- [stow.sh](stow.sh)
- [.shell/install/README.md](.shell/install/README.md)
- [.commitlintrc.json](.commitlintrc.json) / [git/GC_SGC.md](git/GC_SGC.md) — commit conventions
