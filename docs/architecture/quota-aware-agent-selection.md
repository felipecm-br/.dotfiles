# Quota-Aware Agent Selection (`ai-quota` / `ai-launch`)

New Tmux sessions opened from the session picker (`Prefix + s`) no longer hard-code `agy`. Waymaker runs `startup_command = "ai-launch"`, which opens a **CLI × model menu** with live quota on every row. Quota informs the choice; it never makes it. `r` skips the menu and starts the recommendation, and `a` / `A` / `c` start one CLI directly.

The quota engine is `waymux quota` (Claude Code built in, other agents from providers); `ai-quota` is the wrapper the rest of this page calls, and the Antigravity half is the private provider `ai-quota-agy`.
## Picker keys (nav mode: `Esc` from the filter first)

| Key | Action |
| --- | --- |
| `Enter` | Existing session: switch. **New** session: the launch menu (below) opens **inside the popup** first, then the session starts with that pick; `Esc` returns to the picker |
| `r` | Connect + the recommended agent **and model**, no menu (`ai-launch --auto`) |
| `a` | Connect + Antigravity (`agy`) |
| `A` | Connect + Antigravity secondary account (`agyy`) |
| `c` / `C` | Connect + Claude Code (`claude`) |
| `u` | Visual quota & burn telemetry dashboard (`ai-quota --visual`), any key returns to the picker |
| `s` / `w` / `Ctrl+S` | Switch to Cockpit (`c` moved to Claude; Cockpit keeps its other aliases) |

