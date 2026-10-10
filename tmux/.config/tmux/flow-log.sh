#!/usr/bin/env bash
# tmux/flow-log.sh — Zero-fork N=1 telemetry logger for context-switch & human response latency
# Uses Bash 5 printf '%(%s)T' builtin to eliminate date subprocess forks.
set -uo pipefail

log_dir="${XDG_STATE_HOME:-$HOME/.local/state}/flow"
[ -d "$log_dir" ] || mkdir -p "$log_dir"

event="${1:-}"
target="${2:-}"
extra="${3:-}"

[ -z "$event" ] && exit 0

printf -v now '%(%s)T' -1

safe_target="${target//\//_}"
safe_target="${safe_target//%/_pane_}"

case "$event" in
  agent_question|agent_ask)
    printf '%s\n' "$now" > "$log_dir/last_question.txt"
    [ -n "$safe_target" ] && printf '%s\n' "$now" > "$log_dir/last_question_${safe_target}.txt"
    ;;

  human_reply)
    if [ -z "$extra" ]; then
      q_file=""
      if [ -n "$safe_target" ] && [ -f "$log_dir/last_question_${safe_target}.txt" ]; then
        q_file="$log_dir/last_question_${safe_target}.txt"
      elif [ -f "$log_dir/last_question.txt" ]; then
        q_file="$log_dir/last_question.txt"
      fi

      if [ -n "$q_file" ] && [ -s "$q_file" ]; then
        read -r q_time < "$q_file" || true
        if [ -n "$q_time" ] && [ "$q_time" -gt 0 ] 2>/dev/null; then
          lat=$(( now - q_time ))
          if [ "$lat" -ge 0 ] && [ "$lat" -lt 86400 ]; then
            extra="${lat}s"
          fi
        fi
        [ -n "$safe_target" ] && rm -f "$log_dir/last_question_${safe_target}.txt" 2>/dev/null || true
      fi
    fi
    ;;

  agent_finished|task_done)
    printf '%s\n' "$now" > "$log_dir/last_task_done.txt"
    [ -n "$safe_target" ] && printf '%s\n' "$now" > "$log_dir/last_task_done_${safe_target}.txt"
    ;;

  review_start)
    if [ -z "$extra" ]; then
      t_file="$log_dir/last_task_done.txt"
      if [ -f "$t_file" ] && [ -s "$t_file" ]; then
        read -r t_time < "$t_file" || true
        if [ -n "$t_time" ] && [ "$t_time" -gt 0 ] 2>/dev/null; then
          lat=$(( now - t_time ))
          if [ "$lat" -ge 0 ] && [ "$lat" -lt 86400 ]; then
            extra="${lat}s"
          fi
        fi
      fi
    fi
    printf '%s\n' "$now" > "$log_dir/last_review_start.txt"
    ;;

  review_end)
    if [ -z "$extra" ]; then
      r_file="$log_dir/last_review_start.txt"
      if [ -f "$r_file" ] && [ -s "$r_file" ]; then
        read -r r_time < "$r_file" || true
        if [ -n "$r_time" ] && [ "$r_time" -gt 0 ] 2>/dev/null; then
          dur=$(( now - r_time ))
          if [ "$dur" -ge 0 ] && [ "$dur" -lt 86400 ]; then
            extra="${dur}s"
          fi
        fi
        rm -f "$log_dir/last_review_start.txt" 2>/dev/null || true
      fi
    fi
    ;;
esac

printf '%s\t%s\t%s\t%s\n' "$now" "$event" "$target" "$extra" >> "$log_dir/events.tsv"
