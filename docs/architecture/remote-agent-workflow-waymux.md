# Remote AI Agent Execution & Waymux Orchestration Workflow

This document specifies the remote agent execution architecture using **Waymux** (unified control plane daemon and CLI), **Tmux**, and **Tailscale** within the dotfiles ecosystem.

---

## 1. Executive Summary

Instead of relying on monolithic terminal multiplexers like Herdr that replace your entire environment and break Neovim navigation, code review loops (`lazygitrs`), and Waymaker pickers, this setup uses a **modular Unix-philosophy Control Plane**:

```mermaid
flowchart LR
    subgraph Client["Remote Client (Laptop / Mobile / Remote CLI)"]
        RC["SSH / Mosh / HTTP Curl"]
    end

    subgraph Tunnel["Network Layer"]
        TS["Tailscale Mesh VPN (Tailscale SSH / WireGuard)"]
    end

    subgraph Host["Local Workstation"]
        WAYMUX["Waymux Daemon (127.0.0.1:4040/rpc)"]
        TMUX["Tmux Multiplexer & Popups"]
        CLI["waymux-cli / waymux (Ergonomic Wrapper)"]
        AGENTS["AI Agents (agy, opencode, claude)"]
        GIT["Git Worktrees (awt) & lazygitrs"]
    end

    RC -->|Secure Ingress| TS
    TS -->|Tailscale SSH| CLI
    TS -->|Tailscale Serve (Optional HTTPS)| WAYMUX
    CLI -->|JSON-RPC 2.0| WAYMUX
    WAYMUX -->|State & Windows| TMUX
    TMUX --> AGENTS
    AGENTS --> GIT
```

---

## 2. Architectural Comparison: Waymux vs. Herdr

| Capability | Current Stack (`waymux` + Tmux) | Herdr |
| :--- | :--- | :--- |
| **Control Plane** | Lightweight Rust daemon (`waymux` @ `127.0.0.1:4040`) | Monolithic terminal emulator & multiplexer |
| **Multiplexer Freedom** | Native Tmux, Golden-Ratio Popups, Neovim navigation | Proprietary terminal backend |
| **Code Review Loop** | Bidirectional inline diff reviews via `lazygitrs` | No git diff or review integration |
| **Agent State Detection** | Structured hooks (`api/status`, Bearer token auth) | Screen scraping / PTY heuristics |
| **Remote Ingress** | Zero-trust Tailscale SSH / Tailscale Serve | Requires exposing SSH profile or port |
| **Ergonomics & Memory** | Home Row anchored ($H=0$), sub-100ms latency | Incompatible with Tmux/Vim chords |

---

## 3. Network & Ingress Setup (Tailscale)

Machines behind residential NAT or CGNAT connect seamlessly via **Tailscale**:

1. **Install Packages:**
   ```bash
   sudo pacman -S tailscale mosh
   ```
2. **Enable Service:**
   ```bash
   sudo systemctl enable --now tailscaled
   ```
3. **Authenticate with Tailscale SSH:**
   ```bash
   sudo tailscale up --ssh
   ```
   *Benefit:* Tailscale SSH handles cryptographic authentication automatically via your Tailnet identity without needing manual `authorized_keys` deployment or open public ports.

4. **Optional: Private Tailnet HTTPS Endpoint:**
   If you want to invoke `waymux` directly over HTTP JSON-RPC from another machine on your tailnet:
   ```bash
   tailscale serve --bg 4040
   ```

---

## 4. The `waymux-cli` Workflow Tool

The `waymux-cli` utility ([`waymux/.local/bin/waymux-cli`](../../waymux/.local/bin/waymux-cli)) provides a unified CLI interface to communicate with the `waymux` daemon:

### Available Commands

