---
name: dotfiles-docs
description: |
  Maintain, audit, navigate, and update the dotfiles documentation ecosystem. Use whenever updating
  documentation, checking keybinding or alias consistency against code, validating internal markdown
  links, ensuring zero documentation redundancy, or aligning docs with the project's strict KLM-GOMS,
  Home Row, and zero-friction ergonomics standards. All documentation MUST be in English.
---

# Dotfiles Documentation Keeper & Architecture Skill

This skill governs the structure, maintenance, verification, and evolution of the documentation in this dotfiles repository.

---

## 🏛️ 1. Documentation Taxonomy (Single Source of Truth)

Every concept in this repository has **exactly one canonical home**. Never duplicate documentation across multiple files. Link to existing documents instead of copying sections.

```
docs/
├── README.md                      # Central Index & Categorized Sitemap (Must be kept 100% in sync)
│
├── architecture/                  # 🔬 Core Philosophy, Benchmarks & Ergonomic Laws
│   ├── terminal-ergonomics-and-ux-manifesto.md     # Master HCI manifesto, KLM-GOMS, H=0, sub-100ms
│   ├── workflow-keybindings-matrix.md              # Living multi-layer keymap table (Global/Tmux/Zsh/Waymaker/Lazygitrs)
│   ├── zero-friction-file-transfer-benchmark.md    # 6-method KLM-GOMS transfer benchmark & Frecency 2.0
│   ├── neovim-visual-workflow.md                   # Wayland clipboard isolation, Mermaid hover, smart image paste
│   ├── smart-patterns-roadmap.md                   # Event-driven intelligence roadmap and pattern catalog
│   ├── universal-keyboard-ergonomics-and-profiles.md # Dual-profile keyboard ergonomics (vanilla vs keyd)
│   ├── state-of-the-art-terminal-agent-workflow.md # Canonical SOTA architecture, 9.94/10 verdict & benchmarks
│   ├── cockpit-topology-snapshot-and-restore.md    # Session topology snapshot, post-reboot restore & agent resume
│   ├── evidence-based-telemetry-and-deep-work.md   # Human response latency metrics & 24h deep work heatmaps
│   ├── remote-agent-workflow-waymux.md             # Proactive agent supervision, focus auto-dismiss & wait RPCs
│   └── open-source-ai-tmux-stack-plan.md           # Two-tier umbrella blueprint for waymux / lazygitrs / wm
│
├── shell/                         # 🐚 Shell, ZLE & Waymaker Pickers
│   ├── completion.md              # Smart Tab completion (_smart_tab), auto-spacing, wm-ftb
│   ├── vi-mode.md                 # Zsh vi-mode, Starship live mode sync, surround text objects
│   └── waymaker-presets.md        # Waymaker (wm) TOML presets, nav mode, column splitting
│
├── tmux/                          # 🪟 Multiplexer, Popups & Telemetry
│   ├── popups-ergonomics-and-golden-ratio.md    # Golden Ratio (phi) geometry, pure icon badges, bichromatic footers
│   ├── ai-status-bar.md           # Real-time AI agent status pills, animated spinners, Waymux hooks
│   ├── popup-isolation-and-debounce.md          # Tmux 3.8 native popup isolation and 650ms idle debounce
│   ├── clipboard-and-scrollback.md              # Drag-to-copy, Markdown/Mermaid scrollback view, and token yanker
│   └── tmux-activity.md           # Activity alerts and window monitoring
│
├── desktop/                       # 🖥️ Window Manager, Hardware & Display
│   ├── hyprland-aesthetics-and-performance.md   # Hyprland themes, shaders, and GPU benchmarks
│   ├── quickshell-workspace-pills.md            # Reactive Quickshell pills with title-aware webapp icons
│   ├── system-and-hardware.md     # Ghostty CSI u, custom shaders, and battery limits
│   ├── hyprland-animations.md     # Active window animation cubic Bézier presets
│   ├── macbook-notch.md           # Linux kernel GRUB parameters and status bar layout for notch
│   ├── nerd-fonts.md              # Font glyph configuration and Nerd Font symbols
│   ├── hyprland-crash-fix.md      # Crash triage and stability runbooks
│   └── hibiki-keystroke-visualizer.md           # Wayland GTK4 Layer Shell keystroke overlay & Mechvibes audio
│
├── theme/                         # 🎨 Theming & Color Engine
│   ├── system-theme.md            # Omarchy dynamic theme pipeline, colors.toml, and live reload hooks
│   └── separator.md               # Powerline dividers and Nerd Font glyph catalog
│
├── utils.md                       # ⚡ Repository helper scripts cheat sheet (ai-update, cockpit, stow-it, etc.)
│
├── GIT_WORKTREE_AGENTIC_WORKFLOW.md # 🤖 Agent Worktree Orchestration (AWT) & Multi-Agent Git
│
└── articles/                      # 📖 Long-form deep dives and comparative analyses
    ├── tui-ai-workflows.md
    ├── autonomous-agent-examples-en.md
    ├── ai-jail-memory-guide-en.md
    ├── ai-workflow-definitive-analysis.md
    └── ai-memory-multi-repo-guide-en.md
```

