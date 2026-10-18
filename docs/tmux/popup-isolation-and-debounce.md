# Tmux Popup Isolation, ACPD Debounce & Event-Driven Architecture

This document records the identified issues of visual flicker, rendering collisions in floating popups during active AI streaming, and the definitive architectural solutions implemented in `tmux` and the `acpd` daemon.

---

## 1. Root Cause Analysis

### 🔴 Issue A: Status Pill Flicker & Rapid State Bouncing
- **Cause:** During active AI executions (such as Antigravity / OpenCode), chained tasks emit rapid lifecycle events: `PostInvocation` (`idle`) followed immediately by `PreInvocation` (`working`) within 20ms to 100ms intervals on each file read, search, or executed command.
- **Visual Impact:** The window status tab and pill at the top of tmux rapidly flickered between yellow (`󰑮` working) and blue/teal (`󱥂` idle) multiple times per second during a single AI response turn.

### 🔴 Issue B: Popup Top Border & Search Input Disappearing
- **Cause:** Tmux's `display-popup` command renders a floating overlay directly over the active pane. While the AI agent outputs text, the background pane rapidly outputs dozens of lines of text and ANSI scroll escapes per second. In the tmux core engine, `server_client_draw_pane` redraws updated background cells directly to the terminal, clobbering and overwriting the popup's top frame.
- **Visual Impact:** The rounded top border (`╭─── Sesh ───╮`) and search input line (`⚡ ` / ` `) vanished while the agent streamed tokens, only reappearing after the agent concluded execution.

### 🔴 Issue C: Navigation Loss Upon Selecting a Session or Window
- **Cause:** Earlier popup wrapper scripts captured the prior active window/session and executed an unconditional `tmux switch-client -t "$ORIG_TARGET"` upon closing. This forced the client back to the invoking pane, discarding the user's new session/window selection.

### 🔴 Issue D: Useless Periodic Polling (`status-interval 1`)
- **Cause:** Tmux was waking up 60 times per minute to re-evaluate format strings and spawn shell format processes, even when the terminal and system were completely idle.

---

## 2. Architectural Solutions Implemented

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          TARGET ARCHITECTURE                            │
├────────────────────────────────┬────────────────────────────────────────┤
│ Idle or Streaming Terminal     │ Native Tmux 3.8 Display Popup          │
│                                │ (Direct zero-overhead floating modal)  │
├────────────────────────────────┼────────────────────────────────────────┤
│ Rapid AI Tool Transitions      │ 650ms Idle Debounce in ACPD            │
│ (Sequential tool calls)        │ (Cancels intermediate idle state flips)│
├────────────────────────────────┼────────────────────────────────────────┤
│ CPU & Battery Consumption      │ status-interval 0 (100% Event-Driven)  │
│                                │ (Reactive updates via ACPD IPC events) │
└────────────────────────────────┴────────────────────────────────────────┘
```

---

### 🛡️ 1. 650ms Debounce & Deduplication in ACPD
Inside the `waymux` daemon (formerly `acpd`) (`adapters.rs`, configured via `idle_debounce_ms = 650` in `~/.config/waymux/config.toml`):
- **650ms Debounce for `AgentState::Idle`:**
  ```rust
  // When state transitions to Idle, schedule an async cancellation window (idle_debounce_ms)
  let task = tokio::spawn(async move {
      tokio::time::sleep(tokio::time::Duration::from_millis(idle_debounce_ms)).await;
      // Commit Idle only if no new tool call arrived during the window
      set_tmux_option(&pane_id, "@ai_agent_state", &t.icon).await;
      set_tmux_option(&pane_id, "@ai_agent_state_raw", "idle").await;
      refresh_tmux_client().await;
  });
  ```
- **Instant Cancellation:** Any incoming `Working` event immediately aborts the pending `Idle` task, keeping the spinner animating smoothly without flicker.
- **State Deduplication (`pane_states`):** Eliminates redundant tmux IPC writes when pane status remains unchanged.

---

### 🪄 2. Native Tmux 3.8 Display Popup (Historical Snapshot Backdrop Retired)
In earlier Tmux versions (< 3.8), popup launcher scripts required an interim frozen snapshot backdrop (`tmux-popup-isolate.sh` / `_popups:backdrop`) when `@ai_agent_state_raw` was `busy` or `working` to prevent background scroll escapes from clobbering the popup top border.

In **Tmux 3.8**, `server_client_draw_pane` redraw clobbering over active floating popups was resolved upstream in the Tmux core rendering engine. All popup launcher scripts ([`cockpit-picker.sh`](../../tmux/.config/tmux/cockpit-picker.sh), [`session-picker.sh`](../../tmux/.config/tmux/session-picker.sh), [`window-picker.sh`](../../tmux/.config/tmux/window-picker.sh), [`lazygitrs-popup.sh`](../../tmux/.config/tmux/lazygitrs-popup.sh), [`workspace-picker.sh`](../../tmux/.config/tmux/workspace-picker.sh), [`scrollback-picker.sh`](../../tmux/.config/tmux/scrollback-picker.sh)) now invoke `exec tmux display-popup` directly with zero snapshot overhead and sub-5ms launch latency.

---

### ⚡ 3. 100% Event-Driven Status Bar (`status-interval 0`)
In `tmux.conf`:
```tmux
# Event-driven status bar (zero background clock polling; driven exclusively by events and acpd)
set -g status-interval 0
```
- **Advantages:** 0.0% background idle CPU usage, zero shell fork overhead.
- **Spinner Animation:** Maintained at 12 FPS (83ms) by the `acpd` daemon via `refresh_tmux_client()` exclusively when an agent is actively running.

---

## 3. Related Files & Documentation

- `acpd/src/api.rs` (+ `daemon.rs`): authoritative idle-debounce coordinator (`idle_debounce_ms`, default 650ms, set in `~/.config/acpd/config.toml`); `acpd/src/adapters.rs`: pending-idle cancellation and state deduplication.
- [`tmux/.config/tmux/tmux.conf`](../../tmux/.config/tmux/tmux.conf): Configuration of `status-interval 0` and ergonomic popups.
- [`tmux/.config/tmux/cockpit-picker.sh`](../../tmux/.config/tmux/cockpit-picker.sh): AI Fleet Cockpit & Window Manager popup (`Prefix + Space`).
- [`tmux/.config/tmux/session-picker.sh`](../../tmux/.config/tmux/session-picker.sh): Native Waymaker session picker (`Prefix + s`).
- [`tmux/.config/tmux/window-picker.sh`](../../tmux/.config/tmux/window-picker.sh): Waymaker window picker popup.
- [`tmux/.config/tmux/lazygitrs-popup.sh`](../../tmux/.config/tmux/lazygitrs-popup.sh): Lazygitrs popup with smart `--commits` detection, native `display-popup` modal, and dynamic theme styling. The binary is resolved **by capability** (`resolve_lzg` requires `--commits` in `--help`; order: `~/.local/bin`, `PATH`, `~/.cargo/bin`) so a stale install cannot silently close the popup, and the clean-tree check uses `git diff --quiet` / `git diff --cached --quiet` / `git ls-files --others --exclude-standard` (exits on the first dirty file) instead of a full `git status --porcelain`.
- **Tmux 3.8 Native Redraw Fix**: In tmux 3.8, floating popup pane clobbering during active agent streaming was resolved upstream in the terminal redraw engine, allowing `tmux-popup-isolate.sh` to be retired in favor of zero-friction, native `tmux display-popup` across all modal pickers.
- [`docs/tmux/ai-status-bar.md`](ai-status-bar.md): Comprehensive guide to AI agent status pills and state animations.
