# Evidence-Based Personal Telemetry & Deep Work Heatmap Architecture

## 1. Executive Summary

This architecture implements **Evidence-Based Personal Telemetry** to mathematically validate operator focus, task switching frequency, and human-agent interaction latency across our autonomous development environment.

Instead of subjective impressions, the stack captures exact sub-millisecond timestamps of interaction state transitions with zero operating system process forks (`N=1` Bash 5 `printf '%(%s)T'`), calculates uninterrupted flow durations, measures human response latencies to AI agent queries, and visualizes hourly focus intensity directly inside the **Cockpit HUD** (`?` preview) and **Keybindings Catalog HUD** (`Prefix + ?`).

---

## 2. Theoretical & Ergonomic Foundations

1. **Flow Theory & Interruption Cost (Csikszentmihalyi 1990; Mark, Gudith & Klocke 2008)**:
   - Interrupted work is resumed later and costs stress: people compensate by working faster under more pressure (Mark et al. 2008). The often-quoted "23 minutes and 15 seconds" comes from Gloria Mark's interviews about an earlier field study and includes time spent on other tasks before returning; it is not a constant for regaining focus.
   - Grouping activity into contiguous clusters ($\Delta t \le 20\text{ min}$) gives an operational estimate of uninterrupted work blocks.
2. **Attentive Interaction & Breakpoint Scheduling (Iqbal & Bailey 2008)**:
   - Measuring human reply latency ($\Delta t_{\text{reply}} = t_{\text{reply}} - t_{\text{question}}$) and idle lag between task completion and code review ($\Delta t_{\text{review\_start}} = t_{\text{review\_start}} - t_{\text{task\_done}}$) provides evidence of minimal friction.
3. **Zero-Fork Telemetry ($H=0$, sub-1ms overhead)**:
   - Spawning external utilities such as `date` or Python on every window/session switch degrades terminal latency. `flow-log.sh` uses Bash 5 built-in string expansions and `printf '%(%s)T'` to log events in $<0.1\text{ms}$ with zero child process forks.

---

## 3. Telemetry Event Protocol

Events are written to `${XDG_STATE_HOME:-~/.local/state}/flow/events.tsv` with the format:

```tsv
<epoch_timestamp>	<event_type>	<target>	<extra_metadata>
```

| Event Type | Trigger Origin | Target Parameter | Extra Field | Description |
|:---|:---|:---|:---|:---|
| `session` | Tmux hook `client-session-changed` | Session Name | — | Context switch between workspaces (test `_test_*` and `_popups` sessions are skipped; a repeat of the focused session is dropped) |
| `window` | Tmux hook `after-select-window` | `session:win` | — | Focus transition between windows (same filters) |
| `agent_question` | `waymux` daemon state update | Pane ID (`%X`) | Context message | AI agent transitioned to `AwaitingInput` / `Permission` |
| `human_reply` | `waymux` daemon state update / focus dismiss | Pane ID (`%X`) | Latency (e.g. `8s`) | Human responded to agent prompt or dismissed attention badge |
| `agent_finished` | `waymux` daemon debounce completion | Pane ID (`%X`) | Task / prompt ID | AI agent completed task (`Working` $\rightarrow$ `Idle`) |
| `review_start` | `lazygitrs-popup.sh` launch | Project Directory | Lag (e.g. `1s`) | Elapsed seconds between agent completion and review modal opening |
| `review_size` | `lazygitrs-popup.sh` launch | Project Directory | Lines (e.g. `120`) | Insertions + deletions under review (uncommitted diff, or the HEAD commit when the tree is clean) |
| `review_end` | `lazygitrs-popup.sh` exit | Project Directory | Duration (e.g. `92s`) | Elapsed seconds inside the code review modal; paired with `review_size` it gives lines reviewed per minute |

---

## 4. Subsystem Integrations

### 4.1. Zero-Fork Bash 5 Event Logger (`flow-log.sh`)
Located at [`tmux/.config/tmux/flow-log.sh`](../../tmux/.config/tmux/flow-log.sh).  
Calculates elapsed durations directly via Bash arithmetic and file descriptors without subshells:
- Reads previous state timestamp from `$log_dir/last_question.txt` or `$log_dir/last_task_done.txt`.
- Computes latency: `latency=$(( now - prev_time ))`.
- Appends atomically to `events.tsv`.

