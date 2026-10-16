#!/usr/bin/env bash
# record-window-state.sh — tracks active & closed Tmux window states for instant tab reopening
set -euo pipefail

STATE_DIR="$HOME/.local/state/tmux"
mkdir -p "$STATE_DIR"
STACK_FILE="$STATE_DIR/closed-windows.json"
ACTIVE_FILE="$STATE_DIR/last-active-window.json"

inspect_pane() {
  local target="${1:-}"
  local pane_pid pane_path pane_session pane_win_name win_layout pane_win_idx
  local agent_title agent_raw_state pane_cmd

  if [ -n "$target" ]; then
    pane_pid=$(tmux display-message -p -t "$target" '#{pane_pid}' 2>/dev/null || true)
    pane_path=$(tmux display-message -p -t "$target" '#{pane_current_path}' 2>/dev/null || true)
    pane_session=$(tmux display-message -p -t "$target" '#{session_name}' 2>/dev/null || true)
    pane_win_name=$(tmux display-message -p -t "$target" '#{window_name}' 2>/dev/null || true)
    pane_win_idx=$(tmux display-message -p -t "$target" '#{window_index}' 2>/dev/null || true)
    win_layout=$(tmux display-message -p -t "$target" '#{window_layout}' 2>/dev/null || true)
    pane_cmd=$(tmux display-message -p -t "$target" '#{pane_current_command}' 2>/dev/null || true)
    agent_title=$(tmux display-message -p -t "$target" '#{?@ai_agent_title,#{@ai_agent_title},#{@w:@ai_agent_title}}' 2>/dev/null || true)
    agent_raw_state=$(tmux display-message -p -t "$target" '#{?@ai_agent_state_raw,#{@ai_agent_state_raw},#{@w:@ai_agent_state_raw}}' 2>/dev/null || true)
  else
    pane_pid=$(tmux display-message -p '#{pane_pid}' 2>/dev/null || true)
    pane_path=$(tmux display-message -p '#{pane_current_path}' 2>/dev/null || true)
    pane_session=$(tmux display-message -p '#{session_name}' 2>/dev/null || true)
    pane_win_name=$(tmux display-message -p '#{window_name}' 2>/dev/null || true)
    pane_win_idx=$(tmux display-message -p '#{window_index}' 2>/dev/null || true)
    win_layout=$(tmux display-message -p '#{window_layout}' 2>/dev/null || true)
    pane_cmd=$(tmux display-message -p '#{pane_current_command}' 2>/dev/null || true)
    agent_title=$(tmux display-message -p '#{?@ai_agent_title,#{@ai_agent_title},#{@w:@ai_agent_title}}' 2>/dev/null || true)
    agent_raw_state=$(tmux display-message -p '#{?@ai_agent_state_raw,#{@ai_agent_state_raw},#{@w:@ai_agent_state_raw}}' 2>/dev/null || true)
  fi

  # Ignore popup sessions
  if [ "$pane_session" = "_popups" ] || [ -z "$pane_pid" ]; then
    return 1
  fi

  local found_cmd=""
  local found_file=""
  local found_cwd=""

  # Traverse all descendant child processes
  local all_pids=()
  local queue=("$pane_pid")
  while [ ${#queue[@]} -gt 0 ]; do
    local curr="${queue[0]}"
    queue=("${queue[@]:1}")
    local kids
    kids=$(pgrep -P "$curr" 2>/dev/null || true)
    for k in $kids; do
      queue+=("$k")
      all_pids+=("$k")
    done
  done

  for (( i=${#all_pids[@]}-1; i>=0; i-- )); do
    local p="${all_pids[$i]}"
    [ ! -d "/proc/$p" ] && continue
    local pname
    pname=$(cat "/proc/$p/comm" 2>/dev/null || true)
    local raw_cmdline
    raw_cmdline=$(tr '\0' ' ' < "/proc/$p/cmdline" 2>/dev/null | sed 's/ *$//' || true)
    local cwd
    cwd=$(readlink "/proc/$p/cwd" 2>/dev/null || true)

    if [[ "$pname" =~ ^(nvim|vim)$ ]]; then
      local sock="/run/user/$UID/nvim.$p.0"
      if [ -S "$sock" ]; then
        local nfile
        nfile=$(nvim --server "$sock" --remote-expr "expand('%:p')" 2>/dev/null || true)
        if [ -n "$nfile" ] && [ -f "$nfile" ]; then
          found_file="$nfile"
          found_cmd="nvim $(printf '%q' "$nfile")"
          [ -n "$cwd" ] && found_cwd="$cwd"
          break
        fi
      fi

      local args
      args=$(tr '\0' '\n' < "/proc/$p/cmdline" 2>/dev/null || true)
      local file_arg=""
      while IFS= read -r arg; do
        [ -z "$arg" ] && continue
        [[ "$arg" == nvim* || "$arg" == vim* ]] && continue
        [[ "$arg" == -* ]] && continue
        file_arg="$arg"
      done <<< "$args"

      if [ -n "$file_arg" ]; then
        found_file="$file_arg"
        found_cmd="nvim $(printf '%q' "$file_arg")"
      else
        found_cmd="nvim"
      fi
      [ -n "$cwd" ] && found_cwd="$cwd"
      break
    fi

    # AI Agents (smart resume & continuation)
    if [[ "$pname" =~ ^(opencode|agy|agy-bin|antigravity|claude|codex|muse|gemini|aider)$ ]]; then
      local canonical_bin="$pname"
      case "$pname" in
        agy|agy-bin|antigravity) canonical_bin="agy" ;;
        opencode) canonical_bin="opencode" ;;
        claude) canonical_bin="claude" ;;
        codex) canonical_bin="codex" ;;
        muse) canonical_bin="muse" ;;
        gemini) canonical_bin="gemini" ;;
        aider) canonical_bin="aider" ;;
      esac

      local cmd_args=""
      if [[ "$raw_cmdline" =~ [[:space:]] ]]; then
        cmd_args="${raw_cmdline#*[[:space:]]}"
        cmd_args=$(printf '%s' "$cmd_args" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
      fi

      local resume_cmd="$canonical_bin"
      [ -n "$cmd_args" ] && resume_cmd="$canonical_bin $cmd_args"

      case "$canonical_bin" in
        opencode)
          if [[ ! "$resume_cmd" =~ (^|[[:space:]])(-c|--continue|-s|--session)($|[[:space:]]) ]]; then
            resume_cmd="${resume_cmd} --continue"
          fi
          ;;
        agy)
          # Check if an exact conversation lock exists in open file descriptors
          local conv_id=""
          local lock_file
          lock_file=$(ls -l "/proc/$p/fd" 2>/dev/null | grep -oE '/presence/[a-f0-9-]+\.lock' | head -n1 || true)
          if [ -n "$lock_file" ]; then
            conv_id=$(basename "$lock_file" .lock)
          fi

          if [ -n "$conv_id" ] && [[ ! "$resume_cmd" =~ (^|[[:space:]])(--conversation)($|[[:space:]]) ]]; then
            resume_cmd="agy --conversation $conv_id"
          elif [[ ! "$resume_cmd" =~ (^|[[:space:]])(-c|--continue|--conversation)($|[[:space:]]) ]]; then
            resume_cmd="${resume_cmd} --continue"
          fi
          ;;
        claude)
          if [[ ! "$resume_cmd" =~ (^|[[:space:]])(-c|--continue|-r|--resume)($|[[:space:]]) ]]; then
            resume_cmd="${resume_cmd} --continue"
          fi
          ;;
        codex)
          if [[ ! "$resume_cmd" =~ (^|[[:space:]])(resume)($|[[:space:]]) ]]; then
            resume_cmd="${resume_cmd} resume --last"
          elif [[ "$resume_cmd" =~ (^|[[:space:]])resume$ ]]; then
            resume_cmd="${resume_cmd} --last"
          fi
          ;;
        muse)
          if [[ ! "$resume_cmd" =~ (^|[[:space:]])(resume)($|[[:space:]]) ]]; then
            resume_cmd="${resume_cmd} resume --last"
          elif [[ "$resume_cmd" =~ (^|[[:space:]])resume$ ]]; then
            resume_cmd="${resume_cmd} --last"
          fi
          ;;
      esac

      found_cmd="$resume_cmd"
      [ -n "$cwd" ] && found_cwd="$cwd"
      break
    fi

    # CLI tools and runtimes
    if [[ "$pname" =~ ^(lazygit|lazygitrs|yazi|btop|htop|cargo|git|python|python3|node)$ ]]; then
      found_cmd="$raw_cmdline"
      [ -z "$found_cmd" ] && found_cmd="$pname"
      [ -n "$cwd" ] && found_cwd="$cwd"
      break
    fi
  done

  # Fallback if found_cmd is empty but pane_cmd was an AI agent
  if [ -z "$found_cmd" ] && [ -n "${pane_cmd:-}" ]; then
    case "$pane_cmd" in
      opencode) found_cmd="opencode --continue" ;;
      agy|agy-bin|antigravity) found_cmd="agy --continue" ;;
      claude) found_cmd="claude --continue" ;;
      codex) found_cmd="codex resume --last" ;;
      muse) found_cmd="muse resume --last" ;;
    esac
  fi

  [ -n "$found_cwd" ] && pane_path="$found_cwd"
  [ -z "$pane_path" ] && pane_path="$HOME"

  jq -n \
    --arg session "$pane_session" \
    --arg name "$pane_win_name" \
    --arg index "${pane_win_idx:-0}" \
    --arg path "$pane_path" \
    --arg cmd "$found_cmd" \
    --arg file "$found_file" \
    --arg layout "$win_layout" \
    --arg agent_title "$agent_title" \
    --arg agent_state "$agent_raw_state" \
    --arg time "$(date +%s)" \
    '{session: $session, name: $name, index: ($index | tonumber), path: $path, cmd: $cmd, file: $file, layout: $layout, agent_title: $agent_title, agent_state: $agent_state, time: ($time | tonumber)}'
}

