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
| `session` | Tmux hook `client-session-changed` | Session Name | — | Context switch between workspaces (test `_test_*` and `_popups` sessions are skipped) |
| `window` | Tmux hook `after-select-window` | `session:win` | — | Focus transition between windows (same filter) |
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
Formatted from today's events only. Missing data is shown as `—` or "nenhuma revisão registrada", never as a target value; statuses in the markdown table are computed against each target (`✅` / `⚠️` / `— sem dados`). The demo values below appear only with `--canonical`:
```
Hoje você teve 4h12min de fluxo ininterrupto, 8 revisões com média de 92s e nenhum agente ficou ocioso > 2 min
```
The HUD and markdown views also report the median time from a finished task to opening its review and the median review rate in lines per minute.

### 5.2. Hourly Focus Heatmap
Renders an ASCII/ANSI block density chart from 08h to 23h:
```
  08 09 10 11 12 13 14 15 16 17 18 19 20 21 22 23
  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ░  ▓  █  ·  ·  · 
  Legenda: · Vazio  ░ Leve  ▒ Foco  ▓ Intenso  █ Deep Work
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
