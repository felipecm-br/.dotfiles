#!/usr/bin/env bash
# tests/agent_sudo.test.sh — contract test for agent-sudo (approval popup for privileged commands).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/tests/lib/private_tmux.sh"
ok() { echo "ok: $*"; }
bad() { echo "FAIL: $*" >&2; exit 1; }
S="$ROOT/utils/.local/bin/agent-sudo"
export AGENT_SUDO_PORT=1 XDG_STATE_HOME="$(mktemp -d)" XDG_RUNTIME_DIR="$(mktemp -d)"

bash -n "$S" && ok "syntax" || bad "syntax"
"$S" --help >/dev/null && ok "--help" || bad "--help"

# No attached client (private server is detached): must refuse, not hang.
set +e; "$S" -- true 2>/dev/null; rc=$?; set -e
[ "$rc" = 125 ] && ok "no client -> 125" || bad "expected 125, got $rc"

mk() { d="$(mktemp -d)"; printf '%s\0' "$@" >"$d/argv"; pwd >"$d/cwd"; : >"$d/nosudo"; echo "$d"; }

# Popup side: denial must not execute the command.
d="$(mk touch "$XDG_STATE_HOME/pwned")"
printf 'n' | "$S" --popup "$d" >/dev/null
[ "$(cat "$d/rc")" = 126 ] && [ ! -e "$XDG_STATE_HOME/pwned" ] && ok "deny does not run" || bad "deny ran command"

# Commands that run files the agent can write get the red warning; plain ones do not.
warned() { local d out; d="$(mk "$@")"; out="$(printf 'n' | "$S" --popup "$d")"; grep -q "$WARN" <<<"$out"; }
WARN="build tool"; warned make install && ok "build tool warns" || bad "build tool not flagged"
WARN="inside dir"; warned ./setup.sh && ok "repo-local executable warns" || bad "repo-local not flagged"
WARN="can write"; ! warned /usr/bin/systemctl restart x && ok "system binary: no warning" || bad "false warning"

# Approval runs argv without shell interpolation (metachars stay literal).
d="$(mk echo 'a;touch pwned2')"
printf 'y\n' | "$S" --popup "$d" >/dev/null
grep -qx 'a;touch pwned2' "$d/out" && [ ! -e pwned2 ] && ok "approve, no shell interpolation" || bad "interpolation"
[ "$(cat "$d/rc")" = 0 ] && ok "exit code recorded" || bad "rc"
grep -q APPROVED "$XDG_STATE_HOME/agent-sudo/log" && ok "audit log" || bad "log"

# --- agent-sudod bridge (fake agent-sudo: no popup, no root) ---
D="$ROOT/utils/.local/bin/agent-sudod"
python3 -m py_compile "$D" && ok "agent-sudod compiles" || bad "agent-sudod compile"
FAKE="$(mktemp)"; printf '#!/bin/sh\n[ "$1" = -r ] && echo "reason=$2"; shift 3; printf "argv:%%s\n" "$@"; exit 7\n' >"$FAKE"; chmod +x "$FAKE"
PORT=$((20000 + RANDOM % 20000))
AGENT_SUDO_PORT=$PORT AGENT_SUDO_BIN="$FAKE" python3 "$D" 2>/dev/null & DPID=$!
trap 'kill $DPID 2>/dev/null; private_tmux_cleanup' EXIT
for _ in $(seq 50); do (exec 3<>/dev/tcp/127.0.0.1/$PORT) 2>/dev/null && break; sleep 0.1; done
post() { curl -s -o /tmp/as.$$ -w '%{http_code}' -X POST "http://127.0.0.1:$PORT${2:-/run}" -d "$1"; }
[ "$(post '{"argv":["echo","a b"],"cwd":"/tmp","reason":"t"}')" = 200 ] && ok "bridge accepts valid request" || bad "valid request"
grep -q '"rc": 7' /tmp/as.$$ && grep -q 'argv:a b' /tmp/as.$$ && ok "rc + argv relayed intact" || bad "relay: $(cat /tmp/as.$$)"
[ "$(post 'nope')" = 400 ] && ok "bad JSON -> 400" || bad "bad json"
[ "$(post '{"argv":[],"cwd":"/tmp"}')" = 400 ] && ok "empty argv -> 400" || bad "empty argv"
[ "$(post '{"argv":["x"],"cwd":"relative"}')" = 400 ] && ok "relative cwd -> 400" || bad "cwd"
[ "$(post '{"argv":["x"],"cwd":"/tmp","reason":"a\nb"}')" = 400 ] && ok "multiline reason -> 400" || bad "reason"
[ "$(post '{}' /other)" = 404 ] && ok "other paths -> 404" || bad "404"
rm -f /tmp/as.$$ "$FAKE"