### 4.2. Waymux Daemon Telemetry Hooks
Integrated in [`waymux/src/api.rs`](https://github.com/felipecm-br/waymux):
- In `dispatch_update()`, detects attention state entry (`AwaitingInput` / `Permission`) $\rightarrow$ emits `agent_question`.
- On human reply or focus dismiss (`agentState/dismiss`) $\rightarrow$ emits `human_reply`.
- On confirmed debounced transition from `Working` to `Idle` $\rightarrow$ emits `agent_finished`.
- Asynchronous non-blocking dispatch via `tokio::spawn` guarantees zero daemon stall.

### 4.3. Lazygitrs Floating Review Popup
Integrated in [`tmux/.config/tmux/lazygitrs-popup.sh`](../../tmux/.config/tmux/lazygitrs-popup.sh):
- Emits `review_start "$PROJECT_DIR"` and `review_size "$PROJECT_DIR" <lines>` before popup display, and touches `<git-dir>/waymux-reviewed`, which clears the Cockpit's "done, not reviewed" state for that worktree.
- Blocks synchronously while isolator and Lazygitrs run.
- Emits `review_end "$PROJECT_DIR"` upon dismissal with exact review duration.

---

## 5. Telemetry Engine & Visualization (`flow-telemetry`)

Located at [`tmux/.config/tmux/flow-telemetry.py`](../../tmux/.config/tmux/flow-telemetry.py) and exposed globally via `utils/.local/bin/flow-telemetry`.

### 5.1. Daily Evidence Summary Banner
Formatted from today's events only. Missing data is shown as `—` or "no reviews recorded", never as a target value; statuses in the markdown table are computed against each target (`✅` / `⚠️` / `— no data`). The demo values below appear only with `--canonical`:
```
Today you had 4h12min of uninterrupted flow, 8 reviews averaging 92s, and no agent sat idle > 2 min
```
The HUD and markdown views also report the median time from a finished task to opening its review and the median review rate in lines per minute.

### 5.2. Hourly Focus Heatmap
Renders an ASCII/ANSI block density chart from 08h to 23h:
```
  08 09 10 11 12 13 14 15 16 17 18 19 20 21 22 23
  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ░  ▓  █  ·  ·  · 
  Legend: · Empty  ░ Light  ▒ Focus  ▓ Intense  █ Deep Work
```

### 5.3. Cockpit HUD (`Prefix + Space` then `?`)
In [`tmux/.config/tmux/cockpit-picker-help.sh`](../../tmux/.config/tmux/cockpit-picker-help.sh), pressing `?` renders the live ANSI telemetry summary banner, the hourly deep work heatmap, the latency evidence breakdown, and the Cockpit keybindings sheet.

### 5.4. Keybindings Catalog HUD (`Prefix + ?`)
In [`tmux/.config/tmux/keybindings-preview.sh`](../../tmux/.config/tmux/keybindings-preview.sh), selecting `Prefix + ?` generates a full GitHub Flavored Markdown preview containing the evidence summary badge, Markdown heatmap table, and latency status matrix.

---

## 6. CLI Usage

```bash
# Display full colored HUD view in terminal
flow-telemetry

# Display one-line evidence summary
flow-telemetry --summary

# Display canonical benchmark summary
flow-telemetry --summary --canonical

# Output GitHub-flavored markdown report
flow-telemetry --markdown

# Output machine-readable JSON metrics
flow-telemetry --json
```

All commands are cataloged in `intelli-shell/.config/intelli-shell/custom.commands` (`Ctrl + T` discoverable).

---

## 7. Key Telemetry (`key-telemetry`)

Which shortcuts you use, which you never press, and where a shorter path existed. Presses land in `$XDG_STATE_HOME/flow/keys.tsv`, separate from `events.tsv` so they never inflate the flow clusters or the heatmap:

| Column | Example | Meaning |
|:---|:---|:---|
| epoch | `1792809841` | Seconds |
| context | `tmux`, `cockpit`, `cockpit-filter` | Where the key was pressed (Cockpit filter mode is separate) |
| key | `prefix:I`, `g`, `enter`, `esc` | tmux `<table>:<key>`, or the Cockpit key |
| state | `permission`, `review` | Agent state of the Cockpit row the key acted on |
| target | `dotfiles/main:2` | That row's `session:window` (tmux: the current window) |
| origin | `dotfiles/main:0` | The window the Cockpit was opened from |

- **tmux:** [`key-telemetry.py install`](../../tmux/.config/tmux/key-telemetry.py) runs last in `tmux.conf` and rebinds every prefix and root binding (mouse excluded) as `run-shell -b "<waymux> keylog …" \; <original command>`. The log call runs in the background, so the binding keeps its latency; each key keeps its note (`-N`), so `list-keys -N` stays complete; a second run never wraps twice, a waymux without `keylog` is left alone, and `set -g @key_telemetry off` disables it.
- **Cockpit:** every key in the waymux preset starts with `ExecuteAsync(waymux keylog cockpit …)`; `Enter` and `Esc` are logged by the Cockpit itself, which knows the chosen row. `WAYMUX_KEYLOG=0` turns logging off.

`key-telemetry` (or `key-telemetry report --days N`, default 14) prints three sections:

1. **Most used:** presses per action, aliases merged (`g`, `G`, `gg`, `ctrl-g` count as one).
2. **Never used:** actions bound in `tmux.conf` or the Cockpit with no press in the window; tmux and plugin defaults are only counted.
3. **Faster paths:** habits where a shorter route existed:
   - `Enter` in the Cockpit on an agent waiting for you → `Prefix + I`
   - `g` in the Cockpit on the window it was opened from → `Ctrl + G`
   - `s` in the Cockpit to reach sessions → `Prefix + s`
   - Cockpit opened and closed with `Esc` only (3+ times) → status bar icons and `Prefix + I`
   - the same tmux key 3+ times within 3 s (resize and pane moves excluded) → `Prefix + f` or the window number
   - `cd <path>` in shell history (atuin, 5+ times) → `j <query>` or `Tab` on an empty prompt

