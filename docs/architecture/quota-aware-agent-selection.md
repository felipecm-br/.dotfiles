# Quota-Aware Agent Selection (`ai-quota` / `ai-launch`)

New Tmux sessions opened from the session picker (`Prefix + s`) no longer hard-code `agy`. Waymaker runs `startup_command = "ai-launch"`, which opens a **CLI × model menu** with live quota on every row. Quota informs the choice; it never makes it. `r` skips the menu and starts the recommendation, and `a` / `A` / `c` start one CLI directly.

## Picker keys (nav mode: `Esc` from the filter first)

| Key | Action |
| --- | --- |
| `Enter` | Connect; a **new** session opens the launch menu (below) |
| `r` | Connect + the recommended agent **and model**, no menu (`ai-launch --auto`) |
| `a` | Connect + Antigravity (`agy`) |
| `A` | Connect + Antigravity secondary account (`agyy`) |
| `c` / `C` | Connect + Claude Code (`claude`) |
| `u` | Full quota report (`ai-quota`), any key returns to the picker |
| `s` / `w` / `Ctrl+S` | Switch to Cockpit (`c` moved to Claude; Cockpit keeps its other aliases) |

When `r`, `a`, `A` or `c` targets a session that **already exists**, the picker switches to it and opens the agent in a new window. Without this, nothing would launch, because `startup_command` only runs on session creation.

## Launch menu (`ai-launch`)

One row per CLI × model family, in a **fixed order** so positions stay learnable: Claude Code (Fable, Opus, Sonnet, Haiku), then each Antigravity account with one row per family from `agy models` (cached daily in `~/.local/state/ai-quota/agy-models.tsv`, effort `-medium`). Each row shows a relative cost tier (`$` … `$$$$`) and its quota:

- Claude rows: 5h · 7d used (one shared pool), colored by the Claude level.
- Antigravity rows: percent **left** of the row's group (Claude & GPT, Gemini Flash), reset time; `no quota data` for Gemini 4 Argon.

The cursor starts on the recommended row (`★`), so `Enter` `Enter` from the session picker launches the smart pick in two keystrokes. Typing filters and jumps to the best match (`QueryChange → Pos(0)`), for example `son` → Claude Sonnet or `² flash` → secondary account Flash. Red rows stay selectable: starting Claude at 95% to work on a cheaper model is a valid choice. `Esc` leaves a plain shell.

Recommended model: Claude green → Opus, yellow → Sonnet, red → Haiku. Antigravity → its default model while that group has quota, otherwise the group with the most quota left (Claude & GPT → Sonnet row, Gemini Flash → Flash row).

The popup title shows a quota badge, for example `⚡  42·22% ↗ ×4 │  ⏳11:22 │ ² 0p │ → `:

- Claude: 5h% · 7d% used, `↗` when burning ≥ 1 %/h, `×N` live sessions.
- Antigravity: `C<n> G<n>%` = percent **left** for the Claude & GPT group and for Gemini Flash (from the API), `⏳HH:MM` when every group is out; without a valid token, `~N%` of learned capacity or `Np` (prompts in the last 5h).
- `→` shows the recommended agent (the `★` row in the menu, and what `r` starts). Icon color is the level: green · yellow · red · gray (unknown). These are Tmux ANSI names, so they follow the Omarchy theme.

The badge is cached in `~/.local/state/ai-quota/badge` and kept fresh by the refresh timer below, so the popup opens without waiting on telemetry. It is recomputed inline only when absent or older than an hour (about 90 ms).

### Periodic refresh (no waiting in the popups)

The slow part of a cold read is the Antigravity API (about 0.5 s per account, 1 s or more on a cold connection). It is taken off the popup path in two layers:

1. **Timer.** [`ai-quota-refresh.timer`](../../utils/.config/systemd/user/ai-quota-refresh.timer) runs `ai-quota --refresh` every 2 minutes (and 1 minute after login). It forces a read of both accounts, then rewrites the badge cache. `.shell/install/packages/ai-quota.zsh` enables it; `systemctl --user list-timers ai-quota-refresh.timer` shows the schedule.
2. **Stale-while-revalidate.** A reader that finds a cached Antigravity answer older than 60 s but younger than `AI_QUOTA_MAX_STALE` (default 900 s) uses it immediately and starts `ai-quota --refresh` in the background. Reset times in the cache are absolute, so stale data stays correct apart from the percentages. Only an answer older than 15 minutes (for example right after the laptop wakes) is fetched inline.

