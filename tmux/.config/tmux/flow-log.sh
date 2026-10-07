#!/usr/bin/env bash
# tmux/flow-log.sh — Zero-fork N=1 telemetry logger for context-switch tracking
# Uses Bash 5 printf '%(%s)T' builtin to eliminate date subprocess forks
set -uo pipefail

log_dir="${XDG_STATE_HOME:-$HOME/.local/state}/flow"
[ -d "$log_dir" ] || mkdir -p "$log_dir"

printf '%(%s)T\t%s\t%s\n' -1 "$1" "${2:-}" >> "$log_dir/events.tsv"