The picker arms the pick with `ai-launch --next <agent> [args]` (valid for 30 s, consumed by the new session's `startup_command`), so the model chosen in the popup reaches the session. A session counts as new only when it is not running (by name or path) and has no `[[session]]` entry in `session.toml`; the others keep their own behaviour and the arm is removed after 10 s.

When `r`, `a`, `A` or `c` targets a session that **already exists**, the picker switches to it and opens the agent in a new window. Without this, nothing would launch, because `startup_command` only runs on session creation.

## Launch menu (`ai-launch`)

One row per CLI × model family, in a **fixed order** so positions stay learnable: Claude Code (Fable, Opus, Sonnet, Haiku), then each Antigravity account with one row per family from `agy models` (cached daily in `~/.local/state/ai-quota/agy-models.tsv`, effort `-medium`), then one `default` row each for Devin and Codex. Only CLIs installed on the machine get rows, so the same menu works on a PC that has Devin or Codex but no `agy`. Devin and Codex have no quota telemetry (`no quota data`), so they are starred only when no Claude or Antigravity row exists. Each row shows a relative cost tier (`$` … `$$$$`) and its quota:

- Claude rows: 5h · 7d used (one shared pool), colored by the Claude level.
- Antigravity rows: percent **left** of the row's group (Claude & GPT, Gemini Flash, Gemini 4 Argon) and its reset time.

The cursor starts on the recommended row (`⠛` superscript shoulder on the left of the agent icon), so `Enter` `Enter` from the session picker launches the smart pick in two keystrokes. Typing filters and jumps to the best match (`QueryChange → Pos(0)`), for example `son` → Claude Sonnet or `² flash` → secondary account Flash. Red rows stay selectable: starting Claude at 95% to work on a cheaper model is a valid choice. Where `ai-jail` can run, the Claude rows (`Claude Code 󰌾`) start Claude inside `ai-jail` with permission prompts on (`ai-launch jail-claude-ask`), so the project directory is the blast radius while held approvals and the phone page keep working; `--auto` does the same. After the plain rows, `Claude YOLO` (lock icon) runs the recommended Claude model jailed with prompts off (`ai-launch jail-claude`, `ai-memory run --true-yolo`), and `Claude Host` runs it unjailed, for work that needs SSH, Docker or the open web (the jail filters egress). `AI_LAUNCH_JAIL=0` brings back the unjailed Claude rows. The jail maps the stowed `~/.claude/settings.json` link's target read-only at its own path, so Claude keeps its hooks and permission rules inside it; `ai-launch` warns in red when that link has been replaced by a plain file, since `~/.claude` stays writable inside the jail. Inside tmux, a jailed row also keeps the agent under waymux supervision with a hook token scoped to its own pane (`waymux hook-token`, passed with `--env`, daemon port forwarded; see [the benchmark §2.3](state-of-the-art-terminal-agent-workflow.md#23-open-finding-host-side-git-in-agent-writable-repositories)); ai-memory hooks still reach the host daemon through the global `forward_ports` (see [ai-jail-memory-guide-en.md](../articles/ai-jail-memory-guide-en.md)). Inside the dotfiles repo, or without `ai-jail`, the Claude rows are plain and there is no YOLO row, because ai-jail refuses a global `~/.ai-jail` that lives inside the project; `ai-launch jail-claude[-ask]` there prints a warning and starts plain `claude` with prompts on. The last row, `Shell`, starts a plain terminal without an agent. `Esc` closes the menu: in the session picker it returns to the picker, so nothing is created until a row is chosen; in a bare `ai-launch` it leaves a plain shell (footer `Esc Shell`). Under `--pick` (the popups) the caller closes instead, so `ai-launch-pick.toml` is layered over the preset and the footer reads `Esc Close`.

Recommended model: Claude green → Opus, yellow → Sonnet, red → Haiku. Antigravity → its default model while that group has quota, otherwise the group with the most quota left (Claude & GPT → Sonnet row, Gemini Flash → Flash row, Gemini 4 Argon → Argon row).

Only the session picker popup carries quota in its title, and only one token: `⚡ → <icon>`, the agent a new session launches, colored by its level (green · yellow · red · gray for unknown; Tmux ANSI names, so they follow the Omarchy theme). Every other quota popup keeps a pure glyph title because its body already shows the numbers (the launch menu rows, the `Prefix + u` gauges). The full badge string stays available as `ai-quota --badge` for scripts:

- Claude: 5h% · 7d% used, `↗` when burning ≥ 1 %/h, `×N` live sessions.
- Antigravity: `C<n> G<n> A<n>%` = percent **left** for the Claude & GPT group, Gemini Flash, and Gemini 4 Argon (from the API), `⏳HH:MM` when every group is out; without a valid token, `~N%` of learned capacity or `Np` (prompts in the last 5h).
- `→` shows the recommended agent (the `⠛` row in the menu, and what `r` starts).

`ai-quota --badge-min` prints that one colored glyph. It is cached in `~/.local/state/ai-quota/badge-min` and kept fresh by the refresh timer below, so the popup opens without waiting on telemetry. It is recomputed inline only when absent or older than an hour (about 90 ms).

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
| `agy`, `agyy` | Percent left + reset per group: Claude & GPT (min over `claude-*`, `gpt-oss*`), Gemini Flash (`tieredModelIds.flash`), Gemini 4 Argon (`gemini-4-argon*`), and the pro tier (`.pro` when distinct from Flash) | `fetchAvailableModels` (`quotaInfo.remainingFraction`, `resetTime`; a model with a reset but no fraction is at 0%), cached 60 s in `~/.local/state/ai-quota/agy-models-<profile>.json` |
| `agy`, `agyy` | Fallback without a token: exhausted until + window (5h / 7d) | `RESOURCE_EXHAUSTED … Resets in XhYmZs` lines in `antigravity-cli/log/cli-*.log` |
| `agy`, `agyy` | Learned 5h capacity | Prompts between `reset − 5h` and the 429 of the last 5h cap hit |
| `agy`, `agyy` | Sessions | Top-level `agy-bin` processes, split by profile `HOME` |

Claude's figures are server-reported through the statusLine. For Antigravity, the provider [`ai-quota-agy`](../../utils/.local/bin/ai-quota-agy) calls the same endpoints the agy CLI and `ai-usagebar` use: `loadCodeAssist` once per profile (the project id is cached in `agy-project-<profile>`) and `fetchAvailableModels`. The token is the profile's own: its token file, or the keyring entry (`secret-tool lookup service gemini`) only when that entry's account matches the profile's file. It is passed to `curl` on stdin, never on the command line, and the functions that hold it run in a subshell with xtrace off, so `bash -x ai-quota-agy` cannot print it; and is never refreshed by it (agy refreshes it while it runs; with no valid token the log heuristic applies, so its percentage is an estimate, `~`). The statusLine path (`--line`) never calls the API. `AI_QUOTA_NO_API=1` keeps everything local.

`fetchAvailableModels` filters out `gemini-4-argon-*` unless the HTTP `User-Agent` header identifies a recent CLI build with a changelist (`cl=...`). `ai-quota-agy` sends `User-Agent: antigravity/cli/2.0 (aidev_client; cl=9999999999)`, so the API returns `gemini-4-argon-low` / `-medium` / `-high` with their weekly `quotaInfo` (`remainingFraction`, `resetTime`) and `defaultAgentModelId: "gemini-4-argon-medium"` alongside the Claude/GPT and Gemini Flash groups.

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
3. `AI_LAUNCH_AGENT` = `claude` | `agy` | `agyy` | `devin` | `codex` | `auto` | `menu` (pin a default). `AI_AGENT` is deliberately ignored: Claude Code sets it to its own identity marker.
4. The menu, or `auto` when there is no terminal (scripts, pipes)

`ai-launch --peek` prints what would start (`<agent> [args]` or `menu`) without starting it. `ai-launch --pick` shows the menu and prints the chosen `<agent> [args]` without starting it; it backs the standalone popup below.

## In-place model / effort switch (`ai-switch`, `Prefix + A`)

`ai-launch` picks the model when an agent starts; [`ai-switch`](../../utils/.local/bin/ai-switch) changes it **while the agent runs**, without a new window. `Prefix + A` opens [`ai-switch-popup.sh`](../../tmux/.config/tmux/ai-switch-popup.sh) over the current pane, titled with the agent icon and current model, and the pick is typed into that agent as its own slash command, so scrollback and conversation stay:

| Agent | Rows | Typed |
|---|---|---|
| Claude Code | Fable, Opus, Sonnet, Haiku · effort `low` … `max`, `auto` | `/model <alias>`, `/effort <level>` |
| Antigravity | Model families (same cache as the launch menu) · effort `low` / `medium` / `high` of the current family, where `agy models` lists it | `/model <family>-<level>` (Antigravity has no `/effort`: the effort is part of the model id, and a model switch keeps the current effort) |
| Devin | Opus, Sonnet, Codex, Fusion | `/model <name>` |
| Codex | One row | `/model` (Codex's own model & reasoning-effort picker) |

`⠛` (upper $2\times2$ Braille superscript shoulder on the left of the row icon) marks the current Claude model (read from its status line) and effort (the transient `/effort` badge, else the per-model level Claude saves in `settings.json`), and the current Antigravity model and effort (read from its footer, `Gemini 4 Argon · high`); the cursor starts on the current model. The agent is found from the pane's foreground command, else the first agent process in its session (Claude under `ai-jail` / `ai-memory run`, `agy-bin` under the wrapper).

A half-typed prompt is never submitted: when text that is not a dim placeholder follows the prompt marker (`❯`, `›`, `>`), [`ai-prompt`](../../utils/.local/bin/ai-prompt) takes the exact draft out through the agent's external-editor hook, the switch runs, and the draft is put back (Codex: after its picker, with `Prefix + V`). Agents started before `$VISUAL=ai-prompt` was set get a status-line message instead. The same tool backs `Prefix + v` (draft in a Neovim popup) and `Prefix + V` (draft stash toggle for any `/command`); see [utils](../utils.md). Claude Code's `/model` and `/effort` also save the pick as the default for new sessions; `ai-launch` always passes `--model`, so sessions started from the launcher are unaffected. `ai-switch sonnet` / `ai-switch high` switch without the menu, `ai-switch --peek` prints the rows.

## Standalone popups (`Prefix + a` / `Ctrl + Shift + A` and `Prefix + u`)

[`ai-launch-popup.sh`](../../tmux/.config/tmux/ai-launch-popup.sh) opens the launch menu in a `75% × 60%` tmux popup from any pane, the same shape as the `awt` popup (badge ` 󰚩 `, magenta ephemeral frame, pure glyph title: the menu rows already carry the quota). `Enter` opens the pick in a **new window** of the originating session, rooted at the pane directory; `Esc` closes with no side effect. It works in sessions that already exist, which the session picker cannot do for `startup_command`. `Prefix + o` ([`toggle-ai-split.sh`](../../tmux/.config/tmux/toggle-ai-split.sh)) toggles a 35% right split running `ai-launch --auto` (honoring `$AI_LAUNCH_AGENT` and ignoring Claude Code's `$AI_AGENT` identity marker).

[`ai-quota-popup.sh`](../../tmux/.config/tmux/ai-quota-popup.sh) (`Prefix + u`, pure glyph title ` 󰓅 `, cyan frame, `75% × 60%`) runs `ai-quota --popup` (`waymux quota --popup`), which renders the `--visual` (`-v`) report: 20-cell Stephen Few bullet gauges (`█` actual usage/headroom, `▒` projected 5h burn at reset, `│` cyan elapsed-week budget pace marker, `░` remaining headroom) and `10×30m` 5h prompt activity sparklines (`·▁▂▃▄▅▆▇█`) across `claude`, `agy`, and `agyy`. The recommended agent carries the same bright-white `⠛` shoulder marker as the launch and switch menus, in a left gutter that stays empty on every other agent (the level word already carries the quota color), and the closing line reads `⠛ Recommended <agent> (<reason>)`. The footer uses the launch menu vocabulary: `Enter Launch │ ⠛ Recommended │ a Models │ r Refresh │ Esc Close`. Inside the popup: `Enter` launches the recommended agent and model in a new window (`ai-launch --auto`), `a` switches in-place to the CLI × model launch menu (`ai-launch --pick`), `r` forces a live refresh (`ai-quota --refresh`), and `u` / `q` / `Esc` dismisses with no side effect.

## Files

- [`utils/.local/bin/ai-quota`](../../utils/.local/bin/ai-quota): thin wrapper for `waymux quota`, which holds the telemetry, model, badges (`--badge`, `--badge-min`), report, visual bullet gauges (`-v` / `--visual`), popup and statusLine recorder; the wrapper keeps the `~/.local/state/ai-quota` state, `AI_AGENT_PREFERENCE` and `AI_QUOTA_SESSION_RATE`, and adds the Antigravity provider
- [`utils/.local/bin/ai-quota-agy`](../../utils/.local/bin/ai-quota-agy): Antigravity provider for `waymux quota` (agy, agyy): `fetchAvailableModels` per profile with the 429-log fallback, printed as agent JSON; kept in the dotfiles because it reads an undocumented API with the profile's token
- [`waymux/.config/waymux/config.toml`](../../waymux/.config/waymux/config.toml) `[quota]`: the popup's `Enter` (`ai-launch --auto`) and `a` (`ai-launch --pick`) commands
- [`utils/.config/systemd/user/ai-quota-refresh.timer`](../../utils/.config/systemd/user/ai-quota-refresh.timer) / [`.service`](../../utils/.config/systemd/user/ai-quota-refresh.service): 2-minute cache refresh
- [`tmux/.config/tmux/ai-launch-popup.sh`](../../tmux/.config/tmux/ai-launch-popup.sh): tmux launcher popup (`ai-launch --popup`, i.e. `waymux launch --popup`) (`Prefix + a`, `Ctrl + Shift + A`)
- [`tmux/.config/tmux/ai-quota-popup.sh`](../../tmux/.config/tmux/ai-quota-popup.sh): visual quota & burn telemetry tmux popup (`Prefix + u`)
- [`tmux/.config/tmux/toggle-ai-split.sh`](../../tmux/.config/tmux/toggle-ai-split.sh): 35% right-side AI split pane toggle backed by `ai-launch --auto` (`Prefix + o`)
- [`utils/.local/bin/ai-launch`](../../utils/.local/bin/ai-launch): thin wrapper for `waymux launch` (menu, `--auto`, `--peek`, `--pick`, `--next`, `@ai_launch` tag) used by Waymaker; it adds ai-quota's providers, the presets below, `$AI_LAUNCH_AGENT` and the two hooks
- [`utils/.local/bin/ai-launch-rows`](../../utils/.local/bin/ai-launch-rows): `[launch] rows_filter` hook: the jail rows (`Claude Code 󰌾`, `Claude YOLO`, `Claude Host`)
- [`utils/.local/bin/ai-launch-exec`](../../utils/.local/bin/ai-launch-exec): `[launch] exec` hook: starts `jail-claude` / `jail-claude-ask` through ai-jail and ai-memory (hook token, settings pin, settings guard)
- [`waymux/.config/waymux/config.toml`](../../waymux/.config/waymux/config.toml) `[launch]`: Claude Code's model rows (`fable`, `opus`, `sonnet`, `haiku`); Antigravity's rows come from `ai-quota-agy` (`launch`)
- [`utils/.local/bin/ai-switch`](../../utils/.local/bin/ai-switch): thin wrapper for `waymux switch` (in-place model / effort switch for the agent in a pane); adds the Antigravity rows, `ai-prompt` as the draft tool and the preset
- [`utils/.local/bin/ai-switch-agy`](../../utils/.local/bin/ai-switch-agy): `[switch] rows_command` hook: Antigravity model families from the `agy models` cache, effort as the family at another level
- [`tmux/.config/tmux/ai-switch-popup.sh`](../../tmux/.config/tmux/ai-switch-popup.sh): `Prefix + A` popup over the current pane (`ai-switch --popup`)
- [`utils/.local/bin/ai-prompt`](../../utils/.local/bin/ai-prompt): agent draft edit popup, stash and restore
- [`waymaker/.config/waymaker/presets/ai-launch.toml`](../../waymaker/.config/waymaker/presets/ai-launch.toml): launch menu preset
- [`waymaker/.config/waymaker/presets/ai-launch-pick.toml`](../../waymaker/.config/waymaker/presets/ai-launch-pick.toml): `--pick` footer overlay (`Esc Close`)
- [`waymaker/.config/waymaker/session.toml`](../../waymaker/.config/waymaker/session.toml): `startup_command = "ai-launch"`
- [`waymaker/.config/waymaker/presets/session-picker.toml`](../../waymaker/.config/waymaker/presets/session-picker-mine.toml): `r` / `a` / `A` / `c` / `u` binds
- [`tmux/.config/tmux/session-picker.sh`](../../tmux/.config/tmux/session-picker.sh): recommended-agent glyph in the title, agent-aware connect
- [`claude/.claude/settings.json`](../../claude/.claude/settings.json): `statusLine` → `ai-quota statusline`
- Agent skill: `agents-skills/.agents/skills/ai-quota/SKILL.md`
