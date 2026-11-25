#!/usr/bin/env bash
# tests/ai_quota.test.sh — contract test for ai-quota telemetry/model and ai-launch precedence.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ok() { echo "ok: $*"; }
bad() { echo "FAIL: $*" >&2; exit 1; }

# Sandboxed HOME / state / runtime: never the live ~/.claude, ~/.gemini or ~/.local/state.
SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT
export HOME="$SANDBOX/home" XDG_STATE_HOME="$SANDBOX/state" XDG_RUNTIME_DIR="$SANDBOX/run" XDG_CONFIG_HOME="$SANDBOX/config"
mkdir -p "$HOME/.claude/sessions" "$HOME/.gemini/antigravity-cli/log" "$XDG_RUNTIME_DIR" "$SANDBOX/bin"
for b in claude agy-bin; do printf '#!/bin/sh\n' >"$SANDBOX/bin/$b"; chmod +x "$SANDBOX/bin/$b"; done
export PATH="$SANDBOX/bin:$ROOT/utils/.local/bin:$PATH"
unset AI_AGENT_PREFERENCE AI_LAUNCH_AGENT AI_QUOTA_SESSION_RATE AI_LAUNCH_DISABLE
# A shell started through ai-launch carries the wrapper's WAYMUX_* settings; they would point
# these tests at the real quota state and armed-choice file. Drop them.
for _v in $(env | sed -n 's/^\(WAYMUX_\(QUOTA\|LAUNCH\|SWITCH\)_[A-Z_]*\)=.*/\1/p'); do unset "$_v"; done
# The model and precedence checks read the plain rows; §6b covers the jailed default.
export AI_LAUNCH_JAIL=0
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

# 4b. Per-model quota from fetchAvailableModels (fixture, no network): a model with resetTime and
# no remainingFraction is exhausted; the pro tier mapping to the Flash model is reported once.
FIX="$SANDBOX/fixtures"; mkdir -p "$FIX"
iso() { date -u -d "@$1" +%Y-%m-%dT%H:%M:%SZ; }
models() { # <claude remainingFraction or "none"> <flash remainingFraction>
  jq -n --arg c "$1" --argjson f "$2" --arg rc "$(iso $((now + 3600)))" --arg rf "$(iso $((now + 18000)))" '{
    defaultAgentModelId: "claude-opus-5-5-low",
    tieredModelIds: {flash: ["gemini-3.8-flash-tiered"], pro: ["gemini-3.8-flash-tiered"]},
    models: {
      "claude-opus-5-5-low": {quotaInfo: ({resetTime: $rc} + (if $c == "none" then {} else {remainingFraction: ($c | tonumber)} end))},
      "gpt-oss-120b-medium": {quotaInfo: {resetTime: $rc}},
      "gemini-3.8-flash-tiered": {quotaInfo: {remainingFraction: $f, resetTime: $rf}}
    }}'
}
models none 1 >"$FIX/agy.json"
snap=$(AI_QUOTA_FIXTURE_DIR="$FIX" ai-quota --json)
[ "$(jq -r '.agents[1].source' <<<"$snap")" = "api" ] && ok "agy reads the API quota" || bad "agy source: $(jq -c '.agents[1]' <<<"$snap")"
[ "$(jq -c '[.agents[1].groups[] | {key, pct}]' <<<"$snap")" = '[{"key":"claude","pct":100},{"key":"flash","pct":0},{"key":"pro","pct":0}]' ] &&
  ok "Claude/GPT 100% used (no remainingFraction), Gemini Flash 0% used" || bad "groups: $(jq -c '.agents[1].groups' <<<"$snap")"
[ "$(jq -r '.agents[1].level' <<<"$snap")" = "yellow" ] && [ "$(jq -r '.agents[1].default_exhausted' <<<"$snap")" = "true" ] &&
  ok "default model out of quota -> yellow" || bad "agy api level: $(jq -r '.agents[1].level' <<<"$snap")"
report=$(AI_QUOTA_FIXTURE_DIR="$FIX" ai-quota)
[[ "$report" == *"Gemini 4 Argon: no per-model quota in the API"* && "$report" == *"--model gemini-3.8-flash-high"* ]] &&
  ok "report explains Argon and the Gemini fallback" || bad "report: $report"
vis=$(AI_QUOTA_FIXTURE_DIR="$FIX" ai-quota --visual)
[[ "$vis" != *"AI Quota & Burn Telemetry"* && "$vis" == *"█"* && "$vis" == *"▒"* && "$vis" == *"│"* && "$vis" == *"⠛"* && "$vis" == *"Gemini 4 Argon: no per-model quota in the API"* && "$vis" == *"Recommended"*"Antigravity"* ]] &&
  ok "--visual renders bullet gauges, sparklines, Argon note and recommendation" || bad "visual: $vis"