- `waymux-cli status`: Check daemon health, active AI agent states (`working`, `idle`, `waiting`, `permission`, `stalled`, `error`), and active Tmux sessions.
- `waymux-cli run [options] <cmd...>`: Run an agent or command inside a managed Tmux session.
  - `-s, --session <name>`: Target session (default: `agents`).
  - `-w, --window <name>`: Target window name.
  - `-d, --detach`: Launch detached in background without attaching.
  - `-p, --split`: Split active pane instead of creating a new window.
- `waymux-cli wait <pane_id> [options]`: Wait synchronously for an agent pane to reach a target state.
  - `-s, --state <state>`: Target state (default: `idle`).
  - `-t, --timeout <secs>`: Timeout in seconds (default: `300`).
- `waymux-cli dismiss [pane_id]`: Dismiss attention/question/permission badge and notification (automatically called by Tmux `pane-focus-in` hook).
- `waymux-cli list [agents|sessions|windows|panes]`: List active resources.
- `waymux-cli capture <pane_id> [lines]`: Capture scrollback output from a target pane.
- `waymux-cli send <pane_id> <keys...>`: Send keystrokes or prompts to an agent pane.
- `waymux-cli msg <text>`: Display banner notification on the Tmux status bar.
- `waymux-cli bell [pane_id]`: Trigger visual and audible bell notification.
- `waymux-cli kill <target>`: Terminate pane, window, or session.

### Proactive Agent Supervision & Stall Detection

`waymux` includes built-in proactive supervision heuristics:
1. **Stall Detection (Hung Agent Heuristic):**
   - When an agent is in `working` state, `waymux` samples pane output (scrollback diff and cursor position) and Linux process tree CPU ticks (`utime + stime`) every 5 seconds.
   - If a pane emits **no new text output for > 20 seconds** and CPU delta is **zero**, `waymux` transitions the state to `stalled` (glyph `󰔟`, amber color `#fab387` / `#e09d7f`) and triggers an alert.
   - If output resumes or CPU activity picks up, `waymux` automatically recovers the state back to `working`.
2. **Auto-Dismiss on Pane Focus:**
   - When an agent requests attention (`question` or `permission`), switching to that window/pane immediately triggers Tmux's `pane-focus-in` hook.
   - The hook invokes `waymux-cli dismiss #{pane_id}`, which clears the notification bell banner and transitions the badge to `idle` without requiring any manual clicks or reset chords.
3. **Synchronous Synchronization (`agentState/wait`):**
   - Sub-agents, orchestrators, and shell scripts can wait for another agent to complete:
     ```bash
     waymux-cli wait %2 --state idle --timeout 120
     ```

### The `waymux` Unified Binary (`v0.2.0+`)

The crate builds `waymux` from a unified Rust library (`src/lib.rs`). All client subcommands are intercepted synchronously **before** initializing logging, the PID file, or the multi-threaded Tokio runtime (<1.5ms startup overhead):

