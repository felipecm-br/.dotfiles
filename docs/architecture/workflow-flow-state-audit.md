# Flow-State Workflow Audit — Ergonomics, Zero-Friction & TUI UX

> **Canonical document:** `docs/architecture/workflow-flow-state-audit.md`
> **Scope:** `keyd` → Ghostty → tmux → `waymaker` (`wm`) → `lazygitrs` (`fecavmi` branch) → `acpd` → `awt`, benchmarked against Herdr, workmux, Agent of Empires, Age of Agents, Yazi, superfile and peers.
> **Date:** 2026-10-05 · **Method:** local measurements + upstream READMEs/APIs + literature check (see [§0](#0-method-evidence-grades--limits)).
> **Relationship to existing docs:** this audit **supersedes the conclusions** (not the structure) of [`tui-ux-workflow-evaluation-report.md`](tui-ux-workflow-evaluation-report.md) and [`../articles/workflow-vs-herdr-comparison.md`](../articles/workflow-vs-herdr-comparison.md). Corrections are itemized in [§12 Errata](#12-errata-for-existing-docs). The ergonomic doctrine in [`terminal-ergonomics-and-ux-manifesto.md`](terminal-ergonomics-and-ux-manifesto.md) is retained (Zero-Churn Rule).

---

## 0. Method, Evidence Grades & Limits

| Grade | Meaning |
| :---: | :--- |
| **A** | Measured or read directly on this machine / in the upstream source during this audit. |
| **B** | Confirmed by a search-engine summary of the paper/site; primary PDF **not** opened. |
| **C** | Established background knowledge (from memory), **not** re-verified here. Treat as hypothesis. |

**Limits (read before trusting any number):**
- All timings are from **one machine** (Arch/Omarchy, Ghostty 1.3.1, tmux 3.7c), best-of-N or mean-of-N, no CPU pinning, no `hyperfine`. They are directional, not publishable.
- `--version` start-up measures `fork+exec+dynamic-link`, **not** TUI first paint. First-paint latency was **not** measured (needs a pty harness or high-speed camera — see [§9.3](#93-how-to-measure-properly)).
- Competitor claims come from their own READMEs/sites; nothing was installed or run except `yazi`, `fzf`, `zoxide`, `sesh` which are already on this machine.
- Scores in [§1](#1-executive-summary) are **my judgment** against an explicit rubric, not a measurement.

---

## 1. Executive Summary

### 1.1 Verdict

This is a **top-tier single-operator keyboard cockpit**: the hardware layer (`keyd`), the verb-free navigation (`Tab` → `wm -o jump`), the Z-axis popup discipline, the structured agent telemetry (`acpd`) and the review loop (`lazygitrs` dual-diff + review-note injection) are individually excellent and, in combination, **unmatched by any single competitor I checked**.

It is **not yet the "apex"**, for five evidence-backed reasons:

1. **Three verified defects/drifts in the live system** (one of which silently breaks the flagship `Ctrl+G` popup) — [§2](#2-verified-findings-live-system).
2. **The central bottleneck is mis-targeted.** Keystroke-level savings (130 ms vs 3 s) do not move the metric that the 2025–2026 literature says governs AI-assisted work: *comprehension/verification time per diff* — [§4.3](#43-amdahls-law-for-flow-and-the-fan-out-correction).
3. **Nothing is measured.** KLM tables are model estimates; there is no personal telemetry, so no claim can be falsified — [§10](#10-flow-state-engineering-model).
4. **Resilience & portability are the weakest axis** (in-memory `acpd` state, `/etc/keyd` drift, Linux-only, three single-maintainer forks with 0 external stars) — [§7](#7-section-2--home-row--vim-ergonomics-validation) and [§11](#11-prioritized-roadmap).
5. **The evidence base cited in the docs contains errors** (Doherty, Parnin & DeLine, Barke et al., Dhakal et al.) and **competitor facts are outdated** (workmux now has session mode, a sidebar and a dashboard; Herdr ships agent-config integrations, not only screen heuristics) — [§12](#12-errata-for-existing-docs).

### 1.2 Scorecard (judgment, rubric in [§1.3](#13-rubric))

| Dimension | Design | As-deployed | Why |
| :--- | :---: | :---: | :--- |
| Input biomechanics (keyd, Alt-free) | **9.0** | 8.5 | `capslock = overload(control, esc)` live; tmux/nvim have 0 Alt binds. Minus: live `keyd` lacks documented `overload_tap_timeout`; Ghostty 4-modifier chord; Hypr Alt fallbacks. |
| Latency / responsiveness | **9.0** | 8.0 | 2.7–6 ms binary start-up (A). Minus: `wm -f` 2.3–4.9× slower than `fzf --filter` at 10k–384k lines; sync `git status` in popup pre-check. |
| Zero-friction navigation (`j`, `Tab`, `ptl`) | **9.0** | 9.0 | Object-first + frecency; but gain over `zoxide` is ≈0 for *known* targets ([§4.2](#42-klm-goms-recomputation-with-explicit-baselines)). |
| Git/AI review loop | **9.0** | **4.0** | Dual-diff + note injection is unique. **As-deployed the tmux popup launches a stale v0.0.20 binary that rejects `-c`** (F1). |
| Agent supervision & telemetry | **8.5** | 8.0 | Structured hooks + sound cues + attention ring. Minus: no WIP limit, no breakpoint-aware delivery, in-memory state. |
| Visual semiotics / cognition | **8.0** | 8.0 | Dual-coded (glyph + colour) layers are sound; "golden ratio/foveal" justification is not ([§8](#8-section-3--visual-semiotics-colors--eye-tracking)). |
| Resilience, portability, remote | **6.0** | 5.5 | Herdr's core advantage lives here. |
| Measurement & evidence discipline | **4.0** | 4.0 | Model-only numbers; citation errors. |
| Maintainability / bus factor | **5.0** | 5.0 | 53k LOC `wm` + 49k LOC `lazygitrs` fork + `acpd`; all single active maintainer on the fork side. |
| **Weighted overall** | **8.0** | **6.9** | Weights: ergonomics 15, latency 15, navigation 10, review 20, supervision 15, semiotics 5, resilience 10, measurement 5, maintainability 5. |

### 1.3 Rubric

10 = best-in-class **and** evidenced/measured; 8 = best-in-class by design, evidence partial; 6 = works for the owner, fragile elsewhere; 4 = broken or unevidenced; "As-deployed" subtracts verified defects.

### 1.4 Top 10 actions (ordered by value ÷ effort)

| # | Action | Effort | Evidence | Section |
| :-: | :--- | :---: | :---: | :---: |
| 1 | Fix stale `lazygitrs` resolution in `lazygitrs-popup.sh` (or `cargo uninstall`) | 5 min | **A** | [F1](#f1--ctrlg-popup-launches-a-stale-binary-that-rejects-its-own-flags) |
| 2 | Re-apply `keyd` config so live `/etc/keyd/default.conf` matches installer | 2 min | **A** | [F2](#f2--live-keyd-config-drifted-from-installer--docs) |
| 3 | Reconcile `acpd` debounce docs (300/400 ms) with live `650 ms` | 10 min | **A** | [F3](#f3--debounce-value-documented-three-different-ways) |
| 4 | Correct citation/competitor errata ([§12](#12-errata-for-existing-docs)) | 1 h | **A/B** | §12 |
| 5 | Add 6-line personal telemetry (context switches, agent wait→respond, review time) | 1 h | C→measurable | [§10.3](#103-n-of-1-instrumentation) |
| 6 | Soft **WIP limit (3–4 agents)** + "Focus/Triage" mode switch in `acpd` | 1 day | B | [§10.2](#102-two-flow-modes-not-one) |
| 7 | **Review-cost reduction**: risk-ordered file queue, test result shown *before* diff, small-batch nudge | 2–4 days | B | [§4.3](#43-amdahls-law-for-flow-and-the-fan-out-correction) |
| 8 | Breakpoint-aware sound delivery (defer chime until typing pause) | 2 h prototype | B | [§11 P1](#p1--days) |
| 9 | `acpd` state rehydration from tmux pane options on restart + `agentState/wait` RPC | 2 days | B/C | [§11 P1](#p1--days) |
| 10 | Investigate `wm` headless filter slowdown (profile scoring: depth penalty, dir-first) | 1 day | **A** | [F5](#f5--wm--f-is-slower-than-fzf---filter-above-10k-lines) |

---

## 2. Verified Findings (live system)

All items below were reproduced on this machine on 2026-10-05 (**grade A**) unless stated.

### F1 — `Ctrl+G` popup launches a stale binary that rejects its own flags

- [`lazygitrs-popup.sh`](../../tmux/.config/tmux/lazygitrs-popup.sh) hard-prefers `$HOME/.cargo/bin/lazygitrs` over `command -v lazygitrs`.
- `~/.cargo/bin/lazygitrs` is **v0.0.20 (2026-05-18)**; `~/.local/bin/lazygitrs` is **v0.0.38 (2026-10-04)**; `which -a` lists the v0.0.38 first, so an interactive shell hides the problem.
- The script runs `lazygitrs -d -c popup [--commits]`. In v0.0.20, `-d` is `--debug` and `-c` does not exist:

```text
$ ~/.cargo/bin/lazygitrs -d -c popup --commits
error: unexpected argument '-c' found
```

- The `--commits` flag and the `Ctrl+G` dual-diff toggle were introduced later (commits `afaa308`/`c3f1caa` on the `fecavmi` branch, shipped in `v0.1.0-cockpit`).
- **Impact:** with tmux `-E`, a non-zero immediate exit closes the popup at once → the flagship review gesture appears as a flash/no-op. **Fix in [§6](#6-section-5--production-ready-implementation-code) (a).**

### F2 — Live `keyd` config drifted from installer & docs

| Source | `overload_tap_timeout` |
| :--- | :--- |
| [`.shell/install/packages/keyd.zsh`](../../.shell/install/packages/keyd.zsh) | `[global] overload_tap_timeout = 200` |
| 3 docs (manifesto §4.1, keybindings matrix, evaluation report) | "guarded by `overload_tap_timeout = 200`" |
| **Live `/etc/keyd/default.conf`** (dated 2025-12-09) | **absent** — only `capslock = overload(control, esc)` |

The installer was improved after the machine was configured and never re-run. Behavioral consequence: without the timeout, a deliberate long hold followed by release with no other key emits a stray `Esc`. Low harm in Vim, nonzero in modal TUIs where `Esc` unwinds a dialog (the cascading-escape doctrine).
Also note `/etc/keyd` is outside Stow → hardware layer is reproducible only through the installer, and the installer can drift (this is the third-weakest point of [§7](#7-section-2--home-row--vim-ergonomics-validation)).

### F3 — Debounce value documented three different ways

| Source | Value |
| :--- | :---: |
| `docs/README.md` index → *popup-isolation-and-debounce* | **400 ms** |
| `tui-ux-workflow-evaluation-report.md` §5.2 | **300 ms** |
| Live `~/.config/acpd/config.toml` (`idle_debounce_ms`) | **650 ms** |

A living-documentation violation ([AGENTS.md](../../AGENTS.md) "Documentation and code MUST never diverge"). The value matters: 650 ms idle debounce is perceptible against the 100–400 ms thresholds ([§3](#3-scientific-evidence-ledger)).

### F4 — `history-limit 10000` is low for streaming agents

`tmux show -g history-limit` → `10000`. Agent TUIs that render in the main screen can emit >10k lines in one long turn; scrollback extraction (`Prefix y`, `Prefix E`) then silently loses the beginning of the turn. Raise to 30–50k and measure RSS (memory scales with *used* cells per line, per pane). **Grade A (value), C (impact).**

### F5 — `wm -f` is slower than `fzf --filter` above ~10k lines

Headless filter, stdin, query `zshfun`, best of 5, identical top-3 results:

| Input lines | `fzf --filter` | `wm -f` | Ratio |
| ---: | ---: | ---: | :---: |
| 10,000 | 11 ms | 25 ms | 2.3× |
| 100,000 | 43 ms | 155 ms | 3.6× |
| 383,807 | 125 ms | 610 ms | 4.9× |

`wm -f` crosses 100 ms at roughly **60k lines** (linear interpolation). Likely contributors (hypotheses, **C**): path-depth penalty, dir-first tiering, config/preset loading, `redb` open. Caveats: interactive mode streams results incrementally (nucleo), so *perceived* latency is lower than this headless number; `wm -f ... --no-read` numbers were discarded (it ignores stdin and runs the walker). Matters for ZLE widgets that call `wm -f` synchronously on large trees.

### F6 — Synchronous `git status` in the popup pre-check

`lazygitrs-popup.sh` runs `git status --porcelain` before opening the popup to choose Files vs `--commits`. Warm: **10 ms** (this repo). First call after heavy worktree churn in `waymaker`: mean **182 ms over 3 runs** (includes a cold index refresh). Cheaper equivalents measured warm: `git status --porcelain -uno` 7 ms, `git ls-files --others …` 5 ms. Consider `core.untrackedCache=true` and evaluating `core.fsmonitor`. **Grade A (numbers), C (gain on monorepos).**

### F7 — Hardware-layer residue against the "no Alt" doctrine

- tmux: **0** `M-*` binds (✓). Neovim: **0** `<A-…>/<M-…>` maps (✓).
- Hyprland [`bindings.lua`](../../hypr/.config/hypr/bindings.lua): **15** lines still reference `ALT` (documented legacy fallbacks).
- Ghostty config: `alt+shift+enter=csi:13;4u` (feeds a tmux `M-S-Enter` bind that no longer exists in `tmux.conf`) and a **four-modifier** chord `super+control+shift+alt+arrow_*` for `resize_split`. Four simultaneous modifiers are the opposite of the doctrine.

### F8 — Licensing/legal to verify before open-sourcing

`waymaker` ships **AGPL-3.0** (`LICENSE` present) but is a fork of `Squirreljetpack/matchmaker`, whose GitHub license detection is `NOASSERTION` (custom `LICENSE`). `acpd` has no license file. Check upstream terms before publishing (`OPENSOURCE_PLAN.md`). **Grade A (facts), C (legal conclusion).**

### F9 — Maturity/bus-factor snapshot

| Project | Rust LOC | `#[test]` | Commits since Apr-2026 | Authors | CI workflows | Stars |
| :--- | ---: | ---: | ---: | :--- | :--- | ---: |
| `waymaker` | 53,354 | 317 | 774 | felipe 477 / upstream author 441 | release, publish | 0 |
| `lazygitrs` (fork) | 49,113 | 168 | 303 | upstream 339 / felipe 82 / other 10 | release, publish-registries | 0 (upstream 32) |
| `acpd` | 5,385 | **11** | 39 | felipe 39 | release | 0 |

`acpd` is the *load-bearing* telemetry hub with the **thinnest test coverage** (11 tests / 5.4k LOC, no `tests/` dir) and **in-memory state only** (restart loses all pane states until the next hook). The `lazygitrs` fork is healthy: 81 commits ahead, 3 behind upstream.

---

### F10 — `acpd --version` starts a daemon instead of printing a version

`main.rs` reads `std::env::args()` positionally (second arg = config path) and has no flag parsing, so `acpd --version`/`--help` boot a full daemon instance (log line `Starting ACP Daemon`). On this machine the stray instances failed harmlessly at `TcpListener::bind` (port 4040 already bound) **before** `generate_and_save_token()`, so the live token (`$XDG_RUNTIME_DIR/acpd/token`, mtime = service start) and `/tmp/acpd.pid` were untouched (verified). With the service stopped, the same command would silently run a second daemon and rotate the token. Any "version probe" in tooling (including the [§6 doctor](#6-section-5--production-ready-implementation-code)) must therefore **not** call `acpd --version`. Fix: add `clap` (`--version`, `--help`, `--config`). **Grade A.**

### Correction of an earlier measurement in this audit

The first `acpd` RPC timing (14 ms) used a wrong token path and measured `401` responses plus `curl` fork cost. Re-measured with the correct token, `curl %{time_total}`, n = 100: `GET /health` **0.74 ms**, authorized `POST /rpc agentState/list` **0.79 ms** (HTTP 200). Daemon RSS ≈ 6–9 MB (`systemctl --user status`: 8.7 M, peak 10.1 M). `acpd` is not a latency concern.

---

## 3. Scientific Evidence Ledger

Re-checked claims. "Repo claim" = what existing docs say; "Verdict" is mine.

| Source (grade) | What it actually shows | Repo claim | Verdict |
| :--- | :--- | :--- | :--- |
| **Miller 1968; Card, Robertson & Mackinlay 1991** (B) | 0.1 s ≈ instantaneous; 1 s ≈ flow of thought uninterrupted; 10 s ≈ attention limit | "Doherty Threshold (<100 ms)" | **Misattributed.** The 100 ms rule is Miller/Card. |
| **Doherty & Thadhani 1982, IBM** (B) | Productivity rises *super-linearly* as response drops **below ~400 ms** ("Doherty threshold = 400 ms") | "<100 ms", "hyper-linear below 400 ms" in two places | **Partly wrong.** Keep the *superlinear* point; fix the number. |
| **Dhakal, Feit, Kristensson & Oulasvirta, CHI 2018** (B) | 136M keystrokes/168k typists; **rollover** (overlapping key presses) used for 40–70 % of keystrokes by fast typists | "inward rolls (`CapsLock+G`, `j+Enter`) are faster / lower error" | **Overstated/misapplied.** The paper establishes rollover as a fast-typing strategy; it does not test Ctrl-chords or compare "inward vs outward". `CapsLock+G` is a *held chord*, not a roll. `j`→`Enter` is a genuine sequential roll. |
| **METR, Jul 2025** (B) | RCT, 16 experienced OSS devs, 246 tasks: AI-allowed **19 % slower**, believed 20 % faster | Cited correctly | **Valid but dated.** METR's Feb-2026 follow-up was judged **unreliable** by METR itself (selection bias; devs refused no-AI arm; concurrent agents break time-on-task). No valid RCT exists for *parallel-agent supervision UX*. |
| **Anthropic RCT, Jan 2026, "How AI assistance impacts the formation of coding skills"** (B) | 52 engineers learning Trio: AI group **−17 pp** on comprehension quiz; speed gain not significant; "full delegation" patterns worst; conceptual-inquiry patterns preserved learning | Not cited | **Highly relevant.** Supports "active review" designs (writing review notes) and warns against rubber-stamping. |
| **DORA 2025 State of AI-assisted Software Development** (B) | AI amplifies; higher throughput correlates with **higher instability**; larger batch sizes make review the bottleneck | Not cited | **Highly relevant** to review design and commit-size nudges. |
| **Gloria Mark et al., CHI 2008** (B) | Interrupted people finish faster but with more **stress, frustration, time pressure**; quality equal | Not cited | Useful. The popular "23 min 15 s" figure comes from an interview, **not** the paper. |
| **Parnin & DeLine, CHI 2010** (B) | Only **~10 %** of programming sessions resume in <1 min | "ICSE 2010 … 16 % … 10–15 min" | **Wrong venue and figure.** |
| **Barke, James & Polikarpova, OOPSLA/PACMPL 2023** (B) | Acceleration vs exploration modes; 20 programmers; Distinguished Paper | "ACM CHI 2023" | **Wrong venue.** Finding itself is correctly used. |
| **Iqbal & Bailey, CHI 2008** (B) | Deferring notifications to **breakpoints** reduces frustration and speeds task resumption | "30 %–50 % disruption reduction" | **Direction right, number unverified.** |
| **Altmann & Trafton 2002** (C) | Memory-for-goals activation decays over interruption | Cited | Plausible; venue/year per memory. |
| **Olsen & Goodrich 2003** (C) | Fan-out `FO = (NT+IT)/IT = 1 + NT/IT` | `FO = 1 + AT/IT`, then "**19 agents**" | Formula fine; the **extrapolation is invalid** ([§4.3](#43-amdahls-law-for-flow-and-the-fan-out-correction)). |
| **Keir, Bach, Hudes & Rempel 2007** (B) | Carpal-tunnel pressure thresholds; ulnar deviation ≤ **~14.5°** keeps 75 % of people under 30 mmHg | Cites "Marklin 2020; Rempel 1998/2008"; "25–35° ulnar on Alt chords" | **Direction right; the 25–35° figure for Alt chords is unsupported** — it needs measurement (goniometer/video). |
| **Lane, Napier, Peres & Sándor 2005** (B) | Most users never transition from menus to shortcuts | Implicit | Supports the in-situ HUD (`Prefix ?`). |
| **Grossman, Dragicevic & Balakrishnan, CHI 2007** (B) | Strategies to accelerate hotkey learning | "2.5× faster expert transition" | **Number unverified** (could not find it). |
| **Scarr, Cockburn, Gutwin & Bunt, CHI 2012 (CommandMaps)** (B) | Spatially stable, all-at-once layouts beat hierarchical menus via spatial memory | "outperform adaptive menus by 35 %" | **Direction right; 35 % unverified.** Supports spatial stability of popups. |
| **Tognazzini "Ask Tog" (folklore)** (B) | Users *perceive* keyboard as faster than measured mouse; contested | Not cited | Warning: **perceived** speed ≠ measured speed — the reason to instrument ([§10.3](#103-n-of-1-instrumentation)). |
| **Meyer, Fritz, Murphy & Zimmermann 2014/2019** (B) | Productivity = agency + uninterrupted progress; meetings/interruptions are not uniformly harmful | Not cited | Supports a *user-controlled* attention model (pull > push). |
| **Cowan 2001 (4±1); Miller 1956 (7±2)** (C) | Working-memory chunk capacity | Both used | Fine; prefer Cowan for UI chunking. |
| **"Golden ratio improves foveal focus"** (—) | No supporting study found | Central to popup geometry docs | **Unsupported rationale.** Geometry (75 %×60 %, centred, backdrop visible) is fine on *context-preservation* grounds; drop the φ/foveal justification ([§8](#8-section-3--visual-semiotics-colors--eye-tracking)). |
| **"Icons decode in ~15 ms vs 200 ms text"** (—) | No supporting study found | Manifesto §2.1 | **Unsupported number.** Pre-attentive features exist (Treisman, C) but *learned* glyphs need familiarity. |

---

## 4. Section 1 — Ergonomic, Biomechanical & KLM-GOMS Diagnosis

### 4.1 Biomechanical assessment

| Topic | Assessment | Grade |
| :--- | :--- | :---: |
| `CapsLock → Ctrl/Esc` on the home row | Removes the corner-Ctrl reach and the ulnar deviation it induces. Directionally supported by wrist-posture work (Keir et al. 2007: ulnar deviation ≲ 14.5° keeps most people under 30 mmHg carpal-tunnel pressure). The *magnitude* of benefit for this user is **unmeasured**. | B |
| "Inward roll" terminology | `j`→`Enter` is a real sequential roll (Dhakal 2018: rollover is a fast-typing strategy). **`CapsLock+G/S/F` is a static held chord** (pinky holds, index taps), not a roll. Its risk class is *static pinky load*, mitigated by home-row placement, not eliminated. | B |
| Same-hand Ctrl chords on left-hand keys (`C-g`, `C-s`, `C-f`, `C-t`) | One finger holds, another taps; bimanual alternation would be gentler. No right-side Ctrl exists. A mirrored right-hand Ctrl is an *option to evaluate with telemetry*, **not** to adopt now (Zero-Churn Rule; and do **not** overload `Enter`, it would endanger the sacred `j`+`Enter` roll). | C |
| `Ctrl+Shift+<left-hand key>` (`C-S-g`, `C-S-i`, `C-S-t`) | Triple-key chord. Use the **right** Shift for left-hand letters to avoid pinky(Caps)+pinky(LShift)+index on one hand. Also requires CSI-u/`extended-keys` end-to-end ([§7.4](#74-resilience-axis-remote-and-portability)). | C |
| `Esc` via tap | `keyd` emits the tap on **release**, so the 120 ms figure is dwell-time-bound (typ. 80–150 ms), not zero. Acceptable. | A |
| Static load / dosimetry | The stack has no *dose* signal (keystrokes/day, micro-break compliance). `hibiki` already sees every keystroke — a daily counter is nearly free ([§10.3](#103-n-of-1-instrumentation)). | C |

### 4.2 KLM-GOMS Recomputation with Explicit Baselines

Operator values (Card, Moran & Newell; **C**): `K` = 0.12 s (best typist) / **0.20 s** (good) / 0.28 s (average), `P` = 1.10 s, `H` = 0.40 s, `M` = 1.35 s, `R` = system response. **Placement rule:** `M` is dropped inside a cognitive unit that is fully overlearned — so `M ≈ 0` holds *only after consolidation*; for a new user `M` returns to 0.6–1.35 s per decision. Existing docs use `M ≈ 0` unconditionally and compare against a **GUI/mouse** baseline (B0). A fair baseline is a competent vanilla-terminal user with aliases (B1).

Tasks use `K = 0.20 s`. `R` for `wm`/`lazygitrs` start-up is ≈ 3–6 ms (measured, [§9](#9-performance-report)); other `R` values are assumptions.

| Task | B0 GUI/mouse | B1 vanilla terminal | This stack | Speed-up vs B1 | Note |
| :--- | :---: | :---: | :---: | :---: | :--- |
| **Open working-tree review** | 3.2 s (`H`+`P`+click+`R`≈1.5) | 1.25 s (`lg⏎`: `M`0.35 + 3`K` + `R`0.3) | **0.35 s** (`C-g`: `M`0.1 + `K` + `R`) | **3.6×** | Design value; **currently broken by F1.** |
| **Jump to a known directory** (3-letter fragment) | — | `cd` + Tab-completion 3.8 s; **`zoxide` `z foo⏎` 1.8 s** | **1.65 s** (`Tab`+`foo`+`⏎` incl. visual confirm `M`0.6) | **1.1× vs zoxide**, 2.3× vs `cd` | Gain over zoxide is ≈0 for *known* targets; the win is for **ambiguous/unknown** targets (previews, tri-modal source) and verb-free object-first. |
| **Copy a file to last target** | — | 4.6 s (`cp f ~/dir/` ≈ 20 keys) | **2.95 s** (`ptl file.txt⏎`, 13 keys) / **2.4 s** (object-first picker + `ptl⏎`) | 1.6–1.9× | The documented **220 ms omits argument entry**; `ptl file.txt⏎` alone is ≥ 1.56 s at `K` = 0.12. |
| **Dismiss modal** | 0.60 s (`H`+`K`) | 0.60 s | **0.12–0.20 s** (tap `CapsLock`) | 3–5× | Holds only if the hand is on the home row. |
| **Jump to the agent that needs me** (6 windows) | 3.2 s | ≈ 2.2 s (visual search `M` 1.35 + select) | **0.45 s** (`C-S-i`) | 4.9× | Biggest *attention* win: removes visual search entirely. |

Reading: realistic speed-ups are **1.1×–5×**, not 16–22×. That is still excellent — and, more importantly, it is the *wrong lever* for the largest cost, as shown next.

### 4.3 Amdahl's Law for Flow and the Fan-Out Correction

Amdahl: `S = 1 / ((1 − p) + p/s)`. Fan-out (Olsen & Goodrich, **C**): `FO = 1 + NT/IT`, `NT` = neglect time (agent runs unattended), `IT` = interaction time per cycle.

Take a review cycle `IT = 60 s` of which **navigation/switching is p ≈ 5 % (3 s)**. Making navigation *infinitely* fast gives `S = 1/0.95 = 1.05`. With `NT = 180 s`: `FO` moves 4.00 → 4.16.
The existing report's "**19 agents**" assumed `IT = 10 s`, i.e. reading and judging a diff **6× faster**, which nothing in the stack delivers and which conflicts with:
- METR 2025 (verification dominates), Anthropic Jan 2026 RCT (−17 pp comprehension under delegation), DORA 2025 (larger AI batches make review the bottleneck) — all grade B;
- Cowan's `4 ± 1` chunks (**C**): concurrent *goal tracking* caps near 3–4 regardless of how fast switching is.

**Conclusion:** the next gains come from reducing **comprehension cost per diff**, not keystrokes. Levers, in order of expected value:

1. **Small batches** — commit-per-task (DORA). Make the `awc` wizard/AGENTS.md nudge ≤ N changed lines per agent turn.
2. **Tests-as-oracle before reading** — show red/green + failing test names in the `lazygitrs` header for `HEAD`/working tree, so "does it work?" is answered pre-read.
3. **Risk-ordered review queue** — order files by *churn × centrality × lacks test*; auto-collapse lockfiles, snapshots, generated code.
4. **Structural/semantic diff** for moves/renames (evaluate `difftastic` as an external pager; **not verified here**).
5. **Active review, not approval** — keep the `S` review-note injection (writing a note is a high-engagement pattern per the Anthropic taxonomy); consider an "ask the agent *why*" action (conceptual inquiry preserved learning in that study).
6. **WIP limit 3–4** and a Focus/Triage switch ([§10.2](#102-two-flow-modes-not-one)).
7. **Time-box and log** each review with a later outcome (revert rate) to calibrate ([§10.3](#103-n-of-1-instrumentation)).

---

## 5. Competitive Landscape

All stars as of **2026-10-05** (GitHub API, **A**). Feature facts from each project's README/site (**A** for "stated by project", unverified by running).

### 5.1 Taxonomy

| Class | Examples | Defining trait |
| :--- | :--- | :--- |
| **Agent runtime** | Herdr | Server owns PTYs; every UI is a client |
| **Session/worktree manager on tmux** | workmux, Agent of Empires, Claude Squad, Agent Deck, worktrunk, **this stack (`awt`+`acpd`)** | Thin layer over an existing multiplexer |
| **Visualizer** | Age of Agents | Read-only ambient display |
| **GUI "ADE"** | Orca, Conductor, Emdash, Superset | App-bound window |
| **File manager / picker** | Yazi, superfile, lf, television, **`wm`**, fzf+zoxide | Navigation/preview/actions |
| **Git TUI** | lazygit, gitui, jjui, **`lazygitrs`** | Review loop |

### 5.2 Agent orchestration matrix

| | **This stack** | **Herdr 0.9.3** | **workmux** | **Agent of Empires** | **Age of Agents** | **Claude Squad** |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Stars / license / lang | 0 / mixed / Rust+sh | **42.5k** / Apache-2.0 / Rust | 2.8k / MIT / Rust | 3.3k / MIT / Rust | 264 / unspecified / TS | 8.6k / AGPL-3.0 / Go |
| Age | months | 6 mo (2026-03) | 11 mo | 9 mo | 4 mo | 19 mo |
| Substrate | tmux 3.7c | Own server + PTY | tmux (+WezTerm/kitty/Zellij) | tmux | none (reads session data) | tmux |
| Survives UI crash/detach | ✅ (tmux) | ✅ (server) | ✅ (tmux) | ✅ (tmux) | n/a | ✅ |
| Layout/agent restore after **reboot** | ⚠️ layout only (resurrect-style); no agent resume | ✅ layout + resume supported agents (processes themselves do not survive) | ⚠️ tmux-bound | ⚠️ tmux-bound | n/a | ⚠️ |
| Worktree model | **1 worktree = 1 tmux *session*** | worktree support in runtime | **window default; `--session` mode exists** | worktrees | none | worktrees |
| Agent state source | **Structured hooks → `acpd`** | detection manifests (22 agent CLIs) **+ per-agent integrations** | hooks → status icons; "no output 10 s ⇒ interrupted" | status monitor (running/waiting/idle) | local session logs | screen-based |
| Review loop | **✅ `lazygitrs` dual-diff + note → agent** | not stated | dashboard "review changes" | web diffs | ❌ | diff view |
| Remote / mobile | Tailscale+SSH (manual, [doc](remote-agent-workflow-acpd.md)) | **✅ saved SSH machines, unified agent list, mobile client** | via tmux/SSH | **✅ web dashboard (mobile)** | ❌ | ❌ |
| Sandbox | `ai-jail` (docs) | not stated | **✅ container / Lima** | **✅ Docker** | ❌ | ❌ |
| Persistent chrome | **0 columns** (popups) | sidebar/workspace list (width not verified) | window-name icons; **optional `sidebar`** | full-screen TUI | second monitor | TUI |
| Programmatic control | JSON-RPC (`acpd`), `tmux.*` | **CLI + socket API, "wait until blocked"** | CLI, skills | CLI | WebSocket (read) | CLI |
| Plugins | scripts | **1,548 community plugins** | YAML hooks | — | — | — |
| Keyboard doctrine | **Home-row, no Alt, `keyd`** | tmux-style prefix **+** mouse first-class | tmux defaults | TUI keys | n/a | TUI keys |

### 5.3 Per-tool verdicts ("what to steal")

**Herdr (the real competitor).** 42.5k stars and 1.29M installs in six months is momentum this stack cannot match; its thesis — *terminals persist in a server, UIs are disposable clients* — is sound and explicitly includes reboot restore, multi-machine lists and an agent-native API. The prior docs' characterization (monolith, PTY scraping only, "breaks Neovim navigation", "32-column sidebar") is **partly outdated or unverified** (the source tree has both `src/detect/manifests` *and* `src/integration/{claude_settings,opencode_config}.rs`, i.e. config-level integrations). **Do not migrate** — popups, `vim-tmux-navigator`, `sesh`, `lazygitrs` integration and the home-row doctrine are real, working assets (Zero-Churn). **Do copy three ideas:**
1. a **`wait` primitive** — `acpd` RPC `agentState/wait {pane, state, timeout}` (long-poll) so agents/scripts can orchestrate each other;
2. **post-reboot agent resume** — persist `{pane, agent CLI, session id}` and re-issue the agent's resume command;
3. **multi-host fleet list** — one `acpd` per host + Tailscale aggregator (P3).

**workmux.** Prior criticism ("1 worktree = 1 window") is **obsolete**: it has `--session` mode, multi-window sessions, an optional sidebar, a dashboard, container/Lima sandboxes, LLM branch naming, `pre_merge`/`post_create` hooks and 4 backends. Where it still differs: no home-row doctrine, no review-note loop, no popup layer. **Steal:** sandbox integration, status auto-clear on focus, the 10-second "interrupted" heuristic (cheap hardening for `acpd`'s 30 s stale sweep), and a `pre_merge` gate (`just check`) in `awt ship`.

**Agent of Empires.** Philosophically closest sibling (thin Rust layer on tmux, worktrees, Docker sandbox) plus a **web dashboard usable from a phone**. **Steal:** the mobile approval path (a tiny authenticated endpoint on `acpd` behind `tailscale serve`). Not worth adopting wholesale — it overlaps `awt`+`acpd` without the review loop.

**Age of Agents.** A pixel-art, read-only, second-monitor view fed over local WebSocket (264 stars; 4 months old; license undeclared). Against the repo's own attention argument (peripheral motion triggers orienting responses), it is a **net negative for focused flow** and adds no control. Acceptable only as an optional *second-monitor* ambient view; **not** a replacement for `acpd`.

**Others.** Claude Squad (8.6k★, AGPL, auto-accept flag), Agent Deck (1k★, fleet/cost dashboard), worktrunk (8.9k★, worktree CLI — already packaged here), GUI ADEs (Orca 85.9k★ but 7.7k open issues; app-bound by Herdr's own taxonomy — **not** re-verified). None offers the review loop or the ergonomic doctrine.

### 5.4 File managers & pickers

| | **`wm` (waymaker 0.2.0)** | **Yazi 26.9.1** | **superfile** | **lf** | **television** | **fzf + zoxide** |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Stars / lang / license | 0 / Rust / AGPL-3.0 | **42.6k** / Rust / MIT | 23.7k / Go / MIT | 9.5k / Go / MIT | 6.3k / Rust / MIT | 83.4k + 39.9k / Go + Rust / MIT |
| Start-up (`--version`, mean of 30, floor 1.9 ms) | **6.0 ms** | 8.6 ms | not installed | not installed | not installed | fzf 9.3 ms, zoxide 2.3 ms |
| Core model | Nucleo SIMD picker; in-process walker; `redb` frecency | **Fully async I/O**, task scheduler, multi-threaded CPU work | Multi-panel, GUI-like | Minimal, shell-scriptable | Channel-based fuzzy TUI | Line-filter + frecency DB |
| Previews | Kitty/Sixel/iTerm2 media, Markdown + Mermaid, tree | Built-in code highlight, image/video/PDF, preloading | Built-in | External | Channel previews | `--preview` |
| File ops | create / rename / trash / yank-cut-paste / compress / **undo stack** | bulk rename, extract, visual mode, tabs, cross-dir selection, VFS | full ops | via scripts | none | none |
| Extensibility | TOML presets | **Lua plugins, package manager, DDS pub/sub** | plugins/themes | shell | TOML channels | shell |
| Shell/ZLE fit | **Best: object-first buffer, `Tab`-jump, tri-modal source** | `--chooser-file`, `zoxide` plugin | weak | OK | OK | excellent |
| Headless filter (384k lines) | **610 ms** | n/a | n/a | n/a | n/a | `fzf` **125 ms** |

Verdict: **`wm` wins as a *picker/navigator integrated with ZLE and tmux*; Yazi wins decisively as a *file manager*** (async scheduler, 3+ years of maturity, plugin ecosystem, VFS). `fm.rs` + media/Markdown viewers are scope creep for a 0-star, single-maintainer fork. Recommendation: **freeze `fm.rs`**, keep `yazi` (already installed) as the escape hatch for bulk/remote/heavy-preview work, and decide by data: log `a/r/d/y/p/z` action counts for 4 weeks ([§10.3](#103-n-of-1-instrumentation)); if rare, stop investing.

### 5.5 Git TUIs

| | **`lazygitrs` (fecavmi)** | lazygit | gitui | jjui |
| :--- | :--- | :--- | :--- | :--- |
| Stars / lang | 0 (upstream Blankeos 32) / Rust | **82.9k** / Go | 22.5k / Rust | 2.2k / Go (jujutsu) |
| Open issues | 0 | 1,047 | 347 | 42 |
| Start-up | **2.7 ms** | not installed | not installed | not installed |
| Unique here | Dual-diff `C-g` (files ↔ HEAD), directory combined diff, **review-note → agent pane**, `.lazygitrs.port` isolation | Mindshare, maturity | Speed, safety | Jujutsu workflows |
| Fork health | **81 ahead / 3 behind** upstream, 168 tests | — | — | — |

Verdict: the review loop is the stack's strongest differentiator, and the cheapest place to attack comprehension cost ([§4.3](#43-amdahls-law-for-flow-and-the-fan-out-correction)). Keep the fork rebased; try to **upstream** dual-diff and the notes feature to shrink fork debt.

### 5.6 Terminal & multiplexer

Ghostty 1.3.1 (61.9k★, Zig), tmux 3.7c (49.8k★, C), Zellij (35.7k★, Rust, WASM plugins, *persistent* floating panes, session resurrection). The Z-axis law relies on **ephemeral** `display-popup -E`; Zellij floats are persistent panes, so migrating would change the model for no measured gain. No authoritative current terminal-latency numbers exist for Ghostty (Dan Luu's study predates it) — **measure it yourself** ([§9.3](#93-how-to-measure-properly)). **Keep tmux + Ghostty.**

---

## 6. Section 5 — Production-Ready Implementation Code

All snippets below were syntax-checked (`bash -n`) and, where stated, executed on this machine. **None has been applied to the repo or system** by this audit.

### (a) Fix F1 — resolve a *capable* `lazygitrs` in `lazygitrs-popup.sh`

Replace the two `LZG_BIN` lines with a resolver that skips binaries lacking `--commits`. Tested: resolves `~/.local/bin/lazygitrs` (v0.0.38); a copy of the v0.0.20 binary alone is correctly rejected; probe costs ≈ 4.5 ms (cache the result in a tmux option if desired).

```bash
resolve_lzg() {
  local c
  for c in "$HOME/.local/bin/lazygitrs" "$(command -v lazygitrs 2>/dev/null)" "$HOME/.cargo/bin/lazygitrs"; do
    [ -x "$c" ] || continue
    "$c" --help 2>&1 | grep -q -- '--commits' && { printf '%s\n' "$c"; return 0; }
  done
  return 1
}
LZG_BIN="$(resolve_lzg)" || { tmux display-message "lazygitrs >= 0.0.3x not found (stale ~/.cargo/bin?)"; exit 0; }
```

Simplest alternative: `rm ~/.cargo/bin/lazygitrs` (or `cargo uninstall lazygitrs`). **Do not** do this for `acpd`: `~/.local/bin/acpd` is a symlink to `~/.cargo/bin/acpd` by design.

### (b) Fix F2 — re-apply the `keyd` config (requires `sudo`)

```bash
sudo tee /etc/keyd/default.conf >/dev/null <<'EOF'
[global]
overload_tap_timeout = 200

[ids]

*

[main]

capslock = overload(control, esc)
EOF
sudo keyd reload
```

Then confirm: `grep overload_tap_timeout /etc/keyd/default.conf`.

### (c) F4 — scrollback depth

```tmux
set -g history-limit 50000
```

### (d) Breakpoint-aware sound delivery (prototype, untested end-to-end)

Defers a chime until the operator pauses typing (Iqbal & Bailey, grade B). `#{client_activity}` has **1-second resolution**, hence `idle_needed ≥ 2`.

```bash
#!/usr/bin/env bash
# chime-at-breakpoint.sh <wav> — defer an audible cue until typing pauses (max ~MAX_WAIT s)
idle_needed=${IDLE_NEEDED:-2}; max_wait=${MAX_WAIT:-20}; ticks=0
while (( ticks < max_wait * 2 )); do
  act=$(tmux display-message -p '#{client_activity}' 2>/dev/null) || break
  printf -v now '%(%s)T' -1
  (( now - act >= idle_needed )) && break
  sleep 0.5; ticks=$(( ticks + 1 ))
done
exec pw-play "$1"
```

Always bypass the delay for `permission`/`error` in **Focus** mode only if you want them immediate (policy, [§10.2](#102-two-flow-modes-not-one)).

### (e) Zero-fork personal telemetry (tested: logger + summarizer)

`~/.config/tmux/flow-log.sh` (uses the `printf '%(%s)T'` builtin — no `date` fork):

```bash
#!/usr/bin/env bash
mkdir -p "${XDG_STATE_HOME:-$HOME/.local/state}/flow"
printf '%(%s)T\t%s\t%s\n' -1 "$1" "${2:-}" >> "${XDG_STATE_HOME:-$HOME/.local/state}/flow/events.tsv"
```

```tmux
set-hook -g client-session-changed "run-shell -b \"~/.config/tmux/flow-log.sh session '#{session_name}'\""
set-hook -g after-select-window    "run-shell -b \"~/.config/tmux/flow-log.sh window  '#{session_name}:#{window_index}'\""
```

Switches per hour:

```bash
awk -F'\t' '$2=="session"||$2=="window"{h=int($1/3600); n[h]++} END{for(k in n) printf "%s\t%d\n", strftime("%F %H:00",k*3600), n[k]}' \
  ~/.local/state/flow/events.tsv | sort
```

(The `awk` bucket logic was tested on synthetic data; `strftime` needs `gawk`.)

### (f) Drift doctor — would have caught F1, F2, F4 (tested; exits 1 on any WARN)

`acpd` is **deliberately excluded** (F10: `acpd --version` starts a daemon).

```bash
#!/usr/bin/env bash
rc=0; warn(){ printf 'WARN  %s\n' "$*"; rc=1; }; ok(){ printf 'ok    %s\n' "$*"; }
for b in lazygitrs wm; do
  declare -A seen=(); n=0
  for p in "$HOME/.local/bin/$b" "$HOME/.cargo/bin/$b" "$(command -v "$b" 2>/dev/null)"; do
    [ -x "$p" ] || continue
    v=$("$p" --version 2>&1 | head -n1)
    [ -z "${seen[$v]:-}" ] && { seen[$v]="$p"; n=$((n+1)); }
  done
  (( n > 1 )) && warn "$b: $n versions on disk: $(printf '%s | ' "${!seen[@]}")" || ok "$b: single version"
  unset seen
done
grep -q overload_tap_timeout /etc/keyd/default.conf 2>/dev/null && ok "keyd tap timeout" \
  || warn "keyd: live config lacks overload_tap_timeout (installer sets 200)"
hl=$(tmux show -gv history-limit 2>/dev/null || echo 0)
(( hl >= 30000 )) && ok "tmux history-limit=$hl" || warn "tmux history-limit=$hl (<30000)"
exit $rc
```

Result on this machine today: `lazygitrs` WARN (0.0.38 vs 0.0.20), `wm` ok, `keyd` WARN, `history-limit` WARN, exit 1.

### (g) Policy proposal for `acpd` (design only — not implemented)

```toml
[policy]
wip_limit = 4                  # soft cap; exceeding plays one low "slot-full" cue
mode = "triage"                # "focus" | "triage"

[policy.focus]
audible = ["permission", "error"]   # suppress response/question chimes; badges still update
defer_to_breakpoint = true

[policy.triage]
audible = ["response", "question", "permission", "error"]
defer_to_breakpoint = false
```

Expose `acpd-cli mode focus|triage` and show the mode as one glyph in the status bar. Also add the `agentState/wait` RPC and state rehydration from the existing `@ai_agent_state_*` tmux pane options on start ([§11 P1](#p1--days)).

### (h) Reproducible benchmark harness (executed to produce [§9](#9-performance-report))

```bash
bench(){ local n=30 s e; s=$(date +%s%N); for _ in $(seq $n); do "$@" >/dev/null 2>&1; done; e=$(date +%s%N)
         echo "$(( (e-s)/n/1000 )) us/run :: $*"; }
bench /bin/true; bench wm --version; bench lazygitrs --version; bench yazi --version; bench fzf --version; bench zoxide --version; bench tmux -V
# headless filter, best of 5
find /usr "$HOME/dev" -type f 2>/dev/null | head -400000 > /tmp/paths.txt
for f in 10000 100000 400000; do head -$f /tmp/paths.txt > /tmp/p.txt
  for tool in "fzf --filter zshfun" "wm -f zshfun"; do best=99999
    for _ in 1 2 3 4 5; do s=$(date +%s%N); $tool < /tmp/p.txt >/dev/null 2>&1; e=$(date +%s%N); d=$(( (e-s)/1000000 )); (( d < best )) && best=$d; done
    echo "$f lines :: $tool :: ${best} ms"; done; done
# authorized acpd RPC latency (token lives in $XDG_RUNTIME_DIR)
T=$(cat "$XDG_RUNTIME_DIR/acpd/token")
curl -s -o /dev/null -w '%{http_code} %{time_total}s\n' -X POST http://127.0.0.1:4040/rpc \
  -H "Authorization: Bearer $T" -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"agentState/list","params":{},"id":1}'
```

---

## 7. Section 2 — Home Row & Vim Ergonomics Validation

### 7.1 Compliance proof (what was actually checked)

| Requirement | Evidence | Status |
| :--- | :--- | :---: |
| `CapsLock = overload(control, esc)` | `/etc/keyd/default.conf` live; `keyd` active | ✅ (but F2) |
| No `Alt/Option` in tmux | `grep` of `tmux.conf`: **0** `M-*` binds | ✅ |
| No `Alt` in Neovim | **0** `<A-…>/<M-…>` mappings | ✅ |
| No `Alt` in Hyprland | **15** lines still reference `ALT` (legacy fallbacks) | ⚠️ F7 |
| No exotic modifier stacks | Ghostty `super+control+shift+alt+arrow_*` (4 modifiers) | ❌ F7 |
| Sacred `j`+`Enter` | Not touched by any binding found; **do not** overload `Enter` | ✅ |
| Cascading `Esc` unwinding | Documented in manifesto §4.2; **not re-tested** in this audit | ⏳ |
| `escape-time 0` | Set (`tmux.conf:151`) — correct locally; see [§7.4](#74-resilience-axis-remote-and-portability) | ✅ |

### 7.2 Hands-off-home-row residue

Number-row chords (`C-1…9`, `C-S-0…9`, ``C-` ``) are **not** `H = 0`: a one-row reach (small but nonzero). They are acceptable because the same targets are reachable home-row-first via `Prefix s` (picker) and `Prefix f` (Vimium-style hints). Keep (Zero-Churn); do not add more number-row chords.

### 7.3 Section 6 — Interaction, mapping & biomechanical cost matrix (re-audited)

Grade = my ergonomic rating (A best). KLM `T` uses `K` = 0.20 s per key, chord = 1 `K`, `R` ≈ 0.05 s.

| Key / chord | Context | Action | Biomechanics | `T` | Grade | Remark |
| :--- | :--- | :--- | :--- | :---: | :---: | :--- |
| `CapsLock` tap | Global | `Esc` | Left pinky on home row | 0.12–0.20 s | **A** | Tap emitted on release |
| `CapsLock` hold | Global | `Ctrl` | Static pinky hold | 0 | **A−** | Static load, no stretch |
| `j` → `Enter` | Zsh | `cd ~` | Sequential right-hand roll | ~0.10 s | **A** | Sacred; only genuine roll |
| `Tab` (empty buffer) | Zsh | `wm -o jump` | Left pinky | 0.20 s | **A** | Object-first |
| `C-Space` | tmux | Prefix | Pinky + thumb (Space) | 0.20 s | **A** | Thumb is the neutral digit |
| `Prefix` + letter (`s t e f / ? i n`) | tmux | Pickers/HUDs | Two-stage, mnemonic | ≈ 0.45 s | **A** | Duplicates exist (`m`/`z`, `u`/`T`): harmless, don't churn |
| `C-g` | Global/tmux | Review popup | Same-hand held chord | 0.20 s | **B+** | **Broken by F1**; collides with Vim `Ctrl-G` (file info) / zsh `send-break` |
| `C-g` | `lazygitrs` | Toggle Files↔HEAD | Same-hand held chord | 0.20 s | **B+** | 1-touch |
| `C-S-g` / `C-S-i` / `C-S-t` | Global | AWT / triage / reopen | Triple-key; use **right** Shift | 0.30 s | **B** | Needs CSI-u end-to-end |
| `C-1…9` | Global | Select window | Number-row reach; 6–9 bimanual | 0.25 s | **B** | `H` small but ≠ 0 |
| `C-S-0…9` | Global | Move window | Triple chord + number row | 0.35 s | **C+** | Rare; consider Prefix-based |
| `Ctrl+U` | `wm` | Ancestor jump | Held chord | 0.20 s | **B+** | |
| `h/j/k/l`, `u`, `f` | `wm` nav mode | Move / undo / source | Home row | 0.20 s | **A** | |
| `S` | `lazygitrs` diff | Send review note | Shift + left ring | 0.30 s | **B** | |
| `Ctrl+Alt+…` / 4-modifier | Ghostty | `resize_split` | 4-key chord | ≥ 0.5 s | **D** | F7: remove or move to Prefix |

### 7.4 Resilience axis: remote and portability

- `C-S-*` bindings require the Kitty keyboard protocol / `extended-keys`; they silently fail from clients that don't send CSI-u (many mobile SSH apps). Prefix equivalents exist (`Prefix I`, `Prefix i`, `Prefix T`/`u`) — **verify each zero-prefix chord has a prefix fallback** and list them in the keybindings HUD.
- `escape-time 0` can mis-split escape sequences on high-latency links (SSH/Mosh over cellular). Use a per-client override when attached remotely (**C**).
- Nerd Font glyph badges render as tofu when the font is missing (SSH from another machine, phone). Provide an ASCII fallback switch for status scripts ([§8](#8-section-3--visual-semiotics-colors--eye-tracking)).
- Linux-only (`keyd`, Hyprland, PipeWire); the MacBook profile described in the docs has no equivalent live config in this repo.
- `acpd` state is memory-only: a daemon restart blanks every badge until the next hook fires.

---

## 8. Section 3 — Visual Semiotics, Colors & Eye-Tracking

### 8.1 Keep / change

| Item | Verdict | Reason |
| :--- | :---: | :--- |
| 3-layer system (ephemeral mauve / persistent orange / reactive yellow) with **glyph + colour + geometry** | **Keep** | Redundant coding helps colour-vision deficiency and peripheral reading. Sound on usability grounds. |
| "φ ≈ 1.618 improves foveal focus" | **Drop the rationale, keep the geometry** | No supporting study found. The fovea covers ≈ 2° ≈ **2.1 cm at 60 cm**; a 75 %×60 % popup on a ~34×22 cm panel spans ≈ **24° × 13°** — read by saccades and parafoveal vision, not "foveal focus". Real justification: **spatial stability** (CommandMaps, B), context preservation, no re-layout. |
| "Icons decode in ≈ 15 ms vs ≈ 200 ms text" | **Remove the number** | No source found; *learned* glyphs depend on familiarity. |
| `permission` and `error` share colour `#e67e80` in `acpd` config | **Change** | Two *different urgency tiers* (decide-now vs diagnose) differ only by glyph. Give `permission` a distinct hue or a pulse; verified in the live config. |
| 5 agent states (idle/working/question/permission/error) | **Keep, at the limit** | Pop-out colour search degrades beyond ≈ 4–5 categories (C). Don't add a sixth. |
| Nerd Font PUA glyphs | **Add fallback** | Tofu risk remote/mobile. |
| Theme-synced palette (`colors.toml`) | **Keep; add a check** | Verify each theme gives ≥ 3:1 contrast for the three border colours (WCAG non-text contrast, **C**). |

### 8.2 Section 4 — Proposed "Attention Ring v2" wireframe (reactive layer, 80 % × 75 %, 40/60)

Adds a **WIP gauge**, **age** and **test status** to the existing triage popup; no state *words* (pure-glyph doctrine); no persistent chrome (Z-axis law kept).

```text
╭── 󰮯  3/4 ───────────────────────────────────────────────── 󰈈 triage ──╮   zone 1: context + mode badge
│ >                                              │ 󰆍 Preview (frozen snapshot)    │
│                                                │                              │
│ 󱅭  feat-auth    claude    2m10s   ✔ 41/41     │ Bash command                 │   zone 2: list    | zone 3: preview
│ 󱜻  fix-theme    opencode  0m35s   ✔ 12/12     │   rm -rf target/cache/build  │
│ 󰑮  docs         codex     ⠋       …           │ Do you want to proceed?      │
│ 󱥂  spike-wm     claude    8m02s   ✘ 2 fail    │ [Y/n]                        │
│                                                │                              │
╰── ⏎ focus · n next · f focus-mode · ␛ dismiss ─────────── 12 ms ──────────╯   zone 4: HUD
```

Legend: `󱅭` permission (distinct hue, pulse) · `󱜻` question · `󰑮` working · `󱥂` idle · `✔/✘` tests on `HEAD`. Order = urgency (`permission` > `question` > `error` > `working` > `idle`), ties broken by **age** (oldest first), matching the existing sort in `ai-agent-bell-popup.sh`.

---

## 9. Performance Report

### 9.1 Measurements (this machine, 2026-10-05; **grade A**, single-machine, directional)

| Metric | Result | Notes |
| :--- | ---: | :--- |
| Process-spawn floor (`/bin/true`, mean of 30) | 1.88 ms | Subtract from the rows below |
| `zoxide --version` | 2.27 ms (+0.4) | |
| **`lazygitrs --version`** | **2.66 ms (+0.8)** | 14 MB binary |
| `tmux -V` | 5.15 ms (+3.3) | |
| **`wm --version`** | **5.97 ms (+4.1)** | 23 MB binary |
| `yazi --version` | 8.63 ms (+6.7) | 25 MB binary |
| `fzf --version` | 9.30 ms (+7.4) | 4.8 MB binary |
| `acpd` `GET /health` | **0.74 ms** | `curl time_total`, n = 100 |
| `acpd` authorized `POST /rpc` | **0.79 ms** | HTTP 200, n = 100 |
| `acpd` memory | 8.7 MB (peak 10.1 MB) | systemd |
| Headless filter 10k / 100k / 384k lines | `fzf` 11 / 43 / 125 ms · `wm` 25 / 155 / 610 ms | F5 |
| `git status --porcelain` (warm / cold-ish) | 10 ms / up to ~180 ms mean | F6 |

(`acpd --version` start-up was **not** measured: that command launches a daemon, F10.)

### 9.2 Interpretation

- Every binary on the **interaction path** starts in < 10 ms; the Doherty/Miller budgets (100–400 ms) are not threatened by process start-up. The stack's latency risks are elsewhere: **(1)** `wm` headless filtering on > 60k lines, **(2)** synchronous pre-checks in popup scripts (`git status`), **(3)** the 650 ms agent-idle debounce, **(4)** any popup that first calls `tmux capture-pane` for the frozen backdrop on very long scrollbacks (**not measured**).
- `--version` start-up is a *lower bound*; real first paint includes config/preset parsing, `redb` open, walker spawn and terminal I/O.

### 9.3 How to measure properly

1. **First paint:** run each TUI under a pty harness (`script`/`expect`/`vhs`) and timestamp the first non-empty frame; report p50/p95 over ≥ 50 runs with `hyperfine --warmup 5`.
2. **Key-to-photon:** 240 fps camera or `typometer` on Ghostty → tmux → `nvim`; compare with and without the popup layer.
3. **Popup open latency:** `tmux -C` control mode with timestamps around `display-popup`.
4. **`keyd` overhead:** `evtest` on the physical vs virtual device.
5. **CPU pinning / governor:** `performance` governor, `taskset`, discard first run; record machine, commit hashes and tool versions next to the numbers.

---

## 10. Flow-State Engineering Model

### 10.1 Mapping flow conditions to the stack (Csikszentmihalyi; **C**)

| Flow condition | Supported by | Undermined by |
| :--- | :--- | :--- |
| Clear goals | `awt` 1 task = 1 worktree/session; AGENTS.md rules | Fan-out > 3–4 fragments goals (Cowan, C) |
| Immediate feedback | < 10 ms binaries; sound + badge cues | 650 ms idle debounce; stale-binary silent failure (F1) |
| Challenge/skill balance | Muscle memory frees working memory | Verification of *someone else's* code is a different, heavier task |
| Sense of control (**agency**, Meyer et al., B) | User-initiated popups (pull) | Push chimes at arbitrary moments |
| Few interruptions | Z-axis law; ephemeral overlays | Un-deferred notifications (Mark 2008, B: interruptions cost stress even if speed is kept) |

Key point: with AI agents the operator alternates between **making** (deep flow) and **supervising** (vigilance + judgment). Designing for a single "flow" blurs the two.

### 10.2 Two flow modes, not one

| | **Focus (maker)** | **Triage (supervisor)** |
| :--- | :--- | :--- |
| Goal | Protect an uninterrupted block | Minimize agent idle-wait and review latency |
| Audible | `permission`, `error` only | All states |
| Delivery | Deferred to typing breakpoint (≥ 2 s idle) | Immediate |
| Badges | Update silently | Update + pulse for `permission` |
| WIP | Not enforced | Soft cap 3–4 |
| Entry/exit | One keypress or `acpd-cli mode` | One keypress |

This gives the user explicit **agency** (Meyer et al.) over interruption policy and is implementable entirely inside `acpd` ([§6 (g)](#g-policy-proposal-for-acpd-design-only--not-implemented)).

### 10.3 N-of-1 instrumentation

Perceived speed ≠ measured speed (Tognazzini; METR's 20 % vs −19 %). Log, then decide.

| Metric | Source | Why |
| :--- | :--- | :--- |
| Context switches / hour | tmux hooks ([§6 (e)](#e-zero-fork-personal-telemetry-tested-logger--summarizer)) | Interruption proxy |
| Agent `waiting → human responded` latency (p50/p95) | `acpd` state timestamps | Direct `IT` component of fan-out |
| Review time per agent commit + 7-day revert rate | `lazygitrs` open/close + `git log` | Calibrates comprehension cost |
| Longest uninterrupted block (no session change, keys active) | tmux hooks + `hibiki` | Deep-work proxy |
| Keystrokes/day, break compliance | `hibiki` | RSI dosimetry |
| `fm.rs` action counts | `wm` log | Decide whether to keep investing |
| Weekly NASA-TLX (6 items, C) + discomfort diary | Manual, 2 min | Subjective load, strain |

Design: **ABAB** — alternate Focus/Triage days (or Focus vs no policy) for 4 weeks, pre-register the primary metric (agent-wait p50 *and* longest block), accept the change only if it moves in the intended direction with no regression in revert rate.

### 10.4 Operational definition of "apex"

1. `doctor` exits 0 on every login; no doc number disagrees with config (F1–F3 class impossible).
2. Review-cost levers (§4.3 #1–3) shipped and their effect *measured*.
3. WIP cap and Focus/Triage in place with n-of-1 evidence of benefit.
4. Reboot/crash survivability matches Herdr's (layout **and** agent resume).
5. Evidence ledger has zero grade-C load-bearing claims.

---

## 11. Prioritized Roadmap

Zero-Churn Rule: **no existing keybinding is changed**; additions only (plus removal of dead/hostile chords in F7).

#### P0 — Minutes

| Task | Done when |
| :--- | :--- |
| Apply [§6 (a)](#a-fix-f1--resolve-a-capable-lazygitrs-in-lazygitrs-popupsh) | `Ctrl+G` in tmux opens the popup; `doctor` OK for `lazygitrs` |
| Apply [§6 (b)](#b-fix-f2--re-apply-the-keyd-config-requires-sudo) | `grep overload_tap_timeout /etc/keyd/default.conf` matches |
| Reconcile debounce docs (400/300 vs 650 ms) in one canonical file; link the rest | One value in docs = config |
| Apply [§12 errata](#12-errata-for-existing-docs) | `./scripts/docs-lint.sh` green; no wrong citation remains |

#### P1 — Days

| Task | Effort | Done when |
| :--- | :---: | :--- |
| `doctor` script wired into login/CI ([§6 (f)](#f-drift-doctor--would-have-caught-f1-f2-f4-tested-exits-1-on-any-warn)) | 2 h | Fails on drift |
| `acpd`: `clap` CLI (`--version/--help/--config`) (F10), `agentState/wait`, state rehydration from tmux pane options, ≥ 40 tests | 2–3 d | `acpd --version` prints and exits; restart keeps badges |
| Personal telemetry ([§6 (e)](#e-zero-fork-personal-telemetry-tested-logger--summarizer)) | 1 h | 2 weeks of data |
| Breakpoint-aware chime ([§6 (d)](#d-breakpoint-aware-sound-delivery-prototype-untested-end-to-end)) + Focus/Triage + WIP cap ([§6 (g)](#g-policy-proposal-for-acpd-design-only--not-implemented)) | 1–2 d | Mode glyph in status bar; ABAB test running |
| `permission` ≠ `error` colour; ASCII fallback for badges | 2 h | Visually distinct in all themes |
| Review levers 1–3 ([§4.3](#43-amdahls-law-for-flow-and-the-fan-out-correction)) | 2–4 d | Tests status + risk order visible in `lazygitrs` |
| Profile and fix `wm -f` (F5); `git status` pre-check hardening (F6); `history-limit` (F4) | 1–2 d | `wm -f` ≤ 1.5× `fzf` at 100k; popup pre-check < 20 ms p95 |

#### P2 — Weeks

| Task | Done when |
| :--- | :--- |
| Post-reboot **agent resume** (persist pane→agent→session id) | Reboot restores layout and resumes supported agents |
| Sandbox integration for `awt` (container/Lima; study workmux) | Agents run unprivileged by default |
| `pre_merge` gate in `awt ship` (`just check`) | Merge blocked on red |
| Remove/relocate F7 chords (Ghostty 4-mod, stale `alt+shift+enter`, Hypr Alt fallbacks after 30 days unused) | Alt-free repo-wide |
| Rebase/upstream `lazygitrs`; resolve `waymaker`/`acpd` licensing (F8) | Clear licence story |
| Freeze `fm.rs`; evaluate by 4-week action counts | Keep/stop decision recorded |

#### P3 — Research

- Multi-host fleet list (Herdr-style) over Tailscale; mobile approval endpoint (AoE-style).
- Structural diff integration; AI "ask why" in review pane (with the Anthropic caveat: conceptual inquiry, not delegation).
- Publish an honest benchmark methodology (§9.3) before any open-source launch.

---

## 12. Errata for Existing Docs

Apply in the same commit as any behavior change (Living-Documentation rule). Line numbers for `tui-ux-workflow-evaluation-report.md` refer to the file **before** the 2026-10-06 supersession notice was added (add +1).

| File | Current text | Correction |
| :--- | :--- | :--- |
| `terminal-ergonomics-and-ux-manifesto.md` §1.2 (L33–34); `tui-ux-workflow-evaluation-report.md` §3 table "Doherty & Thadani" (L191) | "Doherty Threshold (<100 ms)"; "<400 ms … yields hyper-linear gains" | Doherty & Thadhani 1982: super-linear gains **below ~400 ms**. The **100 ms** instantaneity limit is **Miller 1968 / Card et al. 1991**. |
| `tui-ux-workflow-evaluation-report.md` L173 | "Parnin & DeLine (2010) ACM/IEEE **ICSE**, **16 %** … resumed in 1 min" | **CHI 2010**, "Evaluating cues for resuming interrupted programming tasks"; **~10 %** of sessions resume in < 1 min. |
| same, L158 | "Barke, James & Polikarpova (2023) **ACM CHI**" | **OOPSLA 2023 / PACMPL** (Distinguished Paper). |
| same, L185 + `workflow-keybindings-matrix.md` | Dhakal et al. shows "inward rolls … `CapsLock + G`" faster/lower error | The paper shows **rollover is common among fast typists (40–70 % of keystrokes)**; it does not test Ctrl-chords. `CapsLock+G` is a held chord. |
| same, L161 | Olsen & Goodrich "HRI / IEEE SMC (2003)"; "19 agents" | Venue per memory is PerMIS 2003 (**verify**). Remove the 19-agent extrapolation ([§4.3](#43-amdahls-law-for-flow-and-the-fan-out-correction)). |
| same, L179, L183, L170 | "35 %", "2.5×", "30 %–50 %" | Could not be verified; remove numbers or add the exact table/page from the paper. |
| same, L79–81 | "25°–35° ulnar deviation on Alt chords"; "Marklin 2020" | Unsupported magnitude; cite Keir et al. 2007 thresholds and **measure** the user's actual angles. |
| `terminal-ergonomics-and-ux-manifesto.md` §2.1 | "≈ 15 ms vs ≈ 180–250 ms" | Remove unsourced numbers. |
| manifesto §3 / `popups-ergonomics-and-golden-ratio.md` | "φ … optimal foveal focus (2°–5° cone)" | Replace with spatial-stability / context-preservation rationale ([§8.1](#81-keep--change)). |
| `tui-ux-workflow-evaluation-report.md` L100, L123, L125, manifesto §3.1 ("workmux window bottleneck") | "1 Worktree = 1 Tmux Window" only | workmux has `--session` mode, multi-window sessions, optional sidebar, dashboard, sandboxes, 4 backends ([§5.3](#53-per-tool-verdicts-what-to-steal)). |
| report L101, L115; `workflow-vs-herdr-comparison.md`; `remote-agent-workflow-acpd.md` | Herdr = PTY screen-scraping only; "breaks Neovim navigation"; "32-column sidebar"; "no review loop" | Herdr ships detection manifests **and** per-agent integrations, server/client runtime, reboot restore, multi-machine list, plugins (1,548), socket API. The Neovim/sidebar claims are **unverified**. Repo owner is `herdrdev/herdr`. |
| report §5.2 (L292) ("300 ms"), `docs/README.md` L27 ("400 ms") | Debounce 300/400 ms | Live `idle_debounce_ms = 650`; keep one canonical value (F3). |
| manifesto §4.1, `workflow-keybindings-matrix.md` L10, report L15 | `overload_tap_timeout = 200` | True of the installer; **not of the live `/etc/keyd/default.conf`** until F2 is applied. |
| `zero-friction-file-transfer-benchmark.md` ("220 ms `ptl`") | `ptl` = 220 ms | Excludes argument entry; realistic 2.4–2.95 s vs 4.6 s ([§4.2](#42-klm-goms-recomputation-with-explicit-baselines)). |
| `docs/README.md` index | No entry for this audit | Add entry (done together with this file). |

---

## 13. Sources

Project facts (all fetched 2026-10-05):
- Herdr — <https://herdr.dev>, <https://herdr.dev/compare/>, `herdrdev/herdr` (README, `src/detect`, `src/integration`)
- workmux — <https://github.com/raine/workmux> (README), <https://workmux.raine.dev>
- Agent of Empires — <https://github.com/agent-of-empires/agent-of-empires>
- Age of Agents — <https://github.com/agentsmill/age-of-agents>
- Yazi — <https://github.com/sxyazi/yazi>; superfile — <https://github.com/yorukot/superfile>
- Star/licence/age counts — GitHub REST API (`gh api repos/<owner>/<repo>`)

Literature (grade B unless noted; primary PDFs not opened):
- Miller (1968) *Response time in man-computer conversational transactions*; Card, Robertson & Mackinlay (1991); Doherty & Thadhani (1982) *The Economic Value of Rapid Response Time*, IBM.
- Dhakal, Feit, Kristensson & Oulasvirta (2018) *Observations on Typing from 136 Million Keystrokes*, CHI.
- Keir, Bach, Hudes & Rempel (2007) *Guidelines for wrist posture based on carpal tunnel pressure thresholds*.
- Mark, Gudith & Klocke (2008) *The Cost of Interrupted Work: More Speed and Stress*, CHI.
- Parnin & DeLine (2010) *Evaluating cues for resuming interrupted programming tasks*, CHI.
- Iqbal & Bailey (2008) *Effects of intelligent notification management on users and their tasks*, CHI.
- Barke, James & Polikarpova (2023) *Grounded Copilot*, OOPSLA/PACMPL.
- Scarr, Cockburn, Gutwin & Bunt (2012) *Improving command selection with CommandMaps*, CHI; Grossman, Dragicevic & Balakrishnan (2007), CHI; Lane, Napier, Peres & Sándor (2005).
- Meyer, Fritz, Murphy & Zimmermann (2014) FSE; Meyer et al. (2019/2021) *Today was a Good Day*.
- METR (Jul 2025) developer-productivity RCT and Feb 2026 follow-up note; Anthropic (Jan 2026) *How AI assistance impacts the formation of coding skills*; DORA (2025) *State of AI-assisted Software Development*.
- **Grade C (background, not re-verified):** Card, Moran & Newell KLM operator values; Cowan (2001); Miller (1956); Olsen & Goodrich (2003); Altmann & Trafton (2002); Csikszentmihalyi; Treisman; Hart & Staveland (NASA-TLX); WCAG 1.4.11.

Internal cross-references: [`terminal-ergonomics-and-ux-manifesto.md`](terminal-ergonomics-and-ux-manifesto.md) · [`workflow-keybindings-matrix.md`](workflow-keybindings-matrix.md) · [`zero-friction-file-transfer-benchmark.md`](zero-friction-file-transfer-benchmark.md) · [`remote-agent-workflow-acpd.md`](remote-agent-workflow-acpd.md) · [`../tmux/popup-isolation-and-debounce.md`](../tmux/popup-isolation-and-debounce.md) · [`../tmux/popups-ergonomics-and-golden-ratio.md`](../tmux/popups-ergonomics-and-golden-ratio.md)
