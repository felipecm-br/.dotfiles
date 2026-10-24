# Handoff: Quota-Aware Agent Launch (`ai-quota` / `ai-launch`)

**Date:** 2026-10-24 · **Branch:** `main` (primary worktree) · **Canonical design:** [quota-aware-agent-selection.md](../architecture/quota-aware-agent-selection.md)

This page records where the work stands and what is still open. For how the system works (data sources, the level model, selection policy), read the canonical doc above. It is not repeated here.

## Goal

New tmux sessions from the session picker (`Prefix + s`) always started `agy`. The user wants to:

1. Choose the CLI per session with direct keys (`a` Antigravity, `c` Claude).
2. See token quota (5h window, weekly window, burn rate, concurrent sessions) when choosing.
3. Pick the **model** as well as the CLI. Quota should *inform* the choice, never force it: Claude may be red, but the user can still start it and switch to a cheaper model.

## Status

| Stage | State | Contents |
| --- | --- | --- |
| `0307c0d` feat(shell) | Committed | `ai-quota` (Claude statusLine recorder, burn-rate model, badge, report), first `ai-launch` (auto-start recommended agent), picker keys `a` / `A` / `c` / `u`, quota badge in the popup title, `startup_command = "ai-launch"`, `statusLine` in Claude settings, skill, tests, docs |
| `423ff4b`, `597e4a0` fix(shell) | Committed (follow-up session) | Antigravity per-model-group quota from `fetchAvailableModels`, token kept out of `bash -x` traces |
| Launch popup | **Uncommitted** | `tmux/.config/tmux/ai-launch-popup.sh` (new; restow `tmux`), `ai-launch --pick`, binds `Prefix + a` / `Ctrl + Shift + A`, keybindings picker entry, docs, test section 7. Headless-tested in a detached tmux; the real `display-popup` is not yet verified visually |
| Quota refresh | **Uncommitted** | `ai-quota --refresh`, stale-while-revalidate in `agy_api`, `ai-quota-refresh.timer` (enabled live, every 2 min), installer `.shell/install/packages/ai-quota.zsh`, popups serve the badge up to 1 h old |
| Launch menu | **Uncommitted** (working tree) | `ai-launch` rewritten as a CLI × model menu; `r` = direct recommended launch; new preset `ai-launch.toml`; tests and docs updated |

Uncommitted files for the launch-menu stage:

```text
utils/.local/bin/ai-launch                         (rewritten: menu, --auto, model policy)
waymaker/.config/waymaker/presets/ai-launch.toml   (new; stowed with ./stow.sh -r waymaker)
waymaker/.config/waymaker/presets/session-picker.toml  (r bind, footer "Enter Menu │ r Auto")
tmux/.config/tmux/session-picker.sh                (comments only)
tests/ai_quota.test.sh                             (sections 5–6: menu fallback, model policy)
agents-skills/.agents/skills/ai-quota/SKILL.md
docs/architecture/quota-aware-agent-selection.md
docs/architecture/workflow-keybindings-matrix.md
docs/shell/waymaker-presets.md
docs/tmux/popups-ergonomics-and-golden-ratio.md
docs/utils.md
intelli-shell/.config/intelli-shell/custom.commands
```

Suggested commit: `feat(shell): add CLI × model launch menu with per-row quota to ai-launch`. Leave out the unrelated working-tree changes (`docs/temp/`, `docs/theme/`, `starship/` presets); they belong to other work.

## Current behavior (session picker, nav mode)

| Key | Action |
| --- | --- |
| `Enter` | Connect; a new session opens the `ai-launch` menu |
| `r` | Connect + recommended agent and model, no menu |
| `a` / `A` / `c` | Connect + `agy` / `agyy` / `claude` with the default model |
| `u` | Full `ai-quota` report |
| `s` / `w` / `Ctrl+S` | Cockpit (`c` used to be Cockpit; the user asked for it to become Claude) |

In the menu the rows keep a fixed order, the cursor starts on the `★` recommended row, typing filters, and `Esc` drops to a plain shell.

## Verification

Done:

- `tests/ai_quota.test.sh`: all checks pass (sandboxed `HOME`, fixtures, no network).
- Menu tested in a detached tmux pane with stub CLIs. `Enter` launches the `★` row; `code son` → `claude --model sonnet`; `haiku` → `claude --model haiku`; `² flash` → `agyy --model gemini-3.8-flash-medium`; `Esc` exits cleanly.
- Session picker preset parses; `r` emits `@agent=auto` + selection.
- `./scripts/docs-lint.sh` passes. `./stow.sh -n` reports only the pre-existing `antigravity` and `temp` conflicts.
- Latency: `ai-quota --json` ≈ 110 ms warm, ≈ 1.1 s on a cold Antigravity API cache (60 s TTL); statusLine path ≈ 30 ms.

**Not yet verified live:**

- [ ] Opening the real `Prefix + s` popup and pressing `Enter` / `r` / `c` on a **new** session.
- [ ] `r` / `a` / `c` on an **existing** session: the agent should open in a new window of the target session. The window is created from inside the popup, so the target relies on tmux's current-client resolution.
- [ ] Popup title badge rendering (tmux `#[fg=…]` styles inside `display-popup -T`). The format expands correctly via `display-message`, but has not been checked visually.

## Open decisions (ask the user)

1. **`unknown` ranks above `yellow`** in the recommender (`ai-quota`, selection block). The `★` can land on an account with no data, such as `agyy` before its first API read, while Claude is merely busy. Proposal: rank `unknown` below `yellow` for agents outside the top preference.
2. **`Prefix + o` latent bug**, not fixed: `tmux.conf` runs `${AI_AGENT:-agy}`, but Claude Code exports `AI_AGENT=claude-code_<version>_agent`, so from a Claude-spawned shell it tries to execute that marker. Suggested fix: `ai-launch` (menu) or `ai-launch --auto`. Needs approval because it changes an established binding (zero-churn rule).
3. Should `Enter` on an **existing** session offer the menu in a new window? Today it only switches.

## Gotchas for the next agent

- `AI_AGENT` is **not** a user preference; never read it. Use `AI_LAUNCH_AGENT` (`claude | agy | agyy | auto | menu`).
- `wm --pos` is a sticky cursor *index*, not an item. The menu preset binds `QueryChange = "Pos(0)"`; removing that bind breaks type-to-pick.
- The menu maps the selection back by its ANSI-stripped line text, so rows must stay unique. Do not put fuzzy-matchable words in the `★` marker.
- The Antigravity model list is cached daily in `~/.local/state/ai-quota/agy-models.tsv` (`agy models`, collapsed to the `-medium` effort per family). A hard-coded fallback list in `ai-launch` covers the first run.
- Gemini 4 Argon has no per-model quota in the API. The menu shows `no quota data`; do not estimate one (skill rule).
- New files in a stow package need `./stow.sh -r <package>` (done for `utils`, `waymaker`, `agents-skills`).
- The `ai-quota` token functions run in `( … )` subshells with xtrace off; keep it that way when editing.

## Next steps

1. Live-verify the three unchecked items above.
2. Reload tmux (`Prefix + r` or `tmux source-file ~/.config/tmux/tmux.conf`) and try `Prefix + a` / `Ctrl + Shift + A`.
3. Commit the launch-menu stage (conventional commit, attribution per repo rules).
4. Settle the open decisions with the user, then update the canonical doc and tests in the same commit.
5. Optional ideas raised earlier: quota badge in the tmux status bar; waymux sound or notification when Claude's 5h projection crosses 90%.
