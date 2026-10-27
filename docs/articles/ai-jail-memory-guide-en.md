# Definitive Guide: Using AI-Jail and AI-Memory Together

Setup, daily workflow, and troubleshooting for **ai-jail** (sandbox) and **ai-memory** (long-term memory) as wired in this dotfiles repo. Verified against **ai-jail 2.12.0** and **ai-memory 3.2.7** (2026-10-26).

Architecture and per-repo routing: [ai-memory-workflow.md](../architecture/ai-memory-workflow.md). Multi-repo walkthrough: [ai-memory-multi-repo-guide-en.md](ai-memory-multi-repo-guide-en.md).

---

## 1. Tool Overview

* **ai-jail**: Runs AI coding agents inside a Linux sandbox (`bubblewrap` + Landlock + seccomp). It is **accident prevention for a trusted-but-fallible agent**, not a security boundary against hostile code (use a VM for that). The project directory is the blast radius, which is what makes `--yolo` reasonable.
* **ai-memory**: A server (HTTP + MCP, default `127.0.0.1:49374`) with a git-backed markdown wiki and SQLite index that records sessions and observations across agents and hands work off between them.

### Sandbox defaults that matter here

| Default | Effect |
| :--- | :--- |
| Private home | The agent sees a fresh tmpfs `$HOME`, not your real one |
| `agent_state` (on) | The harness's own state dir (`~/.claude`, `~/.codex`, ...) is mounted read-write and its API-key env var is copied in |
| `toolchains` (on) | Persistent cargo/npm/go caches and filtered egress to package registries |
| Network (off) | **The jail has its own loopback, so the host's ai-memory daemon is unreachable unless forwarded (section 2)** |