plain=$(sed 's/\x1b\[[0-9;]*m//g' <<<"$vis")
[[ "$(grep -c '⠛' <<<"$plain")" -eq 2 && "$plain" != *"●"* && "$plain" != *"← recommended"* && "$plain" != *"% left"* && "$vis" == *$'\e[97m\e[1m⠛'* ]] &&
  ok "--visual: bright-white ⠛ in an empty left gutter, unified % used, no dots or ragged suffix" || bad "visual marker: $plain"
models 0 0 >"$FIX/agy.json"
snap=$(AI_QUOTA_FIXTURE_DIR="$FIX" ai-quota --json)
[ "$(jq -r '.agents[1].level' <<<"$snap")" = "red" ] && [ "$(jq -r '.agents[1].until' <<<"$snap")" = "$((now + 3600))" ] &&
  ok "every group exhausted -> red until the first reset" || bad "agy all exhausted: $(jq -c '.agents[1] | {level, until}' <<<"$snap")"
[ "$(AI_QUOTA_FIXTURE_DIR="$FIX" ai-quota --badge | grep -c 'C100 G100%')" -eq 0 ] && ok "red badge shows the reset, not percentages" || bad "badge"

# 4b-argon. With cli User-Agent (cl=...), fetchAvailableModels includes gemini-4-argon-* quotaInfo
jq -n --arg rc "$(iso $((now + 3600)))" --arg rf "$(iso $((now + 18000)))" --arg ra "$(iso $((now + 500000)))" '{
  defaultAgentModelId: "gemini-4-argon-medium",
  tieredModelIds: {flash: ["gemini-3.8-flash-tiered"], pro: ["gemini-3.8-flash-tiered"]},
  models: {
    "claude-opus-5-5-low": {quotaInfo: {remainingFraction: 1, resetTime: $rc}},
    "gemini-3.8-flash-tiered": {quotaInfo: {remainingFraction: 0.97, resetTime: $rf}},
    "gemini-4-argon-medium": {quotaInfo: {remainingFraction: 0.25, resetTime: $ra}}
  }}' >"$FIX/agy.json"
snap=$(AI_QUOTA_FIXTURE_DIR="$FIX" ai-quota --json)
[ "$(jq -c '[.agents[1].groups[] | select(.key == "argon") | {key, pct}]' <<<"$snap")" = '[{"key":"argon","pct":75}]' ] &&
  ok "Gemini 4 Argon group parsed (75% used)" || bad "argon group: $(jq -c '.agents[1].groups' <<<"$snap")"
[[ "$(AI_QUOTA_FIXTURE_DIR="$FIX" ai-quota)" == *"Gemini 4 Argon: 75% used"* ]] &&
  ok "report shows Gemini 4 Argon quota" || bad "argon report"
[[ "$(AI_QUOTA_FIXTURE_DIR="$FIX" ai-quota --badge)" == *"C0 G3 A75%"* ]] &&
  ok "badge includes A75% for Gemini 4 Argon" || bad "argon badge: $(AI_QUOTA_FIXTURE_DIR="$FIX" ai-quota --badge)"
[ "$(AI_QUOTA_FIXTURE_DIR="$FIX" ai-launch --peek --auto)" = "agy --model gemini-4-argon-medium" ] &&
  ok "ai-launch recommends default Gemini 4 Argon when it has quota" || bad "argon launch: $(AI_QUOTA_FIXTURE_DIR="$FIX" ai-launch --peek --auto)"

# 4b-neon. Antigravity 1.5.13 defaults to gemini-4-neon-high, with its own per-model quota
jq -n --arg rc "$(iso $((now + 3600)))" --arg rn "$(iso $((now + 18000)))" --arg ra "$(iso $((now + 500000)))" '{
  defaultAgentModelId: "gemini-4-neon-high",
  tieredModelIds: {flash: ["gemini-3.8-flash-tiered"], pro: ["gemini-3.8-flash-tiered"]},
  models: {
    "claude-opus-5-5-low": {quotaInfo: {remainingFraction: 1, resetTime: $rc}},
    "gemini-3.8-flash-tiered": {quotaInfo: {remainingFraction: 0.97, resetTime: $rc}},
    "gemini-4-neon-high": {quotaInfo: {remainingFraction: 0.6, resetTime: $rn}},
    "gemini-4-argon-medium": {quotaInfo: {remainingFraction: 1, resetTime: $ra}}
  }}' >"$FIX/agy.json"
