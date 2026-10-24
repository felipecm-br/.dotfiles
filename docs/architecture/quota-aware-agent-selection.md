# Quota-Aware Agent Selection (`ai-quota` / `ai-launch`)

New Tmux sessions opened from the session picker (`Prefix + s`) no longer hard-code `agy`. Waymaker runs `startup_command = "ai-launch"`, which starts the agent with the most quota headroom. One key in the picker forces a specific CLI.

## Picker keys (nav mode: `Esc` from the filter first)

| Key | Action |
| --- | --- |
| `Enter` | Connect; a **new** session starts the recommended agent (`ai-quota --recommend`) |
| `a` | Connect + Antigravity (`agy`) |
| `A` | Connect + Antigravity secondary account (`agyy`) |
| `c` / `C` | Connect + Claude Code (`claude`) |
| `u` | Full quota report (`ai-quota`), any key returns to the picker |
| `s` / `w` / `Ctrl+S` | Switch to Cockpit (`c` moved to Claude; Cockpit keeps its other aliases) |

When `a`, `A` or `c` targets a session that **already exists**, the picker switches to it and opens the agent in a new window. Without this, nothing would launch, because `startup_command` only runs on session creation.

The popup title shows a quota badge, for example `⚡  42·22% ↗ ×4 │  ⏳11:22 │ ² 0p │ → `:

- Claude: 5h% · 7d% used, `↗` when burning ≥ 1 %/h, `×N` live sessions.
- Antigravity: `C<n> G<n>%` = percent **left** for the Claude & GPT group and for Gemini Flash (from the API), `⏳HH:MM` when every group is out; without a valid token, `~N%` of learned capacity or `Np` (prompts in the last 5h).
- `→` shows the agent `Enter` will start. Icon color is the level: green · yellow · red · gray (unknown). These are Tmux ANSI names, so they follow the Omarchy theme.

The badge is cached in `~/.local/state/ai-quota/badge` and refreshed in the background, so the popup opens without waiting on telemetry. It is recomputed inline only when the cache is older than 10 minutes (about 90 ms).

## Data sources

| Agent | Signal | Source |
| --- | --- | --- |
| `claude` | Real 5h / 7d utilization + reset time | `rate_limits` in the Claude Code statusLine JSON, recorded by `ai-quota statusline` |
| `claude` | Burn rate (%/h) | Slope of samples in the current 5h window over the last 60 min |
| `claude` | Sessions (live / active) | `~/.claude/sessions/<pid>.json` with a live `claude` PID / sessions prompted in the last 30 min |
| `agy`, `agyy` | Percent left + reset per group: Claude & GPT (min over `claude-*`, `gpt-oss*`), Gemini Flash and the pro tier (`tieredModelIds.flash` / `.pro`) | `fetchAvailableModels` (`quotaInfo.remainingFraction`, `resetTime`; a model with a reset but no fraction is at 0%), cached 60 s in `~/.local/state/ai-quota/agy-models-<profile>.json` |
| `agy`, `agyy` | Fallback without a token: exhausted until + window (5h / 7d) | `RESOURCE_EXHAUSTED … Resets in XhYmZs` lines in `antigravity-cli/log/cli-*.log` |
| `agy`, `agyy` | Learned 5h capacity | Prompts between `reset − 5h` and the 429 of the last 5h cap hit |
| `agy`, `agyy` | Sessions | Top-level `agy-bin` processes, split by profile `HOME` |

Claude's figures are server-reported through the statusLine. For Antigravity, `ai-quota` calls the same endpoints the agy CLI and `ai-usagebar` use: `loadCodeAssist` once per profile (the project id is cached in `agy-project-<profile>`) and `fetchAvailableModels`. The token is the profile's own: its token file, or the keyring entry (`secret-tool lookup service gemini`) only when that entry's account matches the profile's file. It is passed to `curl` on stdin, never on the command line, and is never refreshed by `ai-quota` (agy refreshes it while it runs; with no valid token the log heuristic applies, so its percentage is an estimate, `~`). The statusLine path (`--line`) never calls the API. `AI_QUOTA_NO_API=1` keeps everything local.

`retrieveUserQuotaSummary` (what `ai-usagebar` reads) only returns the *Claude and GPT models* group for this account, so it cannot show Gemini. **Gemini 4 Argon** has no entry of its own in `fetchAvailableModels`: its levels are built into `agy-bin`, and the API maps the pro tier to `gemini-3.8-flash-tiered`, so the report says so instead of inventing a number.

## Model

For Claude, with `five` / `seven` = used %, `h` = hours to the 5h reset (≤ 5):

```text
per_session = burn / active_sessions        (fallback: AI_QUOTA_SESSION_RATE, default 10 %/h)
burn_new    = burn + per_session             (cost of launching one more session)
projected   = five + burn_new × h
week_pace   = seven / (elapsed_week_fraction × 100)   (1.0 = on budget)
```

| Level | Claude | Antigravity |
| --- | --- | --- |
| `red` | ≥ 98% (5h or 7d), or full in < 30 min at the measured burn | Every group at 0% (API), or an active 429 reset in the future (logs) |
| `yellow` | 5h ≥ 80%, projected ≥ 90% (measured burn only), 7d ≥ 85%, or pace ≥ 1.25× with 7d ≥ 40% | The default model's group at 0% or any group under 20% left (API; the report suggests `--model gemini-3.8-flash-high`), or est. ≥ 80% of learned capacity (logs) |
| `green` | otherwise | otherwise |
| `unknown` | no statusLine sample yet | no valid token and no cap hit observed yet |

Projections only change the level once a burn rate has been **measured** (≥ 2 samples, ≥ 5 min apart, in the current window). The fallback session rate only feeds the `+1 session` estimate in the report, so an assumption never pushes you off your preferred agent.

Selection walks `AI_AGENT_PREFERENCE` (default `claude agy agyy`) and picks the first `green`/`unknown`, then the first `yellow`, then the `red` agent with the earliest reset. When it falls back, `ai-launch` prints a dim one-line reason before starting the agent.

## Precedence in `ai-launch`

1. Explicit argument: `ai-launch claude`
2. One-shot picker choice (`ai-launch --next <agent>`, valid for 30 s, consumed on use)
3. `AI_LAUNCH_AGENT` (pin a default). `AI_AGENT` is deliberately ignored: Claude Code sets it to its own identity marker.
4. `ai-quota --recommend`

## Files

- [`utils/.local/bin/ai-quota`](../../utils/.local/bin/ai-quota): telemetry, model, badge, report, statusLine recorder
- [`utils/.local/bin/ai-launch`](../../utils/.local/bin/ai-launch): launcher used by Waymaker
- [`waymaker/.config/waymaker/session.toml`](../../waymaker/.config/waymaker/session.toml): `startup_command = "ai-launch"`
- [`waymaker/.config/waymaker/presets/session-picker.toml`](../../waymaker/.config/waymaker/presets/session-picker.toml): `a` / `A` / `c` / `u` binds
- [`tmux/.config/tmux/session-picker.sh`](../../tmux/.config/tmux/session-picker.sh): badge title, agent-aware connect
- [`claude/.claude/settings.json`](../../claude/.claude/settings.json): `statusLine` → `ai-quota statusline`
- Agent skill: `agents-skills/.agents/skills/ai-quota/SKILL.md`
