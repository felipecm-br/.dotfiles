#!/usr/bin/env bash

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
_tmux_style="$HOME/.local/state/omarchy/current/theme/tmux-style.sh"
[ -f "$_tmux_style" ] || _tmux_style="$SCRIPT_DIR/tmux-style.sh"
# shellcheck source=/dev/null
. "$_tmux_style"
unset _tmux_style

# Collect all panes that require attention or have AI agent activity
notifying_panes=()

# 0. Primary: Query acpd daemon RPC (http://127.0.0.1:4040/rpc) for real-time agent states
acpd_token=""
for token_path in "/run/user/$UID/acpd/token" "/run/user/$(id -u 2>/dev/null)/acpd/token" "/run/user/1001/acpd/token"; do
  if [ -f "$token_path" ]; then
    acpd_token=$(cat "$token_path" 2>/dev/null || true)
    [ -n "$acpd_token" ] && break
  fi
done

if [ -n "$acpd_token" ] && command -v curl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
  acpd_res=$(curl -s -m 0.25 -X POST http://127.0.0.1:4040/rpc \
    -H "Authorization: Bearer $acpd_token" \
    -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","method":"agentState/list","id":1}' 2>/dev/null || true)

  if [ -n "$acpd_res" ]; then
    # Urgent: permission, awaiting_input, question, error, stalled
    while IFS= read -r p; do
      if [[ -n "$p" && "$p" =~ ^%[0-9]+$ ]] && tmux display-message -t "$p" -p '#{pane_id}' >/dev/null 2>&1; then
        notifying_panes+=("$p")
      fi
    done < <(echo "$acpd_res" | jq -r '
      .result // {} | to_entries |
      map(select(.value.state as $s | ["permission", "awaiting_input", "question", "error", "stalled"] | index($s))) |
      sort_by(-.value.last_timestamp) |
      .[].key
    ' 2>/dev/null || true)

    # Active: working, busy (if no urgent panes found)
    if [ "${#notifying_panes[@]}" -eq 0 ]; then
      while IFS= read -r p; do
        if [[ -n "$p" && "$p" =~ ^%[0-9]+$ ]] && tmux display-message -t "$p" -p '#{pane_id}' >/dev/null 2>&1; then
          notifying_panes+=("$p")
        fi
      done < <(echo "$acpd_res" | jq -r '
        .result // {} | to_entries |
        map(select(.value.state as $s | ["working", "busy"] | index($s))) |
        sort_by(-.value.last_timestamp) |
        .[].key
      ' 2>/dev/null || true)
    fi
  fi
fi

# 1. Native Tmux: search for panes in active attention/question/permission/error/stalled state
if [ "${#notifying_panes[@]}" -eq 0 ]; then
  while IFS= read -r line; do
    [ -n "$line" ] && notifying_panes+=("$line")
  done < <(tmux list-panes -a -F '#{pane_id} #{@ai_agent_state_raw}' 2>/dev/null | awk '$2 ~ /^(question|permission|error|awaiting_input|stalled)$/ {print $1}')
fi

# 2. Fallback to @ai_agent_last_bell if no state-filtered panes found
if [ "${#notifying_panes[@]}" -eq 0 ]; then
  last_bell=$(tmux show-option -gv @ai_agent_last_bell 2>/dev/null)
  if [ -n "$last_bell" ] && tmux display-message -t "$last_bell" -p '#{pane_id}' >/dev/null 2>&1; then
    notifying_panes+=("$last_bell")
  fi
fi

# 3. Fallback: Check for panes currently in active working/busy state
if [ "${#notifying_panes[@]}" -eq 0 ]; then
  while IFS= read -r line; do
    [ -n "$line" ] && notifying_panes+=("$line")
  done < <(tmux list-panes -a -F '#{pane_id} #{@ai_agent_state_raw}' 2>/dev/null | awk '$2 ~ /^(working|busy)$/ {print $1}')
fi

# 4. Fallback: Check for any pane with a registered AI agent state (including idle / recently responded)
if [ "${#notifying_panes[@]}" -eq 0 ]; then
  while IFS= read -r line; do
    [ -n "$line" ] && notifying_panes+=("$line")
  done < <(tmux list-panes -a -F '#{pane_id} #{@ai_agent_state_raw}' 2>/dev/null | awk '$2 ~ /^(idle|working|busy|question|permission|error|awaiting_input|stalled)$/ {print $1}')
fi

# 5. Fallback: Search for any pane running agy, antigravity, or opencode (command or title)
if [ "${#notifying_panes[@]}" -eq 0 ]; then
  while IFS= read -r line; do
    [ -n "$line" ] && notifying_panes+=("$line")
  done < <(tmux list-panes -a -F '#{pane_id} #{pane_current_command} #{pane_title}' 2>/dev/null | awk '$2 ~ /^(agy|antigravity|opencode)$/ || $3 ~ /^(agy|antigravity|opencode)$/ {print $1}')
fi

if [ "${#notifying_panes[@]}" -eq 0 ]; then
  tmux display-message -d 1500 " 󰮯 No active AI Agent notification."
  exit 0
fi

# Ring Buffer Rotation: read and increment index in tmux global env
total=${#notifying_panes[@]}
curr_idx=$(tmux show-option -gv @ai_agent_bell_ring_idx 2>/dev/null || echo 0)
if ! [[ "$curr_idx" =~ ^[0-9]+$ ]] || [ "$curr_idx" -ge "$total" ]; then
  curr_idx=0
fi

pane="${notifying_panes[$curr_idx]}"

# Calculate next index for the next keypress
next_idx=$(( (curr_idx + 1) % total ))
tmux set-option -g @ai_agent_bell_ring_idx "$next_idx" 2>/dev/null

sess=$(tmux display-message -t "$pane" -p '#S' 2>/dev/null)
win_idx=$(tmux display-message -t "$pane" -p '#I' 2>/dev/null)
win_name=$(tmux display-message -t "$pane" -p '#W' 2>/dev/null)

TITLE=" $sess › $win_name ($((curr_idx + 1))/$total)  │  prefix+i cycle "

# If target pane is in the exact same window (a split pane beside you in the current view),
# simply move focus without opening an unnecessary popup overlay.
current_pane=$(tmux display-message -p '#{pane_id}' 2>/dev/null || echo "")
current_sess=$(tmux display-message -p '#S' 2>/dev/null || echo "")
current_win=$(tmux display-message -p '#I' 2>/dev/null || echo "")

# If already focused on this exact target pane:
if [ "$current_pane" = "$pane" ]; then
  if [ "$total" -gt 1 ]; then
    # Cycle directly to the next alerting candidate in ring buffer
    curr_idx=$next_idx
    pane="${notifying_panes[$curr_idx]}"
    next_idx=$(( (curr_idx + 1) % total ))
    tmux set-option -g @ai_agent_bell_ring_idx "$next_idx" 2>/dev/null
    sess=$(tmux display-message -t "$pane" -p '#S' 2>/dev/null)
    win_idx=$(tmux display-message -t "$pane" -p '#I' 2>/dev/null)
    win_name=$(tmux display-message -t "$pane" -p '#W' 2>/dev/null)
  else
    tmux display-message -d 1500 " 󰮯 Already focused on active agent ($sess › $win_name)"
    exit 0
  fi
fi

if [ "$current_sess" = "$sess" ] && [ "$current_win" = "$win_idx" ]; then
  tmux select-pane -t "$pane" 2>/dev/null || true
  tmux display-message -d 1500 " 󰮯 AI Agent: focused split pane ($sess › $win_name)"
  exit 0
fi


POPUP_SESS="_popups"
if ! tmux has-session -t "$POPUP_SESS" 2>/dev/null; then
  tmux new-session -d -s "$POPUP_SESS" -n "_dummy"
fi

# Clean any existing linked window in _popups except the initial _dummy window (index 0)
for w in $(tmux list-windows -t "$POPUP_SESS" -F '#{window_id}:#{window_index}' 2>/dev/null); do
  w_id="${w%%:*}"
  w_idx="${w##*:}"
  if [ "$w_idx" != "0" ]; then
    tmux unlink-window -t "$w_id" 2>/dev/null || tmux kill-window -t "$w_id" 2>/dev/null || true
  fi
done

# Link target window to index 1 of _popups
tmux link-window -s "$sess:$win_idx" -t "$POPUP_SESS:1" 2>/dev/null || tmux link-window -a -s "$sess:$win_idx" -t "$POPUP_SESS:0" 2>/dev/null || true
tmux select-window -t "$POPUP_SESS:1" 2>/dev/null || true
tmux select-pane -t "$pane" 2>/dev/null || true
tmux set-option -t "$POPUP_SESS" status off 2>/dev/null || true
tmux set-option -t "$POPUP_SESS" key-table popup 2>/dev/null || true

ALERT_POPUP_COLOR=$(grep -E '^\s*yellow\s*=' "$HOME/.local/state/omarchy/current/theme/colors.toml" 2>/dev/null | sed -E 's/.*=\s*"([^"]+)".*/\1/')
[ -z "$ALERT_POPUP_COLOR" ] && ALERT_POPUP_COLOR="${TMUX_POPUP_ALERT_BORDER_COLOR:-#f9e2af}"

ISOLATOR="$HOME/.config/tmux/tmux-popup-isolate.sh"
[ -x "$ISOLATOR" ] || ISOLATOR="$(command -v tmux-popup-isolate.sh 2>/dev/null || echo "$ISOLATOR")"

exec "$ISOLATOR" \
  -S "fg=$ALERT_POPUP_COLOR" \
  -s "fg=${TMUX_POPUP_TEXT_COLOR:-default}" \
  -T " 󰮯 " \
  -w "80%" \
  -h "75%" \
  -b rounded \
  -E \
  -- "tmux attach-session -t \"$POPUP_SESS:1\"; tmux unlink-window -t \"$POPUP_SESS:1\" >/dev/null 2>&1 || true"
