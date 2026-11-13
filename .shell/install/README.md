# Dotfiles Package & Plugin Bootstrap (`.shell/install/`)

This directory contains the declarative, idempotent bootstrap engine for installing system packages, custom binaries, and Zsh plugins on Arch Linux + Omarchy.

---

## 1. Architecture & Directory Layout

```text
.shell/install/
├── install.zsh          # Master orchestrator (packages, custom scripts, zsh plugins)
├── helpers.zsh          # Shared logging, idempotency checks, and AUR/pacman wrappers
├── packages/            # Custom per-package installer scripts (<name>.zsh)
│   ├── tmux.zsh         # Tmux 3.8+ (with sixel & systemd support)
│   ├── nvim.zsh         # Neovim + LazyVim dependencies
│   ├── mise.zsh         # Mise runtime manager
│   └── ...
└── plugins/             # Zsh plugin installers (<name>.zsh)
```

- **Source of Truth**: [install.zsh](install.zsh) defines the canonical `PACKAGES` array and sources custom installers from `packages/*.zsh` and `plugins/*.zsh`.
- **Sourced Execution Contract**: All scripts under `packages/` and `plugins/` are **sourced** directly by `install.zsh`. Always use `return 0` (or `return 1`) for early exits—**never** `exit`, which would terminate the parent shell session.

---

## 2. Usage

### Run Full Bootstrap
```zsh
zsh ~/.dotfiles/main/.shell/install/install.zsh
```

### Update AI Workflow & Tooling Ecosystem
For auditing and updating the AI agent and terminal cockpit ecosystem (`tmux`, `plugins`, `fonts`, `codex`, `agy`, `antigravity-ide`, `claude`, `devin`, `opencode`, `waymux`, `ai-memory`, `ai-jail`, `ai-usagebar`, `worktrunk`, `mise`), use the dedicated parallel updater:

```bash
ai-update --check          # Fast dry-run audit across all 15 AI workflow components
ai-update                  # Update all components in parallel
ai-update --only waymux,agy  # Target specific components
```

---

## 3. Fresh Omarchy Install

Checked against Omarchy 4.5 on aarch64 (Apple Silicon). On a Mac, start with [Omarchy 4.5 Fresh Install on Apple Silicon](../../docs/desktop/omarchy-mac-fresh-install.md): disk split, removing the old install, macOS 15.

### Before wiping

1. Every repo under `~/dev/github` is pushed: `git log --branches --not --remotes --oneline` prints nothing.
2. Back up what is not in this repo, and copy the archive **off the machine**:
   `~/.ssh`, `~/.gnupg`, `~/.aws`, `~/.config/gh`, `~/.claude`, `~/.codex`,
   `~/.local/share/ai-memory`, `~/.local/share/atuin` + `~/.config/atuin`,
   non-git folders in `~/dev`, and unstowed user units such as `hermes-gateway.service`.

### After installing Omarchy

```zsh
# 1. Clone in the bare + worktree layout (see docs/GIT_WORKTREE_AGENTIC_WORKFLOW.md)
git clone --bare https://github.com/felipecm-br/.dotfiles.git ~/.dotfiles/.bare
git -C ~/.dotfiles/.bare worktree add ../main main
cd ~/.dotfiles/main

# 2. Packages, custom builds (tmux 3.8, wm, lazygitrs, waymux), zsh + tmux plugins
zsh .shell/install/install.zsh
```

3. **Compare before stowing.** `hypr/.config/hypr/hyprland.lua` loads Omarchy's own modules
   (`default/hypr/bootstrap.lua`, `default.hypr.omarchy`, `default.hypr.toggles`,
   `default.hypr.require_optional`). Diff the fresh `~/.config/hypr/hyprland.lua` and
   `~/.config/omarchy/shell.json` against this repo, and port any renamed module or new key.
4. **Stow.** Omarchy has already written files at the link targets. Either delete them, or adopt and then restore the repo copies:
   ```zsh
   ./stow.sh -a && git restore .   # adopt copies Omarchy's defaults in; restore puts yours back
   ./stow.sh -n && ./stow.sh -s
   ```
5. **User services:** `systemctl --user daemon-reload`, then enable `waymux`, `ai-memory`,
   `dev-gc.timer`, `ai-quota-refresh.timer`, `cockpit-shutdown-save` and `agent-sudod`.
6. **Restore and log in:** extract the backup, then sign in again to `gh auth login`, Claude, Codex, Bitwarden and `sudo tailscale up`.
7. **Finish:** `~/.config/tmux/key-telemetry.py install`, `ai-update --check`.

### Omarchy 4.5 notes

- 4.5 resets Caps Lock to normal and makes `Shift+Caps` the compose key. keyd ([keyd.zsh](packages/keyd.zsh)) remaps the key before Omarchy sees it, so tap-Esc / hold-Ctrl still wins.
- `bindings.lua` rebinds `Super+L`, `Super+M` and `Super+V` on purpose. That gives up 4.5's layout cycle on `Super+L` and minimize-to-dock on `Super+M`. Check the other new defaults (`Super+Q/A/I`, `` Super+` ``) with `o.rebind`.
- On aarch64, AUR `-bin` packages with no ARM build are skipped with a warning.

## 4. Adding a New Package Installer

1. If the package is a standard Arch / AUR package requiring no custom build steps, add its name to the `PACKAGES` list in [install.zsh](install.zsh).
2. If it requires custom setup, post-install hooks, or cargo/git builds, create `.shell/install/packages/<name>.zsh` using the helpers in [helpers.zsh](helpers.zsh) (`is_installed`, `log_info`, `log_success`, `log_warn`, `log_error`).
3. Verify syntax before committing:
   ```bash
   zsh -n .shell/install/packages/<name>.zsh
   ```
