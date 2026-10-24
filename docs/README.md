# Dotfiles Documentation Index

Welcome to the central documentation index for this Arch Linux + Omarchy dotfiles setup.

---

## 📚 Categorized Documentation

### 🔬 0. Core Philosophy & Ergonomics Manifesto (`docs/architecture/`)
- [**Terminal Ergonomics & UX Architecture Manifesto**](architecture/terminal-ergonomics-and-ux-manifesto.md): Core HCI principles, KLM/GOMS ($H=0$), Doherty threshold (<100ms), pure icon badges, universal Omarchy theme color synchronization, and the Ergonomic Stability Rule.
- [**Workflow Keybindings & Ergonomic Reference Matrix**](architecture/workflow-keybindings-matrix.md): Complete multi-layer cheat-sheet and biomechanical audit of all global, Tmux, Zsh, Waymaker, and Lazygitrs shortcuts.
- [**Zero-Friction Frecency 2.0 File Transfer Benchmark & Guide**](architecture/zero-friction-file-transfer-benchmark.md): Quantitative KLM-GOMS benchmark comparing 6 transfer paradigms (220ms `ptl` to 7200ms AI agents), 5 architectural pillars, and operational cheat-sheet (`pt`, `ptg`, `ptl`, `mt`, `mtg`, `mtl`, `j`, `ji`).
- [**Neovim Visual Intelligence & Smart Image Clipboard Workflow**](architecture/neovim-visual-workflow.md): Architecture, safe Wayland clipboard isolation, Mermaid hover preview, and VS Code-parity smart image pasting with Select Mode captioning.
- [**Smart & Context-Aware Patterns Roadmap**](architecture/smart-patterns-roadmap.md): Architectural catalog of active event-driven intelligence and future roadmap (semantic breadcrumbs, workspace indicators, command alerts, scratchpads, and Neovim LSP sync).
- [**Universal Keyboard Ergonomics & Dual-Profile Architecture**](architecture/universal-keyboard-ergonomics-and-profiles.md): Detailed specification for standard/vanilla keyboards vs biomechanical `keyd` overload, Leader sequences, Vim Nav Mode, and open-source packaging strategy for Waymux and Waymaker.
- [**State-of-the-Art Terminal Agent Workflow: Architecture, Ergonomics & Competitor Benchmark**](architecture/state-of-the-art-terminal-agent-workflow.md): The definitive canonical architecture document: 9.94/10 verdict, head-to-head competitor matrix (`workmux`, `herdr`, `zellij`), 6 engineered SOTA pillars, sub-50ms empirical benchmarks, and historical resolution ledger.
- [**Cockpit Topology Snapshot & Post-Reboot Restore**](architecture/cockpit-topology-snapshot-and-restore.md): Event-driven 30s debounced Tmux topology snapshots (`cockpit snapshot`), post-reboot workspace restoration (`cockpit restore`), and multi-agent continuation (`agy`, `claude`, `codex`, `muse`, `opencode`).
- [**Quota-Aware Agent Selection (`ai-quota` / `ai-launch`)**](architecture/quota-aware-agent-selection.md): Session picker `a` / `c` agent keys, quota badge, Claude 5h/7d burn-rate projection, Antigravity exhaustion tracking, and smart `startup_command` launcher.
- [**Evidence-Based Flow Telemetry & Deep Work Analytics**](architecture/evidence-based-telemetry-and-deep-work.md): Zero-latency TSV event logging (`flow-log.sh`), human-agent response latency metrics, 24h ASCII activity heatmaps, and `flow-telemetry` CLI.
- [**Proactive Agent Supervision & Remote Orchestration (`waymux`)**](architecture/remote-agent-workflow-waymux.md): JSON-RPC 2.0 remote agent supervision via Waymux daemon (`waymux` / `waymux-cli`), auto-dismiss on focus (`pane-focus-in`), blocking `agentState/wait` barriers, and multi-agent handoff loops.
- [**TUIOS (`v0.10.1`) Benchmark & Agent Inbox / Delivery-Queue Roadmap**](architecture/tuios-benchmark-and-agent-inbox-roadmap.md): Architectural and KLM-GOMS audit of TUIOS vs. this stack, verified notes on its delivery queue, hook-held approvals, risk rules and mail, and the tiered adoption roadmap (`waymux queue` and live `y`/`n` re-checks shipped; risk rules, hook-held approvals, turn checkpoints and quota-aware `awt fan` ranked next).
- [**Open-Source AI Cockpit Stack Blueprint**](architecture/open-source-ai-tmux-stack-plan.md): Architecture and distribution strategy for the open-source `waymux` + `lazygitrs` + `waymaker` (`wm`) + `tmux` terminal AI cockpit stack.
- [**Nerd Font Icon Registry**](architecture/nerd-font-icon-registry.md): Single source of truth for program, agent, and agent-state glyphs (`[icons]` in the waymux config), and how tmux, the Cockpit, alerts, and shell scripts read it (`waymux icon`, `waymux icons`).

