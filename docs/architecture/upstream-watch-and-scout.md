# Upstream Watch & GitHub Scout

How the AI workflow keeps up with the tools it runs, the fork it carries, the competitors it is benchmarked against, and new projects on GitHub. It complements [`ai-update`](../utils.md), which installs upgrades. These tools say what changed and whether it is worth adopting.

## Design: scripts gather, agents decide

| Layer | What | Why this split |
| :--- | :--- | :--- |
| **Manifest** | `utils/.config/ai-upstream/sources.toml`: every source with its `kind` (`dependency`, `fork`, `reference`, `own`), the project it `feeds` (`waymux`, `waymaker`, `lazygitrs`, `workflow`), the `area` it can improve, its own extra `keywords`, the keywords that flag a release-note line, and the `[scout]` queries | One list both tools read; scout excludes everything already in it |
| **Gathering** | [`ai-upstream`](../../utils/.local/bin/ai-upstream) (`watch` and `scout`; `ai-scout` is a link to it): `gh api`, `git`, and a scrape of github.com/trending | Deterministic, no tokens, a few seconds; safe to run from a timer or by hand |
| **Judgment** | Skills [`ai-upstream-watch`](../../.agents/skills/ai-upstream-watch/SKILL.md) and [`ai-scout`](../../.agents/skills/ai-scout/SKILL.md) | Reading release notes and READMEs against the manifesto and the scorecard needs a model; skills work in Claude Code, Codex and Antigravity alike |
| **State** | `$XDG_STATE_HOME/ai-upstream/state.json`: last `--ack` per source, seen and dismissed repositories | The next run shows only what is new since you last triaged |

## `ai-upstream watch`

