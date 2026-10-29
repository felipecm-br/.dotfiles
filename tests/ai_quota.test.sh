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
[ "$(jq -c '[.agents[1].groups[] | {key, pct}]' <<<"$snap")" = '[{"key":"claude","pct":0},{"key":"flash","pct":100},{"key":"pro","pct":100}]' ] &&
  ok "Claude/GPT 0% (no remainingFraction), Gemini Flash 100%" || bad "groups: $(jq -c '.agents[1].groups' <<<"$snap")"
[ "$(jq -r '.agents[1].level' <<<"$snap")" = "yellow" ] && [ "$(jq -r '.agents[1].default_exhausted' <<<"$snap")" = "true" ] &&
  ok "default model out of quota -> yellow" || bad "agy api level: $(jq -r '.agents[1].level' <<<"$snap")"
report=$(AI_QUOTA_FIXTURE_DIR="$FIX" ai-quota)
[[ "$report" == *"Gemini 4 Argon: no per-model quota in the API"* && "$report" == *"--model gemini-3.8-flash-high"* ]] &&
  ok "report explains Argon and the Gemini fallback" || bad "report: $report"
vis=$(AI_QUOTA_FIXTURE_DIR="$FIX" ai-quota --visual)
[[ "$vis" != *"AI Quota & Burn Telemetry"* && "$vis" == *"█"* && "$vis" == *"▒"* && "$vis" == *"│"* && "$vis" == *""* && "$vis" == *"Gemini 4 Argon: no per-model quota in the API"* && "$vis" == *"recommend:"*"agy"* ]] &&
  ok "--visual renders bullet gauges, sparklines, Argon note and recommendation" || bad "visual: $vis"
models 0 0 >"$FIX/agy.json"
snap=$(AI_QUOTA_FIXTURE_DIR="$FIX" ai-quota --json)
[ "$(jq -r '.agents[1].level' <<<"$snap")" = "red" ] && [ "$(jq -r '.agents[1].until' <<<"$snap")" = "$((now + 3600))" ] &&
  ok "every group exhausted -> red until the first reset" || bad "agy all exhausted: $(jq -c '.agents[1] | {level, until}' <<<"$snap")"
[ "$(AI_QUOTA_FIXTURE_DIR="$FIX" ai-quota --badge | grep -c 'C0 G0%')" -eq 0 ] && ok "red badge shows the reset, not percentages" || bad "badge"

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
[ "$(jq -c '[.agents[1].groups[] | select(.key == "argon") | {key, pct}]' <<<"$snap")" = '[{"key":"argon","pct":25}]' ] &&
  ok "Gemini 4 Argon group parsed (25% left)" || bad "argon group: $(jq -c '.agents[1].groups' <<<"$snap")"
[[ "$(AI_QUOTA_FIXTURE_DIR="$FIX" ai-quota)" == *"Gemini 4 Argon: 25% left"* ]] &&
  ok "report shows Gemini 4 Argon quota" || bad "argon report"
[[ "$(AI_QUOTA_FIXTURE_DIR="$FIX" ai-quota --badge)" == *"C100 G97 A25%"* ]] &&
  ok "badge includes A25% for Gemini 4 Argon" || bad "argon badge: $(AI_QUOTA_FIXTURE_DIR="$FIX" ai-quota --badge)"
[ "$(AI_QUOTA_FIXTURE_DIR="$FIX" ai-launch --peek --auto)" = "agy --model gemini-4-argon-medium" ] &&
  ok "ai-launch recommends default Gemini 4 Argon when it has quota" || bad "argon launch: $(AI_QUOTA_FIXTURE_DIR="$FIX" ai-launch --peek --auto)"

# 4c. `bash -x ai-quota` never prints the token: a fake token file, a curl stub that answers with
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
trace=$(bash -x "$ROOT/utils/.local/bin/ai-quota" --json 2>&1)
[ "$(tail -n 1 <<<"$trace" | jq -r '.agents[1].source')" = "api" ] && ok "token path reaches the API (stubbed)" || bad "token path: $(tail -n 1 <<<"$trace")"
grep -qF "$SECRET" <<<"$trace" && bad "bash -x printed the token" || ok "bash -x never prints the token"
rm -f "$HOME/.gemini/antigravity-cli/antigravity-oauth-token" "$SANDBOX/bin/curl" "$SANDBOX/bin/secret-tool" "$XDG_STATE_HOME/ai-quota/agy-models-agy.json"

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
# /usr/bin without agent CLIs: agy (Antigravity) installs there on some hosts
mkdir -p "$SANDBOX/sysbin"
for f in /usr/bin/*; do
  case "${f##*/}" in agy | agy-bin | antigravity* | claude | codex | devin | opencode) ;; *) ln -s "$f" "$SANDBOX/sysbin/" ;; esac
done
out=$(PATH="$SANDBOX/only-codex:$HOME/.local/bin:$SANDBOX/sysbin" AI_QUOTA_NO_API=1 ai-launch --peek --auto)
[ "$out" = "codex" ] && ok "codex-only machine -> codex" || bad "codex-only: $out"

# 11. Jailed Claude stays supervised: jail_supervision passes a pane-scoped hook token, the pane
# and the daemon port through --env (never argv), forwards the port and maps waymux read-only.
eval "$(sed -n '/^supervise=()$/,/^}$/p' "$ROOT/utils/.local/bin/ai-launch")"
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