snap=$(AI_QUOTA_FIXTURE_DIR="$FIX" ai-quota --json)
[ "$(jq -c '[.agents[1].groups[] | select(.key == "neon") | {key, pct, abbr}]' <<<"$snap")" = '[{"key":"neon","pct":40,"abbr":"N"}]' ] &&
  ok "Gemini 4 Neon group parsed (40% used, badge N)" || bad "neon group: $(jq -c '.agents[1].groups' <<<"$snap")"
[ "$(jq -r '.agents[1].launch[] | select(.model == "Gemini 4 Neon") | "\(.quota | split(" ⟳")[0]) \(.tier) \(.rec)"' <<<"$snap")" = '40% used $$$$ true' ] &&
  ok "Neon launch row: its quota, top tier, recommended as the default" || bad "neon row: $(jq -c '.agents[1].launch' <<<"$snap")"
[ "$(AI_QUOTA_FIXTURE_DIR="$FIX" ai-launch --peek --auto)" = "agy --model gemini-4-neon-medium" ] &&
  ok "ai-launch recommends default Gemini 4 Neon when it has quota" || bad "neon launch: $(AI_QUOTA_FIXTURE_DIR="$FIX" ai-launch --peek --auto)"

# 4b-weekly. retrieveUserQuotaSummary adds 7d Gemini and Claude/GPT groups with pace and informs levels/launch
jq -n --arg gw "$(iso $((now + 432000)))" --arg g5 "$(iso $((now + 14400)))" --arg cw "$(iso $((now + 580000)))" '{
  groups: [
    {displayName: "Gemini Models", buckets: [
      {bucketId: "gemini-weekly", window: "weekly", remainingFraction: 0.70, resetTime: $gw},
      {bucketId: "gemini-5h", window: "5h", remainingFraction: 0.90, resetTime: $g5}
    ]},
    {displayName: "Claude and GPT models", buckets: [
      {bucketId: "3p-weekly", window: "weekly", remainingFraction: 1, resetTime: $cw},
      {bucketId: "3p-5h", window: "5h", remainingFraction: 1, resetTime: $g5}
    ]}
  ]}' >"$FIX/agy-summary.json"
snap=$(AI_QUOTA_FIXTURE_DIR="$FIX" ai-quota --json)
[ "$(jq -c '[.agents[1].groups[] | select(.key == "gemini_7d" or .key == "claude_7d") | {key, pct, window, abbr: (.abbr // null)}]' <<<"$snap")" = '[{"key":"gemini_7d","pct":30,"window":604800,"abbr":"W"},{"key":"claude_7d","pct":0,"window":604800,"abbr":null}]' ] &&
  ok "weekly groups parsed (Gemini 7d 30% W, Claude/GPT 7d 0%, window 604800)" || bad "weekly groups: $(jq -c '.agents[1].groups' <<<"$snap")"
[[ "$(AI_QUOTA_FIXTURE_DIR="$FIX" ai-quota)" == *"Gemini 7d: 30% used"*"pace:"* && "$(AI_QUOTA_FIXTURE_DIR="$FIX" ai-quota)" == *"Claude/GPT 7d: 0% used"* ]] &&
  ok "report shows Gemini 7d with pace and Claude/GPT 7d" || bad "weekly report: $(AI_QUOTA_FIXTURE_DIR="$FIX" ai-quota)"
[[ "$(AI_QUOTA_FIXTURE_DIR="$FIX" ai-quota --visual | sed 's/\x1b\[[0-9;]*m//g')" == *"Gemini 7d"*"30% used"*"× pace"* ]] &&
  ok "--visual shows Gemini 7d gauge and pace" || bad "weekly visual"
[[ "$(AI_QUOTA_FIXTURE_DIR="$FIX" ai-quota --badge)" == *"W30%"* ]] &&
  ok "badge includes W30% for Gemini 7d" || bad "weekly badge: $(AI_QUOTA_FIXTURE_DIR="$FIX" ai-quota --badge)"
[ "$(jq -r '.agents[1].launch[] | select(.model == "Gemini 4 Neon") | .quota | split(" ⟳")[0]' <<<"$snap")" = '40% · 7d 30%' ] &&
  ok "launch row pairs 5h and 7d percentages" || bad "weekly launch row: $(jq -c '.agents[1].launch' <<<"$snap")"
# Weekly Gemini exhausted (proto3 omits remainingFraction) -> default Gemini exhausted, falls back to Claude Sonnet
jq -n --arg gw "$(iso $((now + 432000)))" --arg cw "$(iso $((now + 580000)))" '{
  groups: [
    {displayName: "Gemini Models", buckets: [{bucketId: "gemini-weekly", window: "weekly", resetTime: $gw}]},
    {displayName: "Claude and GPT models", buckets: [{bucketId: "3p-weekly", window: "weekly", remainingFraction: 1, resetTime: $cw}]}
  ]}' >"$FIX/agy-summary.json"
