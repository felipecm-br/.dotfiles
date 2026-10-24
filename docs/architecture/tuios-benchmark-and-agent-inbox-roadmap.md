# TUIOS (`v0.10.1`) Benchmark & Agent Inbox / Delivery-Queue Roadmap

> **Canonical Architectural Reference:** `docs/architecture/tuios-benchmark-and-agent-inbox-roadmap.md`  
> **Related Systems:** [`waymux`](remote-agent-workflow-waymux.md) · [`awt`](../GIT_WORKTREE_AGENTIC_WORKFLOW.md) · [`ai-quota` / `ai-launch`](quota-aware-agent-selection.md) · [`state-of-the-art-terminal-agent-workflow.md`](state-of-the-art-terminal-agent-workflow.md) · [Ergonomics manifesto](terminal-ergonomics-and-ux-manifesto.md)  
> **Verified against:** upstream [`docs/AGENT_STATE.md`](https://github.com/Gaurav-Gosain/tuios/blob/main/docs/AGENT_STATE.md) for TUIOS `v0.10.1` (released 2026-10-17), read on 2026-10-24, and the `waymux` `0.2.4` source.

---

## 1. Executive Summary

[**TUIOS**](https://github.com/Gaurav-Gosain/tuios) (Go, Bubble Tea v2) is a terminal multiplexer and window manager with floating/BSP/master-stack/scrolling layouts, a right-hand sidebar ("the Rail"), an agent Inbox, a daemon-owned delivery queue, inter-agent mail, hook-held approvals, turn checkpoints, diff review (`tuios review`), worktree fan-out (`tuios fan`) and shipping (`tuios ship`).

The audit, run with the `tui-ux-architect` skill, reaches two conclusions:

1. **Keep the multiplexer stack.** Replacing native `tmux` + the Rust tools (`wm`, `lazygitrs`, `waymux`) with TUIOS would add a second terminal emulator in the render path, give up 20–25% of the horizontal viewport to the always-on Rail, reintroduce modal *Window Management* vs *Terminal* mode slipping, depend on `Alt` chords (`alt+enter` in its reply editor), and lose the 5h/7d quota telemetry of [`ai-quota`](../../utils/.local/bin/ai-quota).
2. **Absorb its delivery-safety mechanisms, not its UI.** TUIOS's most valuable ideas are guards: never type into an agent mid-turn or on a prompt, re-check a prompt right before answering it, and slow down risky approvals. Our `waymux` lacked all three: `waymux inject` and `review-notes send` pasted and pressed `Enter` whatever the agent was doing (so a review note could answer a permission prompt), and the Cockpit's `y`/`n` trusted the state its row was drawn with.

---

## 2. Ergonomic, Biomechanical & Architectural Comparison

| Dimension | TUIOS (`v0.10.1`) | This Stack (`tmux` + `waymux` + `wm` + `lazygitrs` + `ai-quota`) | Verdict |
| :--- | :--- | :--- | :--- |
| **Terminal Emulation ($T_R$)** | Go VT parser re-rendering every cell inside Bubble Tea v2 | Native C `tmux` pass-through + event-driven Rust binaries | **This Stack** |
| **Keyboard Biomechanics ($T_H$)** | Modal multiplexer (`Terminal` vs `WM` mode), `Ctrl+B` prefix, `alt+enter` / `shift+enter` newlines in the reply editor | Home Row ($H=0$) via `keyd` `CapsLock` (`Ctrl` hold / `Esc` tap), no `Alt` chords, modeless popups | **This Stack** |
| **Viewport & Eye-Tracking** | Always-on Rail + title bar consume ~20–25% of the horizontal viewport | Full-bleed viewport; on-demand `75% × 60%` popups with a 40/60 split | **This Stack** |
| **File Navigation** | Tree inside the Rail | `wm -o jump` frecency + ZLE `_smart_tab`, `ptl`/`ptg` | **This Stack** |
| **Git & Diff Review** | `tuios review` with daemon-held line notes | `lazygitrs` Dual-Diff (`Ctrl+G`) + `.git/info/lines.json` notes sent with `r` | **This Stack** (full staging/rebase) |
| **Prompt Delivery** | Daemon delivery queue: typed after 1 s at rest, one per rest, never on `needs_input`, `stalled` after 5 s | Now the same model: `waymux queue` (see §4, Phase S1) | **Parity** (absorbed) |
| **Approvals** | Inbox `1`/`2`/`3`, held through the harness's `PermissionRequest` hook, 0.4 s dwell, risky double-press | Cockpit `y`/`n` (keystrokes) with live re-check and 0.4 s dwell (§4, Phase S2) | **TUIOS** until hook-held approvals land (§4, A3) |
| **Quota & Burn-Rate Telemetry** | None (`tuios fan` is blind to rate limits) | [`ai-quota`](../../utils/.local/bin/ai-quota) (`Prefix + u`), [`ai-launch`](../../utils/.local/bin/ai-launch) (`Prefix + a`), quota-aware AI split (`Prefix + o`) | **This Stack** |

---

## 3. How TUIOS Delivers, Answers and Mails (Verified)

Every TUIOS pane has a daemon-managed identity (`TUIOS_PANE_ID`, `TUIOS_SOCKET`, `TUIOS_SESSION`). `tuios integration install` wires agent hooks; panes report `working`, `needs_input` (`blocked_by`: `approval`, `question`, `auth`), `idle`, `done`, `errored` or `unknown`.

### 3.1 Delivery queue (`tuios queue`, verbs `queue-prompt` / `list-queued` / `cancel-queued`)

- A message is typed when the pane is at rest (`idle` or `done`), **has been at rest for one second**, and the rest began after the previous message was typed: **one message per rest**.
- It never types into a pane on `needs_input`; the daemon re-checks right before typing.
- After typing it waits for the agent to take it (a state change). Not taken within **5 seconds**, the message is marked `stalled`, **never typed again**, and holds the ones behind it until the pane next shows `working` or the user drops it.
- A pane holds at most **8** messages of **16 KiB** each (`queue_full`); queues live in daemon memory and die with the pane, the session or the daemon.

### 3.2 Large pastes and invisible characters

A reply over **12 KB** has each paste block written to a private file (kept 24 h) and replaced by `[Pasted text #1: <path>, N lines]`. The reply editor removes Unicode tags, bidi controls and zero-width spaces before sending.

### 3.3 Approvals and risk rules

- Approvals are **held by the harness's own hook** (Claude Code `PermissionRequest`): the Inbox answers with `1` (allow once), `2` (always, only when the rules it adds can be shown) or `3` (deny). No keystroke reaches the pane. Every error prints nothing, which every harness reads as "ask the user", so a failure can never approve.
- Only single-argument calls that fit one line are held (`Bash`, `Read`, `Glob`, `Grep`, `WebFetch`, `WebSearch`); `Write`/`Edit` and MCP tools are answered in the pane.
- Keys do nothing for a held approval on screen for **less than 0.4 s**.
- **Risk rules** (recursive `rm -rf`, force push, `reset --hard`, `git clean -f`, `checkout .` / `restore .`, `curl | sh`) mark a call risky; allowing it needs a **second press within 3 s**, enforced by the daemon (`risk_ack`).
- `ExitPlanMode` plans can be held and approved from the Inbox (`plan_sha` digest).

### 3.4 Mail (`send-agent-message`, `read-agent-messages`, `ask-agent`, `ask-human`)

Mail lives in daemon memory (256 messages per session). Bodies are fenced as untrusted data, a pane cannot send as `human`, and human replies carry `verified_human` (the attached client's nonce). When mail stays unread for **5 seconds** and the recipient is at rest, the daemon queues one sanitized wake line (`You have N unread tuios messages. Read them with: ...`) through the delivery queue. That line has no sender-controlled text, and two wakes of one pane are at least 30 s apart.

### 3.5 Other mechanisms

- **Turn checkpoints:** at the end of each turn the daemon saves the work tree as a commit under `refs/tuios/checkpoints/<window>/<n>` through a temporary index, with `checkpoint diff` and `checkpoint restore` (which first saves a `safety` checkpoint).
- **Finished turns & away recap:** a per-pane `completion_seq` marks unread finished turns; returning after 10+ minutes shows one line (`3 turns, 6 files, 11 commands, go test passed`).
- **Alerts:** a burst of items (a fan) is one dock message, one notification and one sound.
- **Ship:** `tuios ship commit|merge|pr`, where push and PR need a confirmation token tied to branch, commit and remote.

---

## 4. Adoption Roadmap

Ranked by risk removed per unit of complexity. Keys stay as they are: per the [Zero-Churn principle](terminal-ergonomics-and-ux-manifesto.md), the Cockpit keeps `y`/`n` (TUIOS's `1`/`2`/`3` would also collide with `a` Toggle Fleet).

### Tier S: safety fixes (shipped in `waymux` `6628f4a`, installed as 0.2.4)

| ID | Feature | What changed |
| :---: | :--- | :--- |
| **S1** | **Delivery queue** (`waymux queue add\|ls\|rm`, RPC `queue/push`, `queue/list`, `queue/cancel`) | `inject`, `review-notes send` and the Cockpit's `I` go through the daemon. A prompt is typed only after 1 s of `idle`, one per rest, never into `working`, `permission` or `question`; not taken in 5 s → `stalled`, announced, never retyped. 8 × 16 KiB per pane. Without a daemon, typing is refused when the hook last saw the agent working or on a prompt. Review notes are marked sent only once queued. |
| **S1b** | **Large-paste offload & invisible-character strip** | Prompts over 12 KB go to `$XDG_RUNTIME_DIR/waymux/paste/` (`0600`, pruned after 24 h) as `[Pasted text: <path>, N lines]`; Unicode tags, bidi controls and zero-width spaces are removed. |
| **S2** | **Live re-check + 400 ms dwell on `y`/`n`** | `agent-action approve\|deny` reads the daemon's live state (`changed_at` in `agentState/list`) instead of the row's, refuses when the agent left the prompt, and ignores a prompt on screen for less than 400 ms. |

Still open in Tier S:

- **S3. Risk rules on `y`:** require a second `y` within 3 s when the remembered tool summary (`remember_pane_tool`) matches the TUIOS rule set, and badge the preview header red (`#f38ba8`, reserved for operational urgency).
- **S4. Deny-key audit:** `n` is sent as `n` + `Enter`. Verify per harness that `n` denies. Where it is not a hotkey, `Enter` confirms the highlighted option, so `Esc` may be the correct deny.

### Tier A: worth it

| ID | Feature | Notes |
| :---: | :--- | :--- |
| **A1** | **Queued badge in the Cockpit** | `agentState/list` already reports `queued`; render `󰇮 N` in darkgray in the age column of `cockpit-items`. |
| **A2** | **Unread finished turns + away recap** | Count turns per pane; show a one-line recap in the preview after 10+ minutes away. Fits [evidence-based telemetry](evidence-based-telemetry-and-deep-work.md). |
| **A3** | **Hook-held approvals** | Have `waymux hook tmux PermissionRequest` wait for the Cockpit's decision and print `hookSpecificOutput.decision`; print nothing on any error. Off by default; single-line `Bash`/`Read`/`Grep` only. Removes keystroke injection from approvals entirely. |
| **A4** | **Alert burst coalescing** | One sound and one message when several agents need you at once. Check `adapters/sound.rs` first. |

### Tier B: when the workflow needs it

| ID | Feature | Notes |
| :---: | :--- | :--- |
| **B1** | **Turn checkpoints** | `refs/waymux/checkpoints/<pane>/<n>` via a temporary index; `restore` saves a safety checkpoint first. The best safety net among the remaining items. |
| **B2** | **Quota-aware `awt fan` / `verify` / `keep`** | `awt` is `waymux wt`, so this lands in the `waymux` crate. Gate on `ai-quota --json` (`projected_five`). Only worth it for regular best-of-N runs. |
| **B3** | **Fenced inter-agent mail + wake** | High complexity for a single-human workflow. The untrusted-content fence (`│ ` gutter) can be adopted on its own wherever agent text is relayed to another agent. |

### Rejected

The Rail, BSP/floating window management and the modal WM mode, `tuios review` (covered by `lazygitrs`), Inbox digits `1`/`2`/`3`, snoozing (`z`), and the built-in reply editor (the Cockpit's `I` and `$EDITOR` already cover it).

---

## 5. KLM-GOMS Cost Matrix

| Action | Before | After | $\Delta T$ |
| :--- | :--- | :--- | :--- |
| Send a note to a busy agent | $M$ + repeated glances at the pane + $1K$ | $1K$ (queued, typed at rest) | −1–3 s per note, and no answered prompts |
| Approve a routine command | $1K$ (`y`) | $1K$ (`y`), ignored for 400 ms after the prompt appears | ≈ 0 |
| Approve `rm -rf` (S3) | $1K$ | $2K$ within 3 s | +120 ms, a deliberate speed bump |
| Hand a 2,000-line log to an agent | slow PTY paste | $1K$ + file reference | −seconds |
| Return to an agent after 40 min (A2) | $M$ + scrollback | read one recap line | −10–30 s |
