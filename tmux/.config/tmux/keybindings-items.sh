#!/usr/bin/env sh
# keybindings-items.sh — emit structured keybindings for Waymaker HUD.
# Usage: keybindings-items.sh [all|tmux|shell|frecency|hypr|cmd] [palette]
#   Default rows are `key<TAB>name<TAB>layer<TAB>id<TAB>action` (Keybindings HUD, Prefix + ?).
#   Command Palette mode (2nd arg `palette` or WM_KB_PALETTE=1, Ctrl + Shift + P) emits
#   `name<TAB>key<TAB>layer<TAB>id<TAB>action` (VS Code order: label first, shortcut on the right)
#   and adds the shortcut-less `cmd` layer to `all`. Palette rows are ordered most-recently-run first.
set -u

FILTER="${1:-all}"
PALETTE="${2:-}"
if [ -z "$PALETTE" ] && [ "${WM_KB_PALETTE:-0}" = "1" ]; then PALETTE=palette; fi

emit_tmux() {
  cat <<'EOF'
󰈞  Prefix + e	Workspace Files Picker (Golden Ratio)	tmux	tmux-workspace	~/.config/tmux/workspace-picker.sh
  Prefix + P	GitHub Pull Request Review Picker	tmux	tmux-pr	~/.config/tmux/pr-picker.sh
󰅍  Prefix + y	Scrollback Picker (Tokens, Links & Yank)	tmux	tmux-scrollback	~/.config/tmux/scrollback-picker.sh
󰍉  Prefix + /	Workspace Ripgrep Live Search	tmux	tmux-grep	~/.config/tmux/grep-picker.sh
󰓩  Prefix + s	Session Workspace / Task Picker	tmux	tmux-sesh	~/.config/tmux/session-picker.sh
󱂬  Prefix + Space	AI Fleet Cockpit & Window Manager	tmux	tmux-cockpit	~/.config/tmux/cockpit-picker.sh
󰌌  Prefix + f	Vimium Window Hints (1-touch Jump)	tmux	tmux-hints	tmux switch-client -T window_hints
󰌌  Ctrl + `	Direct Jump to Window 0 (Zero-Prefix)	tmux	tmux-select-0	tmux select-window -t 0
󰌌  Ctrl + 1 .. 9	Direct Jump to Window 1 .. 9 (Zero-Prefix)	tmux	tmux-select-win	tmux select-window -t 1
󱂩  Ctrl + Shift + 0 .. 9	Move Window to Target Slot (Shift Reorder)	tmux	tmux-move-win	~/.config/tmux/move-window-to.sh 1
󰊢  Ctrl + Shift + G	AWT Autonomous Worktree Popup	tmux	tmux-awt	~/.config/tmux/awt-popup.sh
󰚩  Prefix + a / Ctrl + Shift + A	AI Agent Launcher (CLI × Model + Quota)	tmux	tmux-ai-launch	~/.config/tmux/ai-launch-popup.sh
󰑓  Prefix + A	AI Model / Effort Hot-Swap (In-Place)	tmux	tmux-ai-switch	~/.config/tmux/ai-switch-popup.sh
󰏫  Prefix + v	AI Prompt Draft in Nvim Popup	tmux	tmux-ai-prompt	~/.local/bin/ai-prompt edit
󰆓  Prefix + V	AI Prompt Draft Stash / Restore (for /commands)	tmux	tmux-ai-prompt-stash	~/.local/bin/ai-prompt stash
󰓅  Prefix + u	AI Quota & Burn Telemetry Visual Popup	tmux	tmux-ai-quota	~/.config/tmux/ai-quota-popup.sh
󰊢  Ctrl + G	Lazygitrs Floating Popup & Dual-Diff	tmux	tmux-lazygitrs	~/.config/tmux/lazygitrs-popup.sh
󰙀  Ctrl + Shift + T	Undo Close Tab (Exact Index & AI Resume)	tmux	tmux-reopen	~/.config/tmux/reopen-window.sh
󰒭  Ctrl + Shift + I	AI Attention Trampoline Direct Jump	tmux	tmux-triage	~/.config/tmux/ai-agent-bell-triage.sh
󰘳  Prefix + i	AI Agent Bell / Alert HUD	tmux	tmux-bell	~/.config/tmux/ai-agent-bell-popup.sh
󰒭  Prefix + I	AI Attention Trampoline Direct Jump	tmux	tmux-triage	~/.config/tmux/ai-agent-bell-triage.sh
󰄧  Prefix + o	AI Side-by-Side Split (35% Right)	tmux	tmux-ai-split	~/.config/tmux/toggle-ai-split.sh
󰏫  Prefix + N	Neovim Floating Scratchpad (90%x90%)	tmux	tmux-scratchpad	~/.config/tmux/nvim-scratchpad.sh
󰄧  Prefix + E	Scrollback & AI Mermaid Modal (90%x88%)	tmux	tmux-view-scrollback	~/.config/tmux/scrollback-view.sh
󰏌  Prefix + t	Create New Window in Current Path	tmux	tmux-new-win	tmux new-window -c '#{pane_current_path}'
󰙀  Prefix + T	Reopen Last Closed Tab (Exact Index & AI Resume)	tmux	tmux-reopen	~/.config/tmux/reopen-window.sh
󰅖  Prefix + w / x	Close Window / Pane (AI Guarded)	tmux	tmux-close	~/.config/tmux/close-window.sh
󰹑  Prefix + m / z	Maximize / Zoom Active Pane	tmux	tmux-zoom	tmux resize-pane -Z
󱁐  Prefix + C-h/j/k/l	Resize Pane (Asymmetric 10%: 20c/5l)	tmux	tmux-resize	tmux resize-pane -L 20
󱂩  Prefix + |	Split Window Vertically	tmux	tmux-split-v	tmux split-window -h
󱂪  Prefix + -	Split Window Horizontally	tmux	tmux-split-h	tmux split-window -v
󰮯  Prefix + h / l	Previous / Next Window	tmux	tmux-prev-next	tmux next-window
󰮯  Prefix + Tab	Last Active Window (MRU Flip-Flop)	tmux	tmux-last-win	tmux last-window
󰮯  Prefix + L	Last Active Session (MRU Flip-Flop)	tmux	tmux-last-sess	tmux switch-client -l
󰑐  Prefix + r	Reload Tmux Configuration	tmux	tmux-reload	tmux source-file ~/.config/tmux/tmux.conf
󰅖  Prefix + W	Smart Kill Session (Guarded)	tmux	tmux-kill-sess	~/.config/tmux/close-session.sh
󰸌  Prefix + B	Toggle Gradient Popup Frames	tmux	tmux-border-gradient	~/.local/bin/border-gradient toggle >/dev/null
󰌌  Prefix + ?	Keybindings & Workflow Catalog HUD	tmux	tmux-help	~/.config/tmux/keybindings-picker.sh
󰘳  Prefix + p / Ctrl + Shift + P	Command Palette (VS Code-style, every command)	tmux	tmux-palette	~/.config/tmux/command-palette.sh
󰌌  Prefix + :	Tmux Raw Keybindings (list-keys -N)	tmux	tmux-raw-keys	tmux list-keys -N
EOF
}

emit_shell() {
  cat <<'EOF'
󰈞  <Tab>	Smart Tab: Directory Jump or Buffer Insert	shell	shell-smart-tab	info
󰛨  <Tab>	Inline Ghost Text Autosuggest Accept	shell	shell-autosuggest	info
󱁐  <Tab>	Waymaker Multi-Column Command Completion	shell	shell-ftb	info
󰌌  Ctrl + F	Waymaker Directory/File Jump Widget	shell	shell-jump	info
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
󰍉  ji / zi	Interactive Waymaker Tree Jump & Ancestor	frecency	frecency-jump-interactive	info
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

emit_cmd() {
  # Palette-only commands: no shortcut (empty key column); actions run through `tmux run-shell`.
  cat <<'EOF'
󰐕  	New Session (prompt for name)	cmd	cmd-new-session	tmux command-prompt -p 'New session:' 'new-session -d -s "%%" ; switch-client -t "%%"'
󰑕  	Rename Window	cmd	cmd-rename-window	tmux command-prompt -I '#W' -p 'Rename window:' 'rename-window -- "%%"'
󰑕  	Rename Session	cmd	cmd-rename-session	tmux command-prompt -I '#S' -p 'Rename session:' 'rename-session -- "%%"'
󰙅  	Choose Tree (Sessions & Windows)	cmd	cmd-choose-tree	tmux choose-tree -Zw
󰓦  	Toggle Synchronize Panes	cmd	cmd-sync-panes	tmux set-window-option synchronize-panes
󰍽  	Toggle Mouse Support	cmd	cmd-mouse	tmux set-option -g mouse
󰕮  	Layout: Tiled	cmd	cmd-layout-tiled	tmux select-layout tiled
󰕮  	Layout: Even Horizontal	cmd	cmd-layout-even-h	tmux select-layout even-horizontal
󰕮  	Layout: Even Vertical	cmd	cmd-layout-even-v	tmux select-layout even-vertical
󰕮  	Layout: Main Vertical	cmd	cmd-layout-main-v	tmux select-layout main-vertical
󰑞  	Rotate Panes	cmd	cmd-rotate	tmux rotate-window
󰁌  	Break Pane into New Window	cmd	cmd-break-pane	tmux break-pane
󰅖  	Kill Other Panes	cmd	cmd-kill-other-panes	tmux kill-pane -a
󰃢  	Clear Pane History	cmd	cmd-clear-history	tmux clear-history
󰆏  	Enter Copy Mode	cmd	cmd-copy-mode	tmux copy-mode
󰘳  	Tmux Command Prompt	cmd	cmd-command-prompt	tmux command-prompt
󰁔  	Move Window to Session (prompt)	cmd	cmd-move-window-session	tmux command-prompt -p 'Move window to session:' 'move-window -t "%%:"'
󰁔  	Move Window to Index (prompt)	cmd	cmd-move-window-index	tmux command-prompt -p 'Move window to index:' 'move-window -t "%%"'
󰁌  	Join Pane from Window (prompt)	cmd	cmd-join-pane	tmux command-prompt -p 'Join pane from (window.pane):' 'join-pane -s "%%"'
󰑐  	Respawn Pane (kill and restart)	cmd	cmd-respawn-pane	tmux respawn-pane -k
󰕮  	Next Layout	cmd	cmd-next-layout	tmux next-layout
󰍉  	Display Pane Numbers	cmd	cmd-display-panes	tmux display-panes
󰖲  	Toggle Status Bar	cmd	cmd-status	tmux set-option -g status
󰥔  	Show Clock	cmd	cmd-clock	tmux clock-mode
󰑓  	Refresh Client	cmd	cmd-refresh	tmux refresh-client
󰍃  	Detach Client	cmd	cmd-detach	tmux detach-client
EOF
}

emit_filter() {
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
  cmd)
    emit_cmd
    ;;
  all|*)
    emit_tmux
    emit_shell
    emit_frecency
    emit_hypr
    if [ -n "$PALETTE" ]; then emit_cmd; fi
    ;;
esac
}

# Palette order: split the leading Nerd Font badge off the key column and prepend it to the name,
# so rows read `<badge> Name<TAB>Shortcut` like VS Code.
palette_rows() {
  awk -F'\t' 'BEGIN { OFS = "\t" }
    {
      key = $1; icon = ""
      if (match(key, /^[^ ]+ +/)) { icon = substr(key, 1, RLENGTH); key = substr(key, RLENGTH + 1); sub(/ +$/, "", icon) }
      sub(/ +$/, "", key)
      $1 = (icon == "" ? $2 : icon "  " $2); $2 = key
      print
    }'
}

# Most-recently-run first (VS Code style). keybindings-run.sh appends the id of every command run
# from the palette to RECENT_FILE (oldest first); unseen rows keep catalog order (stable sort).
RECENT_FILE="${PALETTE_RECENT_FILE:-${XDG_STATE_HOME:-$HOME/.local/state}/tmux-command-palette/recent}"
mru_rows() {
  if [ ! -s "$RECENT_FILE" ]; then cat; return; fi
  awk -F'\t' 'NR == FNR { rank[$0] = FNR; next } { print (($4 in rank) ? rank[$4] : 0) "\t" $0 }' "$RECENT_FILE" - \
    | sort -s -t "$(printf '\t')" -k1,1nr | cut -f2-
}

if [ -n "$PALETTE" ]; then
  emit_filter | palette_rows | mru_rows
else
  emit_filter
fi
