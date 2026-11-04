---
name: ai-scout
description: "Scout GitHub for new and trending repositories that could improve the terminal AI-agent workflow: agent multiplexers, worktree and session managers, agent HUDs, review loops, agent-to-agent messaging, sandboxes, Claude Code and Codex hooks, fuzzy pickers and git TUIs. Classify each one as a new scored competitor, a radar entry, an idea to absorb, or noise. Use when asked to search GitHub, look at trending or new repositories, find similar tools or new competitors, or look for ways to improve the AI workflow. Triggers: trending, github search, new repos, similar projects, competitors, radar, scout, ideas for the workflow, ai-scout."
---

# AI Scout

`ai-scout` (the same as `ai-upstream scout`) finds candidates without spending tokens. Your job is to read the strongest ones and decide. Queries, relevance words and thresholds live in the `[scout]` table of `~/.config/ai-upstream/sources.toml`. Everything listed there as a source is excluded from the results. Design notes: [docs/architecture/upstream-watch-and-scout.md](../../../docs/architecture/upstream-watch-and-scout.md).

## 1. Gather

```sh
ai-scout                              # new repositories (last 45 days, ≥40★) + relevant trending ones
ai-scout --days 90 --min-stars 20     # wider net
ai-scout --json > "$SCRATCH/scout.json"
```

GitHub search allows 30 queries a minute. The script waits for the quota and warns when a search fails, so treat a warning as an incomplete result. Trending pages are scraped best effort.

## 2. Read before judging

For the top 8–10 in each table, and anything whose description names a scored dimension:

```sh
gh api repos/OWNER/REPO/readme --jq .content | base64 -d | head -150
gh api repos/OWNER/REPO --jq '{license: .license.spdx_id, pushed_at, open_issues_count, topics}'
gh api "repos/OWNER/REPO/commits?per_page=10" --jq '.[].commit.message | split("\n")[0]'
```

Look at the platform (this host is aarch64 Linux), whether there is a keyboard path, whether it is maintained, and the license.

## 3. Classify

| Class | When | Action |
| :--- | :--- | :--- |
| **Score** | It is a direct competitor (agent orchestration in or around the terminal), runs on Linux, is active, and has enough docs to score all ten dimensions | Add a column to the SOTA scorecard and matrix (§1, §2), a deep dive like §2.4, and `ai-scout --track OWNER/REPO --area "<dimension>"` |
| **Radar** | Relevant, but macOS-only, GUI-first, early, or a client of something already scored | One row in the SOTA radar (§2.2) with the reason it is not scored; `--track` it if it may grow into a Score |
| **Absorb** | One mechanism worth having (for example agent-to-agent messaging for P9, a quota HUD, a reviewer gate) | A roadmap item in §8 of the SOTA doc, or an Emerging Capabilities row, with the source linked and its license named |
| **Noise** | Courses, prompt packs, SEO skills, wrappers with nothing new, or inactive | `ai-scout --dismiss OWNER/REPO --reason "<why>"` |

Weigh ideas against the [manifesto](../../../docs/architecture/terminal-ergonomics-and-ux-manifesto.md) the same way the [ai-upstream-watch](../ai-upstream-watch/SKILL.md) skill does: fit, zero churn, cost, license, verifiable.

## 4. Report and close

- Report one table (repository, class, why, what it would improve), then the doc edits you made or propose. Ask before editing docs when the user only asked for a search.
- After the report: `ai-scout --ack` marks the shown repositories as seen, so the next run lists only new ones (`--all` shows them again).
- Run `./scripts/docs-lint.sh` after editing the SOTA doc.
