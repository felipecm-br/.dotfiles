#!/usr/bin/env bash
# pr-diff.sh — Interactive terminal diff viewer for GitHub Pull Request
# Usage: pr-diff.sh <pr_number>
set -e

num="${1#\#}"
[ -z "$num" ] && exit 0

if ! command -v gh >/dev/null 2>&1; then
    echo "gh: command not found" >&2
    exit 1
fi

echo -e "\033[1;36m━━━ Loading diff for Pull Request #$num ━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"

if command -v delta >/dev/null 2>&1; then
    gh pr diff "$num" --color=always 2>&1 | delta --paging=always
elif command -v less >/dev/null 2>&1; then
    gh pr diff "$num" --color=always 2>&1 | less -R
else
    gh pr diff "$num"
fi