snap=$(AI_QUOTA_FIXTURE_DIR="$FIX" ai-quota --json)
[ "$(jq -r '.agents[1].level' <<<"$snap")" = "yellow" ] && [ "$(jq -r '.agents[1].default_exhausted' <<<"$snap")" = "true" ] &&
  [ "$(AI_QUOTA_FIXTURE_DIR="$FIX" ai-launch --peek --auto)" = "agy --model claude-sonnet-5-5-medium" ] &&
  ok "Gemini 7d exhausted -> default_exhausted, yellow, launch falls back to Claude Sonnet" || bad "weekly fallback: $(jq -c '.agents[1] | {level, default_exhausted}' <<<"$snap") / $(AI_QUOTA_FIXTURE_DIR="$FIX" ai-launch --peek --auto)"
# All 5h groups exhausted while weekly still has headroom must STILL be red (weekly groups never count as usable models)
models 0 0 >"$FIX/agy.json"
jq -n --arg gw "$(iso $((now + 432000)))" --arg cw "$(iso $((now + 580000)))" '{
  groups: [
    {displayName: "Gemini Models", buckets: [{bucketId: "gemini-weekly", window: "weekly", remainingFraction: 0.70, resetTime: $gw}]},
    {displayName: "Claude and GPT models", buckets: [{bucketId: "3p-weekly", window: "weekly", remainingFraction: 1, resetTime: $cw}]}
  ]}' >"$FIX/agy-summary.json"
snap=$(AI_QUOTA_FIXTURE_DIR="$FIX" ai-quota --json)
[ "$(jq -r '.agents[1].level' <<<"$snap")" = "red" ] && [ "$(jq -r '.agents[1].until' <<<"$snap")" = "$((now + 3600))" ] &&
  ok "all 5h exhausted with weekly headroom stays red until earliest 5h reset" || bad "5h red with weekly: $(jq -c '.agents[1] | {level, until}' <<<"$snap")"
rm -f "$FIX/agy-summary.json"

# 4c. `bash -x ai-quota-agy` (the provider that reads it) never prints the token: a fake token file, a curl stub that answers with
# the fixture, and a secret-tool stub, so no network and no real keyring.
SECRET="FAKE-ACCESS-TOKEN-$$"
jq -n --arg t "$SECRET" --arg e "$(date -d '+1 hour' --iso-8601=seconds)" \
  '{token: {access_token: $t, expiry: $e}, id_token_email: "test@example.invalid"}' \
  >"$HOME/.gemini/antigravity-cli/antigravity-oauth-token"
models none 1 >"$FIX/agy.json"
printf '#!/bin/sh\ncat >/dev/null\ncat "%s"\n' "$FIX/agy.json" >"$SANDBOX/bin/curl"
printf '#!/bin/sh\nexit 1\n' >"$SANDBOX/bin/secret-tool"
chmod +x "$SANDBOX/bin/curl" "$SANDBOX/bin/secret-tool"
rm -f "$XDG_STATE_HOME/ai-quota/agy-models-agy.json"
trace=$(WAYMUX_QUOTA_STATE_DIR="$XDG_STATE_HOME/ai-quota" bash -x "$ROOT/utils/.local/bin/ai-quota-agy" 2>&1)
[ "$(tail -n 1 <<<"$trace" | jq -r '.[0].source')" = "api" ] && ok "token path reaches the API (stubbed)" || bad "token path: $(tail -n 1 <<<"$trace")"
grep -qF "$SECRET" <<<"$trace" && bad "bash -x printed the token" || ok "bash -x never prints the token"
rm -f "$HOME/.gemini/antigravity-cli/antigravity-oauth-token" "$SANDBOX/bin/curl" "$SANDBOX/bin/secret-tool" "$XDG_STATE_HOME/ai-quota/agy-models-agy.json"

# 4d. Forced refresh (`WAYMUX_QUOTA_FORCE=1`) renews a lapsed agyy token via `agy models` (with isolated HOME + D-Bus)
# without ever tracing the refresh token, and respects the cooldown stamp.
mkdir -p "$SANDBOX/agyy-renew/.gemini/antigravity-cli"
REFRESH_SECRET="FAKE-REFRESH-TOKEN-$$"
NEW_SECRET="FAKE-NEW-ACCESS-$$"
jq -n --arg r "$REFRESH_SECRET" \
  '{token: {access_token: "expired", refresh_token: $r, expiry: "2000-01-01T00:00:00Z"}, id_token_email: "sec@example.invalid"}' \
  >"$SANDBOX/agyy-renew/.gemini/antigravity-cli/antigravity-oauth-token"