---

## 📜 2. Core Governance Rules

### Rule 1: All Documentation MUST Be in English
- All files under `docs/`, root `README.md`, `AGENTS.md`, and skill instruction files must be written in English with zero duplicate localized copies.

### Rule 2: Living Documentation Principle (Zero-Divergence)
- Whenever an agent or developer modifies:
  - Keybindings in `lazygitrs/.config/lazygitrs/presets/popup.yaml` or `tmux/.config/tmux/tmux.conf`
  - Shell functions or aliases in `zsh/.zsh/utils/functions.zsh` or `aliases.zsh`
  - Popup dimensions, colors, or script options in `tmux/.config/tmux/*.sh`
  - Hardware / keyboard behaviors in `keyd` or `hypr/`
- **The agent MUST update the corresponding canonical documentation in the SAME commit.** Never allow documentation to drift from implementation.

### Rule 3: Root Directory Non-Proliferation
- **NO loose markdown files are permitted in the repository root.**
- The only permitted markdown files in the repository root are:
  - `README.md` (Project overview and sitemap)
  - `AGENTS.md` (Agent instructions and working model)
  - `prompt.md` (Assistant persona and system specification)
  - `OPENSOURCE_PLAN.md` (Open-source roadmap)
  - `todo.md` (Local scratch task list)
- Any new documentation must be placed in the appropriate `docs/<category>/` subfolder.

### Rule 4: Link First, Never Duplicate
- If a concept is explained in `docs/architecture/terminal-ergonomics-and-ux-manifesto.md` or `zero-friction-file-transfer-benchmark.md`, **link to it**. Do NOT copy-paste paragraphs into package instruction files or root notes.

### Rule 5: IntelliShell Command Catalog Sync
- Whenever an agent or developer creates, alters, or deprecates a CLI command, shell alias, script, or workflow entrypoint (such as `awt`, `awc`, `awp`, `ptl`, `stow.sh`, etc.):
- **The agent MUST update `intelli-shell/.config/intelli-shell/custom.commands` in the SAME commit.**
- Keep descriptions concise, format placeholders with `{{param}}`, and provide dynamic completion helpers (`$ (cmd) param: ...`) where applicable. Run `intelli-sync` to verify parsing.

---

## 🔍 3. Code-to-Documentation Audit Checklist

When reviewing or updating dotfiles, verify synchronicity between code and docs:

| Source Code File | Canonical Documentation Target | What to Verify |
| :--- | :--- | :--- |
| `zsh/.zsh/utils/functions.zsh` | `docs/architecture/zero-friction-file-transfer-benchmark.md` | `pt`, `ptg`, `ptl`, `mt`, `mtg`, `mtl`, `j`, `ji` flags and timings |
| `zsh/.zsh/utils/aliases.zsh` | `docs/architecture/workflow-keybindings-matrix.md` | Shell alias bindings and mnemonic shortcuts |
| `lazygitrs/.../popup.yaml` | `docs/architecture/workflow-keybindings-matrix.md` | In-TUI keys (`<c-g>`, `<c-s>`, `<c-f>`, `-`, `,`, `.`, `<`, `>`) |
| `tmux/.config/tmux/tmux.conf` | `docs/architecture/workflow-keybindings-matrix.md` & `docs/tmux/` | Prefix chords, popup dimensions, and options (`status-interval 0`) |
| `tmux/.config/tmux/*-popup.sh` | `docs/tmux/popups-ergonomics-and-golden-ratio.md` | Popup widths/heights, `-T` icon badges, and Omarchy theme colors |
| `omarchy/.../colors.toml` | `docs/theme/system-theme.md` | Color token mapping and template compilation pipeline |

---

## 🛠️ 4. Verification Tooling

### Run the Documentation Linter
Always run the repository documentation linter before finalizing any documentation changes:

```bash
./scripts/docs-lint.sh
```

What the linter validates:
1. **Root Cleanliness**: Verifies that no rogue `.md` files were created in `/`.
2. **Link Integrity**: Resolves every relative markdown link `[text](target)` across all files. Ensures zero 404s or broken anchors.

### Git Pre-Commit Hook
The linter is wired to git via `scripts/git-hooks/pre-commit` (`core.hooksPath = scripts/git-hooks`).
If a commit introduces a broken relative link or creates a disallowed root file, git will block the commit with actionable error lines.
