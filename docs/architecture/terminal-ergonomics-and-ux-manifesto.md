# Terminal Ergonomics, Visual Semiotics & Zero-Friction Workflow Architecture

## 📖 Overview & Purpose

This document formalizes the engineering principles, human-computer interaction (HCI) models, neurocognitive theories, and biomechanical standards that govern the **state-of-the-art terminal and TUI workflow** in this repository (`tmux`, `matchmaker`, `lazygitrs`, `keyd`, `sesh`, `zsh`).

The overarching goal is to achieve **Zero Cognitive Friction**, **sub-perceptual latency (<100ms)**, **pure Home Row hand anchoring**, and **immutable muscle memory stability**.

---

## 🔬 1. Scientific Foundations & Cognitive Models

Every layout decision, dimensioning rule, visual cue, and keybinding in this setup adheres strictly to established cognitive and biomechanical models:

```mermaid
flowchart TD
    subgraph CorePrinciples ["Core Scientific Principles"]
        KLM["<b>KLM / GOMS (Card & Moran)</b><br/>T_execute = ∑K + ∑P + ∑H + ∑M + ∑R<br/>Target: H = 0, M ≈ 0, minimal K"]
        DOH["<b>Doherty Threshold (&lt;100ms)</b><br/>Sub-100ms execution & destruction<br/>Preserves biological train-of-thought"]
        TUFTE["<b>Data-Ink Ratio &amp; Pure Glyphs (Tufte)</b><br/>Minimalist Nerd Font badges (󱂬, ⚡, 󰊢)<br/>Preattentive decoding in &lt;15ms"]
        SEMIOTICS["<b>Dynamic Visual Semiotics</b><br/>Border colors dynamically bound to Omarchy theme<br/>Ephemeral vs Persistent vs Reactive layers"]
        AUREA["<b>Golden Ratio (φ ≈ 1.618)</b><br/>75% × 60% viewport geometry & 40/60 split<br/>Optimal foveal focus & peripheral anchor"]
        STABILITY["<b>Ergonomic Stability Rule</b><br/>Optimal muscle memory is an asset<br/>Zero unnecessary key churn"]
    end
```

### 1.1 Keystroke-Level Model (KLM/GOMS)
$$T_{\text{execute}} = \sum T_K + \sum T_P + \sum T_H + \sum T_M + \sum T_R$$
* **$T_H$ (Hand Homing):** **$0\text{ ms}$**. Hands remain permanently anchored to the Home Row ($ASDF / JKL;$). Reaching for function keys (`F1-F12`), arrow clusters, or mouse pointing devices is strictly eliminated ($T_P = 0, T_H = 0$).
* **$T_M$ (Mental Preparation / Hesitation):** Minimized to **$\approx 0\text{ ms}$** via immediate visual semiotics (semantic border colors and glyphs) and universal mnemonics (`Esc` cancels/unwinds, `Ctrl+G` opens Git, `s` switches windows).
* **$T_K$ (Keystroke Cost):** Reduced from $240\text{ ms}$ (complex chords) to **$120\text{ ms}$** through 1-touch direct navigation (`nav^^` keys in Matchmaker) and dual-function kernel modifiers.

### 1.2 The Doherty Threshold (<100ms)
When human-computer interaction latency drops below **100 milliseconds**, human perception registers the system as an extension of thought, preserving cognitive flow without biological interruption.
* **Subprocess Latency:** `lazygitrs` (native Rust binary) starts in **~3ms** and exits in **0ms** via Tmux's `-E` flag.
* **Zero-Flicker Double Buffering:** `delay_clear = true` and `debounce_ms = 20` in `matchmaker` eliminates screen tearing during rapid vertical scrolling.
* **Non-Blocking Telemetry:** Notifications utilize asynchronous `tmux display-message` (<1ms), eliminating synchronous blocking popups.

---

## 🎨 2. Visual Semiotics & Dynamic Theme Color Sync