cat >"$SANDBOX/bin/agy-bin" <<EOF
#!/bin/sh
echo "\$HOME|\$DBUS_SESSION_BUS_ADDRESS|\$*" >>"$SANDBOX/renew.log"
if [ "\$1" = models ] && [ "\$HOME" = "$SANDBOX/agyy-renew" ]; then
  jq -n --arg t "$NEW_SECRET" --arg r "$REFRESH_SECRET" --arg e "\$(date -d '+1 hour' --iso-8601=seconds)" \
    '{token: {access_token: \$t, refresh_token: \$r, expiry: \$e}, id_token_email: "sec@example.invalid"}' \
    >"\$HOME/.gemini/antigravity-cli/antigravity-oauth-token"
fi
EOF
chmod +x "$SANDBOX/bin/agy-bin"
models none 1 >"$FIX/agy.json"
printf '#!/bin/sh\ncat >/dev/null\ncat "%s"\n' "$FIX/agy.json" >"$SANDBOX/bin/curl"
printf '#!/bin/sh\nexit 1\n' >"$SANDBOX/bin/secret-tool"
chmod +x "$SANDBOX/bin/curl" "$SANDBOX/bin/secret-tool"
trace=$(AGYY_HOME="$SANDBOX/agyy-renew" WAYMUX_QUOTA_FORCE=1 WAYMUX_QUOTA_STATE_DIR="$XDG_STATE_HOME/ai-quota" bash -x "$ROOT/utils/.local/bin/ai-quota-agy" 2>&1)
[ "$(tail -n 1 <<<"$trace" | jq -r '.[] | select(.agent == "agyy") | .source')" = "api" ] &&
  ok "forced refresh renews lapsed agyy token via agy models" || bad "agyy renew: $(tail -n 1 <<<"$trace")"
grep -qF "$SANDBOX/agyy-renew|unix:path=/dev/null|models" "$SANDBOX/renew.log" &&
  ok "agyy renewal isolates HOME and DBUS_SESSION_BUS_ADDRESS" || bad "renew env: $(cat "$SANDBOX/renew.log")"
grep -qE "$REFRESH_SECRET|$NEW_SECRET" <<<"$trace" && bad "bash -x leaked renewal token" || ok "bash -x never prints refresh or renewed token"
# Cooldown prevents hammering agy models on back-to-back refreshes when token stays expired
jq -n --arg r "$REFRESH_SECRET" \
  '{token: {access_token: "expired", refresh_token: $r, expiry: "2000-01-01T00:00:00Z"}, id_token_email: "sec@example.invalid"}' \
  >"$SANDBOX/agyy-renew/.gemini/antigravity-cli/antigravity-oauth-token"
: >"$SANDBOX/renew.log"
AGYY_HOME="$SANDBOX/agyy-renew" WAYMUX_QUOTA_FORCE=1 WAYMUX_QUOTA_STATE_DIR="$XDG_STATE_HOME/ai-quota" "$ROOT/utils/.local/bin/ai-quota-agy" >/dev/null
! grep -qF "$SANDBOX/agyy-renew|" "$SANDBOX/renew.log" && ok "renewal cooldown skips repeated agy models calls within 10 min" || bad "cooldown ignored: $(cat "$SANDBOX/renew.log")"
printf '#!/bin/sh\n' >"$SANDBOX/bin/agy-bin"; chmod +x "$SANDBOX/bin/agy-bin"
rm -f "$SANDBOX/bin/curl" "$SANDBOX/bin/secret-tool" "$SANDBOX/renew.log" "$XDG_STATE_HOME/ai-quota/agy-models-"*.json "$XDG_STATE_HOME/ai-quota/agy-renew-"*.ts
rm -rf "$SANDBOX/agyy-renew"

# 5. ai-launch precedence: one-shot arm > AI_LAUNCH_AGENT > recommendation; AI_AGENT ignored
ai-launch --next agyy
[ "$(AI_LAUNCH_AGENT=claude ai-launch --peek)" = "agyy" ] && ok "armed choice wins" || bad "arm precedence"
touch -d '-1 min' "$XDG_RUNTIME_DIR/ai-launch.next"
[ "$(AI_LAUNCH_AGENT=claude ai-launch --peek)" = "claude" ] && ok "stale arm ignored" || bad "stale arm"
rm -f "$XDG_RUNTIME_DIR/ai-launch.next"
out=$(AI_AGENT=claude-code_agent ai-launch --peek)
[ "${out%% *}" = "agy" ] && ok "AI_AGENT marker ignored" || bad "AI_AGENT leak: $out"
[ "$(AI_LAUNCH_AGENT=menu ai-launch --peek)" = "$out" ] && ok "menu without a terminal falls back to auto" || bad "menu fallback"
[ "$(ai-launch --peek claude --model haiku)" = "claude --model haiku" ] && ok "explicit args pass through" || bad "explicit args"
[ "$(ai-launch --peek jail-claude --model opus)" = "jail-claude --model opus" ] && ok "jail-claude choice accepted" || bad "jail-claude choice"