`--refresh` is serialised with a lock (`refresh.lock`), so overlapping timers and reader-spawned refreshes never stack. The Claude side needs no polling: Claude Code pushes its rate limits into the statusLine as it works.

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

Claude's figures are server-reported through the statusLine. For Antigravity, `ai-quota` calls the same endpoints the agy CLI and `ai-usagebar` use: `loadCodeAssist` once per profile (the project id is cached in `agy-project-<profile>`) and `fetchAvailableModels`. The token is the profile's own: its token file, or the keyring entry (`secret-tool lookup service gemini`) only when that entry's account matches the profile's file. It is passed to `curl` on stdin, never on the command line, and the functions that hold it run in a subshell with xtrace off, so `bash -x ai-quota` cannot print it; and is never refreshed by `ai-quota` (agy refreshes it while it runs; with no valid token the log heuristic applies, so its percentage is an estimate, `~`). The statusLine path (`--line`) never calls the API. `AI_QUOTA_NO_API=1` keeps everything local.

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

Selection walks `AI_AGENT_PREFERENCE` (default `claude agy agyy`) and picks the first `green`/`unknown`, then the first `yellow`, then the `red` agent with the earliest reset. With `--auto`, `ai-launch` prints the chosen row (dim) before starting the agent.

## Precedence in `ai-launch`

1. Explicit argument: `ai-launch claude --model sonnet`, `ai-launch --auto`, `ai-launch --menu`
2. One-shot picker choice (`ai-launch --next <agent|auto>`, valid for 30 s, consumed on use)
3. `AI_LAUNCH_AGENT` = `claude` | `agy` | `agyy` | `auto` | `menu` (pin a default). `AI_AGENT` is deliberately ignored: Claude Code sets it to its own identity marker.
4. The menu, or `auto` when there is no terminal (scripts, pipes)

`ai-launch --peek` prints what would start (`<agent> [args]` or `menu`) without starting it. `ai-launch --pick` shows the menu and prints the chosen `<agent> [args]` without starting it; it backs the standalone popup below.

## Standalone popup (`Prefix + a` / `Ctrl + Shift + A`)

[`ai-launch-popup.sh`](../../tmux/.config/tmux/ai-launch-popup.sh) opens the same menu in a `75% × 60%` tmux popup from any pane, the same shape as the `awt` popup (badge ` 󰚩 `, magenta ephemeral frame, quota badge in the title). `Enter` opens the pick in a **new window** of the originating session, rooted at the pane directory; `Esc` closes with no side effect. It works in sessions that already exist, which the session picker cannot do for `startup_command`. `Prefix + o` is unchanged.

## Files

- [`utils/.local/bin/ai-quota`](../../utils/.local/bin/ai-quota): telemetry, model, badge, report, statusLine recorder
- [`utils/.config/systemd/user/ai-quota-refresh.timer`](../../utils/.config/systemd/user/ai-quota-refresh.timer) / [`.service`](../../utils/.config/systemd/user/ai-quota-refresh.service): 2-minute cache refresh
- [`tmux/.config/tmux/ai-launch-popup.sh`](../../tmux/.config/tmux/ai-launch-popup.sh): tmux popup wrapper (`Prefix + a`, `Ctrl + Shift + A`)
- [`utils/.local/bin/ai-launch`](../../utils/.local/bin/ai-launch): launch menu and launcher used by Waymaker
- [`waymaker/.config/waymaker/presets/ai-launch.toml`](../../waymaker/.config/waymaker/presets/ai-launch.toml): launch menu preset
- [`waymaker/.config/waymaker/session.toml`](../../waymaker/.config/waymaker/session.toml): `startup_command = "ai-launch"`
- [`waymaker/.config/waymaker/presets/session-picker.toml`](../../waymaker/.config/waymaker/presets/session-picker.toml): `r` / `a` / `A` / `c` / `u` binds
- [`tmux/.config/tmux/session-picker.sh`](../../tmux/.config/tmux/session-picker.sh): badge title, agent-aware connect
- [`claude/.claude/settings.json`](../../claude/.claude/settings.json): `statusLine` → `ai-quota statusline`
- Agent skill: `agents-skills/.agents/skills/ai-quota/SKILL.md`
