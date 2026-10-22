# Starship Chroma Gradient Presets

Eight Starship presets that port the gradient palettes of the notMyShell **Chroma** treatment
(`src/chroma/treatment.ts`, `PRESET_STOPS`) to the prompt, built with the
[starship-glyph-stacking skill](../../.agents/skills/starship-glyph-stacking/SKILL.md).

Files: `starship/.config/omarchy/starship-presets/chroma-<name>.toml`. Apply them with
`wm -o starship-presets` ([Waymaker presets](../shell/waymaker-presets.md)).

## How the gradient is built

notMyShell colors every character cell separately (`position = column / (width - 1)`) and mixes
neighboring stops in RGB. Starship cannot color a full-width row per cell without a `[custom]`
module, which would fork a process on every prompt (against the sub-100 ms budget), so the presets
build a **stepped gradient** instead:

1. The five segments (`$os`, `$directory`, git, languages, `$time`) are filled with the palette
   sampled at `t = 0, 0.25, 0.5, 0.75, 1`.
2. Each transition is a three-glyph chain that steps through two more samples at one third and two
   thirds of the gap, with the colors handed off from glyph to glyph (`fg` of each glyph = `bg` of
   the previous one). The bar therefore changes color almost every cell, like notMyShell's dividers.
3. All samples are interpolated in **OKLab**, not RGB, so the midpoints between distant hues stay
   clean instead of turning grey-brown (between `#ff5f6d` and `#4fb8f7`, RGB gives `#a78cb2`
   and OKLab gives `#bf97b4`).
4. Text uses dark ink or light paper, whichever contrasts more with the fill. Where neither reaches
   4.5:1, it is corrected to pure black or white (`color_ink_deep`), mirroring notMyShell's
   post-gradient contrast correction.
5. The prompt chevron `❯❯❯` repeats the gradient, starting at the first fill that stays visible
   (>= 3:1) on a dark terminal. Errors switch to a single-hue `✗❯` so they never blend into the
   gradient.

## Presets

| File | Stops | Glyph chain |
|---|---|---|
| `chroma-lavender` | `#a67cf3 #c5a4fa #9979d9` | half circles `U+E0B4` x3 (pearls) |
| `chroma-aurora` | `#3ee8b5 #45b8f0 #8f6cf5 #e46cc8` | thick flames `U+E0C0` x3 (curtain folds) |
| `chroma-rainbow` | `#ff5f6d #ffa647 #f2e35b #5be584 #4fb8f7 #9575f0` | slants `U+E0BC` x3 (prism bands) |
| `chroma-nebula` | `#7b2fbf #c2389e #5a4ff0 #3fc2f0` | big squares x2, small squares (gas thinning to dust) |
| `chroma-blackhole` | `#3d1f6e #7a2a8c #e0566b #ffb36b` | disc, flame, small squares (horizon to accretion rim) |
| `chroma-warm` | `#e8573c #f29e4c #f1c453 #d9486b` | shades `▓ ▒ ░` (heat shimmer) |
| `chroma-cool` | `#2ec4b6 #3a86ff #5e60ce #48bfe3` | ice waveforms `U+E0C8` x3 (frost) |
| `chroma-monochrome` | `#6a6e78 #d4d7dd #f4f5f7 #9a9ea8` | vertical eighths `▊ ▌ ▎` (staircase wipe) |

The files carry the `# glyph-stacking: gradient` marker, which tells the skill's validator not to
flag the deliberately small contrast between neighboring gradient steps. Text contrast is still
checked.

## Regenerating colors

```sh
python3 .agents/skills/starship-glyph-stacking/scripts/gradient.py 5 '#3ee8b5' '#45b8f0' '#8f6cf5' '#e46cc8'
python3 .agents/skills/starship-glyph-stacking/scripts/validate.py starship/.config/omarchy/starship-presets/chroma-aurora.toml
```

## Not included

- A full-width gradient divider above the prompt. It could be drawn by a zsh `precmd` that reads
  `$COLUMNS` and computes the colors in pure zsh without forking, but it lives outside the presets
  and is not implemented.
- notMyShell's reversed, center-out, and outside-in layouts. Only the linear direction is ported.
