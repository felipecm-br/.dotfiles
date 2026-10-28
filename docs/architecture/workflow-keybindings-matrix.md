# Workflow Keybindings, Biomechanical Audit & Ergonomic Reference Matrix

This document provides a comprehensive audit and definitive reference of all keyboard shortcuts across the terminal workflow (`tmux`, `zsh`, `waymaker`, `lazygitrs`, `keyd`, and AI agent tools).

---

## 🔬 1. Architectural Principles of the Keybinding System

1. **Home Row First ($H = 0$):** Every high-frequency operation is reachable without moving hands from the base typing position ($ASDF / JKL;$).
2. **Kernel Dual-Function Modifiers (`keyd`):** `CapsLock` operates as `Ctrl` when held and `Esc` when tapped, guarded by `overload_tap_timeout = 200` to prevent accidental stray Esc emission during hesitations.
3. **Prefix Guarding for Destructive Actions:** Non-destructive navigation (switching windows, scratchpads, completions) uses **Zero-Prefix / Direct Chords**; destructive actions (closing windows, killing sessions) require a deliberate **Prefix Guard** to prevent accidental data loss.
4. **TTY Flow Control Immunity (`stty -ixon`):** Shell initialization enforces `stty -ixon`, guaranteeing that chords like `Ctrl + S` (Lazygitrs commit log menu) never trigger legacy TTY `XOFF` software flow control terminal freezes.
5. **Mnemonic Consistency:** `n` = New, `w` = Window/Close, `s` = Switch/Select, `t` = Task/Sesh, `g` = Git, `i` = Inspect AI.

---

## 🗺️ 2. Comprehensive Keybinding Matrix

### 🚀 Layer 0: Global Zero-Prefix & Scratchpad Overlays (Fastest Access)

| Keybinding | Scope | Action | Biomechanical Mechanics | KLM Timing ($T$) |
| :--- | :---: | :--- | :--- | :---: |
| **`Ctrl + G`** | Global / Shell | **Lazygitrs Floating Popup (`90% × 88%`)** | Inward roll: CapsLock (Pinky) + G (Index) | $130\text{ ms}$ |
| **`Ctrl + Shift + G`** | Global / Tmux | **AWT Worktree Manager Popup (`85% × 75%`)** | Inward chord: CapsLock (Pinky) + Shift + G | $140\text{ ms}$ |
| **`Ctrl + Shift + T`** (`C-S-t`) | Global / Tmux | **Reopen Last Closed Window / Tab** | Inward chord: CapsLock (Pinky) + Shift + T (VSCode-style tab restore with file, command, path & session) | $140\text{ ms}$ |
| **`Ctrl + Shift + P`** (`C-S-p`) | Global / Tmux | **Command Palette (`75% × 60%`)** | Inward chord: CapsLock (Pinky) + Shift + P (VS Code muscle memory; `command-palette.sh`, badge ` 󰘳 `). Type a command name, `Enter` runs it. | $140\text{ ms}$ |
| **`Ctrl + Shift + I`** (`C-S-i`) | Global / Tmux | **AI Attention Triage Direct Focus Jump** | Inward chord: CapsLock (Pinky) + Shift + I (No Alt, MacBook-ergonomic) | $140\text{ ms}$ |
| **`Ctrl + \`` / `Ctrl + 1..9`** | Tmux | **Direct Window Select (Window 0: backtick, Windows 1 to 9)** | CapsLock (Pinky) + Number Key | $130\text{ ms}$ |
| **`Ctrl + Shift + 0..9`** | Tmux | **Move & Shift Window to Slot 0..9** | Left Pinky + Left Ring + Number Key | $160\text{ ms}$ |

---

### 🪟 Layer 1: Multiplexer Management (`Prefix` = `Ctrl + Space`)

> **Prefix Execution:** Left Pinky (`CapsLock`) + Thumb (`Space`). Ergonomically neutral with zero wrist deviation.

