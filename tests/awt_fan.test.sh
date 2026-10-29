#!/usr/bin/env bash
# tests/awt_fan.test.sh — contract test for awt-fan: quota gate, fan creation, rows, preview,
# checks, tokens, drop and keep. awt and ai-quota are stubs; tmux and the waymux daemon are unreachable.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ok() { echo "ok: $*"; }
bad() { echo "FAIL: $*" >&2; exit 1; }

SB=$(mktemp -d)
trap 'rm -rf "$SB"' EXIT
export XDG_STATE_HOME="$SB/state" TMUX_TMPDIR="$SB/tmux" WAYMUX_PORT=1 TMUX= LC_ALL=C.UTF-8
mkdir -p "$SB/bin" "$TMUX_TMPDIR"
F="$ROOT/utils/.local/bin/awt-fan"
export PATH="$SB/bin:$PATH" AWT_FAN_AWT="$SB/bin/awt-stub"

# awt stub: real worktrees next to the repo (as awt lays them out); records the agent command.
cat >"$SB/bin/awt-stub" <<'EOF'
#!/usr/bin/env bash
set -e
case "$1" in
  -c) branch=$2 base=$3; shift 3; [ "$1" = --no-connect ] && shift; [ "$1" = -- ] && shift
      git worktree add -q "../${branch//\//-}" -b "$branch" "$base"
      printf '%s\n' "$*" >>"$XDG_STATE_HOME/agent-cmds" ;;
  rm) dir=$(git worktree list --porcelain | awk -v b="refs/heads/$2" '/^worktree /{w=substr($0,10)} $0=="branch "b{print w}')
      [ -n "$dir" ] && git worktree remove --force "$dir"; git branch -q -D "$2" ;;
esac
EOF
chmod +x "$SB/bin/awt-stub"
quota() { printf '#!/bin/sh\ncat <<J\n%s\nJ\n' "$1" >"$SB/bin/ai-quota"; chmod +x "$SB/bin/ai-quota"; }
printf '#!/bin/sh\n' >"$SB/bin/claude"; printf '#!/bin/sh\n' >"$SB/bin/codex"; chmod +x "$SB/bin/claude" "$SB/bin/codex"

mkdir -p "$SB/repo" && cd "$SB/repo"
git init -q -b main && git config user.name t && git config user.email t@t && git config commit.gpgsign false
echo one >a.txt && git add a.txt && git commit -qm init

bash -n "$F" && ok "syntax" || bad "syntax"
"$F" --help | grep -q 'awt-fan new' && ok "help" || bad "help"

# 1. Quota gate: red refused, yellow capped at one attempt, --force overrides.
quota '{"recommend":"codex","agents":[{"agent":"claude","level":"red"},{"agent":"codex","level":"yellow"}]}'
set +e; out=$("$F" new -n 2 -a claude -- fix it 2>&1); rc=$?; set -e
[ $rc -ne 0 ] && grep -q 'claude: quota red' <<<"$out" && ok "red agent refused" || bad "red: $rc $out"
set +e; out=$("$F" new -n 2 -a codex -- fix it 2>&1); rc=$?; set -e
[ $rc -ne 0 ] && grep -q 'at most 1' <<<"$out" && ok "yellow capped at one attempt" || bad "yellow: $out"
[ ! -d "$XDG_STATE_HOME/awt-fan" ] || [ -z "$(ls "$XDG_STATE_HOME/awt-fan")" ] && ok "refused fan leaves nothing" || bad "refused fan left state"

