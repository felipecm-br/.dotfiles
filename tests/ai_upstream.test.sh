#!/usr/bin/env bash
# tests/ai_upstream.test.sh — ai-upstream fork dry runs, patch-id matching, state, offline.
#
# A fake `gh` (always fails) keeps the run off the network; the fork and its upstream are
# local repositories in a temp dir, and state goes to a temp XDG_STATE_HOME.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN_UP="$ROOT/utils/.local/bin/ai-upstream"
ok() { echo "ok: $*"; }
bad() { echo "FAIL: $*" >&2; exit 1; }
command -v python3 >/dev/null || { echo "skip: python3 missing"; exit 0; }

T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin"
printf '#!/bin/sh\nexit 1\n' >"$T/bin/gh"
chmod +x "$T/bin/gh"
export PATH="$T/bin:$PATH" XDG_STATE_HOME="$T/state" AI_UPSTREAM_SOURCES="$T/sources.toml"
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

g() { git -C "$1" "${@:2}" >/dev/null 2>&1; }
# upstream: base, then three commits: one the fork already has (same patch), one clean, one conflicting
git init -q -b main "$T/up"
printf 'a\n' >"$T/up/shared.txt"; printf 'x\n' >"$T/up/other.txt"
g "$T/up" add -A; g "$T/up" commit -m base
git clone -q "$T/up" "$T/fork"
g "$T/fork" remote rename origin upstream
g "$T/fork" checkout -b mine
printf 'mine\n' >"$T/fork/shared.txt"; g "$T/fork" commit -am "fork: change shared"
printf 'same\n' >"$T/fork/same.txt"; g "$T/fork" add -A; g "$T/fork" commit -m "fork: add same"

printf 'same\n' >"$T/up/same.txt"; g "$T/up" add -A; g "$T/up" commit -m "feat: add same (already in fork)"
printf 'y\n' >"$T/up/other.txt"; g "$T/up" commit -am "fix: clean change"
printf 'theirs\n' >"$T/up/shared.txt"; g "$T/up" commit -am "feat: conflicting hook change"
g "$T/fork" fetch upstream

cat >"$T/sources.toml" <<EOF
keywords = ["hook"]
[[source]]
name = "demo"
repo = "example/demo"
kind = "fork"
path = "$T/fork"
branch = "mine"
upstream_branch = "main"
license = "MIT"
[scout]
queries = []
EOF

out=$("$BIN_UP" watch --kind fork --no-fetch --json)
picks=$(jq -r '.sources[0].picks | map(.subject) | join("|")' <<<"$out")
[[ "$picks" == "fix: clean change|feat: conflicting hook change" ]] || bad "patch-id filter: got '$picks'"
ok "already-applied upstream commit is filtered by patch id"
[ "$(jq '.sources[0].picks[0].clean' <<<"$out")" = true ] || bad "clean pick not clean"
[ "$(jq '.sources[0].picks[1].clean' <<<"$out")" = false ] || bad "conflict not detected"
[ "$(jq -r '.sources[0].picks[1].overlap[0]' <<<"$out")" = shared.txt ] || bad "overlap missing"
[ "$(jq '.sources[0].picks[1].keyword' <<<"$out")" = true ] || bad "keyword not flagged"
ok "dry run marks clean, conflict, overlap and keyword"
[ "$(git -C "$T/fork" status --porcelain | wc -l)" -eq 0 ] && [ "$(git -C "$T/fork" rev-parse --abbrev-ref HEAD)" = mine ] \
  || bad "dry run touched the fork"
ok "fork working tree untouched"
[ "$(jq -r '.sources[0].license' <<<"$out")" = MIT ] || bad "manifest license fallback"
ok "license falls back to the manifest when GitHub is unreachable"

"$BIN_UP" watch --kind fork --no-fetch --ack >/dev/null 2>&1
jq -e '.watch.demo.acked' "$T/state/ai-upstream/state.json" >/dev/null || bad "--ack did not save state"
ok "--ack records the run"

"$BIN_UP" scout --dismiss someone/noise --reason test >/dev/null
jq -e '.scout.dismissed["someone/noise"].reason == "test"' "$T/state/ai-upstream/state.json" >/dev/null || bad "dismiss"
ok "--dismiss persists"
echo "all ai-upstream checks passed"
