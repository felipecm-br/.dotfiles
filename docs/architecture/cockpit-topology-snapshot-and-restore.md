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
              "resume": {
                "agent": "claude",
                "id": "0d5f3c1e-8a2b-4c6d-9e0f-1a2b3c4d5e6f",
                "launch": ["jail-claude-ask", "--model", "opus"]
              },
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
- Hooked in [`record-window-state.sh`](../../tmux/.config/tmux/record-window-state.sh) on `pane-focus-in` (`--track #{pane_id}`, run in the background with `run-shell -b` so focus changes never wait on it; a run whose pane already lost focus discards its result).
- Protected by a **zero-fork timestamp debounce** (`~/.local/state/tmux/cockpit-snap-debounce.lock`), ensuring detached capture runs at most once every 30 seconds.
- Internal sessions (such as `_popups`) are filtered out automatically.
- **Before shutdown:** `cockpit-shutdown-save.service` (enabled by `.shell/install/packages/cockpit-shutdown-save.zsh`) holds a logind delay lock and runs `cockpit snapshot` on `PrepareForShutdown`, so the file holds the layout of the last second rather than of the last focus change. logind waits up to `InhibitDelayMaxSec` (5 s by default); a snapshot takes about 40 ms. Suspend does not trigger it; the journal (`journalctl --user -u cockpit-shutdown-save -b -1`) records each save.
- **Kept until restored:** every snapshot records its tmux server (pid and start time). The first snapshot a new server takes (after a reboot or a tmux restart, usually from the focus hook within seconds) moves the old server's last snapshot to `session-topology.previous.json` instead of overwriting it.

### 3.1b. Agent Sessions (`resume`)

A pane gets `resume` only when an agent is still running anywhere below it (a jailed Claude sits under `ai-jail`, `bwrap` and `ai-memory`), from two pane options:

| Option | Set by | Example |
|:---|:---|:---|
| `@ai_session` | `waymux` daemon (0.7.0 and later), from the agent's `SessionStart` and `UserPromptSubmit` hooks (the daemon sets it, since a jailed hook cannot reach tmux) | `claude:0d5f3c1e-…` |
| `@ai_launch` | `ai-launch`, before it starts the agent; a plain shell clears it | `jail-claude-ask --model opus` |

Both are checked when saved and again when restored, because restore types the command into a shell: the id must be 8 to 64 letters, digits, `-` or `_`, and each launch word a plain option. A launch tag from another harness is ignored (Devin runs Claude's hooks too), and so is the whole tag when the agent has exited.

### 3.2. Forensic Reconstruction (`cockpit restore`)
**Automatic after a reboot:** the first tmux session after a boot runs `cockpit restore --auto` (the `session-created[42]` hook in `tmux.conf`). It acts only on a snapshot taken before this boot, so restarting tmux without a reboot never brings back sessions you closed; it restores once (a lock stops two terminals from both restoring), writes its output to `~/.local/state/cockpit/restore.log`, and shows `cockpit: restored N sessions, M agents resumed` in tmux. It stays in the session the terminal opened when the snapshot has it, and switches to the saved active session otherwise. `set -g @cockpit-auto-restore off` turns it off; `cockpit restore` still works by hand.

When `cockpit restore` executes:
1. Verifies Tmux server availability (`tmux start-server` if stopped).
2. Reads `session-topology.previous.json` when an earlier server's snapshot is waiting there, else `session-topology.json` (`--file` picks another). After a restore from it, the file becomes `session-topology.restored.json`, so a second `cockpit restore` does not bring back windows closed since.
3. Inspects currently running Tmux sessions:
   - For pre-existing sessions, missing windows are created. A window that is only a fresh shell (one pane, nothing running: the session a new terminal opens after a reboot) is taken over: `cd` to the saved path, then rebuilt like a missing one. Any other window is left untouched.
   - For dead/unstarted sessions, creates the session detached at the saved window size, then every window at its exact index (`-t <session>:<index>`).
4. Rebuilds each window pane by pane at the saved paths, in order, then applies the saved layout.
5. Starts each pane again: a saved agent resumes its conversation (`ai-launch <launch words> --resume <id>`, or `claude --resume <id>` without a launch tag, `codex resume <id>`), any other recorded foreground application starts as before.
6. Switches client focus back to the saved `active_session`.

---

## 4. CLI Interface

The unified `cockpit` binary (`utils/.local/bin/cockpit`) manages both the interactive TUI HUD and the topology lifecycle:

| Command | Action |
|:---|:---|
| `cockpit` | Open Cockpit interactive HUD modal (85% × 75%) |
| `cockpit snapshot` | Save current Tmux session topology & worktree states |
| `cockpit restore` | Restore the sessions, windows, panes and agents of the last tmux server (runs by itself after a reboot; by hand after a tmux restart) |
| `cockpit restore --auto` | What the `session-created` hook runs: restore once, only a snapshot from before this boot |
| `cockpit restore --dry-run` | Simulate restoration without mutating Tmux state |
| `cockpit status` | Display the snapshot `cockpit restore` would use, its age and sessions |
| `cockpit-shutdown-save` | Hold the shutdown delay lock and snapshot on shutdown (run by `cockpit-shutdown-save.service`) |

Contract test: [`tests/cockpit_restore.test.sh`](../../tests/cockpit_restore.test.sh) (pane order, layout, resume through `ai-launch`, dropped tags, a tampered snapshot, the shutdown watcher).

All commands are cataloged in `intelli-shell/.config/intelli-shell/custom.commands` for instant discoverability (`Ctrl + T`).