Opt-outs: `--no-agent-state`, `--no-toolchains`, `--lockdown` (strictest). See the [upstream README](https://github.com/akitaonrails/ai-jail#readme).

---

## 2. One-Time Setup

### Step 1: Install and update both tools (Arch, x86_64)

```bash
yay -Syu ai-jail-bin ai-memory-bin
systemctl --user restart ai-memory      # required after every ai-memory upgrade
```

Or use the unified updater: `ai-update --only ai-suite` (see [section 6](#6-updating)).

### Step 2: Set up ai-memory

```bash
ai-memory setup --plan     # preview, changes nothing
ai-memory setup            # data dir + token, systemd --user unit, MCP + hooks + skills for detected agents
```

`setup` replaces the old manual `init` + `install-mcp` + `install-hooks` sequence and is idempotent. Limit it with `--agent claude-code --agent open-code`. Verify with `ai-memory status` and `ai-memory doctor`.

Dotfiles state (already stowed in the `ai-memory` package):

* Data dir: `ai-memory/.local/share/ai-memory` (symlinked into the repo)
* Service unit: `ai-memory/.config/systemd/user/ai-memory.service` (`ExecStart=/usr/bin/ai-memory serve --transport http`)

### Step 3: Let the jail reach the daemon (required)

Inside the jail, `127.0.0.1:49374` is the jail's own loopback, so MCP tools and hooks cannot reach the host daemon. Forward exactly that port in the **global** config `~/.ai-jail` (stowed from `zsh-plugins/.ai-jail`):

```toml
forward_ports = [49374]
```

Rules enforced by ai-jail:

* Only the CLI and the **global** config can open a forward. A project `.ai-jail` cannot, unless the global config lists it under `trust_project_config`.
* It cannot be combined with `--network` (the host loopback is already reachable there).
* A symlinked global config is followed only if the target is a regular file you own, not group/world-writable, and **outside the current project directory**.

One-off alternative: `ai-jail --forward-port 49374 ...`.

Verify:

```bash
cd /tmp && ai-jail bash -c 'curl -s -m4 http://127.0.0.1:49374/healthz'   # {"status":"ok"}
```

(ai-jail writes a `.ai-jail` file into the launch directory on first run; delete it if you do not want it.)

### Step 4: Add routing to the project

```bash
ai-memory install-instructions    # adds the marked ai-memory block to CLAUDE.md / AGENTS.md
```

---

## 3. Daily Workflow

### Option A: Managed workstream (recommended)

`ai-memory run` adds a startup handoff ("you stopped at X") and lets you switch agents on one shared workstream. Hooks and MCP are auto-wired on first use.

```bash
ai-memory run claude                 # outside the jail
ai-jail                              # global ~/.ai-jail runs: ai-memory run opencode --yolo
ai-jail ai-memory run --new my_session opencode --yolo
ai-memory run --jail opencode --yolo # ai-memory re-runs itself inside ai-jail
```

Useful `ai-memory run` flags: `--new <name>` (fresh workstream), `--workstream <name>`, `--fresh` (new native session), `--force-unlock` (only when the previous launcher is gone), `--no-jail`, `--true-yolo` (Claude `bypassPermissions`, best with ai-jail).

If a prompt asks which session to continue, answer it or force a new workstream with `--new`.

### Option B: Direct launch in the sandbox

The agent still reaches the memory over MCP (given the Step 3 forward), but gets no automatic handoff on boot.

```bash
ai-jail opencode --yolo
ai-jail codex --yolo
ai-jail agy
ai-jail claude
```

Known presets: `gemini`, `claude`, `codex`, `opencode`, `crush`, `soulforge`, `grok`, `pi`, `jcode`, `kimi`, `bash`; anything else is passed through as the command.

### Caveat: running ai-jail inside this dotfiles repo

`~/.ai-jail` is a symlink into `zsh-plugins/.ai-jail`, which is inside this repo. In `~/.dotfiles/main` ai-jail refuses to read it (`Refusing to read ~/.ai-jail: ... is inside the project directory`) and fails closed. Launch jailed agents from other projects, or run the agent unjailed here.

---

## 4. Verifying the Sandbox

1. `hostname` inside the agent prints `ai-sandbox`.
2. Startup banner: `▸ Jail Active: <path>` and `▸ Landlock: fully enforced`.
3. `ls ~/.ssh` is empty or denied (private home).
4. `ai-jail --dry-run <cmd>` prints the full `bwrap` argv without writing `.ai-jail`.
5. `ai-jail status` shows the project `.ai-jail` in the current directory.

---

## 5. Managing Memory

```bash
ai-memory status                              # server, providers, capture counters
ai-memory doctor                              # marker routing, missing hooks
ai-memory purge-project --confirm             # delete the CURRENT project (add --compact to reclaim bytes)
ai-memory delete-page --path <wiki/path.md>   # delete one page
ai-memory reset --confirm                     # wipe wiki/, db/, raw/ for ALL projects
ai-memory-clean --apply                       # repo helper: stale observations and orphan sessions
```

Deletes are logical: wiki git history and earlier backups still hold the content.

---

## 6. Updating

```bash
ai-update --check --only ai-suite     # version matrix, no changes
ai-update --only ai-suite             # ai-memory + ai-jail
yay -Syu ai-jail-bin ai-memory-bin    # manual equivalent (x86_64)
systemctl --user restart ai-memory    # always after upgrading ai-memory
```

On aarch64 build from source instead: `cargo install --locked ai-jail` and `cargo install --git https://github.com/akitaonrails/ai-memory ai-memory-cli`.

---

## 7. Troubleshooting

| Symptom | Cause / fix |
| :--- | :--- |
| `Connection refused (os error 111)` outside the jail | Daemon stopped: `systemctl --user start ai-memory` |
| Memory tools time out or fail only **inside** the jail | Missing forward. Add `forward_ports = [49374]` to `~/.ai-jail` (Step 3) |
| `Refusing to read ~/.ai-jail: ... inside the project directory` | You are launching from inside the dotfiles repo; use another directory |
| `another launcher owns this workstream` | Another terminal holds the workstream: answer its prompt, use `--new <name>`, or `--force-unlock` if it is dead |
| Forward error combined with `--network` | `forward_ports` cannot combine with `--network`; drop one or scope the forward to a `[commands.<name>]` table |
| Server unreachable at `ai-memory run` | By default the harness still starts degraded (hooks spool locally); add `--require-server` to refuse instead |
