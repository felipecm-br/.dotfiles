#!/usr/bin/env bash
# tests/ai_failover.test.sh — contract test for ai-failover (Prefix + F) and ai-launch-exec's
# AI_LAUNCH_CONTINUE path: the limited agent's family is left out of the pick, the next agent
# starts beside the pane in its directory, through `ai-memory run`. Runs on a private tmux
# server with a sandboxed HOME; ai-launch and ai-memory are stubs.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ok() { echo "ok: $*"; }
bad() { echo "FAIL: $*" >&2; exit 1; }

# shellcheck source=lib/private_tmux.sh
. "$ROOT/tests/lib/private_tmux.sh"
SANDBOX=$(mktemp -d)
trap 'private_tmux_cleanup; rm -rf "$SANDBOX"' EXIT
unset AI_AGENT_PREFERENCE AI_SWITCH_AGENT AI_LAUNCH_CONTINUE

# ai-failover beside a fake ai-launch: --peek --auto prints the pick for the preference it got,
# anything else records its arguments and environment, then waits like an agent would.
mkdir -p "$SANDBOX/bin"
cp "$ROOT/utils/.local/bin/ai-failover" "$SANDBOX/bin/"
cat >"$SANDBOX/bin/ai-launch" <<EOF
#!/usr/bin/env bash
if [ "\$1" = --peek ]; then
  echo "\$WAYMUX_QUOTA_PREFERENCE" >"$SANDBOX/pref"
  case "\${FAKE_PICK:-}" in "") set -- \$WAYMUX_QUOTA_PREFERENCE; echo "\$1 --model m" ;; *) echo "\$FAKE_PICK" ;; esac
  exit 0
fi
printf '%s|%s|%s\n' "\$*" "\${AI_LAUNCH_CONTINUE:-}" "\$PWD" >"$SANDBOX/started"
exec sleep 30
EOF
chmod +x "$SANDBOX/bin/ai-launch"
F="$SANDBOX/bin/ai-failover"

# 1. The limited family leaves the preference; the pick comes from what remains.
[ "$(AI_SWITCH_AGENT=claude "$F" --peek)" = $'claude\tagy --model m' ] && ok "claude limited -> agy" || bad "claude: $(AI_SWITCH_AGENT=claude "$F" --peek)"
[ "$(cat "$SANDBOX/pref")" = "agy agyy" ] && ok "claude family dropped from the preference" || bad "pref: $(cat "$SANDBOX/pref")"
AI_SWITCH_AGENT=jail-claude-ask "$F" --peek >/dev/null && [ "$(cat "$SANDBOX/pref")" = "agy agyy" ] &&
  ok "jailed claude counts as claude" || bad "jail family: $(cat "$SANDBOX/pref")"
AI_SWITCH_AGENT=agy "$F" --peek >/dev/null && [ "$(cat "$SANDBOX/pref")" = "claude" ] &&
  ok "agy limited drops agy and agyy" || bad "agy family: $(cat "$SANDBOX/pref")"
WAYMUX_QUOTA_PREFERENCE="claude codex" AI_SWITCH_AGENT=claude "$F" --peek >/dev/null &&
  [ "$(cat "$SANDBOX/pref")" = "codex" ] && ok "WAYMUX_QUOTA_PREFERENCE honoured" || bad "custom pref: $(cat "$SANDBOX/pref")"
! WAYMUX_QUOTA_PREFERENCE=claude AI_SWITCH_AGENT=claude "$F" --peek 2>/dev/null && ok "nothing else to try: refuses" || bad "empty preference accepted"
! FAKE_PICK="jail-claude-ask --model opus" AI_SWITCH_AGENT=claude "$F" --peek 2>/dev/null &&
  ok "a pick in the same family is refused" || bad "same-family pick accepted"
! FAKE_PICK=menu AI_SWITCH_AGENT=claude "$F" --peek 2>/dev/null && ok "no recommendation: refuses" || bad "menu accepted"

# 2. The next agent starts in a new window right after the pane's, in its directory, continuing.
mkdir -p "$SANDBOX/proj"
tmux new-window -d -t _test_bootstrap: -n limited -c "$SANDBOX/proj"
tmux new-window -d -t _test_bootstrap: -n other
pane=$(tmux display-message -p -t _test_bootstrap:limited '#{pane_id}')
limited_idx=$(tmux display-message -p -t "$pane" '#{window_index}')
AI_SWITCH_AGENT=claude "$F" -t "$pane"
for _ in $(seq 50); do [ -s "$SANDBOX/started" ] && break; sleep 0.1; done
[ "$(cat "$SANDBOX/started")" = "agy --model m|1|$SANDBOX/proj" ] && ok "started with AI_LAUNCH_CONTINUE=1 in the pane's directory" ||
  bad "started: $(cat "$SANDBOX/started" 2>/dev/null)"
next_name=$(tmux display-message -p -t "_test_bootstrap:$((limited_idx + 1))" '#{pane_current_command}')
[ "$(tmux display-message -p -t "_test_bootstrap:$((limited_idx + 2))" '#W')" = other ] && [ -n "$next_name" ] &&
  ok "new window sits right after the limited one" || bad "window order: $(tmux list-windows -t _test_bootstrap -F '#I #W')"
tmux has-session -t "$pane" 2>/dev/null && ok "limited window kept" || bad "limited window gone"

# 3. ai-launch-exec with AI_LAUNCH_CONTINUE=1 runs the agent through `ai-memory run`, the harness
# named for its family and the agent as the executable; without it, the agent starts as is.
printf '#!/bin/sh\necho "ai-memory $*" >"%s/exec"\n' "$SANDBOX" >"$SANDBOX/bin/ai-memory"
printf '#!/bin/sh\necho "agyy $*" >"%s/exec"\n' "$SANDBOX" >"$SANDBOX/bin/agyy"
chmod +x "$SANDBOX/bin/ai-memory" "$SANDBOX/bin/agyy"
X="$ROOT/utils/.local/bin/ai-launch-exec"
PATH="$SANDBOX/bin:$PATH" AI_LAUNCH_CONTINUE=1 "$X" agyy --model m
[ "$(cat "$SANDBOX/exec")" = "ai-memory run --executable $SANDBOX/bin/agyy agy --model m" ] &&
  ok "continue runs ai-memory run with the agy harness" || bad "continue: $(cat "$SANDBOX/exec")"
PATH="$SANDBOX/bin:$PATH" "$X" agyy --model m
[ "$(cat "$SANDBOX/exec")" = "agyy --model m" ] && ok "without AI_LAUNCH_CONTINUE: plain start" || bad "plain: $(cat "$SANDBOX/exec")"

echo "ai_failover: all checks passed"
