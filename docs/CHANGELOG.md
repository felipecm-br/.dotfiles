# Changelog

What changed in these dotfiles, week by week, and **whether it works on a restricted host** (no `sudo`, some apps not allowed). Each entry carries one or more tags from the [Portability Matrix](architecture/portability-matrix.md):

- `portable`: needs only the tool it configures, in `$HOME`.
- `needs: <app>`: works once that app runs (Rust tools such as `wm`, `waymux`, `lazygitrs` run from `~/.local/bin` without root).
- `needs: root`: writes outside `$HOME` or runs privileged commands.
- `host-only`: specific to this machine (Omarchy, Hyprland, its hardware or accounts).

The commit hashes link each entry to the full change (`git show <hash>`). Weeks are ISO weeks, newest first. History before October 2026 is covered by the matrix, not listed here. To draft a new week, run [`scripts/changelog-draft.sh`](../scripts/changelog-draft.sh).

## Unreleased

### AI agents
- `Ctrl + S` (no prefix) stashes an agent's draft on every agent, like Claude Code's own `Ctrl + S`, and brings it back by itself once the `/command` ran; shells, Neovim and popups keep their `Ctrl + S`. `Prefix + S` opens the stash & presets picker, where `p` now pins or unpins and `Enter` on the queue tab sends the queued prompt now. Stash moves return in ~90 ms instead of ~280 ms. (`tmux`, `utils`, `waymaker`) `needs: waymux, wm`
- `Prefix + V` stashes now persist: every stash also goes on a stack (`~/.local/state/waymux/prompt-stash.jsonl`, 50 entries, `0600`) that survives a tmux or host restart, and the Command Palette's *AI Prompt Stash & Presets* puts any of them, or a preset pinned at `0`–`9`, into any agent's prompt; `Tab` there shows the pane's delivery queue to edit or drop. `stash --after-cmd` (or `AI_PROMPT_AUTO_RESTORE=1`) brings the draft back by itself once the `/command` ran. (`utils`, `tmux`, `waymaker`) `needs: waymux, wm, jq`
- `ai-prompt` (`Prefix + v` / `V`, `Prefix + A`) now drives OpenCode too, through its `Ctrl+X E` editor key. (`utils`) `needs: waymux`
- `Prefix + F` carries an unsent draft from the limited agent into the replacement agent's prompt. (`utils`) `needs: waymux`
- `Prefix + Z` lists the pane's agent turns (`waymux checkpoint`) with each turn's diff and restores one behind a confirm: `/rewind` for every agent. (`tmux`, `waymaker`) `needs: waymux, wm`
- `Prefix + b` asks a side question (`/btw`) about what a pane is doing, answered by a headless, hook-free `claude -p` / `codex exec` / `agy -p` from the pane's tail and `git status`, without touching its agent. (`tmux`) `needs: claude | codex | agy`
- With waymux after 0.13 (branch `feat/cli-parity`): a queued prompt waits as `held` while you have a draft in that agent's prompt instead of being pasted into it, and the Prompt Stash's queue tab sends one now (`S`, `waymux queue send`) or edits it in place (`waymux queue edit`); `waymux goal <pane> --check <cmd>` keeps an agent going until a check passes; the Cockpit preview shows the last turn's files and commands; `Prefix + Z` shows each turn's age. (`tmux`, `waymaker`, `intelli-shell`) `needs: waymux > 0.13`
- `ai-inventory` lists the MCP servers and skills of Claude Code, Codex, OpenCode and Antigravity, flags duplicates, missing commands and broken links, and shows each skill's context cost; the Command Palette opens it as a picker. (`utils`, `waymaker`) `portable`
- Agents and scripts get five `waymux` verbs with one exit-status table (3 unknown or ambiguous pane, 4 daemon down): `waymux run --wait` runs a command in a new window or a split without taking the focus and returns its exit status, `waymux wait <pane>` blocks until an agent is idle, `waymux events --json` streams state changes, `waymux report <state>` lets any script show in the status bar and Cockpit, and `waymux api list | describe | call` reaches the JSON-RPC methods without `curl`; all are in the `Ctrl + T` palette. `needs: waymux ≥ 0.13, tmux`
- An agent that ends its turn waiting on its own build, test run or Monitor shows as `background`: a slow honeycomb spinner (`󰫃`→`󰫈`, 2.5 s) in working's blue instead of the thinking spinner, no stall alert, and `Prefix + I` skips it; the window picker shows it as `󰫈`. `needs: waymux ≥ 0.12`
- The Cockpit animates `background` agents with the same slow honeycomb fill as the tmux tab, instead of a still `󰫈`. `needs: waymux ≥ 0.12.1, wm ≥ 0.8`
- `ai-quota`, `ai-quota --visual` (`Prefix + u`) and `ai-launch` now report Antigravity quota as **percent used** (`% used`) like Claude Code instead of percent left, unify color thresholds across all agents on **`0–69%` green · `70–89%` yellow · `90–100%` red**, and fold the 5h prompt sparkline and `1h/5h` prompt counter into the agent header row with column-aligned reset countdowns (`⟳ 1h13m (20:27)`). `needs: waymux ≥ 0.10`
- `ai-launch` and `ai-switch` pick the effort too: `Ctrl + H` / `Ctrl + L` (or `←` / `→`) step a thermal-colored gauge in the footer for the agent under the cursor (`━━●── high`: `low` blue · `medium` green · `high` yellow · `xhigh` orange · `max` red · `ultra` violet). Claude starts with `--effort`, Codex with `-c model_reasoning_effort=<level>`, Antigravity with that model's `-low` / `-high` id, and `ai-switch` types `/effort` after `/model`, so its Claude menu lists only the models. `needs: waymux ≥ 0.10, wm ≥ 0.6`
- The launch menu lists Codex's and Devin's models instead of one `default` row each, each with its own effort scale on the gauge (Codex GPT-5.6-Terra up to `ultra`, Devin through the model id); `AI_LAUNCH_DEVIN_FAMILIES` picks the Devin families (default `swe-1.6-slow`, the only one Devin's free plan starts). `needs: waymux ≥ 0.10`
- `Prefix + A` switches Codex and Devin the same way: their listed models, the effort on the gauge, typed as `/model <slug> --reasoning=<level>` (Codex, this session only) or `/model <id>` (Devin); Codex no longer opens its own picker. `needs: waymux ≥ 0.10`
- Codex panes show working, waiting and idle in the status bar, Cockpit and triage like the other agents, and their session id is kept for `cockpit restore`: its hooks now call `waymux` as well as `workmux` through `codex-hook`, which finds the session's real pane because Codex runs every hook in one shared server (new `codex` package; Codex asks once to trust the new hooks). An idle Codex pane closes without the confirmation popup once it has reported. `needs: codex, waymux, jq`
- `ai-upstream` reports what changed upstream of the AI workflow: dependency releases newer than what is installed, upstream lazygitrs commits with a cherry-pick dry run each, and what the benchmark competitors shipped, with an adoption mode from each license. `ai-scout` ranks new and trending GitHub repositories that could improve it. The `ai-upstream-watch` and `ai-scout` skills turn both reports into decisions. `needs: gh`

### tmux
- The close confirmations (`Prefix + w` / `x` / `W`, `d` in the window picker) ask one question (`Close tab 1?`), say in one line what closing stops, and list only busy agents, each with its own agent icon in the status bar's state color: one warning icon instead of five, and the Waymaker popup footer `y Close │ n/Esc Keep`. `portable`
- After a reboot, an agent started with its permission prompts off (`Claude YOLO`) resumes with them on; start it again from `Prefix + a` to turn them off. `needs: waymux, ai-jail`
- Pickers draw their first row in about 25 ms instead of about 135 ms inside tmux: 17 presets that never show images skip Waymaker's terminal-graphics probe. `needs: wm`
- Tab completion (`ftb`) and the Neovim picker lose the black selection strip and get a bold cursor row. `needs: wm`
- The keybindings HUD runs the real triage jump for `Ctrl+Shift+I` and `Prefix + I` (it named a script that no longer exists). `needs: waymux`

### Other
- `stow-relink` (with `stow-relink.path`) puts back the `shell.json` symlink that Omarchy's shell replaces with a plain file on every bar change, after saving the new content into the repo. (`utils`, `omarchy`) `portable`
- `shell.json` follows the Omarchy 4.5 bar schema: the bar is `glassy` (the `background` key replaces `transparent`), the removed `centerAnchor` is gone, the `ai-usagebar` widget (never installed as an Omarchy plugin) is off the bar, and the Superwhisper panel sits on the bar next to the tray instead of inside its drawer; `hyprland.lua` gains the stock `omarchy_default_gestures` hint. (`omarchy`, `hypr`) `host-only`
- `omarchy-clean reset | status | remove` keeps a stock Omarchy test user, created like the installer creates the owner (`/etc/skel` + `omarchy-provision-user`), to try each update's new defaults without these dotfiles. (`utils`, `intelli-shell`) `host-only`, `needs: root`
- `install.zsh` now builds `wm` (waymaker) and `lazygitrs` from GitHub with cargo, so a fresh machine gets every picker and `Ctrl + G` without hand-built binaries; the [bootstrap README](../.shell/install/README.md#3-fresh-omarchy-install) has a fresh Omarchy 4.5 install checklist. (`.shell/install`) `needs: cargo`
- The Omarchy menu plugin moves the selection with `Ctrl + J` / `Ctrl + K` (and `Ctrl + N` / `Ctrl + P`) like Vim, besides the arrow keys. `host-only`
- Every `wm` picker exits on the first `Ctrl + C` (the new `Abort` action), and `?`, `shift-?` and `*` (help, switch preview, bookmark) act only in navigation mode, so they can be typed into the query; `F1` still opens help. `needs: wm ≥ 0.7.2`
- The `git` package now manages the global ignore file (`~/.config/git/ignore`), which also ignores lazygitrs's `.lazygitrs.port` runtime file in every repository. `portable`

### Docs
- Agent workflow benchmark re-audited on 4 Nov: still 8.75 / 10 against TUIOS 8.18; fut added at 6.13, Orca 1.4.248 and T3 Code 0.1.7 re-scored, seven new entrants in the radar.

## 2026-W45 (2–8 Nov)

### AI agents
- `Prefix + F` continues an agent that hit its usage limit in the next agent with quota, in a new window beside it, in the same `ai-memory` workstream; Claude's `StopFailure` hook marks the limited pane red with `usage limit` (d6400b6). `needs: waymux ≥ 0.9, ai-memory`
- `waymux` 0.9.0: type a prompt into an agent and read its last turn's diff from the phone page; pair with `waymux phone-token --prompt --url` (waymux repository). `needs: waymux ≥ 0.9, tailscale`

### Docs
- Agent workflow benchmark re-audited against TUIOS 0.12 and Orca 1.4.246: 8.75 / 10 against 8.18 (814c4a5).
- New [Portability Matrix](architecture/portability-matrix.md) and this changelog.

## 2026-W44 (26 Oct – 1 Nov)

### AI agents
- Claude starts inside `ai-jail` with permission prompts on by default in `ai-launch`; `Claude YOLO` turns prompts off, `Claude Host` runs unjailed (4d6d91c, 691b890). `needs: ai-jail`
- Jailed Claude stays under `waymux` supervision through a hook token scoped to its own pane (acd15e8). `needs: waymux, ai-jail`
- `agent-sudo` approval popup and the `agent-sudod` bridge let a jailed agent ask for a privileged command that you approve with `y`; early keys are ignored and agent-written code is flagged (e765505, c1a4b80). `needs: root` (by design), `ai-jail`
- `awt-fan` runs one prompt in up to 8 worktrees across agents, gated on quota, with a compare popup, sandboxed test checks and token counts (8817f1b, 32dfe64). `needs: waymux, wm, ai-jail`
- `Prefix + A` switches the model or effort of the agent in the current pane in place; `Prefix + v` / `Prefix + V` edit or stash its prompt draft (f53e6b5, e33fe06, fe0bd8c). `needs: waymux`
- `ai-launch` also offers Devin and Codex (9d0ec48); `cnm` starts Claude without `ai-memory` (e021db2, 5fa1cc0). `portable` for `cnm`
- `ai-launch`, `ai-quota`, `ai-switch`, the Cockpit and triage became thin wrappers over `waymux launch / quota / switch / cockpit / triage` (2dc053b, 19f300c, 3a03f2b, 09dd2dc, dc8b2d6). `needs: waymux ≥ 0.8`
- `ai-memory` config moved out of its data dir; Claude in `ai-jail` starts through `ai-memory run` (baebdcb, 11fdff5, 093f7cc). `needs: ai-memory`
- `openbot` wrapper and installer (e3c2c71). `needs: bun`

### tmux
- The Cockpit comes back after a reboot: a snapshot is taken at shutdown, and the first tmux session restores every pane and resumes each Claude the way it was started (e08bfb2, 8e99fc9, e46cd44, 3c43655). `needs: waymux`; the shutdown snapshot uses a user unit (no root)
- Popup look unified: cyan `│` cursor bar from the first frame, no black selection strip, unselected rows dimmed in selection menus (b9d9558, ee58371). `needs: wm`
- Recommended-agent marker standardized across the usage and launch popups (9a719c3, b7d2513, 3f4c762, 3632a27). `needs: waymux`
- Personal keys layered over Waymaker's bundled pickers (9d4eddb). `needs: wm`

### Shell & git
- `core.fsmonitor` is off for every git on the host, so an agent-written repository config cannot make your prompt run a program (3389ec2). `portable`
- `awt` refuses unknown flags instead of reading them as branch names (dd78587). `portable`

### Other
- Kanagawa Starship presets added, the Chroma Crest set removed (fced721, ebfb2dd, e4a3abb). `portable` (starship)
- Hermes, Bitwarden CLI and openbot added to the installer (3c5060f, fd4adac). `needs: root` (installer)

## 2026-W43 (19–25 Oct)

### AI agents
- Quota-aware agent selection: `ai-quota` reads Claude's 5h / 7d usage and Antigravity's quota per model group; `ai-launch` ranks CLI × model rows by quota; `Prefix + a` opens the launcher, `Prefix + u` the visual quota popup (0307c0d, 423ff4b, 597e4a0, f67d9bf, af6c778, 2fe3583, 873495c). `needs: waymux, wm`; Antigravity rows `host-only`
- Claude Code prompts can be answered from the Cockpit through the held `PermissionRequest` hook (50e155a, f4f3bf6, c263b65). `needs: waymux`
- Claude agent-state hooks and window icon; the repository's agent skills linked into `~/.claude/skills` (ef93096, 7e9ecf5, 66959ff, 3c7b5c2). `needs: claude`
- Devin CLI package with `waymux` hooks (2b4e67a). `needs: devin`
- Every program and state glyph comes from the `waymux` icon registry; each agent state has its own glyph shape (d60c836, c96afb7, f9579ff). `needs: waymux`

### tmux
- The review state (`󰷋`) clears only after a real review in lazygitrs, not a glance (1bb7b6b). `needs: waymux, lazygitrs`
- Key telemetry logs shortcut presses and mouse clicks and suggests faster paths (3002516, bca36d1). `needs: waymux`
- VS Code-style command palette on `Ctrl+Shift+P` (fea50f5). `needs: wm`
- Gradient popup frames and a themed confirm modal replacing `gum confirm` (45a2389, f08c3a1, 52c79f2). `portable` (tmux)
- `Prefix + w` no longer auto-repeats; focus tracking runs in the background; `move-window-to` clamps to the last window (7b8b328, 2db52e9, 2c9a2e5). `portable` (tmux)
- Theme resolution centralized with a non-Omarchy fallback (`THEME_COLORS_FILE`) (9c2f91f). `portable`
- Waymaker presets moved into the `waymaker` package; legacy `mm` references replaced by `wm` (5d354ba, c3fe2e2). `needs: wm`

### Shell, git & stow
- Migration from `acpd` to `waymux` completed across the dotfiles (5b5e57c, 0056cc3, 2b2bb06). `needs: waymux`
- `awt` fetches in the background on worktree switch instead of pulling, and new worktrees accept Claude Code edits while still asking before `git push` and PR actions (8042828, b4a02b5, 6b9de77). `portable` (git)
- User-facing messages translated to English (859c152). `portable`

### Starship
- Dozens of art-inspired presets (Great Wave, Kanagawa, chroma gradients, pattern art, landmarks, scenes, Kintsugi, Bioluminescence) and opt-in prompt-art zsh modules; the preset switcher gained hot-reload preview, category filters and delete (63f47e0 … 3894b55, d640627, 3497b87, 4bac3e0, e6eb615). `portable` (starship); the switcher is `host-only` (Omarchy)

### Desktop
- Machine-local Hyprland config and automatic gaps on Apple hardware (4b8f9e3). `host-only`
- fcitx5 input method set back and forth between US and US International (3524c20, 57b91b4, c4a6c5f). `host-only`

## 2026-W42 (12–18 Oct)

### tmux & Cockpit
- Cockpit grew into the main agent HUD: live diff, prompt input, preview resize, guarded agent actions, PR navigation, `g` toggle to lazygitrs and back with the cursor restored, `Tab` to the `awt` popup, live preview streaming (a542e9d, 3ed38b3, 6d512a2, 10b0328, b5bdd10, 38f8956, b5da02f, 346546f). `needs: waymux, wm, lazygitrs`
- lazygitrs review bridge: per-line notes batched to the agent pane, multi-pane urgency, turbo hunk staging (141a996, 4869fd8, efdb461). `needs: lazygitrs, waymux`
- Close guards: closing a window or session with a working agent asks first, idle agents close at once; Undo Close Tab restores the window index and resumes the agent (c4e731a, 470dd28, ffb99a3, 8351716, b263216, 0f6daa2). `portable` (tmux) for the guards; resume `needs: claude / codex`
- Scrollback view modal with Markdown and Mermaid (50832ac). `needs: wm`
- Hybrid golden-grid layout and the one-accent footer rule for every popup (1dc34b1). `needs: wm`
- Cockpit latency work: no media probe, no periodic reload, zero-fork parsing (e101a2f, c0ed918, e75c523). `needs: waymux`
- tmux 3.8 installer; popups call `display-popup` directly; `tmux-popup-isolate` retired (c51d155, 04aba6b, a0c4117, 1f1bad0, f61bfe6). `needs: tmux ≥ 3.8`; installer `needs: root`
- `Prefix + D` opens the workmux dashboard (9ad25d6). `needs: workmux`
- Window icons for agy, Codex, Muse and Claude (5772ab5, f2f2dfa, 444a812). `portable` (tmux)

### AI agents & daemon
- `waymux` replaced `acpd` as the daemon behind hooks and bindings; the stow package was renamed (a48971f, 10400af, 66cc32f). `needs: waymux`
- `agyy` launcher for a second Antigravity account (5936185). `host-only`
- `update-ai-workflow` (`ai-update`) manages the AI tool updates (5627385, fc4ce14). `needs: root` (installs packages)
- Sound notification paths isolated per event (fe37252). `needs: waymux`

### Shell, git & storage
- `awt` single-pass queries and dirty-state migration (`-W`) (0fb8b3b). `portable` (git)
- `dev-gc` storage hygiene and `awt sweep` upgrades (c14878d). `portable`
- Waymaker presets lost their `Alt` chords and gained the native previewer (b317260). `needs: wm`

## 2026-W41 (5–11 Oct)

### tmux & Cockpit
- Unified Cockpit picker for the agent fleet and windows on `Prefix + Space`, with a lazygitrs bridge, view cycling, a task prompt, PR CI status and worktree actions (c080dda, 70aac12, 9448c77, 1935c2f, 7a61af8, 845f32c). `needs: wm`; agent rows `needs: waymux`
- Zero-latency help toggle in the preview (8cd3f76). `needs: wm`
- Session topology snapshot and post-reboot restore (136b134). `portable` (tmux, python3)
- Flow telemetry: human response latency and a deep-work heatmap (3581031). `portable` (tmux)

### Agents & git
- Proactive agent supervision, auto-dismiss on focus and a `wait` RPC in the daemon (1801b81). `needs: waymux`
- `awt reap` and `awt sweep`; pre-merge `just check` gate and test-status trailers (`gtest`) (dcb24f7, 8ec172f, 6cbc48c). `portable` (git)
- `Alt` removed from lazygitrs and Ghostty bindings (5290bc2, fc13ade). `portable`

## 2026-W40 (28 Sep – 4 Oct)

### tmux
- Window and session pickers: switch between them, live AI session title and conversation preview, `/` filter, index dot column, `n` creates a window (b0001e3, 3c1353e, 934cb70, c484152, d9d8ed6, e2f9a33, 04ec84c, 0867303, 1ad5711, 351aa8e). `needs: wm`

### Shell & keyboard
- `Ctrl+S` reaches TUIs (flow control off) (2acfc33). `portable`
- keyd overload tap timeout so a held CapsLock no longer sends a stray `Esc` (5966479). `needs: root` (keyd)
- Ctrl+Backspace and tmux window keys in foot, Alacritty and Ghostty (335acf7). `portable`
- Waymaker zsh integration replaced the `mm` plugin; jump and transfer aliases deduplicated (4ac3fa7, 400a83d, 4c723a7). `needs: wm`

### Agents & remote
- `acpd` daemon, its CLI and the remote agent workflow (the predecessor of `waymux`) (01bb53a, abde4bf). Superseded by `waymux`
- Tailscale and mosh installers (bdef69a). `needs: root` (installer); tailscale itself may be forbidden on managed hosts
- herdr config (9311f65, 1d2f2b8). `portable` (herdr)

### Desktop
- Hyprland home-row `Super+Ctrl` navigation and per-machine monitor scale (2e9b509, ae8a544). `host-only`
- Antigravity desktop entries; Kitty font set to JetBrainsMono Nerd Font Propo (cba4eb8, ea709b4). `host-only`
