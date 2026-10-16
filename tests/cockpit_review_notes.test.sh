#!/usr/bin/env bash
# tests/cockpit_review_notes.test.sh — Verification for Lazygitrs Review Notes Bridge in Cockpit
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REVIEW_SCRIPT="$DOTFILES_DIR/tmux/.config/tmux/cockpit-review-notes.sh"

echo "=== Running Cockpit Review Notes Bridge Tests ==="

# Test 1: Bash syntax verification
bash -n "$REVIEW_SCRIPT"
bash -n "$DOTFILES_DIR/tmux/.config/tmux/cockpit-picker-diff.sh"
bash -n "$DOTFILES_DIR/tmux/.config/tmux/cockpit-picker-preview.sh"
echo "PASS: Syntax checks"

# Test 2: Temporary test repository setup
TMP_REPO=$(mktemp -d /tmp/test-review-repo-XXXXXX)
trap 'rm -rf "$TMP_REPO"' EXIT

git -C "$TMP_REPO" init --quiet
git_dir=$(git -C "$TMP_REPO" rev-parse --git-dir)
mkdir -p "$TMP_REPO/$git_dir/info"

# 2.1: Count when lines.json does not exist
count=$("$REVIEW_SCRIPT" count "$TMP_REPO")
if [[ "$count" -ne 0 ]]; then
  echo "FAIL: Expected count 0 when lines.json missing, got $count" >&2
  exit 1
fi
echo "PASS: Missing lines.json count == 0"

# 2.2: Create mock lines.json with 2 New notes and 1 Sent note
cat <<'EOF' > "$TMP_REPO/$git_dir/info/lines.json"
{
  "version": 1,
  "notes": [
    {
      "id": "note-1",
      "file": "src/adapters.rs",
      "line": 42,
      "comment": "Handle None case when window is detached",
      "status": "New"
    },
    {
      "id": "note-2",
      "file": "src/main.rs",
      "line": 105,
      "comment": "Add debug logging for connection timeouts",
      "status": "New"
    },
    {
      "id": "note-3",
      "file": "src/auth.rs",
      "line": 15,
      "comment": "Already resolved token check",
      "status": "Sent"
    }
  ]
}
EOF

# 2.3: Count pending notes
count=$("$REVIEW_SCRIPT" count "$TMP_REPO")
if [[ "$count" -ne 2 ]]; then
  echo "FAIL: Expected count 2, got $count" >&2
  exit 1
fi
echo "PASS: Correct pending count ($count == 2)"

# 2.4: List formatted review notes
list_out=$("$REVIEW_SCRIPT" list "$TMP_REPO")
if ! grep -q "src/adapters.rs:42" <<< "$list_out" || ! grep -q "src/main.rs:105" <<< "$list_out"; then
  echo "FAIL: list output did not contain expected notes: $list_out" >&2
  exit 1
fi
echo "PASS: List formats pending notes properly"

# 2.5: Send notes to a dummy pane
# If tmux is running, use current pane or mock
CURRENT_PANE=$(tmux display-message -p '#{pane_id}' 2>/dev/null || echo "")
if [[ -n "$CURRENT_PANE" ]]; then
  # Dry-run send using current pane
  "$REVIEW_SCRIPT" send "$TMP_REPO" "" "" "$CURRENT_PANE"
  
  # Verify status updated to Sent in lines.json
  after_count=$("$REVIEW_SCRIPT" count "$TMP_REPO")
  if [[ "$after_count" -ne 0 ]]; then
    echo "FAIL: Expected count 0 after send, got $after_count" >&2
    exit 1
  fi
  echo "PASS: Send transitioned notes to Sent and cleared pending count"
fi

echo "=== All Cockpit Review Notes Bridge Tests Passed! ==="