```text
╭── 󱂬 ──────────────────────────────────────────────────────────────────────╮  🟣 Mauve / Magenta
│ 1. EPHEMERAL LAYER (Fast Pickers & Transit Navigation < 5s)               │  Geometry: 75% × 60%
│ • Window Picker, Sesh Workspace Picker, Matchmaker Jump. Exit: [Esc]       │
╰───────────────────────────────────────────────────────────────────────────╯

╭── 󰊢 ──────────────────────────────────────────────────────────────────────╮  🟠 Git Orange (colors.toml)
│ 2. PERSISTENT LAYER (High-Density Inspection & Workspaces)                │  Geometry: 90% × 88%
│ • Lazygitrs, Floating Neovim, OpenCode Agent. Exit: [Esc] on Files / [q]   │
╰───────────────────────────────────────────────────────────────────────────╯

╭── 󰮯 ──────────────────────────────────────────────────────────────────────╮  🟡 Alert Yellow (colors.toml)
│ 3. REACTIVE LAYER (AI Agent Attention & Interventions)                    │  Geometry: 80% × 75%
│ • Permission prompts and background agent alerts. Cycle: [prefix+i] / [Esc]│
╰───────────────────────────────────────────────────────────────────────────╯
```

### 2.1 Pure Icon Badges (Tufte's Data-Ink Principle)
* **Glyph Recognition vs Text Decoding (15ms vs 200ms):** The human visual cortex decodes familiar pictograms (`󰊢`, `⚡`, `󱂬`, `󱜻`) preattentively in **$\approx 15\text{ ms}$**, whereas phonetic text parsing takes **$\approx 180\text{ ms}$ to $250\text{ ms}$**.
* **Elimination of Semantic Redundancy:** Frame titles such as *"Windows & Agents"* or *"Lazygit"* are redundant noise. Clean icon badges (`-T " 󱂬 "`, `-T " ⚡ "`, `-T " 󰊢 "`) maximize the Signal-to-Noise ratio while maintaining minimalist geometry.

### 2.2 Universal Dynamic Omarchy Theme Inheritance
All popup scripts dynamically query the active system palette in `~/.local/state/omarchy/current/theme/colors.toml`:

```text
               ┌────────────────────────────────────────────────────────┐
               │    ~/.local/state/omarchy/current/theme/colors.toml    │
               └───────────┬──────────────┬──────────────┬──────────────┘
                           │              │              │
                    magenta/accent       cyan          orange          yellow/alert
                           │              │              │                   │
                           ▼              ▼              ▼                   ▼
                     ╭── 󱂬 ──╮      ╭── ⚡ ──╮      ╭── 󰊢 ──╮           ╭── 󰮯 ──╮
                     │Windows│      │  Sesh │      │Lazygit│           │AI Bell│
                     ╰───────╯      ╰───────╯      ╰───────╯           ╰───────╯
```

When switching themes via `omarchy theme set <theme>`, **100% of popups instantly adopt the exact semantic palette** (e.g., Catppuccin Mocha, Gruvbox Dark, Tokyo Night, Nord).

---

## 📐 3. Golden Ratio Spatial Architecture ($\phi \approx 1.618$)

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                             TERMINAL VIEWPORT                               │
│                                                                             │
│        ┌─ 󱂬 ───────────────────────────────────────────────────────┐        │
│        │  CENTERED MODAL (Width: ~75% │ Height: ~60%)              │        │
│        │                                                           │        │
│        │  ┌───────────────────────┬─────────────────────────────┐  │        │
│        │  │ Candidate List        │ Live Context Preview        │  │        │
│        │  │ (38.2% ≈ 40%)         │ (61.8% ≈ 60%)               │  │        │
│        │  │                       │                             │  │        │
│        │  │ • 0  nvim     󱥂 idle  │ $ git status -s             │  │        │
│        │  │ · 1  agent    󰑮 work  │ M tmux/tmux.conf            │  │        │
│        │  │ · 2  zsh              │ M matchmaker/jump.toml      │  │        │
│        │  │                       │                             │  │        │
│        │  └───────────────────────┴─────────────────────────────┘  │        │
│        │  [Enter] Switch  •  [c] New  •  [d] Kill  •  [Esc] Exit    │        │
│        └───────────────────────────────────────────────────────────┘        │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

* **Foveal Ergonomics (`75% × 60%`):** Human central visual acuity is confined to a 2°–5° foveal cone. The 75% × 60% viewport occupies the visual center without hiding the parent terminal backdrop.
* **Column Partitioning (`40% / 60%`):** Divides space according to $\frac{1}{\phi^2} \approx 38.2\%$ (list) and $\frac{1}{\phi} \approx 61.8\%$ (preview), preventing label truncation.
* **Concurrent Split Editor Architecture (`62% / 38%` LTR):** When opening files from ephemeral pickers (e.g. `wm -o workspace` / `wm -o files` / [`workspace-picker.sh`](../../tmux/.config/tmux/workspace-picker.sh) with `Ctrl+E` or `e`), the modal is immediately dismissed (`display-popup -C`) via [`scrollback-open.sh`](../../tmux/.config/tmux/scrollback-open.sh) to prevent nested modal trapping. The editor (Neovim) is positioned on the left (`split-window -h -b -l 62%`) at $\frac{1}{\phi} \approx 61.8\%$ (62%), preserving the active terminal or AI session on the right at $\frac{1}{\phi^2} \approx 38.2\%$ (38%). This aligns with western Left-to-Right reading hierarchy and modern IDE sidebar architecture (primary workspace left, AI copilot right).
* **High-Density Workspaces (`90% × 88%`):** Lazygitrs expands to 90% × 88% to satisfy Miller's Chunking Law ($7 \pm 2$) across 5 control panels and wide diff viewports.

