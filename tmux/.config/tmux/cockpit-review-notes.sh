#!/usr/bin/env bash
# cockpit-review-notes.sh — Bridge between Lazygitrs review comments (.lines.json) and AI agents in Cockpit HUD
set -euo pipefail

cmd="${1:-}"
ppath="${2:-}"

# Resolve lines.json location
resolve_notes_file() {
  local dir="$1"
  local git_dir
  if git_dir=$(git -C "$dir" rev-parse --git-dir 2>/dev/null); then
    [[ "$git_dir" != /* ]] && git_dir="$dir/$git_dir"
    if [[ -f "$git_dir/info/lines.json" ]]; then
      echo "$git_dir/info/lines.json"
      return 0
    elif [[ -f "$git_dir/lines.json" ]]; then
      echo "$git_dir/lines.json"
      return 0
    fi
  fi
  if [[ -f "$dir/.lines.json" ]]; then
    echo "$dir/.lines.json"
    return 0
  fi
  return 1
}

case "$cmd" in
  count)
    notes_file=$(resolve_notes_file "$ppath" || true)
    if [[ -z "$notes_file" || ! -f "$notes_file" ]]; then
      echo "0"
      exit 0
    fi
    count=$(python3 -c "
import json, sys
try:
    data = json.load(open('$notes_file'))
    notes = data.get('notes', [])
    pending = [n for n in notes if n.get('status', 'New') == 'New']
    print(len(pending))
except Exception:
    print(0)
" 2>/dev/null || echo "0")
    echo "$count"
    ;;

  list)
    notes_file=$(resolve_notes_file "$ppath" || true)
    if [[ -z "$notes_file" || ! -f "$notes_file" ]]; then
      exit 0
    fi
    python3 -c "
import json, sys
try:
    data = json.load(open('$notes_file'))
    notes = data.get('notes', [])
    pending = [n for n in notes if n.get('status', 'New') == 'New']
    if not pending:
        sys.exit(0)
    print(f'\033[1;33m  󰆈 Pending AI Review Notes ({len(pending)}):\033[0m')
    for n in pending[:5]:
        f = n.get('file', 'unknown')
        l = n.get('line', 0)
        c = n.get('comment', '').replace('\n', ' ')
        if len(c) > 60:
            c = c[:57] + '...'
        print(f'    \033[1;36m• {f}:{l}\033[0m \033[2m›\033[0m \"{c}\"')
    if len(pending) > 5:
        print(f'    \033[2m... and {len(pending) - 5} more notes\033[0m')
    print('    \033[2m(Press \033[1;36mr\033[0;2m to dispatch all review notes to agent)\033[0m\n')
except Exception:
    pass
" 2>/dev/null || true
    ;;

  send)
    session="${3:-}"
    idx="${4:-}"
    pane_id="${5:-}"
    
    notes_file=$(resolve_notes_file "$ppath" || true)
    if [[ -z "$notes_file" || ! -f "$notes_file" ]]; then
      tmux display-message "No review notes found for $ppath"
      exit 0
    fi

    prompt_file=$(mktemp)
    count=$(python3 -c "
import json, sys

try:
    with open('$notes_file', 'r') as f:
        data = json.load(f)
    notes = data.get('notes', [])
    pending = [n for n in notes if n.get('status', 'New') == 'New']
    if not pending:
        print('0')
        sys.exit(0)

    lines = ['Please review and address the following ' + str(len(pending)) + ' code review comments from lazygitrs:\n']
    for i, n in enumerate(pending):
        f = n.get('file', 'unknown')
        l = n.get('line', 0)
        c = n.get('comment', '')
        lines.append(f'{i+1}. **\`{f}\`** (line {l}):\n   > {c}\n')
    lines.append('Once addressed, run the relevant tests and summarize your changes.')

    with open('$prompt_file', 'w') as pf:
        pf.write('\n'.join(lines))

    for n in notes:
        if n.get('status', 'New') == 'New':
            n['status'] = 'Sent'

    with open('$notes_file', 'w') as f:
        json.dump(data, f, indent=2)

    print(len(pending))
except Exception as e:
    print('0')
" 2>/dev/null || echo "0")

    if [[ "$count" -eq 0 || ! -s "$prompt_file" ]]; then
      rm -f "$prompt_file"
      tmux display-message "No pending review notes to send"
      exit 0
    fi

    # Find target pane
    target_pane="$pane_id"
    if [[ ! "$target_pane" =~ ^%[0-9]+$ ]]; then
      if [[ -n "$session" && -n "$idx" && "$idx" != "-" ]]; then
        target_pane=$(tmux display-message -p -t "${session}:${idx}" '#{pane_id}' 2>/dev/null || echo "")
      fi
    fi

    if [[ -z "$target_pane" || ! "$target_pane" =~ ^%[0-9]+$ ]]; then
      rm -f "$prompt_file"
      tmux display-message "Target agent pane not found"
      exit 1
    fi

    # Inject into tmux buffer and paste atomically with bracketed paste
    tmux load-buffer -b "cockpit_review_prompt" "$prompt_file" 2>/dev/null || true
    rm -f "$prompt_file"
    if tmux paste-buffer -b "cockpit_review_prompt" -t "$target_pane" -p 2>/dev/null; then
      tmux send-keys -t "$target_pane" Enter
    else
      flat_prompt=$(tr '\n' ' ' < "$prompt_file" 2>/dev/null || echo "")
      tmux send-keys -l -t "$target_pane" -- "$flat_prompt"
      tmux send-keys -t "$target_pane" Enter
    fi

    tmux display-message "Dispatched $count review note(s) to agent in pane $target_pane"
    ;;

  *)
    echo "Usage: $0 {count|list|send} <path> [session] [idx] [pane_id]" >&2
    exit 1
    ;;
esac