### 🐚 1. Shell & Navigation (`docs/shell/`)
- [**Smart Tab Completion & Waymaker**](shell/completion.md): Context-aware `<Tab>`, auto-spacing on aliases (`gco<Tab>`), dual backends (`Ctrl+N` vs `Ctrl+F`), and the [`ftb.toml`](../waymaker/.config/waymaker/presets/ftb.toml) preset with on-demand preview (`Ctrl+P`).
- [**Zsh Vi Mode & Custom Surrounds**](shell/vi-mode.md): `zsh-vi-mode` integration, dynamic Starship prompt sync (`ZVM_MODE`), and unified surround text objects (`ib`, `ab`, `iq`, `aq`).
- [**Waymaker (`wm`) Presets Reference**](shell/waymaker-presets.md): Presets configuration guide for fuzzy finder layouts, preview commands, and navigation modes in `~/.config/waymaker/presets/`.

### 🪟 2. Tmux & Multiplexer (`docs/tmux/`)
- [**Popups Ergonomics, Biomechanics & Golden Ratio**](tmux/popups-ergonomics-and-golden-ratio.md): Golden Ratio ($\phi$) popup architecture, 40/60 column split, 1-touch Home Row navigation, uniform bichromatic footers, and sub-100ms non-blocking HUDs.
- [**AI Agent Status in Status Bar**](tmux/ai-status-bar.md): Real-time per-pane AI agent state pills, animated spinners, color alerts, Vimium window hints (`Prefix + f`), and `waymux` daemon options.
- [**Popup Isolation, Debounce & Event-Driven Architecture**](tmux/popup-isolation-and-debounce.md): Tmux 3.8 native floating popup isolation, 650ms idle debounce in Waymux, and 100% event-driven `status-interval 0`.
- [**Clipboard & Scrollback Capture**](tmux/clipboard-and-scrollback.md): Click-and-hold drag-to-copy to system clipboard, `Prefix + E` Markdown/Mermaid scrollback view popup, and `Prefix + y` fuzzy scrollback token yanker.
- [**Tmux Activity Monitoring**](tmux/tmux-activity.md): Activity alert and notification behavior (`monitor-activity off` in favor of `waymux` status pills).

