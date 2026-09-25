#!/usr/bin/env sh
# keybindings-preview.sh — render rich markdown preview for selected keybinding in Waymaker HUD.
# Usage: keybindings-preview.sh <key> <name> <layer> <id> [action]
set -u

KEY="${1:-}"
NAME="${2:-}"
LAYER="${3:-}"
ID="${4:-}"
ACTION="${5:-}"

# Header banner
printf '# %s\n\n' "$KEY"
printf '**Action:** %s  \n' "$NAME"
printf '**Layer:** `%s`  \n' "$LAYER"

if [ -n "$ACTION" ] && [ "$ACTION" != "info" ]; then
  printf '**Runnable:** `Enter` will execute `%s`  \n' "$ACTION"
else
  printf '**Runnable:** Shell / desktop interactive shortcut  \n'
fi

printf '\n---\n\n'

case "$ID" in
  tmux-workspace)
    cat <<'EOF'
### 󰈞 Workspace Files Explorer (`75% × 60%`)
Inspect workspace files, tree structures, AI code, diagrams, and photos without leaving your active session.

- **Ergonomics**: Inward chord (`e` = Explorer, $H=0$, sub-100ms latency).
- **Previews**: Line-synced syntax preview, native Markdown, Mermaid diagrams & Photos with Kitty Graphics.
- **Controls**:
  - `Enter`: Toggle 100% exclusive fullscreen preview modal.
  - `Ctrl + V`: Injects selected path directly into origin pane / AI prompt.
  - `Ctrl + E` / `e` / `o`: Opens file in Neovim left split (62% × 38%) beside AI session.
  - `Tab` / `Shift + Tab`: Cycles data sources (Local files → Frecency → Bookmarks).
  - `s`: Toggles diagram inspector.
  - `+` / `-` / `0`: Zooms diagrams and photos.
EOF
    ;;

  tmux-yank)
    cat <<'EOF'
### 󰅍 Scrollback Yank & Chrome URL Extractor (`75% × 60%`)
Fuzzy extract shell commands, file paths, URLs, git SHAs, and IPs directly from terminal scrollback.

- **Ergonomics**: Inward chord (`y` = Yank, $H=0$, sub-100ms latency).
- **Controls**:
  - `Enter`: Copies selected token/command to system clipboard (`wl-copy`).
  - `Ctrl + B` / `b` / `w`: Opens URL directly in **Google Chrome** (detached, zero popup flicker).
  - `Ctrl + V`: Injects token directly into origin pane prompt.
  - `Ctrl + E` / `e`: Opens file in Neovim (or auto-delegates URLs to Chrome).
  - `Tab` / `Shift + Tab`: Cycles filter modes (all → cmd → path → url → sha).
  - `Ctrl + P`: Toggles between 60% and 95% full-modal preview.
EOF
    ;;

  tmux-grep)
    cat <<'EOF'
### 󰍉 Workspace Ripgrep Live Search (`85% × 75%`)
Debounced full-text search across the current workspace or project via `ripgrep` + Matchmaker.

- **Ergonomics**: Universal mnemonic `/` with 45/55 foveal layout.
- **Controls**:
  - `Enter`: Opens Neovim directly at the matched line (`+{line} {file}`).
  - `Ctrl + V`: Injects `{file}:{line}` into origin pane.
  - `Ctrl + P` / `Ctrl + /`: Toggles fullscreen preview.
EOF
    ;;

  tmux-sesh)
    cat <<'EOF'
### 󰓩 Sesh Workspace / Task Picker (`75% × 60%`)
Instant teleportation between project workspaces, git worktrees, and tmux sessions.

- **Ergonomics**: `t` = Task/Teleport ($H=0$).
- **Controls**:
  - `Enter`: Connects to selected project workspace session.
  - Integrates with `zoxide`, `git worktrees`, and configured sessions.
EOF
    ;;

  tmux-window)
    cat <<'EOF'
### 󱂬 Window & Session Tree Picker (`75% × 60%`)
Visual grouped view of all sessions and their windows with real-time AI agent status badges.

- **Ergonomics**: `s` = Switch/Select window.
- **Controls**:
  - `Enter`: Focuses selected window immediately.
  - Previews live pane content and active processes.
EOF
    ;;

  tmux-hints)
    cat <<'EOF'
### 󰌌 Vimium Window Hints (1-touch Jump)
Overlays in-situ Home Row hints (`a, s, d, f, j, k, l, ;, g, h`) directly on window tabs.

- **Ergonomics**: Reaction latency $T_R = 0\text{ ms}$.
- **Usage**: Press `Prefix + f` then tap the single letter shown on the tab to jump instantly without typing numbers.
EOF
    ;;

  tmux-bell|tmux-triage)
    cat <<'EOF'
### 󰘳 AI Agent Bell / Alert HUD & Trampoline
Cycles pending AI agent questions, approval prompts, and notifications.

