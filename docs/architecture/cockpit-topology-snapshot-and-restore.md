# Cockpit Session Topology Snapshot & Restore Architecture

## 1. Executive Summary

This architecture establishes a persistent **Session Topology Snapshot & Post-Reboot Restore Engine** for the Tmux and Cockpit ecosystem.

Whenever the host operating system restarts, Tmux terminates, or an unrecoverable system crash occurs, the operator's entire multi-workspace layout—including active sessions, windows, indices, names, paths, split layouts, and foreground CLI tools (e.g. `nvim`, `lazygitrs`, `opencode`)—is resurrected in milliseconds via a single command:

```bash
cockpit restore
```

---

## 2. Architecture & Data Protocol

### 2.1. State Location
The canonical topology manifest is stored at:
```
~/.local/state/cockpit/session-topology.json
```

### 2.2. Schema (`session-topology.json`)

```json
{
  "timestamp": 1791676800,
  "datetime": "2026-10-10T22:28:34.672996",
  "active_session": "waymaker/main",
  "active_window": "0",
  "sessions": [
    {
      "name": "_dotfiles/main",
      "attached": false,
      "windows": [
        {
          "index": 0,
          "name": "",
          "layout": "c01d,207x54,0,0,0",
          "active": true,
          "panes": [
            {
              "index": 0,
              "id": "%0",
              "path": "/home/fecavmi/.dotfiles/main",
              "shell_cmd": "bash",
              "foreground_cmd": null,
              "agent_state": "busy",
              "active": true
            }
          ]
        }
      ]
    }
  ],
  "worktrees": [
    {
      "path": "/home/fecavmi/.dotfiles/main",
      "root": "/home/fecavmi/.dotfiles",
      "branch": "main"
    }
  ]
}
```

---

## 3. Capture & Restore Lifecycle

### 3.1. Automatic Background Snapshotting
- Hooked in [`record-window-state.sh`](../../tmux/.config/tmux/record-window-state.sh) on `pane-focus-in`.
- Protected by a **zero-fork timestamp debounce** (`/tmp/cockpit-snap-debounce-<UID>.lock`), ensuring detached capture runs at most once every 30 seconds.
- Internal sessions (such as `_popups`) are filtered out automatically.

### 3.2. Forensic Reconstruction (`cockpit restore`)
When `cockpit restore` executes:
1. Verifies Tmux server availability (`tmux start-server` if stopped).
2. Reads `session-topology.json`.
3. Inspects currently running Tmux sessions:
   - For pre-existing sessions, missing windows are created without modifying existing active panes.
   - For dead/unstarted sessions, creates the session detached, initializes window 0 at the exact path, applies the original Tmux layout, and spawns the recorded foreground application.
4. Resumes subsequent windows with their exact indices (`-t <session>:<index>`).
5. Switches client focus back to the saved `active_session`.

---

## 4. CLI Interface

The unified `cockpit` binary (`utils/.local/bin/cockpit`) manages both the interactive TUI HUD and the topology lifecycle:

| Command | Action |
|:---|:---|
| `cockpit` | Open Cockpit interactive HUD modal (85% × 75%) |
| `cockpit snapshot` | Save current Tmux session topology & worktree states |
| `cockpit restore` | Restore saved sessions, windows, paths and layouts post-reboot |
| `cockpit restore --dry-run` | Simulate restoration without mutating Tmux state |
| `cockpit status` | Display saved snapshot summary, timestamp, and age |

All commands are cataloged in `intelli-shell/.config/intelli-shell/custom.commands` for instant discoverability (`Ctrl + T`).
