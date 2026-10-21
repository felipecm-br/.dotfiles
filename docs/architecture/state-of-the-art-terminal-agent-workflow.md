# State-of-the-Art Terminal Agent Workflow: Architecture, Ergonomics & Competitor Benchmark

> **Canonical Architectural Reference:** `docs/architecture/state-of-the-art-terminal-agent-workflow.md`  
> **Status:** Production Standard (re-audited Oct 2026) · **Comparative Score:** **7.7 / 10** (profile-weighted, see §1) · **Zero-Churn Verified**

> [!NOTE]
> This document was re-audited in Oct 2026. The previous revision claimed a self-assigned **9.94/10**, cited competitor latencies without a reproducible method, and referenced unverified benchmarks. Every number below is either **measured on this host** (aarch64 Linux, see §5) or explicitly marked as **unmeasured / reported by the vendor**.

---

## 1. Executive Summary & Comparative Verdict

Modern agentic engineering demands orchestrating multiple concurrent AI coding subagents across isolated Git branches, monitoring asynchronous execution states, reviewing generated diffs, and pruning ephemeral environments without cognitive context switching.

This repository implements a terminal-native agent orchestration stack:

1. **`waymux`** ([felipecm-br/waymux](https://github.com/felipecm-br/waymux), v0.2.3): single Rust binary providing the async JSON-RPC 2.0 control plane (`agentState/wait`, `tmux.*`), zero-latency lifecycle hooks (`waymux hook tmux|lazygit`), the Cockpit HUD data path (`cockpit-items|preview|diff`), review-note dispatch (`review-notes`, `inject`), triage (`triage`), and a native worktree orchestrator (`waymux wt`, mirrored by the `awt` entrypoint).
2. **`awt`** (Agent Worktree Orchestrator): worktree lifecycle management, hermetic environment provisioning, dirty-state migration (`-W`), quarantine-safe deletion, `rebase`/`ship`/`sweep`/`reap`.
3. **`waymaker` / `wm`**: SIMD-accelerated (Nucleo) Ratatui fuzzy selector used as the Cockpit renderer.
4. **`tmux`**: Golden Ratio ($\phi$) floating HUDs, event-driven status bars (`status-interval 0`), safe confirmation modals, and transaction-safe Undo Close Tab (`Prefix + u`).
5. **`lazygitrs`**: Rust Git TUI with Dual-Diff toggle (`Ctrl+G`), inline `.git/info/lines.json` review annotations, and batch agent review injection.

```
                    ┌──────────────────────────────────────────────┐
                    │            TERMINAL WORKSPACE (Tmux)         │
                    │                                              │
    Prefix + Space  │   ┌──────────────────────────────────────┐   │
   ─────────────────┼──►│    COCKPIT HUD (waymux cockpit → wm) │   │
                    │   │  Fixed 6-Column Grid                 │   │
                    │   └──────────────────┬───────────────────┘   │
                    │                      │                       │
                    │         Select       │ Tab / Quick Action    │
                    │         Enter        │                       │
                    │         ▼            ▼                       │
                    │   ┌───────────────┐  ┌───────────────────┐   │
                    │   │  Active Pane  │  │ lazygitrs (Review)│   │
                    │   │  (Neovim/Zsh) │  │ Dual-Diff Ctrl+G  │   │
                    │   └───────▲───────┘  └─────────┬─────────┘   │
                    │           │ Batch Review Notes │ r / R / S   │
                    │           └────────────────────┘             │
                    └───────────────────────▲──────────────────────┘
                                            │
                       ┌────────────────────┴───────────────────┐
                       │  waymux daemon (127.0.0.1:4040)        │
                       │  hooks · agent state · urgency · wt    │
                       └────────────────────────────────────────┘
```

### Profile-Weighted Comparative Scorecard

Weights are calibrated for a **terminal-first, keyboard-only, Home-Row ($H=0$)** profile. Scores are the author's **subjective judgment** based on vendor documentation read in Oct 2026 (workmux, herdr, Orca, T3 Code READMEs/sites) and local measurements. Where a capability could not be verified, it was scored conservatively.

| Dimension | Weight | This Stack | workmux | herdr | Orca | T3 Code |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| Worktree lifecycle | 15 | 9.0 | 9.5 | 5.0 | 9.0 | 8.0 |
| Agent state awareness | 15 | 8.0 | 7.5 | **9.5** | 8.0 | 7.0 |
| Persistence / crash isolation | 10 | 7.5 | 7.0 | **9.5** | 7.0 | 6.0 |
| Review loop (diff → line note → agent) | 15 | **9.5** | 6.0 | 4.0 | 8.0 | 8.0 |
| Remote / mobile | 10 | 5.0 | 4.0 | 9.0 | **9.0** | **9.0** |
| Ergonomics & latency (keyboard, $H=0$) | 15 | **10.0** | 7.0 | 6.0 | 3.0 | 3.0 |
| Agent-callable API (`wait`, spawn) | 5 | 8.5 | 6.0 | **10.0** | 6.0 | 5.0 |
| Agent sandboxing | 5 | 3.0 | **9.0** | 3.0 | 4.0 | 3.0 |
| Fan-out / compare N agents | 5 | 4.0 | 8.0 | 5.0 | **10.0** | 7.0 |
| Ecosystem / bus factor | 5 | 4.0 | 7.0 | **10.0** | 8.0 | 8.0 |
| **Composite (0–10)** | **100** | **7.7** | **7.1** | **6.9** | **7.2** | **6.6** |

> [!IMPORTANT]
> The lead is narrow and profile-dependent: it comes from ergonomics (15%) and the closed review loop (15%). Doubling the weight of remote/mobile (10% → 20%) drops this stack to workmux's level. It is clearly **ahead** on review and ergonomics, and clearly **behind** on remote/mobile, sandboxing, fan-out, and ecosystem.

---

## 2. Competitor Matrix & Architecture Analysis

Sources: [workmux](https://github.com/raine/workmux) README, [herdr](https://herdr.dev) site and `/compare`, [Orca](https://github.com/stablyai/orca) README, [T3 Code](https://github.com/pingdotgg/t3code) README. Vendor statistics (stars, installs) are vendor-reported and change quickly.

| Capability | This Stack | `workmux` | `herdr` | Orca | T3 Code |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Paradigm** | Rust daemon + CLI + TUIs on top of Tmux | CLI glue: 1 worktree = 1 tmux window = 1 agent (also kitty, WezTerm, Zellij backends) | Server owns real PTYs; TUI and CLI are clients (agent runtime) | Desktop ADE (Electron) with mobile companion | Web, Electron, and mobile control surface over installed agent CLIs |
| **Agent state detection** | Lifecycle hooks (`waymux hook`), multi-pane urgency aggregation, stall detection | Hook-driven working/waiting/done icons, auto-clear on focus, "interrupted" after 10 s without output | Screen analysis + agent integrations; 22 CLIs detected (vendor-reported) | In-app status and notifications | In-app thread status |
| **Wait / programmatic API** | JSON-RPC `agentState/wait`, `tmux.*` methods | CLI (`workmux wait`-style flows, `/worktree` delegation skill) | Unix-socket API and CLI; agents can drive herdr | Not documented here | Not documented here |
| **Dashboard** | Cockpit HUD: fixed 6-column grid, 40/60 preview split | `dashboard` (live previews, hunk staging, commands) and `sidebar` | Sidebar with grouped agent states | GUI | GUI |
| **Review loop** | **Closed**: Dual-Diff, inline line notes (`.git/info/lines.json`), batch injection into the agent pane | Diff/hunk staging in dashboard; no per-line note dispatch | None | Review UI, PR integration | Unified diffs, one-click PR |
| **Dirty-state carryover** | `awt -c -W` | Rescue options exist (README); semantics not verified here | n/a | n/a | n/a |
| **Safe removal / undo** | Quarantine delete + Undo Close Tab (`Prefix + u`) | `confirm_unmerged_removal` (default on) | Window destruction | App-managed | App-managed |
| **Sandboxing** | None (hermetic env only) | Container / Lima backends | None | Not documented here | Worktree isolation only |
| **Fan-out** | Manual | Multi-worktree `add` | Manual | First-class: one prompt to N agents, compare, merge winner | Parallel threads |
| **Crash model** | Tmux server owns PTYs; `waymux daemon` is supervised by systemd (`Restart=on-failure`); hooks degrade silently when the daemon is down | Tmux owns PTYs | Server owns PTYs; TUI crash is harmless (server crash ≈ tmux-server crash) | App quit stops its agents | Service can run in background (`t3 service install`) |
| **Remote / mobile** | SSH / mosh / Tailscale; no mobile UI | Terminal only | Attach from any tty | iOS / Android companion | iOS / Android / web |
| **Latency / memory** | **Measured** (§5) | Not measured | Not measured | Not measured (Electron) | Not measured (Electron) |

### Deep Architectural Takeaways

1. **Runtime ownership (herdr) vs. Tmux + daemon (this stack):** herdr's thesis is that multiplexers persist terminals, not agents, and that a server should own the PTYs with disposable clients. This stack reaches a similar crash profile by delegating PTY ownership to Tmux and keeping agent state in `waymux daemon` (supervised; `agentState/wait` covers the "wait instead of poll" primitive). It does **not** offer herdr's attach-from-anywhere UX or plugin ecosystem. The earlier claim that herdr has a "catastrophic blast radius" was incorrect.
2. **Fixed-grid HUD vs. list dashboards:** the Cockpit uses a fixed 6-column monospace grid with explicit UTF-8 width alignment, which supports ballistic vertical scanning. workmux's dashboard and herdr's sidebar are functional list views. This is a design argument (saccade model), **not** a measured user-study result.
3. **The review loop is the differentiator:** competitors focus on *dispatching* agents. As dispatch cost approaches zero, human review dominates cycle time (Amdahl). Dual-Diff, inline line notes, and batch injection (`S` / `r`) close the loop; none of the surveyed tools dispatches per-line review notes back into the agent pane.
4. **Known gaps (honest):** no sandboxing (workmux has container/Lima), no fan-out/compare (Orca), no mobile surface (Orca, T3 Code), single-maintainer ecosystem (waymux v0.2.x), and Cockpit footer exceeds the 7-item chunk cap.

---

## 3. The 6 Engineered SOTA Pillars

### 3.1 Worktree Provisioning & Isolation (`awt`)

The Agent Worktree Orchestrator (`awt`, bash entrypoint; also exposed as the native `waymux wt`) treats Git worktrees as disposable, hermetic sandboxes for autonomous agents.

- **Single-Pass Queries:** Avoids multiple sequential `git status` or `git branch` invocations. Resolves branch names, upstream status, commit divergence, and dirty state in a single query.
- **Dirty-State Migration (`awt -c -W <branch>`):** Automatically snapshots uncommitted changes in the current tree and applies them cleanly into the newly created worktree without leaving untracked residue behind.
- **Instant Async Trash Deletion:** `awt-delete.sh` atomically renames removed worktree directories to `.awt_trash_<name>_$$_$RANDOM` and purges them asynchronously in a background subshell (`rm -rf "$trash_dir" &`), returning control to the UI immediately while pruning metadata cleanly.
- **Hermetic Environment Hooks (`.awt.toml` & `post-create.sh`):** Automatically copies or symlinks `.env`, `.env.local`, and runtime secrets into newly created worktrees while honoring worktree isolation boundaries.
- **Linear History & Fleet Hygiene (`awt rebase`, `awt sweep`, `awt reap`):** Integrated linear rebase, merged-worktree sweeping (`awt sweep`), and stale idle-agent garbage collection (`awt reap --hours 4`).

### 3.2 Instant Cockpit HUD (`cockpit-picker` + `waymaker`)

The Cockpit HUD is the central control plane, bound to `Prefix + Space` (`85% × 75%`, badge ` 󱂬 `).

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│ 󱂬  Fleet (All Windows) ❯                                        ? Help · Esc Close     │
├────────────────────────────────────────────────────────────────────────────────────────┤
│ 󱅭  1•  dotfiles · agy: Audit docs   main ↑2         +14 -3      2m                     │
│ 󰑮  2   api · claude: Fix auth       feat/auth ✓     +42 -8  #12 35s                   │
│ 󱥁  3   web · codex: Add tests       fix/tests ↑1    +5 -1       4m                     │
│ ·  4   nvim                         main ✓          clean       12m                    │
├────────────────────────────────────────────────────────────────────────────────────────┤
│ Enter Jump │ y/n Ack │ r Review │ i Input │ g Git │ a Agents │ Tab Worktrees │ ? Help │ Esc Exit │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

- **Sub-50ms Data-Path Latency (`waymux cockpit-items` $P_{50} \approx 19\text{ms}$ measured; see §5):** Streams pre-formatted candidate lines into `wm --config cockpit-picker.toml` with zero intermediate disk scans.
- **Fixed 6-Column Golden Grid (`cockpit-picker-items.sh`):** Monospace columns provide dedicated vertical tracks in the left 40% candidate pane:
  1. `[State Icon]` (2 chars anchored at $X=1$: `󱅭` permission, `󱜻` question, spinner working, `󱥁` stalled, `󰨄` error, `󱥂` idle, `·` no agent). Rows sort by the triage service class (permission → question → error/stalled → working → idle), waiting rows oldest first, and the cursor opens on the first waiting agent.
  2. `[Win Idx + Dot]` (3 chars: e.g. `1•` for active window, `2 ` for background)
  3. `[Win + Agent Title]` (24 chars: window name + active agent prompt/task title)
  4. `[Branch + Sync]` (14 chars: Git branch + upstream `↑N`/`↓N`/`✓`)
  5. `[Diffstat / PR]` (11 chars: uncommitted `+N -M` churn and GitHub PR badge `#N`)
  6. `[Elapsed Age]` (6 chars right-aligned: urgency-colored age since last state transition)
- **Visual Semiotics & Human Factors:**
  - **Semantic State Colors:** Agent-state glyphs use waymux's built-in light/dark palette (blue working, gold question, orange permission, pink stalled, red error, slate idle), shared with the status bar; see [AI Agent Status in Status Bar](../tmux/ai-status-bar.md). They used to come from theme slots, which collapsed under `lumon` (permission, question and stalled were the same blue, CIEDE2000 0–4 between working and the waiting states) and `tokyo-night` (permission = stalled).
  - **Bouma Visual Crowding Reduction:** Eliminates noisy brackets (`[Enter]` $\to$ `Enter`) and uses `{darkgray:│}` hairline separators across the footer.
  - **Dynamic Theme Sync (chrome only):** Branch, diffstat and PR colors are generated from `~/.local/state/omarchy/current/theme/colors.toml`. Theme-derived metadata can fall below WCAG contrast (`lumon` `darkgray` is 1.68:1); state colors are guaranteed ≥ 4.5:1 on every built-in theme.

### 3.3 Daemon Telemetry & Urgency Aggregation (`waymux daemon`)

The Waymux daemon (`waymux daemon`) is an asynchronous Rust daemon communicating over HTTP JSON-RPC 2.0 (`127.0.0.1:4040/rpc`) with `0600` Bearer token authentication (`$XDG_RUNTIME_DIR/waymux/token`) and the `waymux-cli` wrapper.

- **Multi-Pane Window Urgency Aggregation:** When a Tmux window contains multiple split panes (e.g., editor in pane `%1`, test runner in pane `%2`, AI agent in pane `%3`), `waymux` evaluates urgency across **all** child panes. If *any* pane enters `question`, `permission`, or `error`, the parent window's urgency reflects that highest-priority state, guaranteeing that background agent prompts are never missed.
- **650ms Biomechanical Idle Debounce:** Protects against false idle/waiting states triggered during rapid tool-call chaining or streaming LLM output chunks.
- **Proactive Stall Detection & Focus Auto-Dismiss:** Detects hung `working` agents (>20s zero output and zero CPU delta $\to$ `stalled` `󱥁`) and automatically dismisses question/permission alerts via Tmux's `pane-focus-in` hook (`waymux dismiss`).
- **Triage Queue (`Prefix + I` / `Prefix + i`):** Waiting agents are served by class (permission → question → error/stalled, quick decisions first), longest-waiting first within a class. The next target is the entry after the current pane (or after the last peeked pane for the popup), else the head, so servicing an agent never makes the next jump skip one.
- **Spatial PipeWire Audio Telemetry:** Non-blocking auditory feedback (`pw-play`) with distinct cues when tasks complete or require interactive feedback. Every cue currently plays immediately, including for the pane in view: `chime-at-breakpoint` (deferral until a typing pause) exists in `utils/` but is not wired into `waymux` yet.
- **100% Event-Driven Status Bar:** Tmux runs with `status-interval 0`. State updates are pushed instantly via `tmux set-option -w` and `refresh-client -S`, consuming 0.0% CPU when idle.

### 3.4 Bidirectional AI Code-Review Loop (`lazygitrs`)

Closing the gap between agent diff production and human verification:

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│ lazygitrs (fecavmi) · [feat/review-loop] · Dual-Diff: HEAD (Ctrl+G to toggle)          │
├──────────────────────────┬─────────────────────────────────────────────────────────────┤
│ Files                    │ src/orchestrator.rs                                         │
│ > src/                   │ 12  pub fn dispatch_agent(&self) -> Result<()> {            │
│   > core/                │ 13      let socket = self.connect_socket()?;                │
│     picker.rs            │ 14 +    // Review note: verify timeout handling on hung agent│
│     hud.rs               │ 15 +    socket.set_read_timeout(Some(Duration::from_secs(5)))│
│   * orchestrator.rs      │ 16      let resp = socket.read_response()?;                 │
├──────────────────────────┴─────────────────────────────────────────────────────────────┤
│ Actions: Ctrl+G Dual-Diff │ c Add Note │ Enter View Note │ r/R Reset │ S Send │ g Cockpit │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

- **Fast Startup (~2 ms `--version`):** Instant Rust binary startup with zero Electron or Node overhead.
- **Dual-Diff Toggle (`Ctrl+G`):** Instantly toggles between viewing uncommitted working tree diffs and reviewing commits against `HEAD` or target base branch.
- **Inline Review Notes (`.git/info/lines.json`):** Pressing `c` on any diff line (or visual range `v`) opens an inline comment prompt. Notes are stored cleanly inside `.git/info/lines.json` (with XDG fallback) with file path, line range, and instruction text.
- **Direct & Cockpit Review Dispatch (`S` in `lazygitrs` / `r` in Cockpit):** Pressing `S` inside `lazygitrs` dispatches notes directly to the active AI agent pane via HTTP TUI push, SSE, or bracketed paste. Furthermore, the Cockpit HUD preview pane surfaces `󰆈 Pending AI Review Notes (N)` and allows batch-dispatching all pending notes directly from Cockpit via `r` (`R` in the Cockpit reaps stale agents; it does not clear notes).

### 3.5 Smart Window Lifecycle, Topology Snapshot & Safe Pruning

Window and session management incorporates transactional safety to eliminate accidental work destruction:

- **Bypass for Clean Tabs & Idle Agents:** Pressing `Prefix + w` or `Prefix + x` (`close-window.sh`) on a regular shell window or a window whose AI agents are `idle` closes it instantly (near-instant) with zero friction. Similarly, `Prefix + W` (`close-session.sh`) closes sessions with $\le 3$ windows and zero active (non-idle) agents immediately.
- **Modal Confirmation on Active Agents (``):** If the target window or session has an AI subagent actively working, awaiting input, or stalled, `close-window.sh` / `close-session.sh` intercepts the action and presents a themed `68 × 11..18` confirmation modal (`y` Kill │ `n / Esc` Keep).
- **Cockpit Kill Guard (`d` / `x` / `Ctrl+D`):** The Cockpit opens in command mode, so `waymux window-delete` applies the same rule as `close-window.sh` to every pane of the target window or session: idle targets close on one press (restorable with `Prefix + u`), a target with an agent still working arms on the first press (status-line notice) and closes on a second press within 2 s. Undo restores the window and conversation, not an interrupted run, hence the guard.
- **Ship Confirmation (`S`):** `S` in the Cockpit merges, pushes to origin and deletes the branch; like `S` in the awt popup, it now asks first (`awt ship --confirm`).
- **Undo Close Tab (`Prefix + u` / `Prefix + T` / `Ctrl + Shift + T`):** Every closed window writes its state (session, exact window index, title, working directory, git branch, and normalized AI resume command: `agy --conversation <uuid>`, `claude --continue`, `codex resume --last`, `muse resume --last`, `opencode --continue`) to `~/.local/state/tmux/closed-windows.json` (max 25 entries). Pressing `Prefix + u` immediately recreates the window at its exact previous index with the AI conversation resumed (`reopen-window.sh`).
- **Automated Topology Snapshot & Reboot Restore (`cockpit snapshot` / `cockpit restore`):** Event-driven hooks snapshot all sessions, windows, CWDs, and active agent conversations to `~/.local/state/cockpit/session-topology.json` (30s debounced).

### 3.6 Biomechanical Ergonomics & Cognitive Human Factors

Engineered strictly in accordance with [Terminal Ergonomics & UX Architecture Manifesto](terminal-ergonomics-and-ux-manifesto.md):

- **Keystroke-Level Model ($H=0$):** Zero hand-travel from Home Row. Physical `CapsLock` is overloaded at the kernel level (`keyd`) as **`Ctrl`** when held and **`Esc`** when tapped.
- **Inward Rolls:** Critical chord sequences follow inward finger rolls (`Prefix + Space`, `j + Enter`, `Ctrl + g`).
- **Doherty Threshold & Perception Limits:** The Cockpit data path (`waymux cockpit-items`) runs at $P_{50} \approx 19\text{--}23\text{ms}$ (§5), well beneath the 100ms Miller 1968 perception limit, preserving the developer's uninterrupted flow state.

---

---

## 4. Historical Resolution Ledger

| Audit Source | Original Finding / Issue | Resolution Mechanism | Verification Artifact |
| :--- | :--- | :--- | :--- |
| **Flow-State Audit** (F1) | Single-pane status polling missed background split panes | `waymux daemon` aggregates urgency across all window panes | Multi-pane urgency path in `waymux cockpit-items` |
| **Flow-State Audit** (F2) | Cockpit popup launch latency exceeded 150ms on large repos | Single-pass item streaming into `wm --config` | `tests/cockpit_hud_perf.test.sh` |
| **Flow-State Audit** (F3) | Typing bursts caused sporadic false `waiting` audio triggers | Idle debounce tuned to 650 ms (`idle_debounce_ms` in `~/.config/waymux/config.toml`) | Live use; no automated test |
| **Flow-State Audit** (F4) | Worktree deletion blocked UI during large directory removal | Atomic `.awt_trash_*` rename + async background `rm -rf` | `tests/awt_improvements.test.sh` |
| **Flow-State Audit** (F5) | Ragged text alignment in HUD caused eye-tracking fatigue | 6-column fixed monospace Golden Grid | Visual inspection |
| **Flow-State Audit** (F6) | Unstaged changes blocked seamless worktree creation | `awt -c -W` automatic dirty-state carryover | `tests/awt_improvements.test.sh` |
| **Flow-State Audit** (F7) | Accidental window closure killed active agent jobs, while idle agents caused modal fatigue | Smart close tab prompting only on active (non-idle) AI agents | `tests/close_window.test.sh`, `tests/close_session.test.sh` |
| **Flow-State Audit** (F8) | Closed tabs lost window index and agent conversation context | Undo Close Tab (`Prefix + u` / `C-S-t`) with `~/.local/state/tmux/closed-windows.json` | `tests/reopen_window.test.sh` |
| **Flow-State Audit** (F9) | Code review required jumping out to browser or GitHub PR | Embedded `lazygitrs` (`g` / `Ctrl+G`) and side-by-side diff (`v`) in Cockpit | `tests/cockpit_review_notes.test.sh` |
| **Flow-State Audit** (F10)| Review comments had to be manually typed to agents | `.git/info/lines.json` review bridge with `S` (Lazygitrs) & `r` (Cockpit) batch dispatch | `tests/cockpit_review_notes.test.sh`, `tests/lazygitrs_review_notes.test.sh` |
| **Popup Audit** (P1) | Popup border color clashed with dynamic Omarchy themes | Borders and text bound to TrueColor hex from `colors.toml` | Visual verification |
| **Popup Audit** (P2) | Rainbow bracketed footers caused visual crowding | Uniform bichromatic footers (`cyan,bold` + `darkgray` + `│`) with `? Help` | Visual verification |
| **Waymux Audit** (W1) | Missing upstream commit tracking in dashboard | `Branch + Sync` column with `↑N` / `↓N` / `✓` glyphs | `waymux cockpit-items` |
| **Waymux Audit** (W2) | Inconsistent keybindings between Cockpit and Lazygitrs | Navigation aligned to Vim standard | Workflow Keybindings Matrix |
| **Re-audit Oct 2026** (R1) | Legacy `acpd` replaced by `waymux`; dotfiles, docs, installer, scripts, and hooks fully migrated | Stow package `waymux/`; installer `packages/waymux.zsh`; `waymux-cli` wrapper; active `waymux.service` | `scripts/drift-doctor.sh` |
| **Supervision Audit Oct 2026** (S1) | Cockpit `S` merged, pushed and deleted the branch without asking | `--confirm`, matching the awt popup | `cargo test` (`test_ship_asks_for_confirmation`, `test_split_merge_args_forwards_confirm_and_push`) |
| **Supervision Audit Oct 2026** (S2) | Cockpit `d`/`x` killed windows with working agents on one press; six aliases | Active-agent guard (second press within 2 s); `D`, `X`, `ctrl-x` removed | `cargo test` (`test_kill_decision_guards_only_active_agents`), isolated tmux smoke test |
| **Supervision Audit Oct 2026** (S3) | Triage served newest-first with a stored index that skipped agents after one was serviced | Stateless queue by service class, oldest first; Cockpit sorts and opens on the same head | `cargo test` (`test_next_in_queue_never_skips_after_service`, `test_start_idx_prefers_first_waiting_agent`) |
| **Supervision Audit Oct 2026** (S4) | State colors from theme slots collapsed (`lumon`: one blue; `tokyo-night`: permission = stalled) | Built-in semantic palette per light/dark mode in `waymux`; template leaves `color` empty | `cargo test` (`status_palette` contrast and distinctness tests) |
| **Supervision Audit Oct 2026** (S5) | `pane-focus-in` ran `record-window-state.sh --track` synchronously (p50 193 ms) before `waymux dismiss` | Both backgrounded; stale runs drop their result | `tests/focus_hook_async.test.sh` |

> [!NOTE]
> **Waymux Migration:** all consumers (hooks, `waymux-cli`, Cockpit/triage scripts, `drift-doctor`) use native `waymux` paths (`$XDG_RUNTIME_DIR/waymux/token`), configuration is loaded from `~/.config/waymux/config.toml`, sounds are located in `~/.config/waymux/sounds/`, and the systemd unit runs under `waymux.service`.

---

## 5. Measured Latency & Resource Baseline

Measured on this host (**Linux aarch64**), Oct 2026, wall-clock including process spawn. Reproduce with `./tests/cockpit_hud_perf.test.sh` (`N=40` iterations by default). Competitor latencies were **not** measured and are intentionally omitted.

| Operation | $P_{50}$ | $P_{95}$ |
| :--- | :---: | :---: |
| `waymux cockpit-items` (Cockpit data path) | ~19 ms | ~26 ms |
| `waymux health` | ~2 ms | ~4 ms |
| `waymux list` | ~2 ms | ~3 ms |
| `waymux wt ls` | ~10 ms | ~18 ms |
| `wm --version` | ~2 ms | ~4 ms |
| `lazygitrs --version` | ~2 ms | ~3 ms |

Not yet measured: end-to-end Cockpit popup render, worktree creation, `Ctrl+G` Dual-Diff toggle, memory footprint. Do not cite figures for these until a script exists.

---

## 6. Test Coverage

Automated checks live in `tests/`:

1. **`tests/cockpit_hud_perf.test.sh`**: latency budget for `waymux cockpit-items` (p50 ≤ 50 ms) and `waymux health` (p50 ≤ 20 ms); requires a healthy daemon.
2. **`tests/cockpit_review_notes.test.sh`** and **`tests/lazygitrs_review_notes.test.sh`**: review-note indexing, pending counts, and batch dispatch to agent panes in an isolated detached Tmux session.
3. **`tests/close_window.test.sh`**, **`tests/close_session.test.sh`**: guarded termination (clean/idle bypass, confirmation on active agents).
4. **`tests/reopen_window.test.sh`**: Undo Close Tab transaction stack and state restoration.
5. **`tests/awt_improvements.test.sh`**: worktree creation, dirty-state migration, async trash deletion.
6. **Other:** `tests/keybindings_picker.test.sh`, `tests/picker_rg_files.test.sh`, `tests/scrollback_picker.test.sh`, `tests/pr_workflow.test.sh`.
7. **System validation:** `./scripts/docs-lint.sh` (link integrity, English, root cleanliness), `./scripts/drift-doctor.sh` (binary drift, `waymux` RPC health, symlinks), `./stow.sh -n` (symlink health).

---

## 7. Canonical Architecture Index & Related References

- [**Terminal Ergonomics & UX Architecture Manifesto**](terminal-ergonomics-and-ux-manifesto.md): Core HCI principles, KLM/GOMS ($H=0$), Doherty threshold (<100ms), pure icon badges, and dynamic Omarchy theme color synchronization.
- [**Workflow Keybindings & Ergonomic Reference Matrix**](workflow-keybindings-matrix.md): Complete multi-layer cheat sheet for global, Tmux, Zsh, and Lazygitrs shortcuts.
- [**Popups Ergonomics, Biomechanics & Golden Ratio**](../tmux/popups-ergonomics-and-golden-ratio.md): Golden Ratio ($\phi$) popup architecture, 60/40 column split, and sub-100ms non-blocking HUDs.
- [**AI Agent Status in Status Bar**](../tmux/ai-status-bar.md): Real-time per-pane AI agent state pills, animated spinners, color alerts, and `waymux daemon` configuration.
- [**Agent Worktree Manager & Multi-Agent Git Orchestrator**](../GIT_WORKTREE_AGENTIC_WORKFLOW.md): Complete guide to the AWT ecosystem, 4-layer architecture, conventional wizard, and automated lifecycle hooks.
- [**AWT Dotfiles Package Readme**](../../awt/README.md): Dedicated package documentation, CLI command cheat sheet, and keybindings reference.
- [**Zero-Friction Frecency 2.0 File Transfer Benchmark & Guide**](zero-friction-file-transfer-benchmark.md): Quantitative KLM-GOMS benchmark comparing transfer paradigms and operational cheat-sheet (`pt`, `ptg`, `ptl`, `mt`, `mtg`, `mtl`).
