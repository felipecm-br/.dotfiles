#!/usr/bin/env bash
# tests/ai_launch_models.test.sh — Codex and Devin rows of the launch menu, with their effort levels.
#
# A fake `codex` (temp dir on PATH, never under HOME) prints a fixed `debug models` list, and a
# fixed `devin models` listing stands in for the daily cache, so the rows do not depend on the
# installed CLIs or the account.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$ROOT/utils/.local/bin"
ok() { echo "ok: $*"; }
bad() { echo "FAIL: $*" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "skip: jq not installed"; exit 0; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/state" "$TMP/codex"
cat >"$TMP/bin/codex" <<'EOF'
#!/bin/sh
cat <<'JSON'
{"models":[
 {"slug":"hidden-one","display_name":"Hidden","visibility":"hide","priority":1,"default_reasoning_level":"low","supported_reasoning_levels":[{"effort":"low"}]},
 {"slug":"gpt-5.6-terra","display_name":"GPT-5.6-Terra","visibility":"list","priority":8,"default_reasoning_level":"medium","supported_reasoning_levels":[{"effort":"low"},{"effort":"medium"},{"effort":"high"},{"effort":"xhigh"},{"effort":"max"},{"effort":"ultra"}]},
 {"slug":"gpt-6-luna","display_name":"GPT-6-Luna","visibility":"list","priority":5,"default_reasoning_level":"medium","supported_reasoning_levels":[{"effort":"low"},{"effort":"medium"},{"effort":"high"}]}
]}
JSON
EOF
printf '#!/bin/sh\nexit 1\n' >"$TMP/bin/devin" # present, but the cache below is what is read
chmod +x "$TMP/bin/codex" "$TMP/bin/devin"
echo 'model_reasoning_effort = "xhigh"' >"$TMP/codex/config.toml"
cat >"$TMP/state/devin-models.txt" <<'EOF'
Available models (3 families)

SWE-2 (swe-2)
  aliases: swe
  swe-2-high                         SWE-2 High
  swe-2-medium                       SWE-2 Medium
  swe-2-max                          SWE-2 Max
  swe-2-max-lightning                SWE-2 Max Lightning

Claude Opus 5.5 (claude-opus-5.5)
  claude-opus-5-5-medium             Claude Opus 5.5 Medium
  claude-opus-5-5-low                Claude Opus 5.5 Low
  claude-opus-5-5-high-fast          Claude Opus 5.5 High Fast
  claude-opus-5-5-high               Claude Opus 5.5 High

Kimi K3 (kimi-k3)
  kimi-k3                            Kimi K3
EOF

out=$(PATH="$TMP/bin:$PATH" CODEX_HOME="$TMP/codex" WAYMUX_QUOTA_STATE_DIR="$TMP/state" \
  AI_LAUNCH_DEVIN_FAMILIES="claude-opus-5.5 swe-2 kimi-k3" "$BIN/ai-launch-models")

[ "$(jq -r '[.codex[].model] | join(",")' <<<"$out")" = "GPT-6-Luna,GPT-5.6-Terra" ] ||
  bad "codex: visible models by priority: $(jq -c '.codex' <<<"$out")"
ok "codex: visible models only, ordered by priority"
[ "$(jq -r '.codex[1].args' <<<"$out")" = "--model gpt-5.6-terra --effort xhigh" ] || bad "terra args: $out"
[ "$(jq -r '.codex[0].args' <<<"$out")" = "--model gpt-6-luna --effort medium" ] || bad "luna args: $out"
ok "codex: starts at config.toml's effort when the model has it, else the model's default"
[ "$(jq -r '[.codex[1].efforts[].level] | join(",")' <<<"$out")" = "low,medium,high,xhigh,max,ultra" ] || bad "terra levels"
[ "$(jq -r '.codex[1].efforts[5].args' <<<"$out")" = "--model gpt-5.6-terra --effort ultra" ] || bad "terra ultra args"
ok "codex: each model keeps its own levels (Terra up to ultra)"

[ "$(jq -r '[.devin[].model] | join(",")' <<<"$out")" = "Claude Opus 5.5,SWE-2" ] ||
  bad "devin: families in the configured order, single-model families dropped: $(jq -c '.devin' <<<"$out")"
ok "devin: configured families in order"
[ "$(jq -r '[.devin[0].efforts[].level] | join(",")' <<<"$out")" = "low,medium,high" ] || bad "opus levels: $out"
[ "$(jq -r '[.devin[1].efforts[].level] | join(",")' <<<"$out")" = "medium,high,max" ] || bad "swe levels: $out"
ok "devin: levels in order from the model ids, -fast and -lightning variants left out"
[ "$(jq -r '.devin[0].args' <<<"$out")" = "--model claude-opus-5-5-medium" ] || bad "opus default: $out"
[ "$(jq -r '.devin[1].efforts[2].args' <<<"$out")" = "--model swe-2-max" ] || bad "swe max args: $out"
ok "devin: starts at -medium; a level starts its own model id"

rows=$(echo '[{"agent":"codex","args":"","icon":"X","cli":"Codex","model":"default","quota":"no quota data","level":"unknown"},{"agent":"devin","args":"","cli":"Devin","model":"default"}]' |
  PATH="$TMP/bin:$PATH" CODEX_HOME="$TMP/codex" WAYMUX_QUOTA_STATE_DIR="$TMP/state" AI_LAUNCH_JAIL=0 \
    AI_LAUNCH_DEVIN_FAMILIES="claude-opus-5.5 swe-2" "$BIN/ai-launch-rows")
[ "$(jq 'length' <<<"$rows")" = 4 ] || bad "ai-launch-rows: $rows"
[ "$(jq -r '.[0] | "\(.icon) \(.cli) \(.quota) \(.model)"' <<<"$rows")" = "X Codex no quota data GPT-6-Luna" ] ||
  bad "the model rows keep the default row's icon, title and quota: $rows"
ok "ai-launch-rows replaces each default row with the model rows"
echo "ai_launch_models: all checks passed"
