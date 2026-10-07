#!/usr/bin/env sh
# window-picker-delete.sh — helper script to delete selected windows in window-picker

RAW_INPUT=$(cat)

[ -z "$RAW_INPUT" ] && exit 0

first_line=$(printf '%s\n' "$RAW_INPUT" | head -n 1)

# 1. Check if selected row is a session header row (starts with #)
if printf '%s' "$first_line" | grep -qE '^#[[:space:]]*'; then
  sess_name=$(printf '%s' "$first_line" | sed -E 's/^#[[:space:]]*//')
  [ -z "$sess_name" ] && exit 0

  # Check if it's an AWT linked worktree
  wt_path=$(tmux display-message -t "${sess_name}:" -p '#{pane_current_path}' 2>/dev/null || echo "")
  is_linked_wt=0
  branch=""
  if [ -n "$wt_path" ] && [ -d "$wt_path" ]; then
    git_common=$(git -C "$wt_path" rev-parse --git-common-dir 2>/dev/null || echo "")
    git_dir=$(git -C "$wt_path" rev-parse --git-dir 2>/dev/null || echo "")
    if [ -n "$git_common" ] && [ -n "$git_dir" ] && [ "$git_common" != "$git_dir" ]; then
      is_linked_wt=1
      branch=$(git -C "$wt_path" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
    fi
  fi

  if [ "$is_linked_wt" -eq 1 ] && [ -n "$branch" ] && [ "$branch" != "main" ] && [ "$branch" != "master" ]; then
    awt_del="$HOME/.config/waymaker/scripts/awt-delete.sh"
    [ -x "$awt_del" ] || awt_del="$HOME/.dotfiles/main/awt/.config/waymaker/scripts/awt-delete.sh"
    if [ -x "$awt_del" ]; then
      if [ -n "$TMUX" ]; then
        tmux display-popup -b rounded -w 60 -h 12 -E "$awt_del '$sess_name' '$wt_path' '$branch' --confirm"
      else
        "$awt_del" "$sess_name" "$wt_path" "$branch" --confirm
      fi
      exit 0
    fi
  fi

  # Regular session kill with confirmation
  confirmed=0
  if command -v gum >/dev/null 2>&1; then
    if [ -n "$TMUX" ]; then
      tmux display-popup -b rounded -w 45 -h 10 -E "gum confirm 'Kill tmux session $sess_name?'" 2>/dev/null && confirmed=1
    else
      gum confirm "Kill tmux session $sess_name?" && confirmed=1
    fi
  else
    confirmed=1
  fi

  if [ "$confirmed" -eq 1 ]; then
    cur_sess=$(tmux display-message -p '#{session_name}' 2>/dev/null || echo "")
    if [ "$cur_sess" = "$sess_name" ]; then
      tmux switch-client -l 2>/dev/null || tmux switch-client -n 2>/dev/null || true
    fi
    tmux kill-session -t "$sess_name" 2>/dev/null || true
  fi
  exit 0
fi

count=0
window_list=""

IFS='
'
for line in $RAW_INPUT; do
  [ -z "$line" ] && continue
  session=$(printf '%s' "$line" | cut -f4)
  idx=$(printf '%s' "$line" | cut -f2)
  if [ -n "$session" ] && [ -n "$idx" ]; then
    count=$((count + 1))
    window_list="${window_list}${session}:${idx}
"
  fi
done
unset IFS

[ "$count" -eq 0 ] && exit 0

if [ "$count" -gt 1 ]; then
  confirmed=0
  if command -v gum >/dev/null 2>&1; then
    if [ -n "$TMUX" ]; then
      tmux display-popup -b rounded -w 40 -h 10 -E "gum confirm 'remove $count windows?'" 2>/dev/null && confirmed=1
    else
      gum confirm "remove $count windows?" && confirmed=1
    fi
  else
    confirmed=1
  fi
  [ "$confirmed" -eq 0 ] && exit 0
fi

IFS='
'
for target in $window_list; do
  if [ -n "$target" ]; then
    target_session="${target%%:*}"
    is_active=$(tmux display-message -p -t "$target" '#{window_active}' 2>/dev/null || echo 0)
    win_count=$(tmux list-windows -t "$target_session" 2>/dev/null | wc -l)
    if [ "$is_active" = "1" ] && [ "$win_count" -gt 1 ]; then
      tmux select-window -t "$target_session" -l 2>/dev/null \
        || tmux previous-window -t "$target_session" 2>/dev/null \
        || tmux next-window -t "$target_session" 2>/dev/null \
        || true
    fi
    "$HOME/.config/tmux/record-window-state.sh" --push "$target" 2>/dev/null || true
    tmux kill-window -t "$target" 2>/dev/null || true
  fi
done
unset IFS

exit 0