### 3.1 The Z-Axis vs. X-Axis Law: Ephemeral Overlays vs. Persistent Sidebars

A fundamental architectural design question in terminal multiplexing and AI cockpit engineering is: **Should workspace management (sessions, worktrees, file trees) live in a persistent lateral split (Sidebar / Chrome Split) or in an ephemeral floating overlay (Z-Axis Modal)?**

While tools like `workmux` or traditional GUI IDEs (VSCode, JetBrains) adopt permanent lateral sidebars, our Cockpit architecture enforces the **Z-Axis Navigation Law**:

> **The Z-Axis Navigation Law:**  
> *Navigation, context switching, and metadata discovery must strictly occur in the **Z-Axis** (ephemeral floating overlays that self-destruct upon selection).*  
> *Horizontal screen real estate (**X-Axis**) must be exclusively reserved for **Active Content Splits** (high-density code buffers, side-by-side vertical diffs, and live terminal interaction).*

#### 1. The Mathematics of Screen Real Estate Starvation
On standard laptop displays (14"–16" MacBook Pro, or 1080p/4K scaled monitors), a terminal emulator typically spans **160 to 200 character columns**. Modern software development requires simultaneous vertical splits (e.g. source buffer + test suite, or side-by-side Git diff):
$$\text{Ideal Line Length (80–100 cols)} \times 2 + \text{gutters/LSP diagnostics} \approx 176\text{–}190\text{ columns}$$

| Architecture Model | Viewport Budget (180 cols) | Editor Buffer (Left Split) | AI Agent / Terminal (Right Split) | In-Editor Vertical Split (`:vsplit`) | Visual & Ergonomic State |
| :--- | :---: | :---: | :---: | :---: | :--- |
| **A. Static Sidebar (`workmux` style)** | 180 cols - 32 cols sidebar = **148 cols** | 62% of 148 = **91 cols** | 38% of 148 = **57 cols** (severe text truncation) | $91 \div 2 = \mathbf{45\text{ cols}}$ per buffer | **Complete Collapse:** Code lines wrap prematurely; LSP diagnostics overlap; AI markdown output breaks across words. |
| **B. Cockpit Golden Ratio (`awt` / `wm`)** | **180 cols full width** (0 cols wasted) | 62% of 180 = **111 cols** (spacious buffer) | 38% of 180 = **69 cols** (optimal markdown reading) | $111 \div 2 = \mathbf{55\text{–}56\text{ cols}}$ comfortably readable | **Pure Ergonomics:** Full side-by-side concurrency without horizontal scrolling or line folding. |

#### 2. Content Splits vs. Chrome Splits (Tufte's Data-Ink Principle)
1. **Dynamic Content Splits (`scrollback-open.sh` via `wm -o workspace` $\to$ `Ctrl+e`):**
   * **High Data-Ink Density:** Both panes actively emit, inspect, and edit code or commands.
   * **Transient Lifecycle:** Exists only while actively editing; closing the buffer (`:q`) instantly restores the primary terminal to 100% viewport width.
2. **Static Chrome Splits (Persistent Sidebars):**
   * **Extremely Low Data-Ink Density:** 32 columns dedicated permanently to static branch names and window labels. 95% of the working time, these pixels remain static and unread.
   * **Attentional Taxation:** Positioned in the peripheral field ($30^\circ\text{–}60^\circ$), every agent stream, background spinner, or port update triggers the involuntary **orienting reflex** via the *superior colliculus*, breaking deep focus.

