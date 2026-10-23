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

## 3. Adding a New Package Installer

1. If the package is a standard Arch / AUR package requiring no custom build steps, add its name to the `PACKAGES` list in [install.zsh](install.zsh).
2. If it requires custom setup, post-install hooks, or cargo/git builds, create `.shell/install/packages/<name>.zsh` using the helpers in [helpers.zsh](helpers.zsh) (`is_installed`, `log_info`, `log_success`, `log_warn`, `log_error`).
3. Verify syntax before committing:
   ```bash
   zsh -n .shell/install/packages/<name>.zsh
   ```