push_entry() {
  local entry="$1"
  [ -z "$entry" ] && return 0

  local tmp_file="${STACK_FILE}.${$}.tmp"
  if [ -f "$STACK_FILE" ] && [ -s "$STACK_FILE" ] && jq -e . "$STACK_FILE" >/dev/null 2>&1; then
    if jq --argjson item "$entry" '[$item] + .[:24]' "$STACK_FILE" > "$tmp_file" 2>/dev/null; then
      mv "$tmp_file" "$STACK_FILE"
    else
      rm -f "$tmp_file"
      echo "[$entry]" > "$STACK_FILE"
    fi
  else
    rm -f "$tmp_file"
    echo "[$entry]" > "$STACK_FILE"
  fi
}

case "${1:-}" in
  --track)
    entry=$(inspect_pane "" || true)
    if [ -n "$entry" ]; then
      echo "$entry" > "$ACTIVE_FILE"
    fi
    acpd-cli dismiss >/dev/null 2>&1 &
    # Debounced periodic topology snapshot (zero-fork check, max once per 30s)
    printf -v _now '%(%s)T' -1
    _snap_lock="/tmp/cockpit-snap-debounce-${UID:-$(id -u)}.lock"
    _last_snap=0
    [ -f "$_snap_lock" ] && read -r _last_snap < "$_snap_lock" || true
    if [ $((_now - _last_snap)) -ge 30 ]; then
      printf '%s\n' "$_now" > "$_snap_lock"
      ( "$HOME/.config/tmux/cockpit-snapshot.py" snapshot --quiet >/dev/null 2>&1 & )
    fi
    ;;
  --unlinked)
    if [ -f "$ACTIVE_FILE" ] && [ -s "$ACTIVE_FILE" ]; then
      now=$(date +%s)
      tracked_time=$(jq -r '.time // 0' "$ACTIVE_FILE" 2>/dev/null || echo 0)
      # If active window was tracked within last 60 seconds
      if [ $((now - tracked_time)) -le 60 ]; then
        last_closed_time=0
        if [ -f "$STACK_FILE" ] && [ -s "$STACK_FILE" ]; then
          last_closed_time=$(jq -r '.[0].time // 0' "$STACK_FILE" 2>/dev/null || echo 0)
        fi
        # Only push if it was not already pushed (within last 2s) by close-window.sh
        if [ $((now - last_closed_time)) -ge 2 ]; then
          entry=$(cat "$ACTIVE_FILE")
          push_entry "$entry"
        fi
      fi
    fi
    ;;
  --push)
    shift
    target="${1:-}"
    entry=$(inspect_pane "$target" || true)
    if [ -n "$entry" ]; then
      push_entry "$entry"
    fi
    ;;
  *)
    target="${1:-}"
    entry=$(inspect_pane "$target" || true)
    if [ -n "$entry" ]; then
      push_entry "$entry"
    fi
    ;;
esac