#### 3. Architectural Scope: 1 Worktree = 1 Isolated Session vs. 1 Worktree = 1 Window
* **The `workmux` Window Bottleneck:** `workmux` equates 1 worktree to 1 single Tmux window inside a shared session. This forces a persistent sidebar to manage the flat list of windows, yet completely breaks down when a worktree requires multiple internal windows (e.g., Neovim, test runner, server daemon, and log monitor).
* **The Cockpit Session Advantage:** `awt` provisions an **entire, hermetically isolated Tmux session per worktree**. Worktrees can scale to multiple windows and internal splits without polluting other workspaces. The floating modal (`Ctrl+Shift+G` / `awp`) and ACPD sonic telemetry (`Prefix + Space` / `ai-agent-triage-jump.sh`) provide instantaneous cross-session switching without sacrificing a single column of horizontal workspace.

---

## ⌨️ 4. Biomechanical Keymapping & Kernel Integration

### 4.1 Kernel-Level Dual-Function Keys (`keyd`)
In the kernel input pipeline:
* **`CapsLock` (Hold):** Emits `Ctrl`.
* **`CapsLock` (Tap):** Emits `Esc`.

This anchors the two most frequent modifiers directly under the left pinky at resting Home Row position, preventing ulnar deviation and repetitive strain injury (RSI).

### 4.2 Hierarchical Context Unwinding (Cascading Escape)
To eliminate accidental exits during deep inspection:
1. **Focused Diff or Submenu:** Pressing `Esc` unwinds the focus back to the Primary Anchor (*Files panel [2]*).
2. **Root Files List:** Pressing `Esc` dismisses the popup and restores the terminal.
3. **Secondary Exits:** `q` and `Ctrl+C` remain available for immediate exit.

---

## 🔊 5. Multi-Sensory & Auditory Feedback Architecture

True zero-friction development minimizes visual polling by offloading non-critical telemetry to the **Auditory Cortex**.

The `acpd` daemon integrates low-latency audio cues via PipeWire (`pw-play`) configured in [`acpd.toml`](file:///home/fecavmi/.dotfiles/main/acpd/.config/acpd/config.toml):

```toml
[sound]
enabled = true
player = "pw-play"
response   = "~/.local/share/sounds/ai/01-crystal-chime.wav"  # Agent completed turn
question   = "~/.local/share/sounds/ai/02-gentle-ping.wav"    # Interactive question asked
permission = "~/.local/share/sounds/ai/06-cyber-pulse.wav"    # High-priority approval required
error      = "~/.local/share/sounds/ai/10-arcade-blip.wav"    # Execution error / conflict alert
```

* **Zero-Gaze Monitoring:** Developers can switch to other workspaces or read documentation without constantly polling the terminal. A distinct sonic frequency immediately communicates agent state transitions without breaking cognitive focus.
* **Perceptual Complementarity:** Audio signals trigger reflex orientation, while the status bar pills (`󱥂 idle`, `󰑮 work`, `󱅭 permission`) and popups provide precise contextual detail on demand.

---

## 🛡️ 6. The Ergonomic Stability Rule ("If It Works, Don't Churn")

> **Guiding Principle for Developers and AI Agents:**  
> Muscle memory is an accumulated biological asset built over thousands of repetitions. When an interaction model, keybinding, or modal layout satisfies all biomechanical and latency criteria, **it must remain immutable**.

* **Zero Unnecessary Rebinding:** If a keybinding or workflow is optimal and working seamlessly, do NOT arbitrarily change, rebind, or churn it.
* **Preserve Semantic Consistency:** Always respect the 3-layer architecture (Ephemeral vs Persistent vs Reactive) and the Golden Ratio spatial partition.
* **Respect Motor Pathways:** Never break established Home Row muscle pathways (`Esc`, `q`, `Ctrl+G`, `nav^^` single-touch navigation) for trivial stylistic preferences.

---

## 📚 Related Documentation Links
* [`docs/architecture/workflow-keybindings-matrix.md`](workflow-keybindings-matrix.md): Comprehensive keybinding audit, interaction matrix, and KLM timing reference.
* [`docs/architecture/zero-friction-file-transfer-benchmark.md`](zero-friction-file-transfer-benchmark.md): Quantitative KLM-GOMS benchmark and architectural guide for Zero-Friction Frecency 2.0 file transfer and navigation.
* [`docs/tmux/popups-ergonomics-and-golden-ratio.md`](../tmux/popups-ergonomics-and-golden-ratio.md): Detailed reference, formulas, and benchmarks.
* [`docs/tmux/popup-isolation-and-debounce.md`](../tmux/popup-isolation-and-debounce.md): Backdrop snapshots and event-driven architecture.
* [`docs/shell/completion.md`](../shell/completion.md): Matchmaker smart completions.
* [`docs/theme/system-theme.md`](../theme/system-theme.md): Omarchy theme pipeline.
