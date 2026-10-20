---
name: awt-orchestrator
description: "Autonomous Git worktree orchestration with awt. Use this skill whenever you or the user need to provision isolated worktree sandboxes, dispatch background sub-agents, checkout GitHub PRs, rebase linear history, test risky refactors, or ship/merge branches without mutating the primary worktree."
---

# AWT / Waymux WT Orchestrator Skill

You are an AI agent capable of orchestrating isolated Git worktrees and multi-agent workflows using `awt` (and its native Rust engine `waymux wt`) with 100% native Git.

This skill equips you to safely create feature sandboxes, run background test suites or compilers, checkout GitHub pull requests, and cleanly merge or ship completed code.

---

## 1. Core Principles & Safety Rules

1. **Primary Worktree Protection:**
   - In dotfiles (`~/.dotfiles/main`), `$HOME` is symlinked via GNU Stow. **Never run destructive or untested changes directly in `main`**.
   - Always spawn an isolated worktree (`awt -c feat/<name>`) for multi-step refactors, risky experiments, or parallel tasks.

2. **Hermetic Sibling Container Layout:**
   - Repositories follow the `.bare` sibling structure:
     ```text
     repo-root/
     ├── .bare/            (Shared Git object database)
     ├── main/             (Primary branch worktree)
     ├── feat-eval/        (Sibling worktree - Subagent 1)
     └── pr-42/            (Sibling worktree - PR Review)
     ```
   - All sibling worktrees share the same Git object database with 0 overhead and 0 duplicate clones.

3. **Hermetic Secret Propagation:**
   - Lifecycle hooks (`post-create.sh`) automatically copy `.env`, `.env.local`, and `.env.*.local` from the primary worktree so server/test runners execute without missing secrets.

4. **Lifecycle Hygiene:**
   - Always clean up finished or aborted feature worktrees (`awt rm <branch>`) to avoid stale branch clutter and worktree locking.

---

## 2. CLI Recipes & Command Patterns

### A. Create Isolated Worktree
```bash
# Provision feature worktree from HEAD and connect
awt -c feat/my-feature

# Provision feature worktree branching from explicit base (e.g. main)
awt -c feat/my-feature main

# Headless / script mode (do not switch Tmux session)
awt -c feat/my-feature main --no-tmux
```

### B. Inline Agent & Command Dispatch (`--`)
Run a command or launch an agent inside the newly provisioned worktree session:
```bash
# Interactive: provision worktree and launch test suite
awt -c fix/parser main -- cargo test

# Background / Detached: provision worktree, spawn background tmux session, run build, and return immediately
awt -c chore/bench --no-tmux -- npm run build

# Dispatch AI agent CLI inside isolated worktree
awt -c feat/eval-agent -- agy -p "Implement candidate benchmarks"
```

### C. GitHub PR Checkout (`awt pr`)
Inspect and test pull requests in dedicated worktrees without polluting your local branches:
```bash
# Checkout PR #42 directly into isolated worktree `../pr-42`
awt pr 42

# Interactive Waymaker PR picker with live description preview
awt pr
```

### D. Linear Rebase (`awt rebase`)
Rebase active branch onto its base branch with automatic dirty-state stashing:
```bash
# Rebase active branch onto tracked base (or main)
awt rebase

# Rebase onto explicit branch
awt rebase main
```

### E. Ship & Merge (`awt ship` vs `awt merge`)
- **`awt merge` (Local):** Merges active worktree into base, executes `post-merge.sh`, removes source worktree, and switches session.
- **`awt ship` (Local + Push):** Performs local merge, pushes target branch to remote origin (`git push origin <target>`), plays audio completion cue, and cleans up.
```bash
# Local fast-forward merge
awt merge main

# Local merge with squash
awt merge main --squash

# Ship: Rebase + Merge + Push to origin
awt ship main --rebase
```

### F. Delete, Sweep & Reap Worktrees (`awt rm` / `awt sweep` / `awt reap` / `dev-gc`)
```bash
# Delete worktree directory, branch ref, and kill tmux session
awt rm feat/my-feature

# Force remove even if uncommitted changes exist
awt rm feat/my-feature --force

# Batch sweep worktrees whose branches are already merged into base or via GitHub PR
awt sweep

# Batch sweep merged worktrees across ~/.dotfiles and all ~/dev/github/* repositories
awt sweep --all

# Sweep merged worktrees and clean Rust target/ directories in secondary sibling worktrees
awt sweep --all --clean-targets

# Reap stale AI agents (idle > 4h) and orphan worktree sessions
awt reap

# Read-only storage inventory & automated housekeeping (stale Rust target/, yay cache, Trash, Docker build cache >30d)
dev-gc --dry-run
dev-gc --yes --secondary-targets
```

### G. Auto-Naming & Migrating Uncommitted Changes (`-A` / `-W`)
```bash
# Auto-derive conventional branch slug from natural language task prompt
awt -c -A "fix memory leak in parser"

# Carry uncommitted dirty working tree changes from main into a new sandbox worktree
awt -c -W feat/dirty-migration
```

---

## 3. Waymaker TUI Quick Reference (`wm -o awt`)

When inside Tmux, opening the dashboard (`Prefix + g`, `Tab` from Cockpit, `Ctrl+Shift+G`, or `awt`):
- `Enter`: Connect / switch to selected worktree session.
- `Tab`: Switch seamlessly back to the Cockpit HUD (`cockpit-picker.sh`).
- `c`: Interactive 5-step Conventional Commit worktree creation wizard.
- `m`: Local merge into target base (runs `.awt.toml` / `pre-merge.sh` gates).
- `S` (Shift+S): **Ship** — atomic merge into base and push to remote origin.
- `R` (Shift+R): Rebase selected branch onto its base.
- `P` (Shift+P): Open GitHub PR selector (`awt-pr.toml`) with live preview.
- `r`: Rename active branch.
- `d`: Delete worktree and session with confirmation guard and async trash cleanup.
- `p`: Cycle preview layout (Status & Changes / Diff vs Main / Commit Graph).
- `q` / `Esc`: Quit dashboard.
