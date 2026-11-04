---
name: ai-upstream-watch
description: "Check what changed upstream of the AI workflow and decide what to adopt. Covers the tools it runs (Claude Code, Codex, opencode, tmux, ai-memory, ai-jail, worktrunk, ratatui, nucleo), the lazygitrs fork, and the SOTA benchmark competitors (TUIOS, Orca, workmux, herdr, agent-deck, T3 Code, Alethe, fut and others). For each new release, fix or feature, decide whether to upgrade, cherry-pick, port, keep the idea for the roadmap, re-score, or ignore. Use when asked to check dependency or reference updates, new upstream features or fixes, what competitors shipped, whether something can be cherry-picked or attached to the workflow, or to refresh the SOTA benchmark. Triggers: upstream, dependency updates, new release, changelog, cherry-pick, port a feature, competitor update, re-audit, ai-upstream."
---

# AI Upstream Watch

`ai-upstream` gathers the changes and `ai-update` installs upgrades. Your job is the decision in between. The design notes are in [docs/architecture/upstream-watch-and-scout.md](../../../docs/architecture/upstream-watch-and-scout.md), and the sources are in `~/.config/ai-upstream/sources.toml` (repository file `utils/.config/ai-upstream/sources.toml`).

## 1. Gather

```sh
ai-upstream --json > "$SCRATCH/upstream.json"   # all kinds, since each source's last --ack (else 14 days)
ai-upstream --kind fork                           # forks (waymaker, lazygitrs): upstream commits not yet in, with dry runs
ai-upstream --for waymaker --since 30d            # one project: waymux, waymaker, lazygitrs, workflow
ai-upstream --only codex,claude-code --since 30d  # narrow it down
```

Read the Markdown version for an overview and the JSON for details. Do not pass `--ack` yet.

## 2. Triage every item into one verdict

| Verdict | When | Action |
| :--- | :--- | :--- |
| **Upgrade** | A dependency is behind and the release fixes a bug or security issue you hit, or unlocks a verdict below | `ai-update --only <comp>`; note any breaking change from the release notes |
| **Adopt option** | A dependency added a flag, hook, setting or API the workflow can use (for example a new Claude Code hook event, a statusline field, a Codex config key) | Implement it in the owning package (`claude/`, `codex/`, `utils/`, `tmux/`, or the `waymux` repo) |
| **Cherry-pick** | A fork commit is `clean`, or conflicts only in files the fork changed for unrelated reasons | Use an awt worktree (below). Never pick in the primary worktree |
| **Port** | A reference shipped something that closes a scored gap (§8.1 of the SOTA doc) or an Emerging Capabilities row, and its license allows it (`adoption` field) | Implement it in `waymux` or the dotfiles; copy code only when the license is permissive, keep the notice, and name the source in the commit |
| **Idea** | Worth having, but it needs design, or the license is copyleft or missing | Add it to §8 of the SOTA doc as a roadmap item with a "Done when" check |
| **Re-score** | A competitor release changes one of its weighted dimensions | Update §1 and §2 of [the SOTA doc](../../../docs/architecture/state-of-the-art-terminal-agent-workflow.md): the scorecard, a "What moved on <date>" list, the matrix, the sources line, and the ledger |
| **Ignore** | Maintenance, other platforms, GUI-only, or against the manifesto | Nothing |

What to check before giving any verdict except Ignore:

- **Fit:** it improves a scored dimension, or the `area` the manifest names for that source.
- **Zero churn:** it rebinds no consolidated key and needs no `Alt` chord or mouse ([manifesto](../../../docs/architecture/terminal-ergonomics-and-ux-manifesto.md)).
- **Cost:** it does not add a daemon, a polling loop, or latency on a popup path (the budget is under 100 ms, see §5).
- **License:** follow the `adoption` field. `no license` and copyleft licenses mean you reimplement from the documented behavior and copy no code.
- **Verifiable:** you can write a check for it in `tests/` or a `cargo test`. If you cannot, it is an Idea.

## 3. Report before changing code

Present one table per kind: item, verdict, why, and effort (S, M or L). Then ask which Upgrade, Adopt, Cherry-pick and Port items to carry out. Re-score and Idea items are doc-only, so you may apply them directly when the user asked for an audit.

## 4. Cherry-picking from a fork (lazygitrs, waymaker)

waymaker has diverged a long way from matchmaker (hundreds of commits), so nearly every pick conflicts. There, treat a commit as a **Port**: read its diff (`git show <sha>` in `~/dev/github/waymaker/main`; the upstream is at `refs/ai-upstream/main`) and apply the idea to waymaker's own code. Both projects are AGPL-3.0, so copying code is fine.

```sh
cd ~/dev/github/lazygitrs/main          # fork mainline: branch `main` (fcmiranda/lazygitrs)
git fetch upstream
git worktree add ../pick-$(date +%m%d) -b pick/$(date +%m%d) main
cd ../pick-$(date +%m%d) && git cherry-pick -x <sha> [<sha>...]   # -x records the origin
cargo test && cargo clippy -- -D warnings
```

- Each dry run tests one commit on its own, so a run of commits that depend on each other can show CONFLICT one by one but apply cleanly in order. Try them in date order.
- Upstream squash-merges PRs that started in this fork (#33 and #34, for example). They show as not applied because their patch-ids differ. Compare with `git range-diff` or look the PR number up in the fork log, and skip them when the fork already has the change.
- When the work is done, fast-forward `main`, rebuild the installed binary, and remove the worktree.

## 5. Close the loop

- Docs: the SOTA doc for re-scores and ideas; the owning doc and `docs/CHANGELOG.md` for adopted options and ports, following the Living Documentation rules in `CLAUDE.md`.
- Manifest: add a dependency the workflow now uses, or drop one it no longer uses.
- When the triage is written down: `ai-upstream --ack` (or `--only <names> --ack`), so the next run starts from now.