- **`Prefix + i`**: Floating modal popup HUD (`80% × 75%`). Focuses split pane if in current window; opens floating modal for any other window or session. `Esc` dismisses immediately.
- **`Prefix + I`**: Direct focus jump with Bidirectional Trampoline Stack: remembers where you were and returns automatically when alerts clear.
EOF
    ;;

  tmux-ai-split)
    cat <<'EOF'
### 󰄧 AI Agent Side-by-Side Split (35% Right)
Toggles a persistent 35% right split pane running the active AI agent (`$AI_AGENT`).

- **Ergonomics**: `o` = polymOrphic AI split.
- **Usage**: Press `Prefix + o` to reveal or hide the AI assistant pane alongside your active work.
EOF
    ;;

  tmux-scratchpad)
    cat <<'EOF'
### 󰏫 Neovim Floating Scratchpad (`90% × 90%`)
Opens a floating scratchpad editor directly over your current workspace.

- **Ergonomics**: `N` = Neovim scratchpad.
- **Usage**: Jot quick notes, draft code, or inspect temporary buffers without altering existing window layouts.
EOF
    ;;

  shell-smart-tab)
    cat <<'EOF'
### 󰈞 Polymorphic Smart Tab (`_smart_tab`)
Context-aware Tab key widget in Zsh prompt.

- **Empty prompt**: Triggers Matchmaker Jump. Single directory triggers immediate `cd`. Multiple or file triggers Object-First buffer insertion (`BUFFER=" $target"`, `CURSOR=0`).
- **Ghost text at end**: Accepts inline autosuggestion immediately.
- **Command / Mid-line**: Opens Matchmaker multi-column completion picker (`mm-ftb`).
EOF
    ;;

  shell-jump)
    cat <<'EOF'
### 󰌌 Matchmaker Jump Widget (`Ctrl + F`)
Direct fuzzy picker for files and directories with Object-First insertion.

- **Ergonomics**: Left index inward roll ($H=0$).
- Select directory $\rightarrow$ auto `cd`.
- Select file $\rightarrow$ inserts path at start of command line ready for action.
EOF
    ;;

  shell-lazygitrs)
    cat <<'EOF'
### 󰊢 Lazygitrs Floating Popup (`Ctrl + G`)
Instant Git cockpit in a floating popup modal.

- **Dual-Diff Toggle**: Press `Ctrl + G` inside the popup to toggle between modified Files and HEAD commit diff.
- Runs without losing your terminal cursor position.
EOF
    ;;

  shell-intelli)
    cat <<'EOF'
### 󰘳 IntelliShell Command Templates (`Ctrl + T`)
Interactive fuzzy search across 29,000+ curated CLI commands, options, and TLDR snippets.

- **Ergonomics**: $H=0$.
- Type query, select snippet, press Enter to expand template with automatic placeholder substitution.
EOF
    ;;

  shell-atuin)
    cat <<'EOF'
### 󰋚 Atuin Temporal History Search (`Ctrl + R`)
Full-text, temporal, and directory-filtered shell command history search.

- Preserves command duration, exit codes, and timestamps.
EOF
    ;;

  frecency-ptl|frecency-pt|frecency-ptg|frecency-mtl|frecency-mt|frecency-mtg)
    cat <<'EOF'
### ⚡ Frecency 2.0 Zero-Friction File Transfer
World-class benchmarked file transfer system ($20.5\times$ faster than CLI, $32.7\times$ faster than AI).

- **`ptl`**: Paste files to **Last Target** ($220\text{ ms}$) — zero interactive prompts!
- **`pt`**: Paste files to target picked via Matchmaker & stay in current directory.
- **`ptg`**: Paste files and `cd` directly to the destination.
- **`mtl` / `mt` / `mtg`**: Equivalent ultra-fast Move commands.
EOF
    ;;

  frecency-jump|frecency-jump-interactive)
    cat <<'EOF'
### 󰌌 Frecency Jump (`j` / `z` / `ji` / `zi`)
Fast directory navigation powered by frecency.

- **`j` / `z`**: Single-tap left index jump to frequent paths ($100-400\text{ ms}$).
- **`ji` / `zi`**: Interactive full-tree picker with ancestor navigation (`Ctrl + U`) and Neovim launch.
EOF
    ;;

  hypr-browser|hypr-browser-new)
    cat <<'EOF'
### 󰈹 Google Chrome Desktop Bindings
- **`SUPER + B`**: Focuses or launches Google Chrome.
- **`SUPER + SHIFT + B`**: Opens a clean new browser window.
- **`SUPER + SHIFT + ALT + B`**: Opens an incognito browser session.
EOF
    ;;

  *)
    cat <<EOF
### Workflow: $NAME
- **Shortcut**: \`$KEY\`
- **Layer**: $LAYER
- **Identifier**: \`$ID\`
EOF
    ;;
esac

printf '\n---\n*Reference: `docs/architecture/workflow-keybindings-matrix.md`*\n'
