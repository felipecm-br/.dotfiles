#!/usr/bin/env bash
# changelog-draft.sh — Draft docs/CHANGELOG.md entries from the commits since the last entry
#
#   scripts/changelog-draft.sh                 commits after the newest hash already in the changelog
#   scripts/changelog-draft.sh --since <rev>   commits after <rev> (a hash, tag or date like 2026-11-01)
#   scripts/changelog-draft.sh --all           include docs, chore, test and style commits
#
# Prints Markdown grouped by ISO week and by the stow packages each commit touches, with a
# suggested portability tag (see docs/architecture/portability-matrix.md). The suggestion is a
# hint from the paths and the added lines, not a verdict: rewrite each line as one plain sentence,
# merge related commits, check the tag, then paste the result under "## Unreleased" or a week
# heading. Read-only: it changes nothing.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHANGELOG="$ROOT/docs/CHANGELOG.md"
cd "$ROOT"

since=""
all=0
while [ $# -gt 0 ]; do
  case $1 in
    --since) since=${2:?--since needs a revision or a date}; shift 2 ;;
    --all) all=1; shift ;;
    -h | --help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "changelog-draft: unknown argument: $1" >&2; exit 2 ;;
  esac
done

# Default start: the newest commit the changelog already names.
if [ -z "$since" ]; then
  since=$(grep -oE '\b[0-9a-f]{7,40}\b' "$CHANGELOG" 2>/dev/null |
    while read -r h; do git rev-parse -q --verify "$h^{commit}" 2>/dev/null; done |
    xargs -r git rev-list --no-walk --date-order 2>/dev/null | head -1 || true)
  [ -n "$since" ] || { echo "changelog-draft: no commit hash found in $CHANGELOG; pass --since" >&2; exit 1; }
fi

if git rev-parse -q --verify "$since^{commit}" >/dev/null 2>&1; then
  range=("$since..HEAD")
else
  range=(--since="$since" HEAD)
fi

# Paths and package names that point at a tag.
host_only='^(hypr|omarchy|omarchy-antigravity|desktop|tuikit|upscayl|sounds|fcitx5|bluetui|ai_usagebar)/'
root_paths='(^|/)etc/|^battery/|^\.shell/install/|^\.shell/sh/|sudoers'

tag_for() { # <hash>: a suggested tag from the files and added lines of one commit
  local h=$1 files added
  files=$(git show --format= --name-only "$h")
  # Added lines outside docs and tests: prose about sudo is not a need for it.
  added=$(git show --format= --unified=0 "$h" -- . ':!docs' ':!tests' ':!*.md' | grep -E '^\+[^+]' || true)
  if grep -qE "$root_paths" <<<"$files" || grep -qE '\bsudo\b|pacman -S|systemctl (enable|start) [^-]' <<<"$added"; then
    echo '`needs: root`?'
  elif ! grep -qvE "$host_only|^docs/|^tests/" <<<"$files"; then
    echo '`host-only`?'
  else
    local needs=()
    grep -qE '\bwaymux\b' <<<"$added" && needs+=(waymux)
    grep -qE '\bwm\b|waymaker' <<<"$added$files" && needs+=(wm)
    grep -qE '\blazygitrs\b' <<<"$added" && needs+=(lazygitrs)
    grep -qE '\bai-jail\b' <<<"$added" && needs+=(ai-jail)
    grep -qE '\bai-memory\b' <<<"$added" && needs+=(ai-memory)
    if [ ${#needs[@]} -gt 0 ]; then
      local IFS=', '
      echo "\`needs: ${needs[*]}\`?"
    else
      echo '`portable`?'
    fi
  fi
}

skip='^(docs|chore|test|style)(\(|:)'
week=""
count=0
while IFS='|' read -r w h subject; do
  if [ "$all" = 0 ] && [[ $subject =~ $skip ]]; then continue; fi
  if [ "$w" != "$week" ]; then
    week=$w
    printf '\n## %s\n\n' "$week"
  fi
  pkgs=$(git show --format= --name-only "$h" | cut -d/ -f1 | grep -vE '^(docs|tests)$' | sort -u | paste -sd, -)
  printf -- '- %s (%s) [%s] %s\n' "$subject" "$h" "${pkgs:-docs}" "$(tag_for "$h")"
  count=$((count + 1))
done < <(git log --no-merges --reverse --date=format:'%G-W%V' --format='%ad|%h|%s' "${range[@]}")

[ "$count" -gt 0 ] || echo "changelog-draft: nothing new since $since" >&2