| Kind | What it reports | Adoption mode |
| :--- | :--- | :--- |
| `dependency` | Releases newer than the installed version (`version_cmd`, or `cargo_lock` + `crate` for libraries our binaries build with), prereleases, moving tags and other tag prefixes skipped, with the note lines that match the keywords | Upgrade with `ai-update`, then adopt the new options in the owning package |
| `fork` | Upstream commits not yet in the fork branch, compared by patch id (`git log --cherry-pick`); commits whose subject the fork already has (ignoring upstream's ` (#NN)` suffix) are counted as already applied, since a rebased copy changes the patch id. The upstream comes from the `upstream` remote or, with `upstream_url`, is fetched into `refs/ai-upstream/*` without adding a remote. Each one gets a dry run (`git merge-tree --merge-base=<sha>^`, the working tree is untouched) and a list of the files the fork also changed | Cherry-pick with `-x` in an awt worktree |
| `reference` | Releases, plus `feat` / `fix` / `perf` commits since the last `--ack`, with keyword matches (★) sorted first. `commits = false` keeps very busy repositories to releases; `notes_url` reads the headings of a release-notes page when the release body is only a link (VS Code) | Set by the live license: permissive means you may port code and keep the notice; copyleft means reimplement from the behavior; no license means idea only |

```sh
ai-upstream                         # everything, since each source's last --ack (else 14 days)
ai-upstream --kind fork --no-fetch  # fork only, without fetching
ai-upstream --only fut,tuios --since 2026-11-01
ai-upstream --for waymaker --since 30d  # matchmaker fork + television, zoxide, mcat, sesh, yazi, fzf + crates
ai-upstream --json                  # for the skill
ai-upstream --ack                   # after triage: remember this run
```

Limits: the fork dry run tests each commit on its own, so a series of dependent commits can show CONFLICT one by one but apply cleanly in order. PRs from the fork that upstream squash-merged show as not applied.

### What each project watches

| Project | Fork upstream | References | Dependencies |
| :--- | :--- | :--- | :--- |
| `waymux` | — | workmux, tmux-agent-usage, TUIOS, herdr, herdr-core, Orca, T3 Code, VS Code (release notes), agent-deck, Alethe, fut, agtx, Sheprd, Kander | — |
| `waymaker` | matchmaker (AGPL-3.0, like waymaker) | television, zoxide, mcat, sesh, yazi, fzf | nucleo, ratatui, redb (from waymaker's `Cargo.lock`) |
| `lazygitrs` | Blankeos/lazygitrs | lazygit, git-graph, keifu, serie, lumen, gitui, delta, GitLens (ideas only) | worktrunk |
| `workflow` | — | — | Claude Code, Codex, opencode, tmux, ai-memory, ai-jail, ai-usagebar |

## `ai-upstream scout` / `ai-scout`

It searches GitHub with the manifest queries (repositories created in the last `days`, at least `min_stars`) and scrapes the weekly trending pages (all, Rust, Go). It drops archived repositories, forks, manifest sources, and dismissed or already seen ones. Then it ranks what is left in two tables:

- **New repositories:** relevance words matched (minus penalties such as `electron` or `macos only`) times `log(1 + stars per day)`.
- **Trending:** any age, at least two relevance words.

```sh
ai-scout                                    # both tables
ai-scout --days 90 --min-stars 20 --limit 40
ai-scout --track OWNER/REPO --area "P9"     # add it to the manifest as a reference
ai-scout --dismiss OWNER/REPO --reason "course"
ai-scout --ack                              # mark the shown ones as seen
```

GitHub search allows 30 queries a minute. Scout checks the quota first, waits for it if needed, and warns when a search still fails.

## Running it on a schedule

Both commands only read (except `--ack`, `--dismiss` and `--track`), so a weekly run is safe. A plain `ai-upstream > report.md` from a user timer collects the data. The triage needs an agent: start a session, or schedule one, with "use the ai-upstream-watch skill" or "use the ai-scout skill".

## Where the results go

Re-scores, radar rows, deep dives and roadmap items go into the [SOTA benchmark](state-of-the-art-terminal-agent-workflow.md). Adopted options and ports go into the owning package's doc and [the changelog](../CHANGELOG.md).

## Triaged Backlog (4 Nov 2026)

Items gathered by `ai-upstream` across all four projects (`waymux`, `waymaker`, `lazygitrs`, `workflow`) and queued for implementation.

### Ready to adopt, port, or upgrade

| # | Source → project | What | Verdict · license | Effort | Done when |
| :---: | :--- | :--- | :--- | :---: | :--- |
| **U1** | `workmux` 0.1.278 → `waymux` / `codex` | Start Codex with `--no-daemon` from `ai-launch` so hooks run with the session's own `TMUX_PANE` instead of the shared app-server's (fixes the wrong-pane bug at the root and avoids the `clamping Interrupt hook timeout` warning that caused `herdr` to drop Codex hooks; keep `codex-hook` as fallback) | **Adopt** · MIT | S | Two Codex panes in one directory report to their own panes with `--no-daemon`, and P8 passes on a live session |
| **U2** | `herdr-core` → `waymux` | Hold a pane's queued message delivery while the user has an unsent prompt draft in that pane | **Port** · Apache-2.0 | M | A queued message waits while the target pane has an active draft and flushes once the draft clears (`cargo test`) |
| **U3** | `yazi` / `mcat` → `waymaker` | Run the terminal-image protocol probe early with a short timeout instead of blocking the first frame | **Port** · MIT | M | Image-capable presets keep previews without the ~110 ms first-frame cost |
| **U4** | `matchmaker` → `waymaker` | Port upstream fixes from `refs/ai-upstream/main`: fewer idle CPU wakeups, preview ANSI resets no longer clearing pane backgrounds (protects transparent `bg = "reset"` popups), HScroll panic fix, and `results.delay_clear` (no blank flash on reload) | **Port** · AGPL-3.0 | M | Picked or reimplemented in `waymaker` with `cargo test` passing and no background flash in transparent popups |
| **U5** | `sesh` 2.33 → `waymaker` | Escape `#` in `wm session` names and start directories so tmux does not expand `#` as a format string (`.` is already handled) | **Port** · MIT | S | A session or directory containing `#` opens without tmux format expansion |
| **U6** | `lazygit` 0.66.2 → `lazygitrs` | Exit cleanly when the active worktree is deleted underneath it (for example `awt` removing a worktree while the popup is open) and speed up rendering on very long diffs; also review upstream `Blankeos/lazygitrs` `#33` | **Port** · MIT | S–M | Removing the active worktree exits `lazygitrs` with code 0 instead of panicking or looping |
| **U7** | `ratatui` 0.30.0 → 0.30.2 → `waymaker`, `waymux`, `lazygitrs` | Patch upgrade across the three Rust TUIs | **Upgrade** · MIT | S | `cargo update -p ratatui` and `cargo test` pass in each repository |
| **U8** | `fzf` 0.74.3 → 0.74.5 → `workflow` | Two upstream security fixes (`fzf-tab` loads `fzf`) | **Upgrade** · MIT | S | `fzf --version` reports `≥ 0.74.5` |
| **U9** | `worktrunk` 0.68 → 0.81 → `lazygitrs` / `awt` | `wt merge --branch`, prompting hooks, faster worktree removal (the 0.78 / 0.81 breaking renames do not affect `awt` or our config, which only uses `{{ repo_path }}`) | **Upgrade** · MIT | S | `wt --version` reports `≥ 0.81` and `tests/awt_*.test.sh` pass |

### Watched, deferred, or rejected

- **Watch (`fut` 0.41 → `waymux`):** OSC 7501 Program Status Protocol rev 0.4 as a hookless state source (needs tmux passthrough or a pane-output reader in `waymux`), plus forwarding the status rollup to the outer terminal tab ([SOTA §2.4](state-of-the-art-terminal-agent-workflow.md#24-fut-mikkerfut-deep-dive)).
- **Watch (`VS Code` 1.144 / 1.145 → `waymux`):** Agent Host Protocol v1.0 and harness comparison.
- **Watch (`Kander` → `waymux`):** Independent reviewer agent as a delivery gate before `awt ship` ([SOTA §2.2](state-of-the-art-terminal-agent-workflow.md#22-2026-entrants-radar-not-scored)).
- **Defer (`redb` 2.6 → 4.4 → `waymaker`):** Two major versions behind with a database format change; defer until `waymaker`'s frecency store needs a migration.
- **Reject (`Blankeos/lazygitrs` `#41`):** Upstream removes the `Ctrl+G` HEAD toggle that this stack's Dual-Diff review loop relies on. Nine of the other twelve upstream commits are already in the fork under the same subject (including `#34` and `#35` once matching ignores the ` (#NN)` suffix).
