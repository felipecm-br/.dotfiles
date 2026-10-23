# Prompt Art (zsh)

Three opt-in zsh modules that go past what a Starship TOML can do on its own: they react to
history, the clock, and the repository. They live in the `starship` package at
`starship/.zsh/prompt-art/` (stowed to `~/.zsh/prompt-art/`) and are **not sourced by default**;
nothing in `init.zsh` loads them.

| Module | Effect | Mechanism |
|---|---|---|
| `gradient-trail.zsh` | Each collapsed prompt in the scrollback is a `❯` colored by its position in a 24-stop OKLab gradient (ping-pong), so history reads as a ribbon. A failed command leaves a crimson `▍✗ <code>` mark under its output. Empty Enter draws a dim `❯` without advancing | Defines `TRANSIENT_PROMPT_PRETRANSIENT`, the hook zsh-transient-prompt calls before it swaps in the transient prompt. Pure zsh, no forks |
| `sky-clock.zsh` | The active preset's palette follows the hour: night (moonlit blue, muted), dawn (rose), morning (untouched), noon (most vivid), golden (amber), dusk (violet) | Picks a band with the `strftime` builtin and points `STARSHIP_CONFIG` at a cached recolored variant |
| `repo-hue.zsh` | Each repo gets a fixed hue rotation of the active palette (24 steps of 15 degrees), from an FNV-1a hash of the repo. All worktrees of one repo share it. Pin a hue with `PROMPT_ART_REPO_HUES` | Finds the repo with builtin file tests (worktrees resolve to their common git dir) and selects a cached variant |

`sky-clock` and `repo-hue` share `lib.zsh`. Before each prompt the resolvers run in order and the
first match wins, so with both loaded a repo keeps its own hue and the sky tints everything
outside repos.

## Recoloring

`prompt-palette-transform` (in `starship/.config/omarchy/bin/`) writes the variants to
`~/.cache/prompt-art/`. It works on any preset because it only rewrites `#rrggbb` values inside
`[palettes.*]` tables, in OKLCh:

- Lightness is kept, so text contrast on the fills holds. Chroma is reduced until the color fits in sRGB.
- Keys matching `error`, `paper`, `ink` or `text` are left alone, so an error color never drifts.
- Inline colors outside the palette tables are not changed.

It runs (python, one fork) only when a variant is missing or older than the base config, for example
right after picking a new preset in `omarchy-starship-preset`. Otherwise, the per-prompt cost is a
few builtin file tests.

## Enabling

New files in the package need a restow first: `./stow.sh -r starship`. Then source the modules you
want at the end of `~/.zshrc`:

```zsh
source ~/.zsh/prompt-art/gradient-trail.zsh
source ~/.zsh/prompt-art/repo-hue.zsh
source ~/.zsh/prompt-art/sky-clock.zsh
```

Settings go before the `source` lines:

| Variable | Module | Default |
|---|---|---|
| `PROMPT_ART_TRAIL_GLYPH` | gradient-trail | `❯` |
| `PROMPT_ART_TRAIL_FAIL` | gradient-trail | `1` (`0` hides the failure mark) |
| `PROMPT_ART_TRAIL_COLORS` | gradient-trail | the 24 OKLab stops |
| `PROMPT_ART_SKY_BANDS` | sky-clock | `0:night 5:dawn 8:morning 11:noon 15:golden 18:dusk 21:night` |
| `PROMPT_ART_REPO_HUES` | repo-hue | empty assoc, e.g. `(dotfiles 0 waymux 200)` |
| `PROMPT_ART_CACHE` | lib | `${XDG_CACHE_HOME:-~/.cache}/prompt-art` |

`prompt-art status` shows the base and active configs, `prompt-art off` restores the base config for
the current shell, and `prompt-art clear-cache` removes the variants.

For the presets themselves, see [Starship Chroma Gradient Presets](starship-chroma-presets.md).
