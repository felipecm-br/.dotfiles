#!/usr/bin/env bash
# cockpit-picker-help.sh — Clean borderless keybindings cheat-sheet for Cockpit HUD preview pane.
set -euo pipefail

if [[ -x "$HOME/.local/bin/waymux" ]]; then
  exec "$HOME/.local/bin/waymux" cockpit-help "$@"
elif command -v waymux >/dev/null 2>&1; then
  exec waymux cockpit-help "$@"
fi

_colors_toml="$HOME/.local/state/omarchy/current/theme/colors.toml"
_color_yellow=$(grep '^yellow' "$_colors_toml" 2>/dev/null | sed 's/.*= *"\(.*\)"/\1/' || echo "#dbbc7f")
_color_red=$(grep '^red ' "$_colors_toml" 2>/dev/null | sed 's/.*= *"\(.*\)"/\1/' || echo "#e67e80")
_color_magenta=$(grep '^magenta' "$_colors_toml" 2>/dev/null | sed 's/.*= *"\(.*\)"/\1/' || echo "#d699b6")
_color_cyan=$(grep '^cyan' "$_colors_toml" 2>/dev/null | sed 's/.*= *"\(.*\)"/\1/' || echo "#83c092")
_color_blue=$(grep '^blue' "$_colors_toml" 2>/dev/null | sed 's/.*= *"\(.*\)"/\1/' || echo "#7fbbb3")

_hex_esc() {
  local h="${1#\#}"
  if [[ ! "$h" =~ ^[0-9a-fA-F]{6}$ ]]; then
    h="89b4fa"
  fi
  local r=$(( 16#${h:0:2} ))
  local g=$(( 16#${h:2:2} ))
  local b=$(( 16#${h:4:2} ))
  printf '\033[38;2;%d;%d;%dm' "$r" "$g" "$b"
}

C_CYAN=$(_hex_esc "${_color_cyan:-#83c092}")
C_YELLOW=$(_hex_esc "${_color_yellow:-#dbbc7f}")
C_RED=$(_hex_esc "${_color_red:-#e67e80}")
C_MAGENTA=$(_hex_esc "${_color_magenta:-#d699b6}")
C_BLUE=$(_hex_esc "${_color_blue:-#7fbbb3}")
C_RESET='\033[0m'
C_BOLD='\033[1m'
C_DIM='\033[2m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/flow-telemetry.py" ]; then
  python3 "$SCRIPT_DIR/flow-telemetry.py" --hud
fi

printf '  %b󱂬 Cockpit HUD — Keybindings & Shortcuts%b\n\n' "$C_CYAN$C_BOLD" "$C_RESET"

printf '  %b󰊢 Worktree Lifecycle%b\n' "$C_YELLOW$C_BOLD" "$C_RESET"
printf '    %b[w / c]%b  New Worktree      Launch 5-step AWT wizard\n' "$C_YELLOW$C_BOLD" "$C_RESET"
printf '    %b[S]%b      Ship Worktree     Merge, push & clean worktree\n' "$C_CYAN$C_BOLD" "$C_RESET"
printf '    %b[W]%b      Sweep Worktrees   Batch-prune merged worktrees\n\n' "$C_YELLOW$C_BOLD" "$C_RESET"

printf '  %b󱚥 AI Fleet & Agent Triage%b\n' "$C_MAGENTA$C_BOLD" "$C_RESET"
printf '    %b[y / n]%b  Approve / Deny    Guarded prompt reply (permission/question only)\n' "$C_YELLOW$C_BOLD" "$C_RESET"
printf '    %b[r]%b      Review Notes      Dispatch Lazygitrs review notes to agent\n' "$C_CYAN$C_BOLD" "$C_RESET"
printf '    %b[i]%b      Live Passthrough  Stream keystrokes to agent ([Esc] exit)\n' "$C_CYAN$C_BOLD" "$C_RESET"
printf '    %b[I]%b      Prompt Agent      Send sanitized inline prompt to agent\n' "$C_MAGENTA$C_BOLD" "$C_RESET"
printf '    %b[a]%b      Toggle Fleet      Fleet View (all windows) ↔ Agent Triage\n' "$C_YELLOW$C_BOLD" "$C_RESET"
printf '    %b[Bksp]%b   Last Agent        Jump back to previously focused agent\n' "$C_CYAN$C_BOLD" "$C_RESET"
printf '    %b[R]%b      Reap Agents       Garbage-collect stale agents\n\n' "$C_RED$C_BOLD" "$C_RESET"

printf '  %b󰓩 Git & Pull Requests%b\n' "$C_BLUE$C_BOLD" "$C_RESET"
printf '    %b[o]%b      Open PR           Open GitHub pull request in browser\n' "$C_BLUE$C_BOLD" "$C_RESET"
printf '    %b[O]%b      Open PR Checks    Open PR CI status checks in browser\n' "$C_BLUE$C_BOLD" "$C_RESET"
printf '    %b[g]%b      Git Cockpit       Toggle Lazygitrs (Dual-Diff, Esc returns)\n' "$C_MAGENTA$C_BOLD" "$C_RESET"
printf '    %b[p]%b      Patch Mode        Turbo Hunk Staging in Lazygitrs\n\n' "$C_MAGENTA$C_BOLD" "$C_RESET"

printf '  %b󰌌 Navigation & Windows%b\n' "$C_CYAN$C_BOLD" "$C_RESET"
printf '    %b[Enter]%b  Jump / Connect    Focus selected window/session\n' "$C_CYAN$C_BOLD" "$C_RESET"
printf '    %b[Tab]%b    AWT Worktrees     Switch to AWT Worktree popup\n' "$C_YELLOW$C_BOLD" "$C_RESET"
printf '    %b[s]%b      Sessions          Open Session Picker (Sesh)\n' "$C_YELLOW$C_BOLD" "$C_RESET"
printf '    %b[t]%b      New Window        Create window in current path\n' "$C_CYAN$C_BOLD" "$C_RESET"
printf '    %b[d / C-d]%b Kill / Delete     Kill window or delete session\n' "$C_RED$C_BOLD" "$C_RESET"
printf '    %b[J / K]%b  Scroll Preview    Scroll preview pane up/down\n' "$C_BLUE$C_BOLD" "$C_RESET"
printf '    %b[+ / -]%b  Resize Preview    Expand/shrink preview split\n' "$C_BLUE$C_BOLD" "$C_RESET"
printf '    %b[/]%b      Filter            Enter fuzzy query filter mode\n' "$C_BLUE$C_BOLD" "$C_RESET"
printf '    %b[Esc]%b    Exit              Dismiss Cockpit modal\n\n' "$C_BLUE$C_BOLD" "$C_RESET"

printf '  %b────────────────────────────────────────────────────────────%b\n' "$C_DIM" "$C_RESET"
printf '  %b?%b %bHUD help%b   %b│%b   %bg%b %bGit%b   %b│%b   %bp%b %bPatch%b\n' "$C_CYAN$C_BOLD" "$C_RESET" "$C_DIM" "$C_RESET" "$C_DIM" "$C_RESET" "$C_CYAN$C_BOLD" "$C_RESET" "$C_DIM" "$C_RESET" "$C_DIM" "$C_RESET" "$C_CYAN$C_BOLD" "$C_RESET" "$C_DIM" "$C_RESET"