# 6. Recommended model follows quota: Claude green -> opus, yellow -> sonnet; Antigravity with its
# default (Claude) group exhausted -> the Gemini Flash row
rm -f "$XDG_STATE_HOME/ai-quota/claude-samples.tsv"
export AI_AGENT_PREFERENCE=claude # isolate the model mapping from the agent ranking
feed 20 >/dev/null
[ "$(ai-launch --peek --auto)" = "claude --model opus" ] && ok "claude green -> opus" || bad "green: $(ai-launch --peek --auto)"

# 6b. With ai-jail, the Claude rows start jailed with prompts on; where ai-jail would refuse (the
# global ~/.ai-jail inside the project) or with AI_LAUNCH_JAIL=0, plain claude starts.
printf '#!/bin/sh\n' >"$SANDBOX/bin/ai-jail"; chmod +x "$SANDBOX/bin/ai-jail"
mkdir -p "$SANDBOX/proj" "$SANDBOX/elsewhere" && : >"$SANDBOX/proj/.ai-jail" && ln -s "$SANDBOX/proj/.ai-jail" "$HOME/.ai-jail"
out=$(cd "$SANDBOX/elsewhere" && AI_LAUNCH_JAIL=1 ai-launch --peek --auto)
[ "$out" = "jail-claude-ask --model opus" ] && ok "claude rows start jailed with prompts on" || bad "jail default: $out"
out=$(cd "$SANDBOX/proj" && AI_LAUNCH_JAIL=1 ai-launch --peek --auto)
[ "$out" = "claude --model opus" ] && ok "project holding ~/.ai-jail starts plain claude" || bad "refused jail: $out"
[ "$(cd "$SANDBOX/elsewhere" && ai-launch --peek --auto)" = "claude --model opus" ] && ok "AI_LAUNCH_JAIL=0 opts out" || bad "opt-out"
[ "$(ai-launch --peek jail-claude-ask --model sonnet)" = "jail-claude-ask --model sonnet" ] && ok "jail-claude-ask choice accepted" || bad "ask choice"
rm -f "$HOME/.ai-jail" "$SANDBOX/bin/ai-jail"
feed 85 >/dev/null
[ "$(ai-launch --peek --auto)" = "claude --model sonnet" ] && ok "claude yellow -> sonnet" || bad "yellow: $(ai-launch --peek --auto)"
ai-launch --next auto
[ "$(ai-launch --peek)" = "claude --model sonnet" ] && ok "armed auto resolves the recommendation" || bad "armed auto"
rm -f "$XDG_RUNTIME_DIR/ai-launch.next"
unset AI_AGENT_PREFERENCE
feed 99 >/dev/null
models none 1 >"$FIX/agy.json"
[ "$(AI_QUOTA_FIXTURE_DIR="$FIX" ai-launch --peek --auto)" = "agy --model gemini-3.8-flash-medium" ] &&
  ok "agy default exhausted -> Gemini Flash" || bad "agy model: $(AI_QUOTA_FIXTURE_DIR="$FIX" ai-launch --peek --auto)"

# 7. --pick (tmux popup backend) prints the choice instead of exec'ing it; no terminal -> recommendation
pick=$(AI_QUOTA_FIXTURE_DIR="$FIX" ai-launch --pick </dev/null)
[ "$pick" = "$(AI_QUOTA_FIXTURE_DIR="$FIX" ai-launch --peek --auto)" ] && ok "--pick without a terminal prints the recommendation" || bad "--pick fallback: $pick"

# 8. --refresh is silent and serialised (no network: AI_QUOTA_NO_API keeps it local)
[ -z "$(AI_QUOTA_NO_API=1 ai-quota --refresh 2>&1)" ] && ok "--refresh is silent" || bad "--refresh output"
[ -s "$XDG_STATE_HOME/ai-quota/badge" ] && ok "--refresh writes the badge cache" || bad "badge cache missing"

# 8b. --badge-min is a single level-colored glyph for the recommended agent, cached by --refresh
bm=$(AI_QUOTA_FIXTURE_DIR="$FIX" ai-quota --badge-min)
[[ "$bm" == "#[fg="*"]"*"#[default]" && "$bm" != *"%"* && "$bm" != *"│"* ]] &&
  ok "--badge-min is one colored glyph, no numbers" || bad "badge-min: $bm"
