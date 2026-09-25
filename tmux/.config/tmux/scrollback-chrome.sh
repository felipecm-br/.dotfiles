#!/usr/bin/env sh
# scrollback-chrome.sh — open a URL or link token directly in Google Chrome / browser.
# Usage: scrollback-chrome.sh <token> | scrollback-chrome.sh --check <token>
# --check only prints normalized URL (used by tests).
set -u

CHECK=0
if [ "${1:-}" = "--check" ]; then
  CHECK=1
  shift
fi

raw="${1:-}"
[ -n "$raw" ] || exit 0

# Strip leading/trailing whitespace and common wrapper characters
token="$(printf '%s' "$raw" | sed -E 's/^[[:space:]<"'\''([{\[]+//; s/[][[:space:]>"'\''})]+$//; s/[.,;:)>]+$//')"

url="$token"

# Normalize URL patterns
case "$token" in
  git@*:*/*)
    host="$(printf '%s' "$token" | sed -E 's/^git@([^:]+):.*/\1/')"
    repo="$(printf '%s' "$token" | sed -E 's/^git@[^:]+:(.*)/\1/; s/\.git$//')"
    url="https://${host}/${repo}"
    ;;
  http://*|https://*|file://*)
    url="$token"
    ;;
  localhost:*|localhost/*|localhost|127.0.0.1:*|127.0.0.1/*|127.0.0.1)
    url="http://$token"
    ;;
  www.*|github.com/*|gitlab.com/*)
    url="https://$token"
    ;;
  *.*/*)
    url="https://$token"
    ;;
  *.*)
    # Domain without path (e.g. google.com, example.org)
    url="https://$token"
    ;;
esac

if [ "$CHECK" = "1" ]; then
  printf '%s\n' "$url"
  exit 0
fi

# Resolve browser binary (Chrome preferred)
BROWSER_BIN=""
if command -v google-chrome-stable >/dev/null 2>&1; then
  BROWSER_BIN="google-chrome-stable"
elif command -v google-chrome >/dev/null 2>&1; then
  BROWSER_BIN="google-chrome"
elif command -v chromium >/dev/null 2>&1; then
  BROWSER_BIN="chromium"
elif command -v xdg-open >/dev/null 2>&1; then
  BROWSER_BIN="xdg-open"
fi

if [ -z "$BROWSER_BIN" ]; then
  tmux display-message "scrollback: navegador não encontrado (google-chrome-stable/xdg-open)" 2>/dev/null || true
  exit 1
fi

# Copy sanitized URL to system clipboard
if command -v wl-copy >/dev/null 2>&1; then
  printf '%s' "$url" | wl-copy 2>/dev/null || true
elif command -v xclip >/dev/null 2>&1; then
  printf '%s' "$url" | xclip -in -selection clipboard 2>/dev/null || true
else
  printf '%s' "$url" | tmux load-buffer - 2>/dev/null || true
fi

# Close Tmux popup overlay cleanly
tmux display-popup -C 2>/dev/null || true
rm -f "/tmp/tmux-active-popup-${USER:-default}" 2>/dev/null || true

# User feedback in Tmux status bar
tmux display-message " Chrome: $url" 2>/dev/null || true

# Launch browser detached from popup process group
if command -v setsid >/dev/null 2>&1; then
  setsid "$BROWSER_BIN" "$url" >/dev/null 2>&1 &
else
  nohup "$BROWSER_BIN" "$url" >/dev/null 2>&1 &
fi

exit 0