# 2. A fan: worktrees, manifest, each agent started with the prompt as one argument.
quota '{"recommend":"claude","agents":[{"agent":"claude","level":"green"},{"agent":"codex","level":"green"}]}'
"$F" new -n 2 -a claude,codex -- "fix the \"quoted\" bug; don't break it" >/dev/null
id=$(ls "$XDG_STATE_HOME/awt-fan" | sed -n 's/\.json$//p' | head -1)
[ -n "$id" ] && [ -d "$SB/fan-$id-1" ] && [ -d "$SB/fan-$id-2" ] && ok "two worktrees" || bad "worktrees: $id"
first=$(sed -n 1p "$XDG_STATE_HOME/agent-cmds")
eval "set -- $first"
[ "$1" = claude ] && [ "$2" = "fix the \"quoted\" bug; don't break it" ] && [ $# -eq 2 ] && ok "prompt passed as one argument" || bad "quoting: $first"
[ "$(sed -n 2p "$XDG_STATE_HOME/agent-cmds" | cut -d' ' -f1)" = codex ] && ok "agents cycle" || bad "cycle"

# 3. Rows: one per attempt, aligned display, hidden id/n/dir fields.
echo two >>"$SB/fan-$id-1/a.txt"
rows=$("$F" ls "$id")
[ "$(wc -l <<<"$rows")" = 2 ] && ok "one row per attempt" || bad "rows: $rows"
[ "$(cut -f2-4 <<<"$rows" | sed -n 1p)" = "$id	1	$SB/fan-$id-1" ] && ok "hidden fields" || bad "fields: $rows"
w1=$(cut -f1 <<<"$rows" | sed -n 1p); w2=$(cut -f1 <<<"$rows" | sed -n 2p)
[ ${#w1} -eq ${#w2} ] && ok "columns aligned (${#w1} chars)" || bad "widths ${#w1} vs ${#w2}"
grep -q '+1 -0' <<<"$w1" && grep -q 'clean' <<<"$w2" && ok "diffstat per attempt" || bad "diff: $rows"

# 4. Preview: the attempt's diff against the base.
pv=$("$F" preview "$id" 1 2>&1 || true)
grep -q 'two' <<<"$pv" && ok "preview shows the diff" || bad "preview: $pv"

# 4b. Checks: run in the background, ✓/✗ per attempt, ~ once the attempt changes.
waitcheck() { local i; for i in $(seq 50); do ! grep -qs '^running' "$XDG_STATE_HOME/awt-fan/$id.check/"*.status && return 0; sleep 0.1; done; return 1; }
"$F" check "$id" --no-jail -- grep -q two a.txt >/dev/null
waitcheck && ok "checks finish" || bad "checks still running"
rows=$("$F" ls "$id")
grep -q '✓' <<<"$(sed -n 1p <<<"$rows")" && grep -q '✗' <<<"$(sed -n 2p <<<"$rows")" && ok "pass and fail per attempt" || bad "check cells: $rows"
[ "$("$F" ls "$id" | cut -f1 | sed -n 1p | wc -m)" = "$("$F" ls "$id" | cut -f1 | sed -n 2p | wc -m)" ] && ok "check column aligned" || bad "check widths"
grep -q '"check": "grep -q two a.txt"' "$XDG_STATE_HOME/awt-fan/$id.json" && ok "check command remembered" || bad "manifest check"
echo three >>"$SB/fan-$id-1/a.txt"
grep -q '~' <<<"$("$F" ls "$id" | sed -n 1p)" && ok "changed attempt marks its check stale" || bad "stale: $("$F" ls "$id")"
"$F" check "$id" --no-jail >/dev/null && waitcheck && grep -q '✓' <<<"$("$F" ls "$id" | sed -n 1p)" && ok "re-check reuses the command" || bad "re-check"
set +e; out=$(cd "$SB" && mkdir -p bare && cd bare && git init -q && "$F" check nosuch 2>&1); rc=$?; set -e
[ $rc -ne 0 ] && grep -q 'no fan' <<<"$out" && ok "unknown fan refused" || bad "unknown fan: $out"

# 4c. Tokens: from each agent's own session logs, repeated Claude lines counted once, cache reads out.
H="$SB/home"; enc=$(printf '%s' "$SB/fan-$id-1" | sed 's/[^A-Za-z0-9]/-/g')
mkdir -p "$H/.claude/projects/$enc" "$H/.codex/sessions/$(date +%Y/%m/%d)"
u='{"type":"assistant","message":{"id":"m1","usage":{"input_tokens":10,"cache_creation_input_tokens":100,"cache_read_input_tokens":999,"output_tokens":5}}}'
{ echo "$u"; echo "$u"; echo '{"type":"assistant","message":{"id":"m2","usage":{"input_tokens":0,"output_tokens":2000}}}'; } >"$H/.claude/projects/$enc/s.jsonl"
{ echo "{\"type\":\"session_meta\",\"payload\":{\"cwd\":\"$SB/fan-$id-2\"}}"
  echo '{"type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":5000,"cached_input_tokens":4000,"output_tokens":500}}}}'
} >"$H/.codex/sessions/$(date +%Y/%m/%d)/rollout-x.jsonl"
rows=$(HOME="$H" "$F" ls "$id")
grep -q ' 2k ' <<<"$(sed -n 1p <<<"$rows")" && grep -q ' 1k ' <<<"$(sed -n 2p <<<"$rows")" && ok "tokens per attempt (claude 2k, codex 1k)" || bad "tokens: $rows"

# 5. Drop, then keep: the kept attempt is committed and merged, every attempt removed.
"$F" drop "$id" 2 --yes >/dev/null
[ ! -d "$SB/fan-$id-2" ] && ! git rev-parse -q --verify "fan/$id-2" >/dev/null && ok "drop removes worktree and branch" || bad "drop"
"$F" keep "$id" 1 --yes >/dev/null
[ "$(cat a.txt)" = "$(printf 'one\ntwo\nthree')" ] && ok "kept attempt merged into main" || bad "merge: $(cat a.txt)"
[ ! -d "$SB/fan-$id-1" ] && ok "all attempts removed" || bad "leftover worktree"
ls "$XDG_STATE_HOME/awt-fan" | grep -q "$id.json.kept-1" && ok "manifest archived" || bad "manifest"
[ ! -e "$XDG_STATE_HOME/awt-fan/$id.check" ] && [ ! -e "$XDG_STATE_HOME/awt-fan/$id.target" ] && ok "check results removed with the fan" || bad "check leftovers"