[ -s "$XDG_STATE_HOME/ai-quota/badge-min" ] && ok "--refresh writes the badge-min cache" || bad "badge-min cache missing"
for f in tmux/.config/tmux/ai-launch-popup.sh tmux/.config/tmux/ai-quota-popup.sh; do
  ! grep -q 'BADGE_FILE\|--badge' "$ROOT/$f" 2>/dev/null && ok "$f: pure glyph title" || bad "$f still reads the quota badge"
done

# 9. The pick armed by the session picker carries the model and a plain-terminal choice
ai-launch --next claude --model sonnet
[ "$(ai-launch --peek)" = "claude --model sonnet" ] && ok "armed pick keeps its model" || bad "armed args: $(ai-launch --peek)"
rm -f "$XDG_RUNTIME_DIR/ai-launch.next"
ai-launch --next shell
[ "$(ai-launch --peek)" = "shell" ] && ok "armed shell choice" || bad "armed shell"
rm -f "$XDG_RUNTIME_DIR/ai-launch.next"

# 10. Machines without Claude or Antigravity: Devin/Codex choices pass through, and auto falls back
# to whichever agent CLI is installed (system dirs only, so the host's own agents stay out of PATH)
[ "$(ai-launch --peek devin)" = "devin" ] && ok "devin choice accepted" || bad "devin choice"
[ "$(ai-launch --peek codex -m o4)" = "codex -m o4" ] && ok "codex args pass through" || bad "codex args"
mkdir -p "$SANDBOX/only-codex"
printf '#!/bin/sh\n' >"$SANDBOX/only-codex/codex"; chmod +x "$SANDBOX/only-codex/codex"
# Stowed layout: the agy wrapper lives in ~/.local/bin, where ai-quota knows to skip it
mkdir -p "$HOME/.local/bin"
for b in ai-launch ai-quota agy; do ln -sf "$ROOT/utils/.local/bin/$b" "$HOME/.local/bin/$b"; done
ln -sf "$(command -v waymux)" "$HOME/.local/bin/waymux"
# /usr/bin without agent CLIs: agy (Antigravity) installs there on some hosts
mkdir -p "$SANDBOX/sysbin"
for f in /usr/bin/*; do
  case "${f##*/}" in agy | agy-bin | antigravity* | claude | codex | devin | opencode) ;; *) ln -s "$f" "$SANDBOX/sysbin/" ;; esac
done
out=$(PATH="$SANDBOX/only-codex:$HOME/.local/bin:$SANDBOX/sysbin" AI_QUOTA_NO_API=1 ai-launch --peek --auto)
[ "$out" = "codex" ] && ok "codex-only machine -> codex" || bad "codex-only: $out"

