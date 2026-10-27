# ai-memory in the Dotfiles AI Workflow (v3.2.5)

How [`ai-memory`](https://github.com/akitaonrails/ai-memory) fits this cockpit: what it stores, how its scoping model maps onto our repositories and worktrees, and the recommended layout (hybrid: **one server, a few workspaces, one project per repository**).

Generic multi-repo walkthrough: [ai-memory-multi-repo-guide-en.md](../articles/ai-memory-multi-repo-guide-en.md). Sandbox side: [ai-jail-memory-guide-en.md](../articles/ai-jail-memory-guide-en.md). Upstream references: `docs/marker-file.md`, `docs/cookbook.md`, `docs/agent-messaging.md`, `docs/upgrading-to-3.0.md` in the upstream repo.

---

## 1. Mental Model (3 layers)

| Layer | What | Where it lives here |
| :--- | :--- | :--- |
| **Server** | One daemon, SQLite index + markdown wiki in git (source of truth) | `ai-memory.service` → `127.0.0.1:49374` (`ai-memory/.config/systemd/user/`) |
| **Scope** | `(workspace, project)` namespaces every page, session and handoff | resolved per checkout (section 2) |
| **Clients** | Lifecycle hooks (auto-capture) + MCP tools (`memory_query`, `memory_write_page`, handoffs) | `ai-memory run <agent>`, `opencode.json`, `.ai-jail` |

Hooks capture prompts and tool lifecycle automatically; agents only write durable pages when asked ("remember…") or when a rule/decision must outlive the session.

---

## 2. How a Checkout Becomes a Project

Resolution order (first hit wins):

1. `identity = "…"` in `.ai-memory.toml`
2. `project = "…"` in `.ai-memory.toml`
3. Normalized `upstream`, else `origin` remote, host dropped, `/` → `-` (v3 default `identity_style = "path"`)
4. Folder basename (only when there is no remote)

Consequences for this machine (bare-repo + worktree layout, `~/dev/github/<repo>/{.bare,main,<branch>}`):

| Checkout | Remote | Default project (v3) | Problem |
| :--- | :--- | :--- | :--- |
| `~/.dotfiles/main` | `felipecm-br/.dotfiles` | `felipecm-br-.dotfiles` (leading dot, owner prefix) | ugly, hard to type in MCP args |
| `lazygitrs/{main,fecavmi}` | `fcmiranda/lazygitrs` | `fcmiranda-lazygitrs` | owner differs from waymux |
| `waymux/main` | `felipecm-br/waymux` | `felipecm-br-waymux` | owner differs from lazygitrs |
| `starship-studio/{main,refractory}` | `felipecm-br/starship-studio` | `felipecm-br-starship-studio` | OK but verbose |

**Worktrees are already safe:** every worktree of a repo carries the same remote, so `main`, `fecavmi`, `refractory` and every `awt` sandbox collapse into **one project per repository**. Hooks follow `git rev-parse --git-common-dir`, so this also holds for out-of-tree worktrees. Do not create a project per worktree.

The default names work, but the leading dot and the mixed `-` separators are hard to read. We pin names with a committed marker using the convention **`<github-owner>.<repo>`** (dot between owner and repo, so `felipecm-br.dotfiles`, `felipecm-br.waymux`, `fcmiranda.lazygitrs`, `fcmiranda.waymaker`, `felipecm-br.starship-studio`). It mirrors the remote, stays unique across forks, and `.` is valid in project names.

---

## 3. Recommended Topology: Hybrid (Single Server, Workspace per Context, Project per Repo)

| Option | Verdict | Why |
| :--- | :--- | :--- |
| One project for everything | Reject | Pages and handoffs from `starship-studio` pollute `dotfiles` recall; defeats per-project briefs |
| Fully isolated repos, all in `default` | Acceptable baseline | No leakage, but siblings cannot link (`[[project:path]]`) and cross-repo facts get re-explained |
| **Hybrid: workspaces by context, one project per repo, explicit bridges** | **Recommended** | Isolation by default, deliberate sharing where the code is actually coupled |

```
workspace "workflow"  (tightly coupled toolchain: shared contracts, keybindings, RPC)
  ├─ felipecm-br.dotfiles   ~/.dotfiles/*
  ├─ felipecm-br.waymux     ~/dev/github/waymux/*
  ├─ fcmiranda.lazygitrs    ~/dev/github/lazygitrs/*
  └─ fcmiranda.waymaker     ~/dev/github/waymaker/*

workspace "projects"  (independent products; no shared contracts)
  ├─ felipecm-br.starship-studio
  └─ nerdsight      (remote host, see section 6; marker not yet added)
```

Why this split:

- **`workflow` shares a workspace** because the repos are coupled by contracts that already live in `docs/architecture/` (waymux RPC, lazygitrs `.lazygitrs.port`, waymaker presets, tmux popups). Sibling links `[[waymux:path]]` and workspace-scoped queries pay off here.
- **`projects` stays separate** so recall in `dotfiles` never surfaces starship-studio noise, and a future client/NDA project can opt out of everything with `[profile] contribute = false`.
- **Bridges are explicit, not ambient:** use `memory_message_send` (claim-once inbox) for "waymux must expose X for dotfiles", and `scope: "global"` / the cross-project profile for personal rules ("never force-push", "docs in English"). Avoid `[recall] default_global = true` except in a deliberate meta-repo.

### Markers (committed, one per repository)

Already added to all five repos (local commits `chore: add ai-memory project marker`, not pushed).

```toml
# <repo>/.ai-memory.toml  (committed; every worktree inherits it)
workspace = "workflow"
project   = "felipecm-br.waymux"
# project_strategy = "repo-root"   # only for remote-less repos
```

Create with `ai-memory project init` from the repo, then commit. Names: lowercase `^[a-z0-9][a-z0-9._-]*$`. For a rename of an existing project add `aliases = ["old-name"]` instead of re-capturing.

For an operator-wide default (no per-repo file), `~/.ai-memory.toml` can route by identity or path:

```toml
[routes.path."~/dev/github/waymux"]
route_workspace = "workflow"
route_project = "felipecm-br.waymux"
```

Per-repo markers win for repos you own; use home routes only for repos where you cannot commit a marker.

---

## 4. Daily Workflow in This Cockpit

| Step | Command | Notes |
| :--- | :--- | :--- |
| Launch an agent | `ai-memory run claude` (or `opencode`, `agy`…) | Auto-wires hooks + MCP on first use; resumes the cross-harness workstream |
| Launch inside the sandbox | `ai-jail …` (see `.ai-jail`: `ai-memory run opencode --yolo`) | Server runs on the host (`opencode.json` MCP URL `http://127.0.0.1:49374/mcp`) |
| Switch agent mid-task | `ai-memory continue` / `ai-memory resume` | Claude ↔ Codex ↔ OpenCode ↔ agy share one workstream |
| Where did we leave off | ask the agent: "catch me up" | Handoff + optional on-start brief |
| Diagnose capture | `ai-memory doctor` | Reports marker routing, missing hooks, leftover configs |
| Prune noise | `ai-memory-clean --apply` | Existing helper in `utils/` |
| Update | `ai-update --only ai-memory` | See section 7 |

Per-repo opt-in worth enabling when sessions start cold:

the marker's `[briefing]` keys (compiled project brief at SessionStart, costs tokens every start; see upstream `marker-file.md` for the exact keys). Keep it off for `dotfiles` if the root `CLAUDE.md` already carries the rules (**Single Source of Truth**: do not duplicate rules into wiki pages that already live in `AGENTS.md`).

**Division of labour (zero-duplication rule):**

| Knowledge | Canonical home |
| :--- | :--- |
| Repo rules, keybinding contracts, ergonomics law | `AGENTS.md` / `docs/` (versioned with code) |
| Decisions, gotchas, "why we did X", session continuity | ai-memory wiki |
| Personal cross-project habits | ai-memory profile / `_global` |

---

## 5. Capture Wiring & Verification

Hooks are what make capture automatic. They are written into each agent's config, and those configs are **stowed**, so installing hooks edits tracked dotfiles and must be committed.

| Harness | Install | Tracked file touched |
| :--- | :--- | :--- |
| Claude Code | `ai-memory install-hooks --agent claude-code --apply` | `claude/.claude/settings.json` (additive; existing `waymux hook …` entries stay) |
| Antigravity CLI | `ai-memory install-hooks --agent antigravity-cli --apply` | `antigravity/.gemini/config/hooks.json` |
| OpenCode / Codex / others | `ai-memory run <agent>` wires hooks + MCP on first launch | none or per-agent config |

Hooks load at session start: open a **new** session after installing. Verify with `ai-memory doctor`:

- `✓ <harness> N local → M captured` means events reach the server.
- `⚠ … ran here but nothing was captured` means the hook is missing or the session predates it; install it and start a fresh session.
- `hook spool: N event(s) waiting` is transient flush lag. If it persists, the daemon is down (`systemctl --user status ai-memory.service`). Nothing is lost: the spool replays when the server returns.
- `auth: none (loopback)` is acceptable while bound to `127.0.0.1`; run `ai-memory auth enable` before any tunnel or LAN bind.

Workspaces were renamed from `cockpit`/`side` to `workflow`/`projects` on 2026-10-26, right after the first captures; the store was reset (`ai-memory reset --confirm`, after a backup) rather than migrated. Re-verify with `ai-memory doctor` in a new session. Sessions that predate the hooks can be imported once with `ai-memory backfill` (new, empty store only), which is now possible again.

---

## 6. Remote Projects (nerdsight)

Decision depends on whether nerdsight's history may sit next to the rest of your memory:

| Mode | Setup | Use when |
| :--- | :--- | :--- |
| **A. One brain (recommended)** | On the remote: `AI_MEMORY_SERVER_URL=http://127.0.0.1:49374`, reverse-tunnel `ssh -R 49374:127.0.0.1:49374 nerdsight`, enable auth (`ai-memory auth enable`, token via `AI_MEMORY_AUTH_TOKEN`) | Personal project; you want a single recall surface and one backup |
| **B. Own server** | Run `ai-memory serve` on the remote; locally `ai-memory server add nerdsight --url … --root ~/dev/nerdsight --auth-token-stdin` and set `server = "nerdsight"` in its marker | Data must stay on that host / client confidentiality; fail-closed routing guarantees no cross-delivery |

Hooks spool locally when the server is unreachable (`ai-memory status` shows `pending`), so a dropped tunnel loses nothing. Never bind to `0.0.0.0` without auth and an `allowed_hosts` entry.

---

## 7. Updating (and why `ai-update` was stuck)

| Symptom | Root cause | Fix (applied) |
| :--- | :--- | :--- |
| `ai-update --check` showed ai-memory "OK" on 2.5.2 while 3.2.5 existed | `inspect_ai_memory` hardcoded `lat="1.17.3"` (stale constant), so current ≥ latest always | Resolve latest live: AUR RPC for pacman installs, GitHub releases for cargo installs; proper `sort -V` comparison |
| Update would build into the wrong place | `update_ai_memory` ran `cargo install` → `~/.cargo/bin`, but the active binary is `/usr/bin/ai-memory` (pacman `ai-memory-bin`) | Updater now uses `yay -S ai-memory-bin` when the pacman package is present, cargo otherwise, then `try-restart ai-memory.service` |
| Service could never start | `ai-memory.service` pointed at `~/.cargo/bin/ai-memory` (absent) | `ExecStart=/usr/bin/ai-memory serve --transport http` |

Upgrade procedure 2.5 → 3.x (from upstream `upgrading-to-3.0.md`):

```bash
ai-update --check --only ai-memory      # expect 2.5.2 → 3.2.5
ai-update --only ai-memory -y           # AUR upgrade + service restart
ai-memory doctor && ai-memory status    # migrations V77–V80 run on first start
```

Behavior changes that matter here: new installs create a root bearer token and turn auth on; `memory_query` now searches raw observations by default (set `[retrieval] observation_stream = false` to restore 2.x ranking); remote-backed projects are named by repository path. The `ai-memory user add/expire/rotate-token` commands are gone (use `api-key`); nothing in this repo scripts them.

`ai-jail` still has the same hardcoded-latest pattern (`lat="1.16.0"` in `update-ai-workflow`); audit it next.

---

## 8. Stow Hygiene (data directory is a symlink into the repo)

`~/.local/share/ai-memory` is stowed as a **directory symlink** to `ai-memory/.local/share/ai-memory/`, so the server's runtime state (wiki, SQLite, logs, `auth-tokens/`) would be written inside the dotfiles worktree.

- `.gitignore` now ignores everything under that directory except `config.toml`.
- `config.toml` is tracked and contains `[auth] token_pepper`. It is only consumed once multi-user is enabled, but it is a secret in git history: rotate it before enabling multi-user, and upstream supports `AI_MEMORY_*` env overrides for config values (verify the exact key name with `ai-memory --help` before moving it to the service environment).
- Better long-term: stow only the file (`--no-folding` for this package) or relocate the data dir with `AI_MEMORY_DATA_DIR=~/.local/share/ai-memory-data`, so the repo never sees runtime state. Back up with `ai-memory backup --to <file>` (SQLite online backup, safe while running).

---

## 9. Open Decisions

| Decision | Recommendation |
| :--- | :--- |
| Workspace names (`workflow` / `projects`) | Adopt; rename only before first capture (renames after are costly) |
| Existing `felipecm-br-*` / `fcmiranda-*` projects from earlier captures | Add `aliases` in markers so history keeps its UUID |
| Enable `[briefing]` on `dotfiles` | No; `AGENTS.md` already injects the rules |
| nerdsight mode A vs B | A unless it holds third-party data |
