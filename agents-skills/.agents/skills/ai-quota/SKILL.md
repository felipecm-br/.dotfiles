---
name: ai-quota
description: "Quota-aware AI agent selection and token telemetry for Claude Code (claude) and Antigravity (agy / agyy). Use whenever you need to decide which agent CLI to launch or dispatch work to, check 5h / weekly quota headroom, estimate burn rate across concurrent sessions, explain why ai-launch picked an agent, or extend the quota model. Triggers: quota, rate limit, usage limit, 5h window, weekly limit, burn rate, token budget, which agent should I use, ai-quota, ai-launch, session picker agent choice, RESOURCE_EXHAUSTED, Individual quota reached."
---

# AI Quota Telemetry & Agent Selection

Canonical design and policy: [docs/architecture/quota-aware-agent-selection.md](../../../../docs/architecture/quota-aware-agent-selection.md). Read it before changing thresholds or data sources.

## Commands

| Command | Use |
| --- | --- |
| `ai-quota` | Human report: per-agent level, 5h / 7d %, burn %/h, projection at reset, sessions |
| `ai-quota -v` / `--visual` | Visual TUI dashboard: 20-cell bullet gauges (`█` actual, `▒` projected burn, `│` weekly budget pace marker, `░` headroom) + `10×30m` 5h activity sparklines (also in `Prefix + u` tmux popup, `ai-quota-popup.sh`) |
| `ai-quota --json` | Snapshot for scripts and agents (`.recommend`, `.reason`, `.agents[]`) |
| `ai-quota --recommend` | Print `claude`, `agy` or `agyy` |
| `ai-launch` | CLI × model menu with quota per row (Waymaker `startup_command`) |
| `ai-launch --auto` | Start the recommended agent and model directly (also backs `Prefix + o` 35% right split via `toggle-ai-split.sh`) |
| `ai-launch <agent> [args]` | Force one, e.g. `ai-launch claude --model sonnet` |
| `ai-quota --refresh` | Silent forced refresh of the Antigravity cache and badge (run every 2 min by `ai-quota-refresh.timer`; readers serve up to 15 min stale and refresh in the background) |
| `ai-launch --pick` | Show the menu and print the chosen `<agent> [args]` without starting it (backend of the `Prefix + a` tmux popup, `ai-launch-popup.sh`) |
| `ai-launch --peek [--auto]` | Show what would start (`<agent> [args]` or `menu`), without starting it |

## Agent workflow

1. Before dispatching a sub-agent or a long autonomous run to another CLI, run `ai-quota --json` and read `.agents[] | {agent, level, projected_five, week_pace, until}`.
2. Avoid agents at `red` (exhausted, or projected to hit the cap within 30 min). Prefer `green` over `yellow`.
3. Each extra concurrent session raises the burn rate; check `rate_with_new` before starting parallel Claude agents.
4. Do not add new quota endpoints or token handling beyond what `ai-quota-agy` (the Antigravity provider `ai-quota` passes to `waymux quota`) already does: Antigravity quota comes from `fetchAvailableModels` (using `User-Agent: antigravity/cli/2.0 (aidev_client; cl=9999999999)` so `gemini-4-argon-*` quota is included) with the profile's own token, passed to `curl` on stdin and never refreshed or printed. `AI_QUOTA_NO_API=1` keeps everything local.

## Data contract

- Engine: `waymux quota` (Rust, in the waymux repo). `ai-quota` only sets `WAYMUX_QUOTA_STATE_DIR` (this repo's `ai-quota` state), `WAYMUX_QUOTA_PROVIDERS` (`ai-quota-agy`) and `WAYMUX_QUOTA_PREFERENCE` (`AI_AGENT_PREFERENCE`), then runs it. Antigravity changes go in `ai-quota-agy`; Claude, scoring, rendering and the popup change in waymux.

- Claude samples: `${XDG_STATE_HOME:-~/.local/state}/ai-quota/claude-samples.tsv` (`epoch  five%  seven%  five_resets_at`), written only by `ai-quota statusline` (configured as `statusLine` in `claude/.claude/settings.json`).
- Antigravity: `.agents[] | select(.source == "api") | .groups[] | {key, pct, reset}` (`claude` = Claude & GPT, `flash` = Gemini Flash, `argon` = Gemini 4 Argon, `pro` = pro tier), percent **left**; `default_exhausted` is true when the profile's default model is out of quota. Fallback (`source: "logs"`): 429 lines `Individual quota reached ... Resets in XhYmZs` in `~/.gemini/antigravity-cli/log/cli-*.log` (same path under `$AGYY_HOME` for `agyy`).
- Levels: `green` · `yellow` · `red` · `unknown` (no data yet, treated as usable).
