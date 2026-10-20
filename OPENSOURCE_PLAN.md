# Open-Source Strategy: Terminal AI Cockpit Stack

> **Canonical Blueprint:** See [docs/architecture/open-source-ai-tmux-stack-plan.md](docs/architecture/open-source-ai-tmux-stack-plan.md) for the complete production-grade architectural specification, technical audit, and multi-arch CI/CD pipeline based on Fabio Akita's open-source release principles.

---

## 1. Executive Summary & Value Proposition

The goal is to transition our battle-tested terminal AI state orchestration into a modular, zero-compilation open-source distribution: **The Terminal AI Cockpit Stack**.

### The Core Problem Solved (Akita's Golden Rule)
1. **Zero Terminal Redraw Flicker:** Tmux 3.8+ native floating overlays (`display-popup`) keep borders and search inputs rock-solid during background AI token streaming.
2. **Event-Driven Status Bar:** `status-interval 0` with 0% idle CPU drain and 650ms idle debounce in `waymux`.
3. **Hybrid Golden-Grid Cockpit HUD:** Sub-50ms (`P50 = 31ms`) 6-column fleet dashboard (`cockpit-picker.sh`) with multi-pane urgency aggregation and tri-layout previews.
4. **1-Key Inline Diff Review to AI:** Review git diffs directly in TUI (`lazygitrs`), annotate lines, and bracket-paste them instantly into active agent panes (`agy`, `claude`, `codex`, `muse`, `opencode`).
5. **Zero-Compile 1-Command Install:** Pre-built static `musl` Linux and Apple Silicon `Darwin` binaries bundled into a single repository (`waymux`), installed via `curl -fsSL ... | bash` in under 30 seconds.

---

## 2. Two-Tier Umbrella Architecture

Rather than forcing users to assemble disparate repositories or compile 13 C tree-sitter grammars from source, the project employs a **Two-Tier Distribution Model**:

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                        TIER 1: UPSTREAM SUB-REPO ENGINES                               │
├──────────────────────────┬───────────────────────────┬─────────────────────────────────┤
│ fcmiranda/waymux         │ fcmiranda/lazygitrs       │ fcmiranda/matchmaker (waymaker) │
│ (Axum 0.8, Tokio 1.52)   │ (branch: fecavmi)         │ (binary: wm / waymaker)         │
│ Native Rust Toolchain    │ cross-rs / cargo-zigbuild │ Native Rust Toolchain           │
│ (musl + Darwin static)   │ (13 C parsers + musl)     │ (musl + Darwin static)          │
└────────────┬─────────────┴─────────────┬─────────────┴────────────────┬────────────────┘
             ▼                           ▼                              ▼
     waymux-<target>.tar.gz      lazygitrs-<target>.tar.gz        wm-<target>.tar.gz
             │                           │                              │
             └───────────────────────────┼──────────────────────────────┘
                                         ▼
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                 TIER 2: waymux UMBRELLA DISTRIBUTION (ZERO COMPILATION)                │
├────────────────────────────────────────────────────────────────────────────────────────┤
│ • install.sh               -> 1-line zero-compile curl installer (< 5s execution)      │
│ • waymux-manifest.json     -> Pinned upstream release tags of waymux, lazygitrs, wm    │
│ • pre-built release assets -> Unified tarballs: waymux-v*.*.*-<target>                 │
│ • waymux.tmux              -> Event-driven status pills & ergonomic popup keybindings  │
│ • scripts/                 -> cockpit-picker.sh, lazygitrs-popup.sh, lazygit-tmux-injector.sh │
│ • hooks/                   -> Universal AI agent lifecycle hooks (waymux-hook.mjs)     │
│ • systemd/                 -> waymux.service user unit                                 │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Subsystem Breakdown

### A. `fcmiranda/waymux` (The Broker Daemon)
- **Role:** High-throughput async broker managing per-pane agent state transitions, multi-pane window urgency aggregation, dynamic spinner rendering, and status sinks (Tmux, Waybar/Quickshell).
- **Status:** Tagged and released as `v0.1.0`. Release CI active with multi-arch Linux builds (`x86_64` / `aarch64` musl + glibc) and sha256 checksums. 100% compliant with 0 clippy warnings and all unit tests passing.
- **Next:** Reference in Tier 2 `waymux-manifest.json`.