- `waymux --version` (`-V`): Print the version and exit.
- `waymux --help` (`-h`): Print usage and exit.
- `waymux health`: `GET /health` against `127.0.0.1:4040`; prints the JSON (`status`, `uptime_secs`) and exits 0, or exits 1 if the daemon is unreachable.
- `waymux status`: Print daemon health and active AI agent states across Tmux panes.
- `waymux list`: List active AI agent pane states in TSV format (`pane_id`, `state`, `last_timestamp`).
- `waymux dismiss [pane_id]`: Dismiss attention/question/permission badge for a pane (invoked directly by Tmux `pane-focus-in` hook).
- `waymux daemon [--config <FILE>]` (managed via `waymux.service`): Start the async Axum/Tokio control plane daemon.
- `waymux cockpit`: Launch the Golden-Ratio (`85% × 75%`) AI Fleet & Window Cockpit HUD via Waymaker (`wm`) with an embedded preset and `@SEGMENT_BG`/`@FG`/`@ACCENT_COLOR` theme synchronization.
- `waymux cockpit-items`: Generate the 12-column TSV rows for Waymaker using native `/proc/<pid>/stat` and `/proc/<pid>/comm` scanning (~14ms).
- `waymux cockpit-preview <session> <idx> <pane_id> [path]` / `waymux cockpit-diff <path> [pane_id]` / `waymux cockpit-help`: Render live terminal previews, `delta` side-by-side git diffs, and telemetry help cards.
- `waymux agent-action <approve|deny|prompt> <state> <pid> [pane_id]` & `waymux review-notes <count|list|send> ...`: Execute guarded agent prompt actions (`approve`/`deny` re-read the daemon's live state and ignore a prompt on screen for less than 400 ms; `deny` sends `Esc`, never `Enter`; a call matching a risk rule needs a second `approve` within 3 s) and dispatch `.git/info/lines.json` review notes through the delivery queue.
- `waymux triage --popup` & `waymux triage --jump`: Cycle notifying AI agent panes in an isolated `_popups` overlay or jump directly with return-origin memory.
- `waymux hook <tmux|lazygit> [event]` & `waymux inject <workspace_dir> <prompt>`: Native sub-10ms AI lifecycle hooks and prompt delivery through the queue.
- `waymux queue <add <pane> <text>|ls [pane]|rm <pane> [id]>`: The daemon holds prompts and types them only after 1 s of `idle`, one per rest, never into `working`/`permission`/`question`; a prompt not taken in 5 s is marked `stalled` and never retyped. See [the TUIOS roadmap](tuios-benchmark-and-agent-inbox-roadmap.md#4-adoption-roadmap).
- Away recap & alert bursts: after 10 minutes away from a pane, the Cockpit preview opens with one line of what its agent did since you last focused it (turns, files, commands, last test; RPC `agent/recap`). Blocking alerts within 1.5 s play one sound and share one status-bar line (`3 agents need you › …`).
- `waymux wt <subcommand>` (or invoked via `awt` symlink): Native Git worktree orchestrator (`new`, `go`, `ls`, `rm`, `ship`, `reap`, `sweep`, `pick`).
- `waymux init <--tmux|--systemd|--hooks>`: Emit portable integration snippets for `.tmux.conf`, user systemd, and agent hooks.

> Running an already-running daemon's binary again with no arguments still attempts to start a second instance (it is stopped by the PID file guard). A rebuilt binary only takes effect in the running service after `systemctl --user restart waymux.service`.

---

## 5. Remote Workflows in Practice

### Recipe 1: Interactive Remote Agent Session via Tailscale SSH

From any laptop, tablet, or terminal on your Tailnet:
```bash
# Connect and automatically attach to the agents session:
ssh -t user@my-desktop "tmux new -A -s agents"
```

Or connect using `mosh` for high resilience over unstable Wi-Fi:
```bash
mosh user@my-desktop -- tmux new -A -s agents
```

### Recipe 2: Detached Background Execution (Fire-and-Forget)

Dispatch a long-running agent command without keeping the remote connection open:
```bash
ssh user@my-desktop "waymux-cli run -d -s background -w refactor 'awt -c refactor/auth main -- agy'"
```

### Recipe 3: Checking Progress and Capturing Output Remotely

```bash
# 1. Check which agents are active and their status
ssh user@my-desktop "waymux-cli status"

# 2. Capture the last 40 lines of pane %0
ssh user@my-desktop "waymux-cli capture %0 40"

# 3. Send approval confirmation ("y") to an agent waiting for input
ssh user@my-desktop "waymux-cli send %0 y Enter"
```

---

## 6. Related References

- [State-of-the-Art Terminal Agent Workflow](state-of-the-art-terminal-agent-workflow.md)
- [Waymux Skill](../../.agents/skills/waymux/SKILL.md)
- [Terminal Ergonomics & UX Manifesto](terminal-ergonomics-and-ux-manifesto.md)
- [AWT Worktree Workflow](../GIT_WORKTREE_AGENTIC_WORKFLOW.md)
