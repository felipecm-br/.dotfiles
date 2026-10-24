#!/usr/bin/env bash
# tests/review_marker.test.sh — a glance in lazygitrs must not clear the Cockpit's "done, not
# reviewed" state; a long enough session or a stage/commit/discard must. Also checks that
# flow-log.sh drops repeated session/window switches.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LAZYGITRS_POPUP="$DOTFILES_DIR/tmux/.config/tmux/lazygitrs-popup.sh"
FLOW_LOG="$DOTFILES_DIR/tmux/.config/tmux/flow-log.sh"

echo "=== Running Review Marker Tests ==="

TMP_DIR=$(mktemp -d /tmp/test-review-marker-XXXXXX)
trap 'rm -rf "$TMP_DIR"' EXIT

# Sandboxed HOME with stub tmux and lazygitrs: the popup "session" runs $POPUP_ACTION in the repo.
export HOME="$TMP_DIR/home"
export XDG_STATE_HOME="$TMP_DIR/state"
mkdir -p "$HOME/.local/bin" "$TMP_DIR/bin"
printf '#!/usr/bin/env bash\necho "usage: lazygitrs [--commits]"\n' > "$HOME/.local/bin/lazygitrs"
cat > "$TMP_DIR/bin/tmux" <<'EOF'
#!/usr/bin/env bash
[ "${1:-}" = "display-popup" ] && eval "${POPUP_ACTION:-:}"
exit 0
EOF
chmod +x "$HOME/.local/bin/lazygitrs" "$TMP_DIR/bin/tmux"
export PATH="$TMP_DIR/bin:$PATH"

REPO="$TMP_DIR/repo"
git init -q "$REPO"
git -C "$REPO" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
echo change > "$REPO/file.txt"
MARKER="$REPO/.git/waymux-reviewed"

run_review() {
  rm -f "$MARKER"
  POPUP_ACTION="$1" WAYMUX_REVIEW_MIN_SECS="$2" "$LAZYGITRS_POPUP" "$REPO" >/dev/null 2>&1 || true
}

run_review ":" 20
[ ! -e "$MARKER" ] || { echo "FAIL: a glance cleared the review state" >&2; exit 1; }
echo "PASS: A glance keeps the review state"

run_review "git -C '$REPO' add file.txt" 20
[ -e "$MARKER" ] || { echo "FAIL: staging did not count as a review" >&2; exit 1; }
git -C "$REPO" reset -q
echo "PASS: Staging counts as a review"

run_review ":" 0
[ -e "$MARKER" ] || { echo "FAIL: a session past the minimum did not count as a review" >&2; exit 1; }
echo "PASS: A long enough session counts as a review"

for target in a a b b a; do "$FLOW_LOG" session "$target"; done
got=$(awk -F'\t' '$2 == "session" {printf "%s ", $3}' "$XDG_STATE_HOME/flow/events.tsv")
[ "$got" = "a b a " ] || { echo "FAIL: flow-log kept repeated switches: $got" >&2; exit 1; }
echo "PASS: flow-log drops repeated session switches"

echo "=== All Review Marker Tests Passed ==="