### 🖥️ 3. Desktop, Terminal & Hardware (`docs/desktop/`)
- [**Hyprland Aesthetics vs. Performance Benchmark**](desktop/hyprland-aesthetics-and-performance.md): Deep-dive comparing Liquid Glass (`hyprglass`), Tokyo Night Solar Dawn (current), Catppuccin Pastel, Cyberpunk Neon, and OLED Zen with GPU/battery benchmarks on Apple Silicon M1 Pro.
- [**Dynamic Context-Aware Workspace Pills**](desktop/quickshell-workspace-pills.md): Reactive Quickshell workspace pills with real-time app icon rewriting and title-aware webapp detection (YouTube, GitHub, Google Photos, etc.).
- [**System, Displays & Hardware**](desktop/system-and-hardware.md): Ghostty terminal enhancements (CSI u escapes, epoll, custom shaders) and battery charge thresholds / CPU power profiles.
- [**Hyprland Animations Configuration**](desktop/hyprland-animations.md): Active animation rules, cubic Bézier curve presets, tree speeds, and override methods.
- [**MacBook Display Notch Adaptation**](desktop/macbook-notch.md): Linux kernel GRUB parameters and status bar layout adaptation for Apple Silicon MacBook notch screens.
- [**Nerd Fonts Configuration**](desktop/nerd-fonts.md): Font glyph setup and symbol rendering.
- [**Hyprland Crash Recovery**](desktop/hyprland-crash-fix.md): Crash triage and stability fixes.
- [**Eyelash Sofle Keyboard**](desktop/eyelash-sofle-keyboard.md): Live ZMK keymap read over Studio RPC (printable PDF per layer), ZMK Studio connection runbook on Asahi, and firmware-level ergonomics tips (Esc tap / Ctrl hold, thumb chords).
- [**Eyelash Sofle Home-Row Chord Guide**](desktop/eyelash-sofle-home-row-chords.md): Every hot-path tmux, zsh, lazygitrs and Hyprland chord mapped onto the Sofle's physical keys, with KLM cost, verdicts and ranked modifier changes (thumb Super, mirrored pinky Ctrl).
- [**Hibiki Keystroke Visualizer**](desktop/hibiki-keystroke-visualizer.md): Wayland native GTK4 Layer Shell keystroke badge and bubble overlay, Mechvibes mechanical audio engine, and Hyprland integration.

### 🎨 4. Theme & Design System (`docs/theme/`)
- [**System Theming Architecture**](theme/system-theme.md): The Omarchy theme rendering pipeline (`~/.local/state/omarchy/current/theme/`), `colors.toml` template generation, overrides, and live reload hooks.
- [**Separator & Nerd Font Glyph Library**](theme/separator.md): Reference catalog of Powerline dividers, pills, and Nerd Font status glyphs.
- [**Starship Chroma Gradient Presets**](theme/starship-chroma-presets.md): Eight `chroma-*` Starship presets porting notMyShell's Chroma palettes as OKLab stepped gradients with glyph-stacked transitions.
- [**Prompt Art (zsh)**](theme/prompt-art.md): Opt-in zsh modules for a gradient scrollback trail, a time-of-day palette, and a per-repo hue on any Starship preset.

### ⚡ 5. Utilities & Commands (`docs/utils.md`)
- [**Utils & Command Reference**](utils.md): Quick reference for repository scripts (`stow-it`, `killport`, `dotadd`, `wtr`, `battery-threshold`, `perf-toggle`, Hyprland refresh helpers).

---

## 🤖 AI Workflow & Agent Architecture (`docs/articles/`)
- [**Agent Worktree Manager & Multi-Agent Git Orchestrator (`GIT_WORKTREE_AGENTIC_WORKFLOW.md`)**](GIT_WORKTREE_AGENTIC_WORKFLOW.md): Complete guide to the AWT ecosystem, 4-layer architecture, conventional wizard, live previews, and automated lifecycle hooks.
- [**AWT Dotfiles Package Readme (`awt/README.md`)**](../awt/README.md): Dedicated package documentation, CLI command cheat sheet, and keybindings reference.
- [**TUI AI Workflows**](articles/tui-ai-workflows.md): Interactive workflows and design patterns for agentic development.
- [**Autonomous Agent Examples**](articles/autonomous-agent-examples-en.md): Practical scenarios and agent configurations.
- [**AI Jail & Memory Architecture**](articles/ai-jail-memory-guide-en.md): Memory isolation and workspace jail documentation.
- [**AI Workflow Definitive Analysis**](articles/ai-workflow-definitive-analysis.md): Deep dive into agent tool use and telemetry.
- [**Multi-Repository AI Memory Architecture**](articles/ai-memory-multi-repo-guide-en.md): Connecting multiple repositories to a centralized memory hub.
