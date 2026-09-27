#!/usr/bin/env bash
# pr-open-chrome.sh — Open GitHub Pull Request in Google Chrome / browser
# Usage: pr-open-chrome.sh <pr_number>
set -e

num="${1#\#}"
[ -z "$num" ] && exit 0

# Try gh pr view --web first
if command -v gh >/dev/null 2>&1; then
    gh pr view "$num" --web 2>/dev/null && exit 0
fi

# Fallback: parse repo remote URL and open Chrome directly
remote_url=$(git config --get remote.origin.url 2>/dev/null || true)
if [ -n "$remote_url" ]; then
    slug=$(echo "$remote_url" | sed -E 's/.*github\.com[:\/]([^\/]+\/[^\/\.]+).*/\1/; s/\.git$//')
    if [ -n "$slug" ]; then
        url="https://github.com/$slug/pull/$num"
        if command -v google-chrome-stable >/dev/null 2>&1; then
            google-chrome-stable "$url" >/dev/null 2>&1 &
            exit 0
        elif command -v google-chrome >/dev/null 2>&1; then
            google-chrome "$url" >/dev/null 2>&1 &
            exit 0
        elif command -v xdg-open >/dev/null 2>&1; then
            xdg-open "$url" >/dev/null 2>&1 &
            exit 0
        fi
    fi
fi
exit 0
