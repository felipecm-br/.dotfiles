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
| `ai-quota --json` | Snapshot for scripts and agents (`.recommend`, `.reason`, `.agents[]`) |
| `ai-quota --recommend` | Print `claude`, `agy` or `agyy` |
| `ai-launch [agent]` | Start the recommended (or forced) agent; Waymaker `startup_command` |
| `ai-launch --peek` | Show what would start, without starting it |

## Agent workflow

1. Before dispatching a sub-agent or a long autonomous run to another CLI, run `ai-quota --json` and read `.agents[] | {agent, level, projected_five, week_pace, until}`.
2. Avoid agents at `red` (exhausted, or projected to hit the cap within 30 min). Prefer `green` over `yellow`.
3. Each extra concurrent session raises the burn rate; check `rate_with_new` before starting parallel Claude agents.
4. Never call private quota endpoints or read OAuth tokens. All data is local: the Claude statusLine feed and Antigravity logs and history.

## Data contract

- Claude samples: `${XDG_STATE_HOME:-~/.local/state}/ai-quota/claude-samples.tsv` (`epoch  five%  seven%  five_resets_at`), written only by `ai-quota statusline` (configured as `statusLine` in `claude/.claude/settings.json`).
- Antigravity: 429 lines `Individual quota reached ... Resets in XhYmZs` in `~/.gemini/antigravity-cli/log/cli-*.log` (same path under `$AGYY_HOME` for `agyy`).
- Levels: `green` · `yellow` · `red` · `unknown` (no data yet, treated as usable).
