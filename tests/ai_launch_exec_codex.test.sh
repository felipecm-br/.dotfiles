#!/usr/bin/env bash
# tests/ai_launch_exec_codex.test.sh — ai-launch-exec starts Codex without the shared app-server (U1).
#
# A fake `codex` (in a temp dir) prints the arguments it was given.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXEC="$ROOT/utils/.local/bin/ai-launch-exec"
ok() { echo "ok: $*"; }
bad() { echo "FAIL: $*" >&2; exit 1; }

BIN=$(mktemp -d)
trap 'rm -rf "$BIN"' EXIT
for name in codex agy; do
  printf '#!/usr/bin/env bash\necho "%s $*"\n' "$name" >"$BIN/$name"
  chmod +x "$BIN/$name"
done
export PATH="$BIN:$PATH"
unset AI_LAUNCH_CONTINUE AI_LAUNCH_CODEX_DAEMON

run() { env -u AI_LAUNCH_CONTINUE "$@"; }

out=$(run "$EXEC" codex --model gpt-6)
[ "$out" = "codex --no-daemon --model gpt-6" ] || bad "codex gets --no-daemon first: '$out'"
ok "codex starts with --no-daemon"

out=$(run "$EXEC" codex resume abc)
[ "$out" = "codex --no-daemon resume abc" ] || bad "resume keeps --no-daemon before the subcommand: '$out'"
ok "codex resume keeps --no-daemon"

out=$(run "$EXEC" codex --no-daemon --model gpt-6)
[ "$out" = "codex --no-daemon --model gpt-6" ] || bad "no duplicate --no-daemon: '$out'"
ok "an explicit --no-daemon is not doubled"

out=$(AI_LAUNCH_CODEX_DAEMON=1 "$EXEC" codex --model gpt-6)
[ "$out" = "codex --model gpt-6" ] || bad "AI_LAUNCH_CODEX_DAEMON=1 keeps the shared server: '$out'"
ok "AI_LAUNCH_CODEX_DAEMON=1 opts out"

out=$(run "$EXEC" agy --model x)
[ "$out" = "agy --model x" ] || bad "other agents untouched: '$out'"
ok "other agents are untouched"