### B. `fcmiranda/lazygitrs` (The Review Engine)
- **Role:** Blazing fast Git TUI with `--commits`, Dual-Diff toggle (`Ctrl+G`), worktree port discovery, and headless inline diff review note injection (`S` bracket-pasted to active AI pane, or `r` dispatched from Cockpit HUD).
- **Status:** Tagged and released as `v0.1.0-cockpit`. Notes relocated to `.git/info/lines.json` (eliminating working tree pollution) with full worktree resolution, XDG state fallback, and automatic migration. Compiles cleanly with all 168 unit tests passing and multi-arch release CI active with sha256 checksums.
- **Next:** Reference in Tier 2 `waymux-manifest.json`.

### C. `fcmiranda/matchmaker` / `waymaker` (The Nav, Frecency & Session Layer)
- **Role:** Sub-millisecond fuzzy finder with live-reload inotify watch (`-w`), Kitty graphics caching, Mermaid diagram rendering, ACID `redb` frecency store, and **native workspace & session engine** (`wm session`, `wm connect`, `wm last`, `wm preview`).
- **Status:** Tagged and released as `v0.1.0`. Branch `main` synchronized with `waymaker` as default branch; upstream history preserved in `upstream-main`. Sesh and frecency completely incorporated into Waymaker (`session.rs`). External `sesh-bin` (Go) and `zoxide` dependencies **100% eliminated**. Over 228 tests passing with 0 failures (`cargo test`). Multi-arch release CI active with sha256 checksums.
- **Next:** Reference in Tier 2 `waymux-manifest.json`.

### D. `tmux` Popup Layer
- **Role:** Native zero-flicker floating modal popups powered by Tmux 3.8+.
- **Status:** With Tmux 3.8 resolving upstream floating pane and background redraw tearing, popups run directly via native `tmux display-popup` without requiring auxiliary backdrop freeze workarounds (`tmux-popup-isolate.sh` retired).
- **Next:** Maintain native `tmux display-popup` across all modal pickers.

---

## 4. Immediate Roadmap & Action Items (What is Missing for Launch)

- [x] **Audit & Synchronization:** Align dotfiles and documentation with the Two-Tier Cockpit strategy and Waymaker rebrand.
- [x] **Git Remote Tracking:** Ensure all engine branches (`waymux:main`, `lazygitrs:fecavmi`, `waymaker:waymaker`) are pushed to remote origins.
- [x] **Native Tmux 3.8 Popup Isolation:** Migrated all modal pickers to native `tmux display-popup` and retired legacy snapshot backdrop scripts.
- [x] **Lints & Build Sanitization:** Fixed `waymux` clippy warnings, eliminated double-debounce, sanitized hardcoded `/home/fecavmi` fallbacks in agent hooks.
- [x] **Native Sesh & Frecency Integration:** Fully incorporated `sesh` workspace management into `waymaker` (`session.rs`), eliminating external `sesh-bin` and `zoxide` dependencies with drop-in wrapper.
- [x] **Tier 1 Engine Tagged Releases:** Published `v0.1.0` releases for `waymux` and `waymaker`, and `v0.1.0-cockpit` for `lazygitrs` with multi-arch binary assets and SHA-256 checksums.
- [x] **Umbrella Meta-Repo (`waymux`):** Initialized and published [`fcmiranda/waymux`](https://github.com/fcmiranda/waymux) (`v0.1.0`) with `waymux-manifest.json`, `tmux/waymux.tmux`, `scripts/`, `hooks/`, and `systemd/`.
- [x] **Universal Installer:** Shipped POSIX `install.sh` for one-command, zero-compilation curl installation (< 10s execution) with architecture detection and SHA-256 verification.
- [x] **Problem-First README:** Shipped high-impact README with banner, architecture diagrams, and clear problem-first value proposition.
- [ ] **VHS Terminal Demos:** Record animated SVGs/GIFs showing flicker-free streaming popups and 1-key inline diff reviews.
- [ ] **Packaging Distribution:** Publish Arch Linux AUR package (`waymux-bin`) and Homebrew formula (`brew tap fcmiranda/tap`).
- [ ] **Container Smoke Test:** Validate `install.sh` against clean Ubuntu and Alpine Docker containers.

---

*For detailed technical specifications, benchmark comparisons, and CI configuration templates, consult [docs/architecture/open-source-ai-tmux-stack-plan.md](docs/architecture/open-source-ai-tmux-stack-plan.md).*
