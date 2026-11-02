#!/usr/bin/env bash
# tests/codex_hook.test.sh — codex-hook reports to the session's own pane, never the server's.
#
# Codex runs hooks in one shared app-server, so TMUX_PANE names whichever pane started it.
# A fake `waymux` (in a temp dir, never under the sandbox HOME) records the pane it was given.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$ROOT/utils/.local/bin/codex-hook"
ok() { echo "ok: $*"; }
bad() { echo "FAIL: $*" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "skip: jq not installed"; exit 0; }

# shellcheck source=lib/private_tmux.sh
. "$ROOT/tests/lib/private_tmux.sh"
BIN=$(mktemp -d)
LOG="$BIN/calls"
trap 'private_tmux_cleanup; rm -rf "$BIN"' EXIT
cat >"$BIN/waymux" <<EOF
#!/usr/bin/env bash
echo "\$TMUX_PANE \$*" >>"$LOG"
echo '{}'
EOF
chmod +x "$BIN/waymux"
export PATH="$BIN:$PATH"

DIR=$(mktemp -d -p "$BIN")
# Two panes that look like Codex in one directory, and one that does not.
a=$(tmux new-window -d -P -F '#{pane_id}' -c "$DIR" "exec -a codex sleep 300")
b=$(tmux new-window -d -P -F '#{pane_id}' -c "$DIR" "exec -a codex sleep 300")
other=$(tmux new-window -d -P -F '#{pane_id}' "sleep 300")
for _ in $(seq 50); do
  [ "$(tmux display -p -t "$b" '#{pane_current_command}')" = codex ] && break
done
[ "$(tmux display -p -t "$a" '#{pane_current_command}')" = codex ] || { echo "skip: cannot fake a codex pane here"; exit 0; }

hook() { TMUX_PANE=$other "$HOOK" "$@"; }
last() { tail -1 "$LOG" 2>/dev/null; }
sid=01a1aaaa-test-7000-8000-00000000000b

: >"$LOG"
out=$(hook SessionStart <<<"{\"session_id\":\"$sid\",\"cwd\":\"$DIR\"}")
[ "$out" = '{}' ] || bad "an unresolved event must print {} (got $out)"
[ ! -s "$LOG" ] || bad "two Codex panes and no prompt must report nothing (got: $(last))"
ok "ambiguous pane, no prompt: reports nothing"

tmux send-keys -t "$b" 'zz prompt typed in pane b'
for _ in $(seq 50); do tmux capture-pane -p -t "$b" | grep -q 'zz prompt' && break; done
hook UserPromptSubmit <<<"{\"session_id\":\"$sid\",\"cwd\":\"$DIR\",\"prompt\":\"zz prompt typed in pane b\"}" >/dev/null
[ "$(last)" = "$b hook tmux UserPromptSubmit codex" ] || bad "prompt on b's screen must pick b (got: $(last))"
ok "picks the pane whose screen shows the submitted prompt"

tmux set-option -p -t "$b" @ai_session "codex:$sid" # what waymux sets after that first hit
hook Stop <<<"{\"session_id\":\"$sid\",\"cwd\":\"/elsewhere\"}" >/dev/null
[ "$(last)" = "$b hook tmux Stop codex" ] || bad "a pinned session must follow its pane (got: $(last))"
ok "a session pinned by @ai_session wins over cwd"

tmux kill-pane -t "$a"
hook Notification <<<"{\"session_id\":\"01a1aaaa-test-7000-8000-0000000000ff\",\"cwd\":\"$DIR\"}" >/dev/null
[ "$(last)" = "$b hook tmux Notification codex" ] || bad "the only Codex pane in cwd must be used (got: $(last))"
ok "the only Codex pane in the cwd is used"

: >"$LOG"
hook Stop <<<'{"session_id":"01a1aaaa-test-7000-8000-0000000000fe","cwd":"/nowhere"}' >/dev/null
[ ! -s "$LOG" ] || bad "no Codex pane in cwd must report nothing (got: $(last))"
grep -q "$other" "$LOG" 2>/dev/null && bad "never report the server's own TMUX_PANE"
ok "unknown cwd: reports nothing, never the server's pane"

echo "codex_hook: all checks passed"
