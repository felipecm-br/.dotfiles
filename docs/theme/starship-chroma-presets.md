# Starship Chroma Gradient Presets

Starship presets that port the gradient palettes of the notMyShell **Chroma** treatment
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

### Extended set

These go beyond notMyShell's stops, and each one introduces a different gradient technique.

| File | Technique | Glyph chain |
|---|---|---|
| `chroma-chrome` | 1980s chrome lettering: the sky reflection steps in OKLab, then **snaps** at the horizon to a white glint and dark earth | slants `U+E0BC`, specular star `U+2736` |
| `chroma-holographic` | Pastel iridescent foil that **fades in and out of the terminal** | shades `▓ ▒ ░` |
| `chroma-isoluminant` | Hue sweep from 20 to 320 at **constant OKLCH lightness** (L 0.78, C 0.13), interpolating the hue angle, so text contrast is the same in every segment | honeycomb `U+E0CC` |
| `chroma-dither-sunset` | **No in-between colors**: a Braille dither ramp of one segment over the next, mixed by the eye (ordered dither) | `⣿ ⡷ ⡵ ⠕ ⠂` |
| `chroma-neon-tube` | **Inverted**: the gradient is carried by the text and the tube caps, on glass tinted 16% toward each gas color | thin caps `U+E0B5` / `U+E0B7` |
| `chroma-mesh` | **2D mesh gradient**: upper half blocks with `fg` on a top track and `bg` on a different bottom track; segment fills are the midpoint of the two tracks | `▀` x4 |
| `chroma-thermal` | Inferno colormap starting at t 0.18, so the coldest fill still shows on a dark terminal | pixel squares `U+E0C6 U+E0C6 U+E0C4` |
| `chroma-oil-slick` | Thin-film interference cycle: violet, blue, teal, gold, magenta, back to violet | ice waveforms `U+E0C8` |
| `chroma-supernova` | notMyShell's **center-out** layout: the gradient starts at the git segment (white-hot core) and runs to both ends; flames point away from the core on each side | mirrored flames `U+E0C2` left, flames `U+E0C0` right |
| `chroma-wormhole` | notMyShell's **outside-in** layout: bright mouths at both ends, a dark throat in the middle, arrows converging inward | `U+E0B0` left, `U+E0B2` right |
| `chroma-liquid-fill` | **Vertical wipe**: the next color rises from the bottom of the cells like liquid; the bar fills from the terminal and drains at the end | eighths `▁▂▃▄▅▆▇` |
| `chroma-halftone` | **Print halftone**: no mixed inks, only dot size; the next ink's dots grow, then the current ink's dots shrink (Ben-Day dots) | `· ∙ • ●` and back |
| `chroma-prism` | White light hits a glass prism (a peak) and **disperses** into an OKLCH spectrum at constant lightness, fading into ultraviolet | peak `U+E0BA U+E0B8`, slants `U+E0BC` |
| `chroma-opal` | **Play-of-color**: a milky pale body gradient with a saturated fleck in every cell, colors rotating from gap to gap | quadrants `▗ ▘ ▝ ▖` |
| `chroma-bokeh` | Dusk gradient with **out-of-focus light discs** of three sizes over each step; a few orbs drift off onto the terminal | `● ∙ •` |
| `chroma-conic` | **Closed loop**: one full turn of the OKLCH hue wheel, so the last segment matches the first | pearls `U+E0B4` |
| `chroma-lava-lamp` | **Two-way exchange**: a blob of the next layer's wax (an OKLab mix 62% of the way) has risen into the current segment and a blob of the current wax (30%) into the next; the hottest blob detaches and drifts off the end | pills `U+E0B6 U+E0B4`, round cap |
| `chroma-risograph` | **Subtractive, not interpolated**: three riso inks, with the in-between segments computed as their multiply overprints; seams are misregistered, alternating a sliver of bare paper and a darker double hit | upper-left wedges `U+E0BC` x2 |
| `chroma-mobius` | **Two-faced ribbon**: a warm front gradient and a cool back gradient; every seam shades, pinches through the terminal and reopens on the other face | `U+E0BC`, bowtie `U+E0B0 U+E0B2`, `U+E0BE` |
| `chroma-long-shadow` | **Flat-design long shadow** instead of a divider: each tile casts a shadow that falls away and fades (OKLab steps from the next tile's shade) | eighths `▇ ▆ ▄ ▂` |
| `chroma-kelvin` | **Physical colors only**: every cell is a blackbody color (Tanner Helland's fit), 1300 K candle to 12000 K sky, evenly spaced in mireds | full-block swatches `█` x3 |

The files carry the `# glyph-stacking: gradient` marker, which tells the skill's validator not to
flag the deliberately small contrast between neighboring gradient steps. Text contrast is still
checked.

## Regenerating colors

```sh
python3 .agents/skills/starship-glyph-stacking/scripts/gradient.py 5 '#3ee8b5' '#45b8f0' '#8f6cf5' '#e46cc8'
python3 .agents/skills/starship-glyph-stacking/scripts/validate.py starship/.config/omarchy/starship-presets/chroma-aurora.toml
```

### Full-width set (`$fill` bands)

These span the whole terminal row at any width with no fork. Starship splits a line evenly between
every `$fill` module, and a `[fill]` styled `fg:prev_fg` / `bg:prev_bg` inherits the color of the
glyph printed just before it. Each band is therefore one seed glyph followed by a `$fill`, which
stretches the seed's color across its share of the width; a few interpolated seam cells join the
bands. Starship rounds each share down, so up to (number of fills - 1) cells can stay empty at the
right edge. The presets use five or six fills to keep that gap at a few cells.

| File | Technique | Glyphs |
|---|---|---|
| `chroma-divider` | Port of notMyShell's `paintDivider`: a full-width rule in six OKLab bands, with the directory and clock set into it like a section title; the second line is text only, tinted per module | heavy rule `━` |
| `chroma-horizon` | Panoramic sunset: every cell is an upper half block with the sky as `fg` and the sea reflection as `bg`; center-out across the width, with the sun in the middle and sun glitter on the water | `▀` |
| `chroma-full-bleed` | The status bar fills the row: modules on the left, then the gradient keeps going as background bands through the empty middle to the clock at the right edge | spaces with `bg:prev_bg` |

### Width-scaling scenes (`$fill` grid)

Multi-row panoramas that stretch with the terminal. Every scene row has the same number of
columns, and each column is one joint cell followed by a `$fill` (a space styled `bg:prev_bg`).
Because each `$fill` is preceded by the same number of fixed cells in every row, the fills get the
same share of the width and the columns line up vertically at any terminal size. A joint is either
a plain cell (a vertical edge) or a wedge drawn with `fg` = the previous column and `bg` = the new
one (`U+E0BC`, `U+E0B8`, `U+E0BA`, `U+E0BE`), which draws a slope. `$fill` can only make flat
tops, so the subjects are chosen to have them.

| File | Scene | Glyphs |
|---|---|---|
| `chroma-monument-valley` | The Mittens at sunset: two buttes on sheer walls above talus and hazy far mesas, sun setting in the west (left), sandstone lit on the west faces | flat seams, wedges `U+E0BC` / `U+E0B8` |
| `chroma-aurora-panorama` | Aurora curtains of different lengths hanging from the top (nitrogen violet, oxygen green, bright fringe) with a shimmering hue, over a black ridge; the near-black sky hides the rounding gap at the right edge | hanging wedges `U+E0BA` / `U+E0BE`, ridge `U+E0BC` / `U+E0B8` |

## Not included

- notMyShell's reversed layout. Linear, center-out (`chroma-supernova`), and outside-in
  (`chroma-wormhole`) are ported.
