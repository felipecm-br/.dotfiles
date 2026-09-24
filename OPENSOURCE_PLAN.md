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
- **Status:** Tagged and released as `v0.1.0`. Release CI active with multi-arch Linux builds (`x86_64` / `aarch64` musl + glibc) and sha256 checksums. 100% compliant with 0 clippy warnings and all 11 unit tests passing.
- **Next:** Reference in Tier 2 `cockpit-manifest.json`.

### B. `fcmiranda/lazygitrs` (The Review Engine)
- **Role:** Blazing fast Git TUI with `--commits`, worktree port discovery, and headless inline diff review note injection (`S` bracket-pasted to active AI pane).
- **Status:** Tagged and released as `v0.1.0-cockpit`. Notes relocated to `.git/info/lines.json` (eliminating working tree pollution) with full worktree resolution, XDG state fallback, and automatic migration. Compiles cleanly with all 168 unit tests passing and multi-arch release CI active with sha256 checksums.
- **Next:** Reference in Tier 2 `cockpit-manifest.json`.

### C. `fcmiranda/matchmaker` / `waymaker` (The Nav, Frecency & Session Layer)
- **Role:** Sub-millisecond fuzzy finder with live-reload inotify watch (`-w`), Kitty graphics caching, Mermaid diagram rendering, ACID `redb` frecency store, and **native workspace & session engine** (`wm session`, `wm connect`, `wm last`, `wm preview`).
- **Status:** Tagged and released as `v0.1.0`. Sesh and frecency completely incorporated into Waymaker (`session.rs`). External `sesh-bin` (Go) and `zoxide` dependencies **100% eliminated**. Over 228 tests passing with 0 failures (`cargo test`). Multi-arch release CI active with sha256 checksums.
- **Next:** Reference in Tier 2 `cockpit-manifest.json`.

### D. `tmux` Backdrop Isolation Layer
- **Role:** Guarantees popup stability during active token streaming via frozen ANSI backdrops.
- **Status:** Core isolator script [`tmux/.config/tmux/tmux-popup-isolate.sh`](tmux/.config/tmux/tmux-popup-isolate.sh) implemented with full CLI parsing, conditional idle bypass, and `0600` UID-pane isolation. All 7 popup callers (`grep-picker.sh`, `lazygitrs-popup.sh`, `files-picker.sh`, `sesh-picker.sh`, `window-picker.sh`, `scrollback-extract.sh`, `awt-popup.sh`) 100% migrated and verified.
- **Next:** Package inside umbrella repo `terminal-ai-cockpit/scripts/`.

---

## 4. Immediate Roadmap & Action Items (What is Missing for Launch)

- [x] **Audit & Synchronization:** Align dotfiles and documentation with the Two-Tier Cockpit strategy and Waymaker rebrand.
- [x] **Git Remote Tracking:** Ensure all engine branches (`acpd:main`, `lazygitrs:fecavmi`, `waymaker:waymaker`) are pushed to remote origins.
- [x] **Backdrop Isolator:** Author and deploy `tmux-popup-isolate.sh` with migration of all 7 callers.
- [x] **Lints & Build Sanitization:** Fixed `acpd` clippy warnings, eliminated double-debounce, sanitized hardcoded `/home/fecavmi` fallbacks in agent hooks.
- [x] **Native Sesh & Frecency Integration:** Fully incorporated `sesh` workspace management into `waymaker` (`session.rs`), eliminating external `sesh-bin` and `zoxide` dependencies with drop-in wrapper.
- [ ] **Tier 1 Engine Tagged Releases:** Publish `v0.1.0` releases for `acpd` and `waymaker`, and `v0.1.0-cockpit` for `lazygitrs` to populate GitHub Release assets.
- [ ] **Umbrella Meta-Repo:** Initialize `fcmiranda/terminal-ai-cockpit` with `cockpit-manifest.json`, `cockpit.tmux`, `scripts/`, `hooks/`, and `systemd/`.
- [ ] **Universal Installer:** Ship POSIX `install.sh` for one-command, zero-compilation curl installation (< 30s execution).
- [ ] **Problem-First README & VHS Demos:** Record animated SVGs showing flicker-free streaming popups and 1-key inline diff reviews.

---

*For detailed technical specifications, benchmark comparisons, and CI configuration templates, consult [docs/architecture/open-source-ai-tmux-stack-plan.md](docs/architecture/open-source-ai-tmux-stack-plan.md).*
