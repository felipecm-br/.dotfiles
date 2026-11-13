# gc & sgc — AI commits

> Implemented natively in [lazygitrs](https://github.com/felipecm-br/lazygitrs) (`lazygitrs gc`, `lazygitrs sgc`, and `M` in its Files panel).
> `git/.zsh/packages/git.zsh` only keeps thin wrappers. No Python, `gum` or temp scripts.

| | `gc` | `sgc` |
|---|---|---|
| Input | staged changes (wrapper stages all unless `-s`) | every staged, unstaged and untracked change |
| Output | one Conventional Commit (title + bulleted body) | N atomic commits, reviewed before committing |
| Review | message pre-filled as `git commit -m …` in the prompt | TUI popup: toggle, edit, reorder, merge, per-group diff |
| Cache | — | plan cached by content hash; leftovers survive partial commits |

## gc

```zsh
gc                 # stage all, generate, pre-fill `git commit -m "…"` for review
gc -s              # only what is already staged
gc -o              # print the message only
gc -g 3            # 3 candidates, numbered picker
gc -e -l pt        # gitmoji, Portuguese
gc -P claude -m haiku   # pin agent / model (also -p, GC_PROVIDER, GC_MODEL)
gc -t              # title line only
gc -n              # silent when nothing is staged
gc -d              # print prompt and raw AI output
gc hook install    # prepare-commit-msg: bare `git commit` opens with an AI message
gc hook status | uninstall   # uninstall also removes the old zsh hook block
```

Raw binary: `lazygitrs gc [-a] [-c]` prints the message (`-a` stages all, `-c` commits it).

## sgc

```zsh
sgc                # open the review popup (TUI)
sgc -y             # commit the whole plan, no review
sgc -n / --json    # print the plan only
sgc -g fine        # granularity: coarse | medium (default) | fine
sgc -f             # ignore the cached plan
sgc -e -l pt -H "scope everything under tui"
sgc -P claude -m haiku -d
```

Review keys: `space` toggle · `a` all · `e` edit (ctrl-s save) · `J`/`K` reorder · `m` merge with next ·
`g` cycle granularity · `r` regenerate · `pgup`/`pgdn` scroll diff · `enter` commit · `esc` close (plan kept).

## How it works

1. **Context**: `git status` + `git diff HEAD` + untracked contents. Diffs are compressed (metadata stripped,
   one context line per run, hunks capped at 80 changed lines) and fitted to a 48 KB budget by collapsing the
   largest files to a `+A/-D` summary.
2. **`.sgcignore`** (built-ins `*-lock.*`, `*.lock`, `go.sum`, `*.min.js`, `*.min.css`, `*.map`, then
   `~/.sgcignore`, then the repo's; gitignore syntax incl. `!`, `/anchored`, `dir/`): matching files stay in the
   plan and get committed with the change that produced them — only their content is hidden from the model.
3. **commitlint** (`.commitlintrc*`, `commitlint.config.{js,cjs,mjs,ts}`, `package.json`): allowed types and
   scopes, header length, subject/scope case go into the prompt and into title validation.
4. **Repair**: unknown paths dropped, directories expanded, duplicates removed, bodies wrapped at 72 columns.
   Unassigned files or invalid titles trigger a corrective retry (3 attempts); anything still unassigned lands
   in a flagged `chore` group.
5. **Commit**: `git commit --only -- <files>` per group, so anything else you staged is untouched; rename
   sources travel with their destination.

## AI command

lazygitrs runs `git.commit.smartCommitCommand` (falls back to `generateCommand`, here `ai-commit-msg`) with the
full prompt on stdin and `LAZYGITRS_AI_COMMIT_INPUT=prompt`; `-P`/`-m` arrive as `LAZYGITRS_AI_PROVIDER` /
`LAZYGITRS_AI_MODEL`. `ai-commit-msg` (`utils/.local/bin/`) tries `claude` haiku → `agy` flash → `opencode`.

```yml
# ~/.config/lazygitrs/config.yml
git:
  commit:
    generateCommand: "ai-commit-msg"
    smartCommitGranularity: medium
```

## gtest

Unchanged: runs the project's tests and amends HEAD with a `Test-Status` trailer (see `git.zsh`).