| Prefix Shortcut | Target Action | Ergonomic Justification & Mnemonic |
| :--- | :--- | :--- |
| **`Prefix + Space`** | **AI Fleet Cockpit & Window Manager (`85% × 75%`)** | Space = Instant zero-reach thumb roll ($H=0$). Central unified triage cockpit (` 󱂬 `) for windows, AI agents, and Git context with live PR/CI badges & diffstat. Opens with the cursor on the first agent waiting on you (same order as `Prefix + I`), else on the first `󰷋` row (finished work nobody has reviewed; cleared by a review in lazygitrs with `g` or `Ctrl + G`: 20 s or a stage/commit/discard, not a glance), else on your current window. Waiting rows show why the agent waits (e.g. `Bash: cargo test`) in place of the task title. 7-item bichromatic **Footer** (the chunk cap): `Enter Jump │ y/n Ack │ i Input │ g Git │ r Notes │ ? Help │ Esc Exit`; `a` (fleet ↔ agents view) and `Tab` (worktrees) still work and are listed under `?`. `r` reads *Notes* because it sends lazygitrs review notes to the agent, while the `󰷋` review state is cleared by `g`; additional modal actions: `R` reap stale agents (asks first), `Bksp` last agent, `o`/`O` open PR/checks, `S` ship worktree (asks first), `W` sweep, `c`/`t` new window, `s` sessions, `d`/`x` (`Ctrl+D` while filtering) kill window or session: one press for idle targets (`Prefix + T` / `Ctrl + Shift + T` restores), a second press within 2 s when an agent is still working. |
| **`Prefix + f`** | **Vimium Window Hints (1-touch Jump)** | `f` = **F**ollow / **F**ind window. In-situ Home-Row hints (`a, s, d, f, j, k, l, ;, g, h`) overlaid directly on tabs ($T_R = 0\text{ ms}$). |
| **`Prefix + s`** | **Waymaker Session / Project Picker (`85% × 75%`)** | `s` = **S**essions / project switcher (`session-picker.sh` via `wm session`, badge ` ⚡ `). Inside: `Enter` connects (new sessions first show the CLI × model launch menu inside the popup, cursor on the recommended row, `Esc` back to the picker), `r` connects with the recommended agent and model, `a` / `A` / `c` connect with Antigravity / Antigravity secondary / Claude, `u` shows the quota report ([quota-aware agent selection](quota-aware-agent-selection.md)), `s` (or `w` / `Ctrl+S`) switches to Cockpit, `Tab` / `Shift+Tab` cycles sources (All $\rightarrow$ Tmux $\rightarrow$ Dirs), `d` (or `Ctrl+D`) kills session. |
| **`Prefix + T`** | **Reopen Last Closed Window / Tab** | Shift+T mnemonic: uppercase of new tab `Prefix + t`, aligned with browser/IDE tab restore with exact index/position, working directory, and resumed AI agent session (`agy --conversation`, `claude --continue`, `codex resume --last`, `muse resume --last`, `opencode --continue`). Bound also to `Ctrl+Shift+T`. |
| **`Prefix + u`** | **AI Quota & Burn Telemetry Visual Popup (`75% × 60%`)** | `u` = **U**sage / Quota (`ai-quota-popup.sh`, badge ` 󰓅 ` + quota badge), matching `u` inside the Session Picker (`Prefix + s`). Renders `ai-quota --visual` with 20-cell Stephen Few bullet gauges (`█` actual, `▒` projected burn, `│` weekly budget pace marker, `░` headroom) and `10×30m` 5h activity sparklines. Inside: `Enter` launches the recommended agent/model in a new window, `a` opens the CLI × model menu in-place, `r` refreshes live quota, `u`/`q`/`Esc` exits. |
| **`Prefix + i`** | **AI Agent Bell / Alert HUD (`80% × 75%`)** | `i` = **I**ntelligence / **I**nspect agent turn or question (` 󰮯 `). Cycles pending alerts via floating modal popup HUD. Focuses split pane if in current window; opens floating modal for any other window or session so `Esc` (or `Prefix + i`) instantly dismisses and restores origin. |
| **`Prefix + I`** | **AI Agent Attention Triage Direct Jump** | Shift+I direct focus jump without opening an intermediate popup. Visits waiting agents by class (permission → question → error/stalled), longest-waiting first, then finished work nobody has reviewed (`󰷋`); servicing an agent never makes the next jump skip one. Features **Bidirectional Trampoline Stack**: records origin context and automatically returns to starting window/session when alerts are clear. tpm's own `Prefix + I` (install plugins) is moved to `Prefix + F12` (`@tpm-install`), since it is bound after `tmux.conf` and used to hide this jump. |
| **`Prefix + t`** | **New Window (Current Path)** | `t` = New **T**ab / Window. Aligned with universal browser tab creation (`Prefix + t` opens, `Prefix + T` reopens). |
| **`Prefix + c`** | **Interactive Tmux Window Tree (`choose-window`)** | Native Tmux tree selector fallback. |
| **`Prefix + w` / `x`** | **Close Pane / Window (`close-window.sh`)** | `w` / `x` = Close **W**indow. Smart AI guard: confirmation modal (``, `68 × 11..15`) is shown only if active (non-idle) AI agents are running; windows with idle AI agents or normal shells close immediately (saving to reopen stack). `w` does not auto-repeat, so a `w` typed right after closing reaches the shell instead of closing another window. |
| **`Prefix + W`** | **Smart Kill Session (`close-session.sh`)** | Shift+W symmetry. Smart AI guard: confirmation modal (``, `68 × 11..18`) is shown if active (non-idle) AI agents are running or session has >3 windows; closes immediately if $\le 3$ windows and 0 active agents. |
| **`Prefix + B`** | **Gradient Popup Frames Toggle (`border-gradient`)** | `B` = **B**order. Rare, deliberate toggle (Shift is acceptable off the hot path): swaps single-color popup borders for multi-color gradient frames on the next popup opened; status shown via `display-message`. See [popups §3.5](../tmux/popups-ergonomics-and-golden-ratio.md#35-optional-gradient-frames-border-gradient). |
| **`Prefix + o`** | **AI Split Pane (35% Right Side)** | `o` = Polymorphic AI side-by-side split (`toggle-ai-split.sh` via `ai-launch --auto`, honoring `$AI_LAUNCH_AGENT` and ignoring `$AI_AGENT`). Toggle closes split if already open. |
| **`Prefix + N`** | **Neovim Floating Scratchpad (`90% × 90%`)** | Quick scratchpad editor (`  `) over the active workspace. |
| **`Prefix + \|`** | **Vertical Split Window** | Intuitive visual divider symbol. |
| **`Prefix + -`** | **Horizontal Split Window** | Intuitive visual divider symbol. |
| **`Prefix + h` / `l`**| **Previous / Next Window** | Vim standard directional motions. |
| **`Prefix + Tab`** | **Last Active Window (MRU Toggle)** | Instant toggle between the two most recent windows. |
| **`Prefix + y` / `C-y`** | **Token Extract / Yank (`85% × 75%`)** | `y` = **Y**ank tokens, URLs, hashes, paths via Waymaker (`scrollback-picker.sh`, badge ` 󰅍 `). Inward chord ($H=0$). Direct browser open in Chrome (`Ctrl+B`/`b`/`w`), Neovim open (`Ctrl+E`), prompt insert (`Ctrl+V`). |
| **`Prefix + E`** | **Full Scrollback in Neovim (`90% × 88%`)** | Captures scrollback history, strips ANSI sequences into `/tmp/tmux_scrollback_${UID}_${PANE}.md`, and opens a floating Neovim Markdown popup (` 󰄧 `) with automatic Mermaid diagram rendering (`image-hover.lua`) and `n`/`N` diagram hopping. |
| **`Prefix + e` / `C-e`** | **Workspace Files Picker (`85% × 75%` / `96% × 92%`)** | `e` = **E**xplore workspace files via Waymaker popup (` 󰈞 `). Data sources cycle via `Tab`/`Shift+Tab` (Local -> Frecency -> Bookmarks), dynamic 60%/100% full preview modal (`Enter`), native Markdown, Mermaid & Photos rendering with Kitty graphics passthrough, diagram zoom (`+`/`-`/`0`), inspector (`s`), AI prompt insert (`Ctrl+V`), `e` / `o` / `Ctrl+E` opens in Golden Ratio split Neovim pane (62% × 38%) on left beside AI session. |
| **`Prefix + P`** | **GitHub PR Review Picker (`75% × 60%`)** | `P` = **P**ull Requests (`pr-picker.sh`, badge `  `). Interactive PR list with live metadata/diff preview, worktree checkout (`Enter`), Chrome open (`Ctrl+E`), and diff inspection (`Ctrl+D`). |
| **`Prefix + G`** | **AWT Worktree Manager Popup (`85% × 75%`)** | Prefix alias for `Ctrl + Shift + G` (`awt-popup.sh`, badge `  `). |
| **`Prefix + a` / `Ctrl + Shift + A`** | **AI Agent Launcher Popup (`75% × 60%`)** | `a` = **A**gent (`ai-launch-popup.sh`, badge ` 󰚩 ` + quota badge). CLI × model menu with live quota per row, cursor on the `★` recommended row; `Enter` opens the pick in a **new window** of the current session at the pane's directory. `Esc` closes with no side effect. Same zero-prefix chord pair as `Ctrl + Shift + G`. |
| **`Prefix + A`** | **AI Model / Effort Hot-Swap Popup (`75% × 60%`)** | `A` = **A**gent in place (`ai-switch-popup.sh`, title = agent icon + current model). Types the pick into the agent of the **current pane** as `/model <id>` or `/effort <level>`, so the window and conversation stay; `● now` marks the current model and effort. A half-typed prompt is never submitted: it is stashed and restored around the switch (`ai-prompt`). Claude Code, Antigravity, Devin (`/model <name>`), Codex (opens its own `/model` picker; `Prefix + V` brings the draft back after it). |
| **`Prefix + v`** | **AI Prompt Draft in Nvim Popup (`75% × 60%`)** | `v` = **v**im (`ai-prompt edit`). Opens the draft of the agent in the **current pane** in Neovim over it, through the agent's own external-editor key (Claude Code `Ctrl+X Ctrl+E`, Codex / Antigravity / Devin `Ctrl+G`) with `$VISUAL` / `$EDITOR` = `ai-prompt`: the exact draft goes in, `:wq` puts it back, `:cq` cancels. |
| **`Prefix + V`** | **AI Prompt Draft Stash / Restore** | Toggle (`ai-prompt stash`): puts the draft aside and empties the prompt so a `/command` can be the first word, then brings it back on the next press. For agents without mid-prompt slash commands. |
| **`Prefix + g`** | **Lazygitrs Floating Popup (`90% × 88%`)** | Prefix alias for `Ctrl + G` (`lazygitrs-popup.sh`, badge ` 󰊢 `). |
| **`Prefix + m`** / **`z`** | **Maximize / Zoom Toggle Pane** | `m` = **M**aximize pane (bi-manual hand alternation: left hand prefix, right index taps `m`). Standard `z` also preserved. |
| **`Prefix + Ctrl + h / j / k / l`** | **Resize Pane (Asymmetric 10%: 20 cols / 5 lines)** | Repeatable with prefix held (`-r`). Keep holding `Ctrl` after prefix and tap Vim directions: `C-h`/`C-l` shifts 20 columns (~10% width), `C-j`/`C-k` shifts 5 lines (~10% height). |
| **`Prefix + L`** | **Switch to Last Session** | `L` = **L**ast session (MRU toggle). Instant jump back to the previously active session. |
| **`Prefix + /`** | **Workspace Full-Text Ripgrep (`85% × 75%` / `96% × 92%`)** | `/` = Universal search mnemonic. Waymaker live search modal (` 󰍉 `) with 45/55 foveal layout, debounced query reload, line-synced `bat` syntax preview, `Enter` opens in Neovim (`+{line} {file}`), `Ctrl+V` inserts `{file}:{line}` into origin pane. |
| **`Prefix + ?`** | **Keybindings & Navigation HUD (`85% × 75%`)** | `?` = Universal help mnemonic. Interactive Waymaker workflow HUD (` 󰌌 `) with category filtering (`Tab`), native Markdown previews, and direct execution (`Enter`). |
| **`Prefix + p` / `Ctrl + Shift + P`** | **Command Palette (`75% × 60%`)** | VS Code-style palette over the same catalog as `Prefix + ?` (`command-palette.sh` + `command-palette.toml` layered on `keybindings.toml`). Rows read `Command name ⇥ Shortcut ⇥ Layer`; `Enter` runs the command (most recently run commands list first, MRU kept in `~/.local/state/tmux-command-palette/recent`), `Tab` / `Shift + Tab` filters layers, `Ctrl + O` jumps to shortcut-less tmux commands only (rename, move window/session, join pane, layouts, sync panes, choose-tree, detach, ...; `Ctrl + O` / `Tab` returns). `Prefix + p` is the no-chord alias (default previous-window `p` is free: `Prefix + h/l` cover it). Add new palette-only commands in `emit_cmd` of `keybindings-items.sh`. |

### 🐚 Layer 2: Smart Shell (`zsh`) & Object-First Navigation Widgets

| Keybinding | Widget / Function | Behavior & Context Awareness |
| :--- | :--- | :--- |
| **`<Tab>`** (Empty Prompt) | `_smart_tab` $\rightarrow$ `_jump_widget` | Triggers Waymaker Jump (`wm --no-read -o jump`). If single directory $\rightarrow$ immediate `cd`. If multiple or file $\rightarrow$ Object-First buffer insertion (`BUFFER=" $target"`, `CURSOR=0`). |
| **`<Tab>`** (Ghost Text at End) | `_smart_tab` $\rightarrow$ `autosuggest-accept` | Accepts autosuggestion immediately (`$CURSOR == $#BUFFER`). |
| **`<Tab>`** (Command / Mid-line) | `_smart_tab` $\rightarrow$ `wm-ftb` | Auto-spaces command name (`_auto_space_if_command`) and opens Waymaker multi-column completion picker (`wm-ftb`, aliased as `mm-ftb`). |
| **`Ctrl + F`** | `_jump_widget` | Manual Waymaker Jump Widget: fast directory/file picker with Object-First buffer insertion ($H=0$). |
| **`Ctrl + G`** | `_git_files_widget` | Lazygitrs Floating Popup (`~/.config/tmux/lazygitrs-popup.sh "$PWD"`, or detaches if already inside popup). |
| **`Ctrl + N`** | `_wm_tab_widget` | Explicitly invokes Waymaker completion UI (`_wm_tab_widget`). |
| **`Ctrl + K`** | `history-beginning-search-backward-end` | Prefix history search backward based on current buffer query. |
| **`Ctrl + J`** | `history-beginning-search-forward-end` | Prefix history search forward based on current buffer query. |
| **`Ctrl + Backspace`** | `backward-kill-word` | Deletes preceding word in Insert mode ($T_K = 120\text{ ms}$). |
| **`Ctrl + R`** | `atuin-search` | Full-text contextual and temporal history search. |
| **`Ctrl + T`** | `_intelli_search` | IntelliShell Command Templates & TLDR: Interactive fuzzy search across curated command snippets with parameter replacement ($H=0$). |

#### 2.1 Zero-Friction Frecency 2.0 File Transfer & Directory Jump
> For comprehensive KLM-GOMS benchmarks, speedup tables ($20.5\times$ vs CLI, $32.7\times$ vs AI), and architectural pillars, see [**Zero-Friction File Transfer Benchmark & Architectural Guide**](zero-friction-file-transfer-benchmark.md).

| Command / Alias | Action Executed | Biomechanical Mechanics | KLM Cost ($T$) | Ergonomic Rationale |
| :--- | :--- | :--- | :---: | :--- |
| **`j`** / **`z`** | Jump Home / Directory / Frecency | Left Index single tap or query | $100\text{ ms} - 400\text{ ms}$ | $H=0$. Immediate navigation without typing `cd ~` or long paths (`wm_smart_chpwd` auto-tracks). |
| **`ji`** / **`zi`** | Interactive Waymaker Jump | Left Index inward chord / alias | $200\text{ ms}$ | Full tree navigation, ancestor jump (`Ctrl+U`), and editor launch. |
| **`pt`** (`pasteto`) | Copy Files & Stay | Home-row chord + WM picker | $750\text{ ms}$ | Transfers files to frecency destination without leaving current context. |
| **`ptg`** (`pasteto -g`) | Copy Files & Jump to Destination | Home-row chord + WM picker + `cd` | $750\text{ ms}$ | Transfers files and immediately navigates to destination. |
| **`ptl`** (`pasteto -l`) | Copy Files to Last Target | Home-row chord + cached `_MM_LAST_TARGET` | **$220\text{ ms}$** | **Record transfer speed ($20.5\times$ vs CLI):** Bypasses picker entirely. |
| **`mt`** / **`mtg`** / **`mtl`** | Move Equivalents (`moveto`) | Home-row chords + `moveto` flags | $220\text{ ms} - 750\text{ ms}$ | Move equivalents with zero interactive blocking prompts. |

---

### 📂 Layer 3: Waymaker Frecency Directory Jump & File Manager (`jump.toml`)

| Keybinding | Action / Command | Behavior & Context Awareness |
| :--- | :--- | :--- |
| **`Enter`** | `Accept` | Selects item: `cd` to directory or emit selected path to caller. |
| **`u`** | `@undo` | **File Manager UndoStack:** Undoes last file operation (yank, cut, paste, delete). |
| **`Ctrl + U`** | Ancestor Hierarchy Jump | Walks directory hierarchy backwards up to root `/` dynamically via `Reload(...)`. |
| **`h` / `Left`** | `ChDir(..)` | Navigates up to parent directory ($H=0$). |
| **`l` / `Right`** | `ChDir({=})` | Drills down into selected directory ($H=0$). |
| **`e` / `Ctrl + E`** | `Execute(nvim {+})` | Opens selected file(s) in Neovim with frecency boost. |
| **`y` / `x`** | `@yank` / `@cut` | Stages file(s) for copy or move in File Manager. |
| **`p` / `P` (`Ctrl + V`)** | `@paste` / `@paste_into` | Pastes staged files into current directory or selected subfolder. |
| **`Tab` / `Shift + Tab`** | `@reloadnext` / `@reloadprev` | Cycles data sources: Local Directory $\rightarrow$ Frecency History $\rightarrow$ Bookmarks. |
| **`Space`** | `Toggle` | Toggles multi-selection on the highlighted file or directory. |
| **`,`** | `SortMenu` | Opens sort configuration menu. |
| **`\`** | `ToggleParentPeek` | Toggles split parent-directory preview. |
| **`Ctrl + P`** | `SwitchPreview` | Toggles or cycles preview window layout. |

---

### 📦 Layer 4: Lazygitrs Modal Navigation, Commits, Diff Review & AI Notes

#### 4.1 Hierarchical Unwinding, Dual-Diff & Panel Navigation
| Keybinding | Scope | Behavior |
| :--- | :--- | :--- |
| **`Ctrl + G`** (`<c-g>`) | Global / Files / Diff | **Dual-Diff Toggle (`toggleWorkingTreeAndHead`):** Instantly toggles between uncommitted Working Tree changes and `HEAD` commit inspection. |
| **`g`** | Global / Files | **Return to Cockpit (`returnToCockpit`):** Exits Lazygitrs with code 10, reopening the Cockpit HUD at the exact cursor position. |
| **`Esc`** | Inside Diff / Submenus | **Unwinds Focus:** Returns focus to the Files list without closing. |
| **`Esc`** | On Root Files List | **Closes Popup:** Closes the popup (or returns to Cockpit if launched from Cockpit). |
| **`q`** / **`Ctrl + C`** | Anywhere | Quits Lazygitrs and closes the popup immediately. |
| **`1` / `2` / `3` / `4` / `5`** | Root Navigation | Instant jump to Status (1), Files (2), Branches (3), Commits (4), Stash (5). |
| **`:`** (Colon) | Global | Universal shell command runner popup (executes arbitrary shell commands in repo root). |

#### 4.2 Tree View Navigation (Files & Commit Files)
| Keybinding | Scope | Behavior |
| :--- | :--- | :--- |
| **`-`** | Directory Node | **Fold / Unfold:** Explicitly toggles directory collapse state for any folder (including root). |
| **`Enter`** | Directory Node | **Fullscreen Combined Diff:** Expands and focuses a combined unified diff of all child files. |
| **`Enter`** | File Node | Focuses the diff panel for the selected file in fullscreen. |
| **`,`** (Comma) | Tree View | **Jump to Parent:** Navigates directly to parent directory node. |
| **`.`** (Period) | Tree View | **Jump to Child:** Navigates directly to first child node within directory. |
| **`<`** | Tree View | **Previous Sibling:** Navigates directly to previous sibling node at the same tree depth. |
| **`>`** | Tree View | **Next Sibling:** Navigates directly to next sibling node at the same tree depth. |

#### 4.3 Reconciled Commits Panel & Branch Filtering
| Keybinding | Scope | Action & Ergonomic Alignment |
| :--- | :--- | :--- |
| **`Ctrl + S`** (`<c-s>`) | Commits Panel | **Branch Filter Menu (`openLogMenu`):** Multi-select branch filtering popup with `<Clear Filter>`. **Dynamically rendered in the status bar** based on configuration. |
| **`Ctrl + F`** (`<c-f>`) | Commits Panel | **Mark Commit as Fixup (`markCommitAsFixup`):** Targets highlighted commit for subsequent fixup. |
| **`F`** (Shift+F) | Commits Panel | **Create Fixup Commit (`createFixupCommit`):** Creates immediate fixup commit targeting the marked commit. |
| **`a`** | Commits Panel | **Toggle All Branches Log:** Toggles commit log view between all branches and HEAD-only. |
| **`b`** | Commits Panel | **Bisect Options Menu (`viewBisectOptions`):** Opens Git bisect workflow menu. |
| **`i`** | Commits Panel | **Interactive Rebase (`interactiveRebase`):** Initiates interactive rebase atop highlighted commit. |
| **`C` / `V`** | Commits Panel | **Cherry-Pick Copy & Paste:** `C` copies commit to clipboard; `V` pastes/applies cherry-pick. |
| **`s` / `S`** | Commits Panel | **Squash:** `s` squashes down into next commit; `S` squashes all commits above. |
| **`r` / `R`** | Commits Panel | **Rename Commit:** `r` renames in-place; `R` opens default `$EDITOR`. |
| **`g`** | Commits Panel | **Reset Options:** Soft, mixed, or hard reset menu. |

#### 4.4 Diff Review & Hunk Navigation (Turbo Patch Mode)
| Keybinding | Scope | Behavior |
| :--- | :--- | :--- |
| **`Space`** | Diff View | **Turbo Hunk Staging:** Stages (or unstages) the active hunk and **auto-advances** selection to the next hunk (`cycle_next_revert_hunk`). |
| **`{` / `}`** | Diff View | Cycles between change hunks backwards / forwards. |
| **`[` / `]`** | Diff View | Switches view between Old side only, New side only, or Side-by-Side. |
| **`Enter`** | Diff View | **Revert Block:** Reverts hovered or selected diff block in working tree. |
| **`u`** | Diff View | **Undo Revert Block:** Undoes the last diff block revert. |
| **`v`** | Diff View | Toggles visual line/range selection in diff. |

#### 4.5 AI Review Notes Workflow & Worktree Isolation
| Keybinding | Scope | Action & Mechanics |
| :--- | :--- | :--- |
| **`Ctrl + N`** (`<c-n>`) | Diff / Files | **Quick Note for AI Agent (`quickAiNote`):** Opens a 1-step prompt modal pre-anchored to `[file:line]` (in Diff View) or `[file]` (in Files / CommitFiles), saves the note to `.git/info/lines.json`, and **immediately dispatches** it to the active AI agent pane. |
| **`c`** | Diff View / Note | **Create Inline Note (Queue):** Creates an inline review comment (`status: New`) on the hovered/selected line without dispatching immediately, allowing multi-hunk/multi-file batch review. |
| **`n` / `N`** | Diff View | **Cycle Notes:** Jumps to next (`n`) or previous (`N`) review note in current diff. |
| **`y`** | Note Selected | **Yank / Copy Note:** Copies full note text to system clipboard with a 500ms Neovim-style flash highlight. |
| **`S` / `A` / `R`** | Diff View / Note | **Batch Send to AI:** Formats all pending (`New`) notes in `.git/info/lines.json` into a numbered review prompt, dispatches to the active AI session (via ACP HTTP, SSE, or `agent-note.sh` Tmux bracketed paste), and marks them `Sent`. (Also triggered via `r` from the Cockpit HUD). |
| **`r`** | Note Selected | **Reset Note Status:** Resets the selected note's status from `Sent`/`Addressed` back to `New`. |
| **`d`** | Note Selected | **Delete Note:** Removes review note from `.git/info/lines.json` with fallback selection to adjacent note. |
| **`Enter` / `o`** | Note Selected | **View Note Details:** Opens modal popup displaying author, timestamp, status, and full markdown text. |
| *Automated* | Worktree Root | **Worktree Port Isolation (`.lazygitrs.port`):** Each worktree writes its dynamic port to `.lazygitrs.port`, isolating concurrent agent sessions. |

---

## 🔬 3. Consolidated Interaction Matrix (KLM Biomechanical Audit)

The table below consolidates the definitive keybindings across all layers, auditing each chord through Card, Moran & Newell's **Keystroke-Level Model (KLM)**:

| Key / Chord | Context / Mode | Action Executed | Biomechanical Mechanics | KLM Cost ($T$) | Ergonomic Rationale |
| :--- | :--- | :--- | :--- | :---: | :--- |
| **`Ctrl + G`** | Global / Shell | Open Lazygitrs Floating Popup | Inward roll: CapsLock (Pinky) + G (Index) | $130\text{ ms}$ | $H=0$. Immediate access to Git workspace without context switching. Bound in tmux's root table, so it also wins inside Claude Code, whose own `Ctrl+G` (edit the prompt in `$EDITOR`) is reachable as `Ctrl+X Ctrl+E`. Opening it marks the worktree reviewed for the Cockpit. |
| **`Ctrl + Shift + G`** | Global / Tmux | AWT Worktree Manager Popup | Inward chord: CapsLock (Pinky) + Shift + G | $140\text{ ms}$ | Direct access to worktrees; symmetric to `Ctrl+G`. |
| **`Ctrl + Shift + I`** | Global / Tmux | AI Agent Triage Direct Focus Jump | Inward chord: CapsLock (Pinky) + Shift + I | $140\text{ ms}$ | Home Row, no-Alt, MacBook-ergonomic focus switch to next agent needing attention. |
| **`Prefix + Space`** | Tmux Multiplexer | AI Fleet Cockpit & Window Manager (`85% × 75%`) | Left Pinky (CapsLock) + Thumb (Space) $\rightarrow$ Space | $200\text{ ms}$ | Immediate double-thumb roll on Spacebar ($H=0$). Central hub for windows, AI agents, and Git. |
| **`Prefix + f`** | Tmux Multiplexer | Vimium Window Hints (1-touch Jump) | Inward roll: CapsLock + Space $\rightarrow$ `f` | $240\text{ ms}$ | Replaces legacy `find-window` with instant Home-Row hints ($H=0$). |
| **`Prefix + s`** | Tmux Multiplexer | Waymaker Session Picker (`85% × 75%`) | Left Pinky (CapsLock) + Thumb (Space) $\rightarrow$ `s` | $220\text{ ms}$ | `s` = Session switcher (`wm session`); home-row left-hand inward roll. |
| **`Prefix + i`** | Tmux Multiplexer | AI Agent Bell / Alert HUD | Left Pinky (CapsLock) + Thumb (Space) $\rightarrow$ `i` | $240\text{ ms}$ | `i` = Intelligence; cycles pending questions/permissions in universal floating popup modal (`Esc` returns to origin). Focuses split pane if in current window. |
| **`Prefix + I`** | Tmux Multiplexer | AI Agent Triage Direct Jump | Left Pinky (CapsLock) + Thumb (Space) $\rightarrow$ `I` | $240\text{ ms}$ | Direct focus jump to the next waiting agent (permission → question → error/stalled, oldest first), then `󰷋` work to review, with Bidirectional Trampoline Stack (returns to starting window/session when alerts clear). |
| **`Prefix + w` / `x`** | Tmux Multiplexer | Close Pane / Window (`close-window.sh`) | Left Pinky (CapsLock) + Thumb (Space) $\rightarrow$ `w` / `x` | $240\text{ ms}$ | Guarded destruction: prompts confirmation modal (``) only if active (non-idle) AI agents are running; saves state for `Prefix + u` / `Ctrl+Shift+T` restore. Not repeatable (`bind w`, no `-r`). |
| **`Prefix + W`** | Tmux Multiplexer | Smart Kill Session (`close-session.sh`) | Left Pinky (CapsLock) + Thumb (Space) $\rightarrow$ `W` | $240\text{ ms}$ | Guarded destruction: prompts confirmation modal if non-idle AI agents are active or >3 windows. |
| **`Prefix + B`** | Tmux Multiplexer | Gradient Popup Frames Toggle (`border-gradient`) | Left Pinky (CapsLock) + Thumb (Space) $\rightarrow$ `B` | $260\text{ ms}$ | Rare aesthetic toggle; no reload, applies to the next popup opened. |
| **`S`** (in `awt`) | Waymaker AWT | Ship Worktree (Merge & Push) | Shift + S (Left Pinky + Left Ring) | $140\text{ ms}$ | Atomic local merge into base and push to remote origin. |
| **`P`** (in `awt`) | Waymaker AWT | Checkout GitHub PR Worktree | Shift + P (Left Pinky + Right Pinky) | $140\text{ ms}$ | Interactive PR list with live preview and dedicated worktree checkout. |
| **`<Tab>`** (Empty) | Shell / ZLE | Waymaker Directory Jump | Left Pinky single tap on Tab | $100\text{ ms}$ | **Object-First ergonomics:** Empty prompt immediately surfaces directory jumper (`wm --no-read -o jump`). |
| **`<Tab>`** (Ghost) | Shell / ZLE | Accept Inline Autosuggestion | Left Pinky single tap on Tab | $100\text{ ms}$ | Accepted only when `$CURSOR -eq $#BUFFER`, preventing midline ghost-text hijacking. |
| **`<Tab>`** (Command) | Shell / ZLE | Auto-space & Waymaker FTB (`wm-ftb`) | Left Pinky single tap on Tab | $100\text{ ms}$ | Eliminates manual spacebar typing after aliases/commands. |
| **`Ctrl + F`** | Shell / ZLE | Waymaker Jump Widget | Inward chord: CapsLock (Pinky) + F (Index) | $120\text{ ms}$ | $H=0$. Replaces legacy `Ctrl+T` with home-row inward curl. |
| **`Ctrl + N`** | Shell / ZLE | Waymaker Completion UI (`_wm_tab_widget`) | CapsLock (Pinky) + N (Right Index) | $130\text{ ms}$ | Direct fallback completion invocation without touching arrow keys. |
| **`Ctrl + K` / `J`** | Shell / ZLE | Prefix History Search Prev / Next | CapsLock (Pinky) + K / J (Home Row) | $120\text{ ms}$ | Preserves Vim navigation instincts during shell command search. |
| **`u`** | Waymaker Jump | Undo File Operation (`@undo`) | Right Index reach up to `u` | $110\text{ ms}$ | Unmodified 1-touch operation for File Manager UndoStack. |
| **`Ctrl + U`** | Waymaker Jump | Ancestor Hierarchy Jump | CapsLock (Pinky) + U (Right Index) | $130\text{ ms}$ | Differentiated from `u`; walks up directory tree up to root `/`. |
| **`h` / `l`** | Waymaker Jump | Directory Up (`..`) / Down (`{=}`) | Right Index / Ring on Home Row | $100\text{ ms}$ | Flawless Vim horizontal navigation with zero wrist movement. |
| **`e` / `Ctrl + E`** | Waymaker Jump | Edit in Neovim (`nvim {+}`) | Left Middle reach up to `e` | $110\text{ ms}$ | Fast handoff from directory search to code editor. |
| **`y` / `x` / `p`** | Waymaker Jump | Yank / Cut / Paste File Operations | Home row & bottom row direct taps | $110\text{ ms}$ | Intuitive file manager clipboard workflow. |
| **`-`** | Lazygitrs Tree | Fold / Unfold Directory Node | Right Pinky top-row reach to `-` | $120\text{ ms}$ | Dedicated directory collapse toggle for all folders (including root). |
| **`Enter`** (on dir) | Lazygitrs Tree | Fullscreen Combined Diff | Right Pinky tap on Enter | $100\text{ ms}$ | Instant multi-file diff view without manual traversal. |
| **`,` / `.`** | Lazygitrs Tree | Navigate to Parent / Child Node | Right Middle / Ring reach to bottom row | $110\text{ ms}$ | Hierarchical tree traversal without lateral hand shift. |
| **`<` / `>`** | Lazygitrs Tree | Navigate Prev / Next Sibling | Shift + `,` / `.` (Pinky + Ring/Middle) | $140\text{ ms}$ | Sibling navigation preserving structural depth. |
| **`Ctrl + S`** | Lazygitrs Commits | Open Branch Filter Menu (`openLogMenu`) | CapsLock (Pinky) + S (Left Ring) | $120\text{ ms}$ | Home-row chord; dynamic status bar reflects active keybinding. |
| **`Ctrl + F`** | Lazygitrs Commits | Mark Commit as Fixup | CapsLock (Pinky) + F (Left Index) | $120\text{ ms}$ | Home-row inward chord; fast target marking before squash/fixup. |
| **`F`** (Shift+F) | Lazygitrs Commits | Create Fixup Commit | Left Pinky (Shift) + Left Index (F) | $140\text{ ms}$ | Direct uppercase counterpart to fixup marking. |
| **`a`** | Lazygitrs Commits | Toggle All Branches vs HEAD Log | Left Pinky tap on Home Row `a` | $100\text{ ms}$ | Instant log view alternation with zero finger reach. |
| **`b`** | Lazygitrs Commits | Open Bisect Options Menu | Left Index reach down to `b` | $110\text{ ms}$ | Rapid access to binary search debugging workflow. |
| **`i`** | Lazygitrs Commits | Interactive Rebase Menu | Right Middle reach up to `i` | $110\text{ ms}$ | Standard Git interactive rebase mnemonic. |
| **`C` / `V`** | Lazygitrs Commits | Cherry-Pick Copy / Paste | Shift + C / Shift + V (Pinky + Index) | $140\text{ ms}$ | Universal OS clipboard mnemonics adapted for Git commits. |
| **`:`** (Colon) | Lazygitrs Global | Universal Shell Command Runner | Shift + `;` (Right Pinky chord) | $130\text{ ms}$ | Vim ex-command mnemonic; executes arbitrary scripts in repo root. |
| **`Space`** (in diff) | Lazygitrs Diff | Stage Active Hunk & Auto-Advance | Thumb tap on Spacebar ($H=0$) | $100\text{ ms}$ | Turbo patch mode: stages current hunk and cycles to next hunk instantly. |
| **`{` / `}`** | Lazygitrs Diff | Previous / Next Diff Hunk | Shift + `[` / `]` (Right Pinky reach) | $140\text{ ms}$ | Classic Vim paragraph/block motion applied to diff hunks. |
| **`[` / `]`** | Lazygitrs Diff | Old / New / Both Diff Side Switch | Right Pinky reach to bracket keys | $120\text{ ms}$ | Fast inspection of individual file revisions. |
| **`Enter`** (in diff) | Lazygitrs Diff | Revert Hovered Diff Block | Right Pinky tap on Enter | $100\text{ ms}$ | Immediate hunk rejection during review. |
| **`u`** (in diff) | Lazygitrs Diff | Undo Last Revert Block | Right Index reach up to `u` | $110\text{ ms}$ | Safety net: instant recovery of accidental hunk reverts. |
| **`Ctrl + N`** | Lazygitrs Diff/Files| Quick Note for AI Agent (1-Step Send) | CapsLock (Pinky) + N (Right Index) | $130\text{ ms}$ | Anchors to `[file:line]`, saves to `.lines.json`, and dispatches immediately to AI pane. |
| **`c`** | Lazygitrs Diff | Create Inline Review Note (Queue) | Left Middle reach down to `c` | $110\text{ ms}$ | Queues inline comment (`New`) on active line for multi-note batch review. |
| **`n` / `N`** | Lazygitrs Diff | Cycle Next / Prev Review Note | Right Index reach to `n` / Shift + `N` | $110\text{ ms}$ / $140\text{ ms}$ | Standard search-next convention for review note navigation. |
| **`y`** (on note) | Lazygitrs Diff | Yank / Copy Note to Clipboard | Right Index reach up to `y` | $110\text{ ms}$ | Neovim-style 500ms flash feedback; copies full note text. |
| **`S` / `A` / `R`** | Lazygitrs Diff | Batch Send Pending Notes to AI | Left Pinky (Shift) + Left Ring (`S`) | $140\text{ ms}$ | `S` = Send / Submit all `New` notes to active AI session (`Sent`). |
| **`r`** (on note)| Lazygitrs Diff | Reset Selected Note Status to `New` | Left Index reach up to `r` | $110\text{ ms}$ | Enables re-reviewing or re-dispatching a specific note to agent. |
| **`d`** (on note) | Lazygitrs Diff | Delete Review Note | Left Middle tap on Home Row `d` | $100\text{ ms}$ | Destructive single-note dismissal with auto-selection of next note. |
| **`Enter` / `o`** | Lazygitrs Diff | View Note Full Details Popup | Right Pinky tap / Right Ring reach | $100\text{ ms}$ / $110\text{ ms}$ | Full markdown rendering of rationale, author, and timestamp. |
| **`Esc`** | Lazygitrs Global | Hierarchical Context Unwind / Cockpit Return | Left Pinky tap (keyd CapsLock tap) | $100\text{ ms}$ | $H=0$. In diff: unwinds to Files panel. At Files panel: returns to Cockpit (code 10) or dismisses standalone popup (code 0). |
| **`K`** | Neovim Normal | Smart Universal Hover (Visual/LSP) | Right Middle tap on Home Row `k` | $100\text{ ms}$ | $H=0$. Previews Mermaid diagram/image or delegates to LSP hover. |
| **`p`** | Neovim Markdown | Smart Image Paste After Cursor | Right Pinky reach to `p` | $100\text{ ms}$ | Automatically saves to `assets/` and activates Select Mode for captioning. |
| **`P`** | Neovim Markdown | Smart Image Paste Before Cursor | Shift + P (Pinky + Ring) | $140\text{ ms}$ | Direct counterpart to `p` inserting above the cursor with alt selection. |

---

### 🖼️ Layer 2.5: Neovim In-Editor Visual Intelligence & Mermaid Hover
> For full architectural specifications, Wayland clipboard isolation runbooks, and KLM benchmarks, see [**Neovim Visual Intelligence & Smart Image Clipboard Workflow**](neovim-visual-workflow.md).

| Keybinding / Trigger | Scope | Target Action | Ergonomic Mechanics | KLM Timing ($T$) |
| :--- | :---: | :--- | :--- | :---: |
| **Cursor Hover** (`CursorMoved`) | Normal Mode | **Auto Sidecar Preview (Default)** on Link / Diagram | Zero extra keystroke: hover on link/block | $0\text{ ms}$ |
| **`K`** | Normal Mode | **Smart Universal Hover** (Mermaid Diagram / Image or LSP in Sidecar) | Home Row tap on `k` (Right Middle) | $100\text{ ms}$ |
| **`<LeftMouse>` (on Hover)** | Normal Mode | **Click-to-Zoom Lightbox Modal** from Sidecar Preview | Single mouse click on floating preview | $120\text{ ms}$ |
| **`<2-LeftMouse>`** | Normal Mode | **Double-Click to Lightbox Modal** in Markdown | Double-click on link or diagram block | $140\text{ ms}$ |
| **`<leader>mi`** | Normal Mode | **Direct Sidecar Image / Diagram Preview** | Home Row inward roll: Space $\rightarrow$ m $\rightarrow$ i | $130\text{ ms}$ |
| **`<leader>mz`** / **`<leader>mI`** | Normal Mode | **Interactive Lightbox Modal** (Zoom `+`/`-` or wheel, Pan `h/j/k/l`, Reset `0`) | Space $\rightarrow$ m $\rightarrow$ z / Space $\rightarrow$ m $\rightarrow$ Shift+I | $130\text{ ms}$ |
| **`<leader>mt`** / **`<leader>um`** | Normal Mode | **Toggle Automatic Cursor Hover** (`:ImageHoverToggle`) | Space $\rightarrow$ m $\rightarrow$ t / Space $\rightarrow$ u $\rightarrow$ m | $130\text{ ms}$ |
| **`:ImageHover`** | Ex Command | **Open Visual Preview** in right-margin sidecar | Command palette invocation | $180\text{ ms}$ |
| **`:ImageLightbox`** | Ex Command | **Open Interactive Lightbox Modal** with zoom and pan | Command palette invocation | $180\text{ ms}$ |
| **`p`** (in Markdown) | Normal Mode | **Smart Paste After** (Clipboard Image $\rightarrow$ Save + Select Alt, or Text) | Home Row tap on `p` | $100\text{ ms}$ |
| **`P`** (in Markdown) | Normal Mode | **Smart Paste Before** (Clipboard Image $\rightarrow$ Save + Select Alt, or Text) | Shift + P (Pinky + Ring) | $140\text{ ms}$ |
| **`<C-v>`** (in Markdown) | Insert Mode | **Smart Insert Paste** (Clipboard Image $\rightarrow$ Select Alt, or Text) | CapsLock (Pinky) + V | $130\text{ ms}$ |
| **`<leader>p`** / **`<leader>ip`** | Normal Mode | **Explicit Paste Image** (`:PasteImage`) | Space $\rightarrow$ p / Space $\rightarrow$ i $\rightarrow$ p | $130\text{ ms}$ |
| **`:PasteImage`** | Ex Command | **Paste Image with VS Code Style Alt Selection** | Command palette invocation | $180\text{ ms}$ |

* **Zero Buffer Clutter & Non-Occluding Sidecar:** Images and Mermaid diagrams render in an ephemeral, rounded floating window (`border = "rounded"`) docked to the right margin (`relative = "editor", col = -1, row = 1`), keeping 100% of the Mermaid source code completely visible and editable without text occlusion. Auto-hover is active by default.
* **Interactive Lightbox Modal with Zoom Badges:** Centered 88% modal dialog with darkened backdrop for deep visual inspection. Displays real-time zoom percentage badges (`󰍉 120%` for Zoom In, `󰍋 85%` for Zoom Out, `󰄧 100%` for 1:1), supporting dynamic scaling (`+`/`-` or mouse wheel `<ScrollWheelUp>`/`<ScrollWheelDown>`), 2D panning (`h/j/k/l` or arrows), reset (`0` or double click), and instant dismissal (`q`, `<Esc>`, or right-click).
* **Click-to-Zoom Interaction:** Clicking directly on the floating sidecar preview window or double-clicking on an image/diagram in Markdown automatically enters the centered Lightbox modal.
* **VS Code-Style Alt Text Selection:** When pasting an image from the system clipboard via `p` or `P`, it automatically saves to `assets/` and pre-selects the alt text `image` in Neovim Select Mode (`vi]<C-g>`). Typing any character immediately replaces it with your custom caption, while `<Esc>` keeps the default label.
* **Safe Wayland Clipboard Isolation:** The Wayland clipboard provider in `options.lua` guarantees that `wl-paste` strictly requests `text/plain` for text registers, completely preventing unprintable raw image binary escape sequences (`\8E\E5l...`) from polluting registers or documents.
* **Smart Contextual Pasting:** Pressing `p` or `P` in Markdown inspects the system clipboard via `wl-paste` and magic bytes (`\x89PNG`, `\xFF\xD8\xFF`, `GIF8`, `WEBP`) in sub-1ms; if an image is detected, it triggers the image paste pipeline; otherwise, it executes standard text pasting with zero disruption.
* **Smart Treesitter Link Recognition:** Treesitter queries for `markdown_inline` and `markdown` match both standard inline images (`![alt](url)`), markdown links (`[label](chart.mmd)` / `[arch](diagram.png)`), and fenced ````mermaid```` code blocks.
* **Universal Link Fallback:** Bare URLs and quoted file paths in any filetype (Lua, Python, Rust, etc.) are detected and rendered on the fly.
* **Sub-100ms Graphics Pipeline:** Leverages native Kitty Graphics Protocol through Ghostty and Tmux passthrough with local `mmdc` headless compilation.

---

## 🔬 4. Biomechanical Audit Summary & Verdict

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                       WORKFLOW ERGONOMIC HEALTH SCORE                       │
├────────────────────────────────┬──────────────┬─────────────────────────────┤
│ Dimension                      │ Score        │ Key Driver                  │
├────────────────────────────────┼──────────────┼─────────────────────────────┤
│ 1. Home Row Anchoring (H = 0)  │ 10 / 10      │ keyd CapsLock=Ctrl/Esc      │
│ 2. Cognitive Friction (M ≈ 0)  │ 9.9 / 10     │ Dynamic Omarchy Semiotics   │
│ 3. Latency & Responsiveness    │ 10 / 10      │ Sub-100ms Doherty Threshold │
│ 4. Conflict Safety             │ 10 / 10      │ Clean POSIX/Vim Separation  │
│ 5. Muscle Memory Stability     │ 10 / 10      │ Zero Arbitrary Key Churn    │
└────────────────────────────────┴──────────────┴─────────────────────────────┘
```

* **Zero Collision Guarantee:** Global keys do not intercept POSIX TTY signals (`Ctrl+W`, `Ctrl+C`, `Ctrl+Z`), preserving full shell and editor functionality.
* **Complete Symmetry:** Pairings (`w`/`W`, `h`/`l`, `j`/`k`, `Esc`/`Enter`, `c`/`d`, `n`/`N`) maintain intuitive directional and hierarchical relationships.
* **Worktree Port Isolation:** Dynamically resolving `.lazygitrs.port` prevents port collisions and ensures seamless multi-agent concurrency.

---

## 🔗 Related Documentation
* [`docs/architecture/terminal-ergonomics-and-ux-manifesto.md`](terminal-ergonomics-and-ux-manifesto.md): Core HCI philosophy and cognitive models.
* [`docs/architecture/neovim-visual-workflow.md`](neovim-visual-workflow.md): Neovim visual intelligence, Mermaid hover preview, and smart image clipboard architecture.
* [`docs/architecture/zero-friction-file-transfer-benchmark.md`](zero-friction-file-transfer-benchmark.md): Quantitative KLM-GOMS benchmark and architectural guide for Zero-Friction Frecency 2.0 file transfer and navigation.
* [`docs/tmux/popups-ergonomics-and-golden-ratio.md`](../tmux/popups-ergonomics-and-golden-ratio.md): Golden Ratio geometry and visual semiotics.
* [`docs/GIT_WORKTREE_AGENTIC_WORKFLOW.md`](../GIT_WORKTREE_AGENTIC_WORKFLOW.md): Agent worktree orchestrator and multi-agent Git workflow.
* [`docs/shell/completion.md`](../shell/completion.md): Waymaker completion architecture.
* [`docs/shell/waymaker-presets.md`](../shell/waymaker-presets.md): Waymaker presets reference.

