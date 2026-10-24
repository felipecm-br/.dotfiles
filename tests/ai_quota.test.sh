#!/usr/bin/env bash
# tests/ai_quota.test.sh — contract test for ai-quota telemetry/model and ai-launch precedence.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ok() { echo "ok: $*"; }
bad() { echo "FAIL: $*" >&2; exit 1; }

# Sandboxed HOME / state / runtime: never the live ~/.claude, ~/.gemini or ~/.local/state.
SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT
export HOME="$SANDBOX/home" XDG_STATE_HOME="$SANDBOX/state" XDG_RUNTIME_DIR="$SANDBOX/run"
mkdir -p "$HOME/.claude/sessions" "$HOME/.gemini/antigravity-cli/log" "$XDG_RUNTIME_DIR" "$SANDBOX/bin"
for b in claude agy-bin; do printf '#!/bin/sh\n' >"$SANDBOX/bin/$b"; chmod +x "$SANDBOX/bin/$b"; done
export PATH="$SANDBOX/bin:$ROOT/utils/.local/bin:$PATH"
unset AI_AGENT_PREFERENCE AI_LAUNCH_AGENT AI_QUOTA_SESSION_RATE
: >"$HOME/.claude/history.jsonl"
: >"$HOME/.gemini/antigravity-cli/history.jsonl"

now=$(date +%s); r5=$((now + 7200)); r7=$((now + 3 * 86400))
feed() { # <five%> : push a statusLine payload (epoch five reset, ISO weekly reset)
  printf '{"model":{"display_name":"Opus"},"rate_limits":{"five_hour":{"used_percentage":%s,"resets_at":%s},"seven_day":{"used_percentage":22,"resets_at":"%s"}}}' \
    "$1" "$r5" "$(date -u -d "@$r7" +%Y-%m-%dT%H:%M:%S.000Z)" | ai-quota statusline
}

# 1. statusline records and renders
mkdir -p "$XDG_STATE_HOME/ai-quota"
printf '%s\t30\t20\t%s\n%s\t36\t21\t%s\n' $((now - 2400)) "$r5" $((now - 1200)) "$r5" >"$XDG_STATE_HOME/ai-quota/claude-samples.tsv"
line=$(feed 42)
[[ "$line" == *"5h 42%"* && "$line" == *"7d 22%"* ]] && ok "statusline renders 5h/7d" || bad "statusline: $line"
[ "$(wc -l <"$XDG_STATE_HOME/ai-quota/claude-samples.tsv")" -eq 3 ] && ok "sample appended" || bad "sample not appended"

# 2. burn rate from samples (30% -> 42% over 40 min = 18 %/h), ISO weekly reset parsed
snap=$(ai-quota --json)
[ "$(jq '.agents[0].rate' <<<"$snap")" = "18" ] && ok "burn rate 18 %/h" || bad "rate: $(jq '.agents[0].rate' <<<"$snap")"
[ "$(jq '.agents[0].seven_reset' <<<"$snap")" = "$r7" ] && ok "ISO resets_at parsed" || bad "seven_reset"
# No active sessions -> new session costs AI_QUOTA_SESSION_RATE (10): 42 + (18 + 10) x 2h = 98 -> yellow
[ "$(jq '.agents[0].projected_five' <<<"$snap")" = "98" ] && ok "projection at reset 98%" || bad "projection: $(jq '.agents[0].projected_five' <<<"$snap")"
[ "$(jq -r '.agents[0].level' <<<"$snap")" = "yellow" ] && ok "claude yellow on projection" || bad "claude level"

# 3. Antigravity 429 with future reset -> red; preference falls back to claude
stamp=$(date -d "@$((now - 600))" +%m%d\ %H:%M:%S)
echo "E${stamp}.000000 1 errorreport.go:224] RESOURCE_EXHAUSTED (code 429): Individual quota reached. Please upgrade your subscription to increase your limits. Resets in 4h20m0s." \
  >"$HOME/.gemini/antigravity-cli/log/cli-$(date +%Y%m%d)_000000.log"
snap=$(AI_AGENT_PREFERENCE="agy claude" ai-quota --json)
[ "$(jq -r '.agents[1].level' <<<"$snap")" = "red" ] && ok "agy exhausted -> red" || bad "agy level"
[ "$(jq -r '.agents[1].window' <<<"$snap")" = "5h" ] && ok "agy window 5h" || bad "agy window"
[ "$(jq -r '.recommend' <<<"$snap")" = "claude" ] && ok "fallback to claude" || bad "recommend: $(jq -r .recommend <<<"$snap")"

# 4. Claude at the cap -> recommend the next agent with headroom
rm -f "$HOME/.gemini/antigravity-cli/log/"*.log
feed 99 >/dev/null
[ "$(ai-quota --recommend)" = "agy" ] && ok "claude red -> agy" || bad "recommend with claude red"

# 5. ai-launch precedence: one-shot arm > AI_LAUNCH_AGENT > recommendation; AI_AGENT ignored
ai-launch --next agyy
[ "$(AI_LAUNCH_AGENT=claude ai-launch --peek)" = "agyy" ] && ok "armed choice wins" || bad "arm precedence"
touch -d '-1 min' "$XDG_RUNTIME_DIR/ai-launch.next"
[ "$(AI_LAUNCH_AGENT=claude ai-launch --peek)" = "claude" ] && ok "stale arm ignored" || bad "stale arm"
rm -f "$XDG_RUNTIME_DIR/ai-launch.next"
[ "$(AI_AGENT=claude-code_agent ai-launch --peek)" = "agy" ] && ok "AI_AGENT marker ignored" || bad "AI_AGENT leak"
