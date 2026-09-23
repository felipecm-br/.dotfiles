# Open-Source Strategy: Terminal AI Cockpit Stack

> **Canonical Blueprint:** See [docs/architecture/open-source-ai-tmux-stack-plan.md](docs/architecture/open-source-ai-tmux-stack-plan.md) for the complete production-grade architectural specification, technical audit, and multi-arch CI/CD pipeline based on Fabio Akita's open-source release principles.

---

## 1. Executive Summary & Value Proposition

The goal is to transition our battle-tested terminal AI state orchestration into a modular, zero-compilation open-source distribution: **The Terminal AI Cockpit Stack**.

### The Core Problem Solved (Akita's Golden Rule)
1. **Zero Terminal Redraw Flicker:** Active AI token streaming breaks popup borders and search inputs during background ANSI redraws.
2. **Event-Driven Status Bar:** `status-interval 0` with 0% idle CPU drain and sub-300ms debounce.
3. **Frozen Snapshot Backdrop Popups:** Seamless floating overlays (`display-popup`) backed by per-pane UID-isolated ANSI snapshot buffers.
4. **1-Key Inline Diff Review to AI:** Review git diffs directly in TUI (`lazygitrs`), annotate lines, and bracket-paste them instantly into active agent panes (`antigravity`, `opencode`).
5. **Zero-Compile 1-Command Install:** Pre-built static `musl` Linux and Apple Silicon `Darwin` binaries bundled into a single repository (`terminal-ai-cockpit`), installed via `curl -fsSL ... | bash` in under 30 seconds.

---

## 2. Two-Tier Umbrella Architecture

Rather than forcing users to assemble disparate repositories or compile 13 C tree-sitter grammars from source, the project employs a **Two-Tier Distribution Model**:

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                        TIER 1: UPSTREAM SUB-REPO ENGINES                               │
├──────────────────────────┬───────────────────────────┬─────────────────────────────────┤
│ fcmiranda/acpd           │ fcmiranda/lazygitrs       │ fcmiranda/matchmaker (waymaker) │
│ (Axum 0.8, Tokio 1.52)   │ (branch: fecavmi)         │ (binary: wm / waymaker)         │
│ Native Rust Toolchain    │ cross-rs / cargo-zigbuild │ Native Rust Toolchain           │
│ (musl + Darwin static)   │ (13 C parsers + musl)     │ (musl + Darwin static)          │
└────────────┬─────────────┴─────────────┬─────────────┴────────────────┬────────────────┘
             ▼                           ▼                              ▼
     acpd-<target>.tar.gz       lazygitrs-<target>.tar.gz        wm-<target>.tar.gz
             │                           │                              │
             └───────────────────────────┼──────────────────────────────┘
                                         ▼
┌────────────────────────────────────────────────────────────────────────────────────────┐
│          TIER 2: terminal-ai-cockpit UMBRELLA DISTRIBUTION (ZERO COMPILATION)          │
├────────────────────────────────────────────────────────────────────────────────────────┤
│ • install.sh               -> 1-line zero-compile curl installer (< 30s execution)     │
│ • cockpit-manifest.json    -> Pinned upstream release tags of acpd, lazygitrs, wm      │
│ • pre-built release assets -> Unified tarballs: terminal-ai-cockpit-v*.*.*-<target>    │
│ • cockpit.tmux             -> Event-driven status pills & popup bindings               │
│ • scripts/                 -> tmux-popup-isolate.sh, lazygit-tmux-injector.sh          │
│ • hooks/                   -> Zero-config AI agent hooks (antigravity, opencode)       │
│ • systemd/                 -> acpd.service user unit                                   │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Subsystem Breakdown

### A. `fcmiranda/acpd` (The Broker Daemon)
- **Role:** High-throughput async broker managing per-pane agent state transitions, dynamic spinner rendering, and status sinks (Tmux, Waybar).
- **Status:** Release CI configured, dynamic token generation verified, pushed to `origin/main`. Actively running via `systemd --user`.
- **Next:** Centralize debouncing in `api.rs` (300ms), fix 4 `collapsible_if` clippy warnings.

### B. `fcmiranda/lazygitrs` (The Review Engine)
- **Role:** Blazing fast Git TUI with `--commits`, worktree port discovery, and headless inline diff review note injection (`S` bracket-pasted to active AI pane).
- **Status:** Branch `fecavmi` pushed to `origin/fecavmi` (commit `27bce0347`). Bare worktree architecture active.
- **Next:** Remediate clippy warnings, configure `cross-rs` for the 13 C tree-sitter parsers, relocate `.lines.json` to `.git/info/` to eliminate repository working tree pollution.

### C. `fcmiranda/matchmaker` / `waymaker` (The Nav & Selector Layer)
- **Role:** Sub-millisecond fuzzy finder with live-reload inotify watch (`-w`), Kitty graphics caching, and Mermaid diagram rendering.
- **Status:** Evolved and rebranded to **Waymaker** (`wm`) on branch `waymaker`, pushed to origin. Canonical binary `~/.local/bin/wm` active throughout dotfiles.
- **Next:** Scope `rustfmt --check` in CI to changed files, gate dead code in `fm.rs`.

### D. `tmux` Backdrop Isolation Layer
- **Role:** Guarantees popup stability during active token streaming via frozen ANSI backdrops.
- **Status:** Core isolator script [`tmux/.config/tmux/tmux-popup-isolate.sh`](tmux/.config/tmux/tmux-popup-isolate.sh) implemented with full CLI parsing, conditional idle bypass, and `0600` UID-pane isolation. All popup callers (`grep-picker.sh`, `lazygitrs-popup.sh`, `files-picker.sh`, `sesh-picker.sh`, `window-picker.sh`, `scrollback-extract.sh`, `awt-popup.sh`) migrated.
- **Next:** Optional decoupled border theming fallbacks for generic non-Omarchy systems.

---

## 4. Immediate Roadmap & Action Items

- [x] **Audit & Synchronization:** Align dotfiles and documentation with the Two-Tier Cockpit strategy and Waymaker rebrand.
- [x] **Git Remote Tracking:** Ensure all engine branches (`acpd:main`, `lazygitrs:fecavmi`, `waymaker:waymaker`) are pushed to remote origins.
- [x] **Backdrop Isolator:** Author and deploy `tmux-popup-isolate.sh`.
- [x] **Caller Migration:** Route dotfiles tmux popup scripts through `tmux-popup-isolate.sh`.
- [x] **Lints & Build Sanitization:** Fixed `acpd` clippy warnings and sanitized hardcoded `/home/fecavmi` fallbacks in agent hooks.
- [ ] **Umbrella Meta-Repo:** Initialize `fcmiranda/terminal-ai-cockpit` with `cockpit-manifest.json` and Tier 2 GitHub Actions packaging.
- [ ] **Universal Installer:** Ship POSIX `install.sh` for one-command installation.

---

*For detailed technical specifications, benchmark comparisons, and CI configuration templates, consult [docs/architecture/open-source-ai-tmux-stack-plan.md](docs/architecture/open-source-ai-tmux-stack-plan.md).*