# 11. Jailed Claude stays supervised: jail_supervision passes a pane-scoped hook token, the pane
# and the daemon port through --env (never argv), forwards the port and maps waymux read-only.
eval "$(sed -n '/^supervise=()$/,/^}$/p' "$ROOT/utils/.local/bin/ai-launch-exec")"
printf '#!/bin/sh\n[ "$1" = hook-token ] && [ "$2" = "%%5" ] && echo tok123\n' >"$SANDBOX/bin/waymux"
chmod +x "$SANDBOX/bin/waymux"
supervise=(); TMUX_PANE=%5 jail_supervision
got="${supervise[*]}"
want="--env TMUX_PANE --env WAYMUX_HOOK_TOKEN --env WAYMUX_PORT --forward-port 4040 --map $(readlink -f "$SANDBOX/bin/waymux")"
[ "$got" = "$want" ] && ok "jailed claude gets a scoped hook token" || bad "supervise: $got"
[[ "$got" != *tok123* ]] && ok "hook token stays out of argv" || bad "token in argv"
supervise=(); TMUX_PANE= jail_supervision
[ ${#supervise[@]} -eq 0 ] && ok "outside tmux: unsupervised jail" || bad "no-tmux: ${supervise[*]}"
printf '#!/bin/sh\nexit 1\n' >"$SANDBOX/bin/waymux"
supervise=(); TMUX_PANE=%5 jail_supervision
[ ${#supervise[@]} -eq 0 ] && ok "no daemon: unsupervised jail" || bad "no-daemon: ${supervise[*]}"
rm -f "$SANDBOX/bin/waymux"

# 12. The jail sees the real Claude settings (hooks, permission rules): the stow link's target is
# mapped read-only at its own path; a plain file (not a link) is left alone.
eval "$(sed -n '/^pin_settings() {$/,/^}$/p' "$ROOT/utils/.local/bin/ai-launch-exec")"
mkdir -p "$SANDBOX/dot/claude"; echo '{}' >"$SANDBOX/dot/claude/settings.json"
ln -sf "$SANDBOX/dot/claude/settings.json" "$HOME/.claude/settings.json"
supervise=(); pin_settings
[ "${supervise[*]}" = "--map $(readlink -f "$SANDBOX/dot/claude/settings.json")" ] && ok "settings link target mapped read-only" || bad "pin: ${supervise[*]}"
rm "$HOME/.claude/settings.json"; echo '{}' >"$HOME/.claude/settings.json"
supervise=(); pin_settings
[ ${#supervise[@]} -eq 0 ] && ok "plain settings file needs no map" || bad "pin plain: ${supervise[*]}"
rm -f "$HOME/.claude/settings.json"

# 13. ai-launch tags the pane with how it started the agent (`@ai_launch`), so `cockpit restore`
# can start it the same way; a plain shell clears the tag. tmux is a stub: never the live server.
printf '#!/bin/sh\necho "$*" >>"%s/tmux.log"\n' "$SANDBOX" >"$SANDBOX/bin/tmux"; chmod +x "$SANDBOX/bin/tmux"
TMUX_PANE=%9 ai-launch claude --model opus >/dev/null 2>&1
# (waymux launch then lists panes for its shared-worktree warning, so look for the call, not the last line)
grep -qxF -- "-u set-option -p -t %9 @ai_launch claude --model opus" "$SANDBOX/tmux.log" && ok "launch tagged on the pane" || bad "tag: $(cat "$SANDBOX/tmux.log")"
TMUX_PANE=%9 SHELL=/bin/true ai-launch shell >/dev/null 2>&1
grep -qxF -- "-u set-option -p -u -t %9 @ai_launch" "$SANDBOX/tmux.log" && ok "shell clears the tag" || bad "untag: $(tail -3 "$SANDBOX/tmux.log")"
: >"$SANDBOX/tmux.log"; TMUX_PANE= ai-launch claude >/dev/null 2>&1
[ ! -s "$SANDBOX/tmux.log" ] && ok "outside tmux: no tag" || bad "tagged outside tmux"

# 11. Missing history.jsonl under pipefail must not break ai-quota-agy (e.g. fresh agyy profile)
mkdir -p "$SANDBOX/agyy/.gemini/antigravity-cli"
printf '{"token":{"access_token":"x","expiry":"2000-01-01T00:00:00Z"}}\n' >"$SANDBOX/agyy/.gemini/antigravity-cli/antigravity-oauth-token"
snap=$(AGYY_HOME="$SANDBOX/agyy" AI_QUOTA_NO_API=1 ai-quota --json)
[ "$(jq -r '[.agents[] | .agent] | sort | join(",")' <<<"$snap")" = "agy,agyy,claude" ] &&
  ok "missing agyy history.jsonl keeps agy and agyy" || bad "missing history: $(jq -c '[.agents[].agent]' <<<"$snap")"

# 12. AI_LAUNCH_DISABLE and ~/.config/ai-quota/disable hide agents independently and exclude them from recommendations
mkdir -p "$XDG_CONFIG_HOME/ai-quota"
printf '# unpaid subscription\nclaude\n' >"$XDG_CONFIG_HOME/ai-quota/disable"
[ "$(ai-quota --recommend)" = "agy" ] && ok "disable file skips claude in recommend" || bad "disable recommend: $(ai-quota --recommend)"
rows=$(printf '[{"agent":"claude","cli":"Claude Code","model":"opus","rec":true},{"agent":"agy","cli":"Antigravity","model":"neon","rec":false},{"agent":"agyy","cli":"Antigravity ²","model":"neon","rec":false}]' | ai-launch-rows)
[ "$(jq -r '[.[].agent] | join(",")' <<<"$rows")" = "agy,agyy" ] &&
  ok "disable file removes claude (and jail rows), keeps agy + agyy" || bad "disable rows: $rows"
rows_env=$(printf '[{"agent":"claude","cli":"Claude Code","model":"opus","rec":true},{"agent":"agy","cli":"Antigravity","model":"neon","rec":false},{"agent":"agyy","cli":"Antigravity ²","model":"neon","rec":false}]' | AI_LAUNCH_DISABLE="agyy" ai-launch-rows)
[ "$(jq -r '[.[].agent | select(. != "jail-claude")] | join(",")' <<<"$rows_env")" = "claude,agy" ] &&
  ok "AI_LAUNCH_DISABLE=agyy disables only agyy, keeping claude + agy" || bad "env disable rows: $rows_env"
rm -f "$XDG_CONFIG_HOME/ai-quota/disable"
