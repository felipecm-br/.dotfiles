# AI CLI Feature Parity & Prompt Stash Roadmap

> **Canonical Architectural Reference:** `docs/architecture/cli-feature-parity-and-prompt-stash-roadmap.md`  
> **Related Systems:** [`waymux`](remote-agent-workflow-waymux.md) · [`ai-quota` / `ai-switch` / `ai-failover`](quota-aware-agent-selection.md) · [TUIOS Delivery & Checkpoint Roadmap](tuios-benchmark-and-agent-inbox-roadmap.md) · [Upstream Watch Backlog](upstream-watch-and-scout.md) · [Popups & Golden Ratio](../tmux/popups-ergonomics-and-golden-ratio.md) · [Ergonomics Manifesto](terminal-ergonomics-and-ux-manifesto.md)  
> **Verified Against (2026-11-12):** `claude` (`2.1.323`), `codex-cli` (`0.167.2`), `opencode` (`1.19.5` local / `v2.2.7` upstream), `agy` (`1.5.5`–`1.5.7`), and `waymux` (`0.12.2`).

---

## 0. Implementation Status (2026-11-13)

| Item | State | Where |
| :--- | :--- | :--- |
| `W1` Turn checkpoints & rewind | **Shipped** · `Prefix + Z` (`Prefix + R` is tmux-sensible's reload, not free) | [`checkpoint-picker.sh`](../../tmux/.config/tmux/checkpoint-picker.sh), `checkpoint.toml`; ages need `waymux checkpoint list --time` (waymux > 0.13) |
| `W2a` OpenCode in `ai-prompt` | **Shipped** · `Ctrl+X E` | [`ai-prompt`](../../utils/.local/bin/ai-prompt) |
| `W2b` Persistent stash + presets `0–9` | **Shipped** · Command Palette *AI Prompt Stash & Presets* (no new chord) | `ai-prompt list\|send\|preset\|save\|pin\|drop`, [`prompt-stash-picker.sh`](../../tmux/.config/tmux/prompt-stash-picker.sh) |
| `W2c` Auto-restore after a `/command` | **Shipped** · opt-in `stash --after-cmd` / `AI_PROMPT_AUTO_RESTORE=1` (waymux's `Config` rejects unknown keys, so no `[prompt_stash]` section) | `ai-prompt _autorestore` (`waymux wait` busy → idle) |
| `W2d` Failover draft carryover | **Shipped** | [`ai-failover`](../../utils/.local/bin/ai-failover) → `ai-prompt _carry` |
| `W3` Draft-aware hold, queue inspect / edit / send now | **Built, unreleased** (waymux branch `feat/cli-parity`): `held` status, `queue/send`, `queue/edit`, Cockpit preview lists the queue; dotfiles queue tab falls back to drop + re-add on 0.13 | `src/api/queue.rs`, `tests/tmux.rs` |
| `W4` `/btw` side question | **Shipped** · `Prefix + b` | [`btw-popup.sh`](../../tmux/.config/tmux/btw-popup.sh) |
| `W5.1` Last-turn recap | **Built, unreleased** (waymux `src/activity.rs`) | Cockpit preview line `󰄬 Last turn …` |
| `W5.2` `/goal` verifier | **Built, unreleased** as its own verb, `waymux goal <pane> --check <cmd>`: `run --wait` waits on a command, not an agent | `src/verbs.rs` |
| `W5.3` MCP & skill inventory | **Shipped** (leftover dev processes on window close not covered) | [`ai-inventory`](../../utils/.local/bin/ai-inventory) |

## 1. Executive Summary

An audit of native features across the four supported AI CLIs (**Claude Code**, **Codex CLI**, **OpenCode**, and **Antigravity CLI**) against this stack (`tmux`, `waymux`, `wm`, `lazygitrs`, `awt`, and [`ai-prompt`](../../utils/.local/bin/ai-prompt)) shows a clear division:

1. **Multi-agent orchestration stays superior in `waymux` + popups.** Single-vendor CLIs cannot match unified cross-harness fleet triage (`Prefix + Space`), quota-ranked launching (`Prefix + a`), zero-draft-loss model switching (`Prefix + A`), cross-provider failover (`Prefix + F`), or whole-branch `lazygitrs` hunk staging with inline review notes (`Ctrl+G` → `r`).
2. **Targeted CLI composer & turn ergonomics are worth absorbing.** Specifically:
   - **Prompt Stash** (`Claude Ctrl+S` auto-restore + `OpenCode PromptStash` persistent modal stack + `Codex tui.presets.0..9`) can upgrade our single-slot [`ai-prompt`](../../utils/.local/bin/ai-prompt) into a **cross-agent, persistent stash + presets system** that even survives `Prefix + F` failover.
   - **Per-Turn Diff & `/rewind`** already has its Rust backend built in `waymux checkpoint` (`~/dev/github/waymux/src/checkpoint.rs`) — it only needs a Golden Ratio `wm` popup UI.
   - **Ephemeral Side-Questions (`/btw`)**, **Queue Inspector/Editor (`waymux queue` + `U2` draft-hold)**, and **Autonomous `/goal` Verification + Fleet Recap** close the remaining usability gaps without adding clutter to normal runs.

---

## 2. Verified Audit Matrix

### 2.1 Prompt Stash & Reusable Presets

| Harness | Mechanism | Storage & Payload | Killer Detail to Absorb | Current Gap |
| :--- | :--- | :--- | :--- | :--- |
| **This Stack (`Prefix + V`)** | [`ai-prompt`](../../utils/.local/bin/ai-prompt) `stash` (`take`/`put` over `$VISUAL`) + `WAYMUX_SWITCH_DRAFT` in `waymux switch` | Single ephemeral file per pane (`$XDG_RUNTIME_DIR/ai-prompt/<pane>.stash`) | Works across harnesses (`claude`, `codex`, `agy`, `devin`), paired with `Prefix + v` floating Neovim edit | Single slot overwrites prior stash; lost on kill/reboot; manual restore `Prefix + V`; `opencode` omitted from `AGENT_RE` |
| **Claude Code (`Ctrl+S`)** | `chat:stash` action toggles draft stash | In-session `{value, cursorOffset, mode, pastedContents}`; persisted in `CLAUDE_JOB_DIR` for `--bg` | **Auto-restores after submit** with `"Draft restored"` toast right after a `/command` finishes | Single slot; locked inside one Claude session |
| **OpenCode** | `PromptStash` (`prompt.stash`, `prompt.stash.pop`, `prompt.stash.list`) | Persistent JSONL stack (`<state>/prompt-stash.jsonl`, cap 50) with `{input, parts, timestamp}` | **Searchable Stash modal** (title, timestamp, `~N lines`, `ctrl+d` double-press delete); `v2.2.5` diff comment `Ctrl+Enter` preserves draft | Default keybinds `"none"` (opened via `ctrl+p` Command Palette unless customized) |
| **Codex CLI** | **No** `Ctrl+S` prompt stash; has `chat.open_presets` (`tui.keymap.*`) | Saved `tui.presets.0`..`9` prompt slots | **`0–9` single-key run**, `s` save, `d` delete reusable prompts + `chat.edit_queued_message` | Manual templates rather than instant transient draft stashing |
| **Antigravity (`agy`)** | **None** in `/usr/bin/agy` | — | Uses `ctrl+g` external editor (already routed through `ai-prompt` by [`agy`](../../utils/.local/bin/agy)) | No native multi-slot stash |

### 2.2 Broad CLI Workflow Capabilities vs This Stack

| Capability | Upstream CLIs | Current Dotfiles / `waymux` State | Verdict |
| :--- | :--- | :--- | :--- |
| **Fleet Center & Triage** | `claude agents`/`--bg`/`attach`, `codex agents`, `agy /agents` | `Prefix + Space` Cockpit + `Prefix + i`/`I` triage + guarded `y`/`n` + `/m` phone | **Already Ahead** (cross-harness) |
| **Repo Diff & Inline Notes** | `claude /diff`, `opencode` split/patch diff + `Ctrl+Enter` quote, `agy /diff` | `Ctrl+G` `lazygitrs` Dual-Diff + hunk staging + `.git/info/lines.json` → `r` (`waymux review-notes send`) | **Already Ahead** (whole branch); adopt per-turn UI below |
| **Per-Turn Checkpoints / `/rewind`** | `claude /rewind` (`checkpoint`/`undo`), `opencode /timeline` + `/undo`, `codex /rewind`, `agy /rewind` | `waymux checkpoint list\|diff <n>\|restore <n>` (`DEFAULT_KEEP = 50` in bare alternates store) **already exists in Rust**, **zero UI/keybinding** | **Adopt (`W1`)** — trivial high-ROI `wm` popup |
| **Delivery Queue UI & Hold** | `claude ctrl+x enter` / `ctrl+x ctrl+s`, `opencode <leader>q`, `codex queue` + `edit_queued_message` | `waymux queue add\|ls\|rm` (`OFFLOAD_BYTES = 12 KiB`, invisible-char strip) via Cockpit `I`; [`U2`](upstream-watch-and-scout.md#ready-to-adopt-port-or-upgrade) tracks draft hold | **Adopt (`W3`)** — inspect/edit popup + draft-aware hold |
| **Ephemeral Side Question** | `claude /btw`, `agy /btw`, `codex toggle_side_conversation` | No lightweight read-only side popup; must open another window/pane | **Adopt (`W4`)** — harness-agnostic floating popup |
| **Autonomous Stop Gate (`/goal`)** | `claude /goal`, `opencode v2.2.1 /goal`, `codex goals` | `Stop` / `StopFailure` hooks report state only ([`claude/.claude/settings.json`](../../claude/.claude/settings.json)) | **Adopt (`W5`)** — optional verification gate for `waymux run` |
| **Recap & Context Audit** | `claude /recap`, `/context`, `/skill-doctor`, `/settings-review`, `agy /context` | `waymux` away-recap (`A2`) counts turns/files/cmds after 10 min; roadmap [`P4`](state-of-the-art-terminal-agent-workflow.md#83-open-three-phases-to-92) tracks MCP inventory | **Adopt (`W5`)** — 1-line turn recap + MCP/skill audit |
| **TUI Render Internals** | `claude` TS plugin `mods`/`easel`, `--prompt-suggestions`; `codex` `fast_mode`/`code_mode`/`voice` | Native inside each TUI; [`pr-picker.sh`](../../tmux/.config/tmux/pr-picker.sh) + `awt` already cover `opencode pr` | **Keep Native** — do not wrap |

---

## 3. Implementation Plan (`W1`–`W5`)

All work items obey the [Ergonomics Manifesto](terminal-ergonomics-and-ux-manifesto.md): **Zero-Churn** (never rebind consolidated chords), Home Row ($H=0$), no `Alt` chords, **Golden Ratio** geometry (`75% × 60%` ephemeral pickers / `85% × 75%`–`90% × 88%` diff views), pure Nerd Font title badges, dynamic `theme-helper.sh` borders, and `<100ms` first-frame launch.

### `W1` — Turn Checkpoint & Diff Rewind Popup (`waymux checkpoint`) — **Effort: S**

**Goal:** Expose the existing `waymux checkpoint` bare alternates store (`~/dev/github/waymux/src/checkpoint.rs`) as a keyboard-driven `/rewind` and per-turn diff popup across every agent harness.

1. **Popup Script & Preset (`tmux` + `waymaker`):**
   - Add `tmux/.config/tmux/checkpoint-picker.sh` + `waymaker/.config/waymaker/presets/checkpoint.toml` (`85% × 75%`, `40/60` split, pure Nerd Font badge e.g. ` 󰁯 ` synced via [`waymux/.config/waymux/config.toml`](../../waymux/.config/waymux/config.toml)).
   - Source list: `waymux checkpoint list -w "$ORIGIN_PANE"` (commit/turn index, timestamp, relative age, short stats/subject).
   - Right preview pane (60%): `waymux checkpoint diff <n> -w "$ORIGIN_PANE"` piped through `delta --side-by-side` (reusing the `render_diff_stream` pattern in `~/dev/github/waymux/src/cockpit/diff.rs`).
2. **Navigation & Safe Restore Actions (`nav` mode):**
   - `J` / `K`: scroll diff preview; `g`: open working tree in `lazygitrs`.
   - `Enter` or `r`: confirm modal (or two-step press / `--force` guard when working tree is dirty), then execute `waymux checkpoint restore <n> -w "$ORIGIN_PANE"` (which automatically records a safety checkpoint first per `checkpoint.rs`).
   - Expose in Cockpit (`~/dev/github/waymux/src/presets/cockpit-picker.toml` and `help.rs`) and [Command Palette](../../tmux/.config/tmux/command-palette.sh) (`Ctrl+Shift+P` / `Prefix + p`). Check [`tmux.conf`](../../tmux/.config/tmux/tmux.conf) and telemetry before assigning any dedicated `Prefix` shortcut (`Prefix + R` is currently free).
3. **Done when:**
   - Opening the checkpoint picker over any `claude`/`codex`/`opencode`/`agy` pane lists recent turns within `<100ms`, renders per-turn `delta` diffs cleanly, and restores an earlier turn safely with a pre-restore safety snapshot verified by unit/integration test.

---

### `W2` — Persistent Multi-Slot Prompt Stash, `0–9` Presets & Failover Carryover — **Effort: M**

**Goal:** Upgrade [`ai-prompt`](../../utils/.local/bin/ai-prompt) + `waymux` from a 1-slot per-pane temp file to a persistent, cross-agent stash stack + quick-template palette that integrates cleanly with `ai-switch` (`Prefix + A`) and `ai-failover` (`Prefix + F`).

#### Sub-tasks

- **`W2a` — Add `opencode` Support in [`ai-prompt`](../../utils/.local/bin/ai-prompt) (Quick Fix):**
  - Confirmed in the `opencode` binary that `editor_open` invokes `process.env.VISUAL || process.env.EDITOR` (set globally in [`zsh/.zshenv`](../../zsh/.zshenv)).
  - Extend `AGENT_RE='^(claude|agy|agy-bin|antigravity|devin|codex|opencode)$'` and add `opencode)` key dispatch (respecting `AI_PROMPT_KEY_opencode` matching `<leader>e` / [`tui.json`](../../opencode/.config/opencode/tui.json)).
- **`W2b` — Persistent JSONL Stash Store + Pinned `0–9` Presets (`waymux` / `ai-prompt`):**
  - Store `$XDG_STATE_HOME/waymux/prompt-stash.jsonl` (capped at `50` entries, `0600` perms, invisible chars stripped via `delivery::strip_invisible`):
    `{ "id", "ts", "pane", "agent", "cwd", "pinned_slot": 0..9 | null, "text", "lines" }`.
  - Keep `Prefix + V` as zero-popup fast toggle: if current pane has a non-empty draft, `take` pushes to the JSONL stack and clears input; if empty and pane has a recent stash, `put` restores and removes/marks popped (preserving exact current UX).
  - Add a **Prompt Stash & Presets Picker** (`75% × 60%` `wm` popup via Command Palette & `ai-prompt list` / `ai-prompt presets`):
    - Top/pinned rows `[0]`–`[9]` act like Codex's `chat.open_presets` (instant `0–9` key injection via `ai-prompt put` or `waymux inject`).
    - History rows show agent icon, relative timestamp, cwd/branch, and `~N lines`, with multi-line preview on the right (60%).
    - Keybinds in `nav` mode: `Enter` inject/restore into active pane (even from *another* agent), `e` edit in floating `nvim` first, `s` pin/save as preset `0–9`, `d` delete (with confirm on pinned presets).
- **`W2c` — Opt-in / Smart Auto-Restore After `/command` (Claude `Ctrl+S` Parity):**
  - Add `ai-prompt stash --after-cmd` (or config flag `[prompt_stash] auto_restore = true` in [`waymux/.config/waymux/config.toml`](../../waymux/.config/waymux/config.toml)): when stashed on a pane whose next transition goes `idle → busy/working → idle` (typically `/compact`, `/clear`, `/context`, `/model`), check `has_draft()` (`switch.rs`) — if composer is still blank after 350 ms settle, auto-run `put` and show tmux HUD `"󰏫 Draft restored"`.
- **`W2d` — Cross-Agent Draft Carryover in [`ai-failover`](../../utils/.local/bin/ai-failover) (`Prefix + F`):**
  - Before `ai-failover` opens the fallback agent (`agy`, `agyy`, `codex`) with `AI_LAUNCH_CONTINUE=1`, run `ai-prompt -t "$pane" --ready && ai-prompt -t "$pane" take`.
  - Pass the captured stash id to the spawned pane (or queue `waymux inject` / `ai-prompt put` once the failover pane reaches initial `idle`).
- **Done when:**
  - `Prefix + V` works across `claude`, `codex`, `agy`, and `opencode`; multiple stashes persist across tmux/host restarts; presets `0–9` insert cleanly; and triggering `Prefix + F` on a Claude pane with an active draft carries that draft into the replacement agent without manual retyping.

---

### `W3` — Queue Inspector/Editor UI & Draft-Aware Delivery Hold (`U2`) — **Effort: M**

**Goal:** Give `waymux queue` (`~/dev/github/waymux/src/delivery.rs`) visibility/editing matching OpenCode `<leader>q` and Codex `edit_queued_message`, while preventing queued prompts from clobbering active typing ([`U2`](upstream-watch-and-scout.md#ready-to-adopt-port-or-upgrade)).

1. **Draft-Aware Queue Hold (`waymux` daemon):**
   - Before `dispatch_prompt` (`~/dev/github/waymux/src/delivery.rs`) types a queued item when a pane reaches `1 s` `idle`, capture the bottom prompt lines and check `switch.rs`'s `has_draft()` (which already filters out Claude `❯` and Codex `›` placeholders).
   - If a non-empty user draft is present, hold delivery in `waiting_for_empty_composer` state (avoiding the `herdr-core` `4d133ea` failure mode by: (a) expiring/clearing hold cleanly on `Submit`/hook `UserPromptSubmit`, (b) keeping a short cap + manual `sendNow` override in UI, and (c) testing false positives across every agent's placeholder theme).
2. **Queue Inspector Mode:**
   - Surface queued prompts directly in the Cockpit preview header (showing count + truncated items) and via a `wm` Queue Manager mode (shared with or toggled from the `W2` Prompt Stash/Presets popup via `Tab`):
     - `Enter` / `e`: edit queued text in floating `nvim` (`waymux queue edit` / drop+re-push).
     - `s`: force send now (bypass wait when pane is safe idle).
     - `d`: drop (`waymux queue rm <pane> <id>`).
3. **Optional `lazygitrs` Quick-Send (`Ctrl+Enter` parity with OpenCode `v2.2.5`):**
   - Keep batched notes (`r` in Cockpit) as default; optionally expose an immediate single-note `waymux queue add` binding from review mode without touching any composer draft.
4. **Done when:**
   - Typing half a prompt in an idle pane holds pending `waymux queue` messages until the draft is submitted or stashed (`cargo test` + live tmux test); Cockpit/popup can inspect, edit in `nvim`, force-send, or delete any queued prompt.

---

### `W4` — Ephemeral Side-Question Popup (Harness-Agnostic `/btw`) — **Effort: M**

**Goal:** Provide a fast, read-only "ask a quick side question about what this pane is doing" popup (matching Claude `/btw`, Antigravity `/btw`, and Codex `toggle_side_conversation`) that works identically over any harness (or plain shell) without interrupting a busy agent or polluting context.

1. **Trigger & Geometry:**
   - Register in [`command-palette.sh`](../../tmux/.config/tmux/command-palette.sh) and Cockpit; optionally assign an unbound `Prefix` key (e.g., `Prefix + b`, verified free in [`tmux.conf`](../../tmux/.config/tmux/tmux.conf)).
   - Opens a `75% × 60%` Golden Ratio popup (`-S "fg=$CYAN_COLOR"`, pure badge ` 󰭹 `).
2. **Context Snapshot (Zero Pane Interference):**
   - Captures read-only context: bottom ~120 lines of `tmux capture-pane -t "$ORIGIN_PANE" -p`, `git -C "$ORIGIN_CWD" status -sb`, and active branch/pane agent name.
   - Prompts for a 1-line question (`wm` input or fast `gum`/`nvim`/inline prompt), then invokes a low-latency non-persistent query (`claude -p --no-session-persistence`, `codex exec`, or `agy -p` chosen via `ai-quota` headroom) with `--model` defaulted to fast tier.
3. **Output Ergonomics:**
   - Streams rendered Markdown/ANSI (via `glow`/`bat` or `nvim -R`) inside the popup: `y` yanks answer to Wayland clipboard, `i` forwards answer into `waymux queue` if needed, `Esc` dismisses with zero traces in the main pane.
4. **Done when:**
   - Triggering `/btw` over a `working` Claude/Codex/Agy pane answers a question using pane tail + repo context in `<3 s` without pausing or altering the running agent's conversation.

---

### `W5` — Turn Recap Summary, `/goal` Stop-Gate & MCP Bloat Audit (`P4`) — **Effort: S–M**

Incremental quality-of-life upgrades extending already-started pieces in [`state-of-the-art-terminal-agent-workflow.md`](state-of-the-art-terminal-agent-workflow.md):

1. **1-Line Last-Turn Recap in Cockpit (`A2` Extension):**
   - When a pane finishes a turn (`working → idle`/`review`), extract a deterministic compact summary (`files touched + last command + diff stat` or optional short note) alongside the existing `A2` away-recap so scanning Cockpit (`Prefix + Space`) doesn't require reading raw scrollback tails.
2. **Optional `--goal` Verifier for `waymux run` (`P14`):**
   - Allow `waymux run --wait --goal-cmd "<test cmd>"` (or hook gate) so autonomous loops re-queue a short nudge when the verification command fails before reporting `done`, giving uniform `/goal` semantics outside Claude Code `2.1.323` and OpenCode `2.2.1`.
3. **Cross-CLI MCP & Skill Inventory (`P4` Tie-In):**
   - Single `wm` picker scanning configured MCP servers and active skill footprints across `~/.claude`, `~/.codex`, `~/.config/opencode`, and Antigravity configs, flagging duplicates/unused servers (inspired by Claude Code `/context` & `/skill-doctor`) plus leftover dev processes on window close.

---

## 4. Non-Goals (Keep Native to Each CLI)

To preserve `<100ms` latency, zero wrapper fragility, and clean boundaries:

- **In-transcript UI plugins / inline charts / prompt autocomplete predictions** (Claude Code `mods`, `cc-plugin-easel`, `--prompt-suggestions`): tightly coupled to Claude's Ink renderer.
- **Voice dictation / `fast_mode` / JS REPL `code_mode`** (`codex` / `agy mic-serve`): harness-runtime internals; invoke directly when desired.
- **PR checkout CLI wrappers** (`opencode pr <number>`): already solved faster across all tools via [`pr-picker.sh`](../../tmux/.config/tmux/pr-picker.sh) (`Prefix + P`) and `awt`.

---

## 5. Implementation Governance Checklist (Per `AGENTS.md`)

Whenever any item (`W1`–`W5`) ships, complete these updates in the **same commit**:

1. **Keybindings & Palette Sync:** Update [`keybindings-items.sh`](../../tmux/.config/tmux/keybindings-items.sh), `tmux/.config/tmux/keybindings-preview.sh`, [`key-telemetry.py`](../../tmux/.config/tmux/key-telemetry.py), and run `~/.config/tmux/key-telemetry.py install` on the live tmux server.
2. **Command Catalog:** Add any new CLI verbs/scripts to [`custom.commands`](../../intelli-shell/.config/intelli-shell/custom.commands) (`intelli-sync`).
3. **Canonical Docs & Changelog:** Update [`workflow-keybindings-matrix.md`](workflow-keybindings-matrix.md), [`quota-aware-agent-selection.md`](quota-aware-agent-selection.md) (for `W2`), and [`CHANGELOG.md`](../CHANGELOG.md) under `## Unreleased` with portability tags.
4. **Verification Gates:** Run `./stow.sh -n`, `./scripts/docs-lint.sh`, [`tests/key_telemetry.test.sh`](../../tests/key_telemetry.test.sh), [`tests/picker_rg_files.test.sh`](../../tests/picker_rg_files.test.sh), and `cargo test` in `~/dev/github/waymux`.
