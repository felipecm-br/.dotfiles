# Remote AI Agent Execution & ACPD Orchestration Workflow

This document specifies the remote agent execution architecture using **ACPD** (Agent Client Protocol Daemon), **Tmux**, and **Tailscale** within the dotfiles ecosystem.

---

## 1. Executive Summary

Instead of relying on monolithic terminal multiplexers like Herdr that replace your entire environment and break Neovim navigation, code review loops (`lazygitrs`), and Matchmaker pickers, this setup uses a **modular Unix-philosophy Control Plane**:

```mermaid
flowchart LR
    subgraph Client["Remote Client (Laptop / Mobile / Remote CLI)"]
        RC["SSH / Mosh / HTTP Curl"]
    end

    subgraph Tunnel["Network Layer"]
        TS["Tailscale Mesh VPN (Tailscale SSH / WireGuard)"]
    end

    subgraph Host["Local Workstation"]
        ACPD["acpd Daemon (127.0.0.1:4040/rpc)"]
        TMUX["Tmux Multiplexer & Popups"]
        CLI["acpd-cli (Ergonomic Wrapper)"]
        AGENTS["AI Agents (agy, opencode, claude)"]
        GIT["Git Worktrees (awt) & lazygitrs"]
    end

    RC -->|Secure Ingress| TS
    TS -->|Tailscale SSH| CLI
    TS -->|Tailscale Serve (Optional HTTPS)| ACPD
    CLI -->|JSON-RPC 2.0| ACPD
    ACPD -->|State & Windows| TMUX
    TMUX --> AGENTS
    AGENTS --> GIT
```

---

## 2. Architectural Comparison: ACPD vs. Herdr

| Capability | Current Stack (`acpd` + Tmux) | Herdr |
| :--- | :--- | :--- |
| **Control Plane** | Lightweight Rust daemon (`acpd` @ `127.0.0.1:4040`) | Monolithic terminal emulator & multiplexer |
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
   If you want to invoke `acpd` directly over HTTP JSON-RPC from another machine on your tailnet:
   ```bash
   tailscale serve --bg 4040
   ```

---

## 4. The `acpd-cli` Workflow Tool

The `acpd-cli` utility ([`acpd/.local/bin/acpd-cli`](file:///home/fecavmi/.dotfiles/main/acpd/.local/bin/acpd-cli)) provides a unified CLI interface to communicate with the `acpd` daemon:

### Available Commands

- `acpd-cli status`: Check daemon health, active AI agent states (`working`, `idle`, `waiting`, `permission`, `stalled`, `error`), and active Tmux sessions.
- `acpd-cli run [options] <cmd...>`: Run an agent or command inside a managed Tmux session.
  - `-s, --session <name>`: Target session (default: `agents`).
  - `-w, --window <name>`: Target window name.
  - `-d, --detach`: Launch detached in background without attaching.
  - `-p, --split`: Split active pane instead of creating a new window.
- `acpd-cli wait <pane_id> [options]`: Wait synchronously for an agent pane to reach a target state.
  - `-s, --state <state>`: Target state (default: `idle`).
  - `-t, --timeout <secs>`: Timeout in seconds (default: `300`).
- `acpd-cli dismiss [pane_id]`: Dismiss attention/question/permission badge and notification (automatically called by Tmux `pane-focus-in` hook).
- `acpd-cli list [agents|sessions|windows|panes]`: List active resources.
- `acpd-cli capture <pane_id> [lines]`: Capture scrollback output from a target pane.
- `acpd-cli send <pane_id> <keys...>`: Send keystrokes or prompts to an agent pane.
- `acpd-cli msg <text>`: Display banner notification on the Tmux status bar.
- `acpd-cli bell [pane_id]`: Trigger visual and audible bell notification.
- `acpd-cli kill <target>`: Terminate pane, window, or session.

### Proactive Agent Supervision & Stall Detection

`acpd` includes built-in proactive supervision heuristics:
1. **Stall Detection (Heurística de Detecção de Agente Travado):**
   - When an agent is in `working` state, `acpd` samples pane output (scrollback diff and cursor position) and Linux process tree CPU ticks (`utime + stime`) every 5 seconds.
   - If a pane emits **no new text output for > 20 seconds** and CPU delta is **zero**, `acpd` transitions the state to `stalled` (glyph `󱥁`, amber color `#fab387` / `#e09d7f`) and triggers an alert.
   - If output resumes or CPU activity picks up, `acpd` automatically recovers the state back to `working`.
2. **Auto-Dismiss on Pane Focus:**
   - When an agent requests attention (`question` or `permission`), switching to that window/pane immediately triggers Tmux's `pane-focus-in` hook.
   - The hook invokes `acpd-cli dismiss #{pane_id}`, which clears the notification bell banner and transitions the badge to `idle` without requiring any manual clicks or reset chords.
3. **Synchronous Synchronization (`agentState/wait`):**
   - Sub-agents, orchestrators, and shell scripts can wait for another agent to complete:
     ```bash
     acpd-cli wait %2 --state idle --timeout 120
     ```

### The `acpd` binary itself

The daemon binary handles these arguments **before** initializing logging, the PID file or the network listener, so they are safe to call at any time (they never start or disturb a running daemon):

- `acpd --version` / `acpd -V`: Print the version and exit.
- `acpd --help` / `acpd -h`: Print usage and exit.
- `acpd health`: `GET /health` against `127.0.0.1:4040`; prints the JSON (`status`, `uptime_secs`) and exits 0, or exits 1 if the daemon is unreachable.
- `acpd --config <FILE>` (also `-c <FILE>` and `--config=<FILE>`): Start the daemon with a custom `config.toml`.

> Running an already-running daemon's binary again with no arguments still attempts to start a second instance (it is stopped by the PID file guard). A rebuilt binary only takes effect in the running service after `systemctl --user restart acpd`, which clears in-memory agent state until each pane's next hook.

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
ssh user@my-desktop "acpd-cli run -d -s background -w refactor 'awt -c refactor/auth main -- agy'"
```

### Recipe 3: Checking Progress and Capturing Output Remotely

```bash
# 1. Check which agents are active and their status
ssh user@my-desktop "acpd-cli status"

# 2. Capture the last 40 lines of pane %0
ssh user@my-desktop "acpd-cli capture %0 40"

# 3. Send approval confirmation ("y") to an agent waiting for input
ssh user@my-desktop "acpd-cli send %0 y Enter"
```

---

## 6. Related References

- [Workflow vs. Herdr Comparison](file:///home/fecavmi/.dotfiles/main/docs/articles/workflow-vs-herdr-comparison.md)
- [ACPD Tmux Skill](file:///home/fecavmi/.dotfiles/main/.agents/skills/acpd-tmux/SKILL.md)
- [Terminal Ergonomics & UX Manifesto](file:///home/fecavmi/.dotfiles/main/docs/architecture/terminal-ergonomics-and-ux-manifesto.md)
- [AWT Worktree Workflow](file:///home/fecavmi/.dotfiles/main/docs/GIT_WORKTREE_AGENTIC_WORKFLOW.md)
