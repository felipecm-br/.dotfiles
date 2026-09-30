#!/usr/bin/env sh
# keybindings-items.sh — emit structured keybindings for Matchmaker/Waymaker HUD.
# Usage: keybindings-items.sh [all|tmux|shell|frecency|hypr]
set -u

FILTER="${1:-all}"

emit_tmux() {
  cat <<'EOF'
󰈞  Prefix + e	Workspace Files Picker (Golden Ratio)	tmux	tmux-workspace	~/.config/tmux/workspace-picker.sh
  Prefix + P	GitHub Pull Request Review Picker	tmux	tmux-pr	~/.config/tmux/pr-picker.sh
󰅍  Prefix + y	Scrollback Yank & Chrome URL Extractor	tmux	tmux-yank	~/.config/tmux/yank-picker.sh
󰍉  Prefix + /	Workspace Ripgrep Live Search	tmux	tmux-grep	~/.config/tmux/grep-picker.sh
󰓩  Prefix + t	Session Workspace / Task Picker	tmux	tmux-sesh	~/.config/tmux/session-picker.sh
󱂬  Prefix + s	Window & Session Tree Picker	tmux	tmux-window	~/.config/tmux/window-picker.sh
󱂬  Prefix + S	Window Picker (100% Fullscreen Modal)	tmux	tmux-window-fullscreen	~/.config/tmux/window-picker.sh --fullscreen
󰌌  Prefix + f	Vimium Window Hints (1-touch Jump)	tmux	tmux-hints	tmux switch-client -T window_hints
󰌌  Ctrl + `	Direct Jump to Window 0 (Zero-Prefix)	tmux	tmux-select-0	tmux select-window -t 0
󰌌  Ctrl + 1 .. 9	Direct Jump to Window 1 .. 9 (Zero-Prefix)	tmux	tmux-select-win	tmux select-window -t 1
󱂩  Ctrl + Shift + 0 .. 9	Move Window to Target Slot (Shift Reorder)	tmux	tmux-move-win	~/.config/tmux/move-window-to.sh 1
󰊢  Ctrl + Shift + G	AWT Autonomous Worktree Popup	tmux	tmux-awt	~/.config/tmux/awt-popup.sh
󰊢  Ctrl + G	Lazygitrs Floating Popup & Dual-Diff	tmux	tmux-lazygitrs	~/.config/tmux/lazygitrs-popup.sh
󰙀  Ctrl + Shift + T	Undo Close Tab (VSCode Reopen Stack)	tmux	tmux-reopen	~/.config/tmux/reopen-window.sh
󰒭  Ctrl + Shift + I	AI Attention Trampoline Direct Jump	tmux	tmux-triage	~/.config/tmux/ai-agent-bell-triage.sh
󰘳  Prefix + i	AI Agent Bell / Alert HUD	tmux	tmux-bell	~/.config/tmux/ai-agent-bell-popup.sh
󰒭  Prefix + I	AI Attention Trampoline Direct Jump	tmux	tmux-triage	~/.config/tmux/ai-agent-bell-triage.sh
󰄧  Prefix + o	AI Side-by-Side Split (35% Right)	tmux	tmux-ai-split	~/.config/tmux/toggle-ai-split.sh
󰏫  Prefix + N	Neovim Floating Scratchpad (90%x90%)	tmux	tmux-scratchpad	~/.config/tmux/nvim-scratchpad.sh
󰤄  Prefix + E	Full Scrollback Buffer in Neovim	tmux	tmux-view-scrollback	~/.config/tmux/scrollback-view.sh
󰙀  Prefix + T / u	Reopen Last Closed Window / Tab	tmux	tmux-reopen	~/.config/tmux/reopen-window.sh
󰅖  Prefix + w / x	Close Pane / Window (Save to Reopen)	tmux	tmux-close	~/.config/tmux/close-window.sh
󰹑  Prefix + m / z	Maximize / Zoom Active Pane	tmux	tmux-zoom	tmux resize-pane -Z
󱁐  Prefix + C-h/j/k/l	Resize Pane (Asymmetric 10%: 20c/5l)	tmux	tmux-resize	tmux resize-pane -L 20
󱂩  Prefix + |	Split Window Vertically	tmux	tmux-split-v	tmux split-window -h
󱂪  Prefix + -	Split Window Horizontally	tmux	tmux-split-h	tmux split-window -v
󰮯  Prefix + h / l	Previous / Next Window	tmux	tmux-prev-next	tmux next-window
󰮯  Prefix + Tab	Last Active Window (MRU Flip-Flop)	tmux	tmux-last-win	tmux last-window
󰮯  Prefix + L	Last Active Session (MRU Flip-Flop)	tmux	tmux-last-sess	tmux switch-client -l
󰑐  Prefix + r	Reload Tmux Configuration	tmux	tmux-reload	tmux source-file ~/.config/tmux/tmux.conf
󰅖  Prefix + W	Kill Entire Session	tmux	tmux-kill-sess	tmux kill-session
󰌌  Prefix + ?	Keybindings & Workflow Catalog HUD	tmux	tmux-help	~/.config/tmux/keybindings-picker.sh
󰌌  Prefix + :	Tmux Raw Keybindings (list-keys -N)	tmux	tmux-raw-keys	tmux list-keys -N
EOF
}

emit_shell() {
  cat <<'EOF'
󰈞  <Tab>	Smart Tab: Directory Jump or Buffer Insert	shell	shell-smart-tab	info
󰛨  <Tab>	Inline Ghost Text Autosuggest Accept	shell	shell-autosuggest	info
󱁐  <Tab>	Matchmaker Multi-Column Command Completion	shell	shell-ftb	info
󰌌  Ctrl + F	Matchmaker Directory/File Jump Widget	shell	shell-jump	info
󰊢  Ctrl + G	Lazygitrs Floating Popup & Dual-Diff	shell	shell-lazygitrs	~/.config/tmux/lazygitrs-popup.sh
󰘳  Ctrl + T	IntelliShell Fuzzy Command Catalog (29k+)	shell	shell-intelli	info
󰋚  Ctrl + R	Atuin Temporal & Contextual History Search	shell	shell-atuin	info
󰁔  Ctrl + J	History Prefix Search Forward (Mid-Query)	shell	shell-hist-fwd	info
󰁔  Ctrl + K	History Prefix Search Backward (Mid-Query)	shell	shell-hist-bwd	info
󰁨  Ctrl + Backspace	Delete Preceding Word in Insert Mode	shell	shell-kill-word	info
EOF
}

emit_frecency() {
  cat <<'EOF'
⚡  ptl	Paste Files to Last Target (220ms, 20.5x CLI)	frecency	frecency-ptl	info
󰆏  pt	Paste Files & Stay in Current Directory	frecency	frecency-pt	info
󰈞  ptg	Paste Files & Jump Immediately to Destination	frecency	frecency-ptg	info
⚡  mtl	Move Files to Last Target (Ultra-Low Latency)	frecency	frecency-mtl	info
󰪹  mt	Move Files & Stay in Current Directory	frecency	frecency-mt	info
󰒭  mtg	Move Files & Jump Immediately to Destination	frecency	frecency-mtg	info
󰌌  j / z	Direct Home/Frecency Jump (Single Left Index)	frecency	frecency-jump	info
󰍉  ji / zi	Interactive Matchmaker Tree Jump & Ancestor	frecency	frecency-jump-interactive	info
EOF
}

emit_hypr() {
  cat <<'EOF'
󰈹  SUPER + B	Launch Google Chrome Browser	hypr	hypr-browser	google-chrome-stable
󰅍  SUPER + SHIFT + B	New Google Chrome Window	hypr	hypr-browser-new	google-chrome-stable --new-window
󰆍  SUPER + Return	Open Alacritty Terminal	hypr	hypr-terminal	alacritty
󰘳  SUPER + Space	Open Walker Application Launcher	hypr	hypr-walker	walker
󰅖  SUPER + Q / C	Close Active Window	hypr	hypr-close	hyprctl dispatch killactive
󰹑  SUPER + F	Toggle Fullscreen	hypr	hypr-fullscreen	hyprctl dispatch fullscreen
󱁐  SUPER + M	Toggle Floating / Tiled Mode	hypr	hypr-float	hyprctl dispatch togglefloating
󰍉  SUPER + Shift + S	Capture Interactive Screenshot	hypr	hypr-screenshot	omarchy-screenshot
EOF
}

case "$FILTER" in
  tmux)
    emit_tmux
    ;;
  shell)
    emit_shell
    ;;
  frecency)
    emit_frecency
    ;;
  hypr)
    emit_hypr
    ;;
  all|*)
    emit_tmux
    emit_shell
    emit_frecency
    emit_hypr
    ;;
esac
