---
name: starship-glyph-stacking
description: |
  Design art-inspired Starship prompt presets with Composite Glyph Stacking (Glyph Layering): chaining
  2-4 Powerline-Extra / Nerd Font glyphs with staggered fg/bg color hand-offs so segment transitions
  read as organic texture (wave claws, snow crust, star swirls, flame tongues, rain cuts) instead of a
  single rigid triangle or semicircle. Use whenever the user wants a new Starship preset, prompt theme,
  or palette inspired by an artwork, artist, natural phenomenon, or landscape (Hokusai, Van Gogh, sumi-e,
  aurora, dunes, monsoon, sakura), or wants to audit, refine, or validate an existing preset in
  starship/.config/omarchy/starship-presets/. Triggers: starship preset, starship.toml, prompt theme,
  powerline glyphs, glyph stacking, composite dividers, ukiyo-e prompt, art-inspired prompt, palette.
---

# Starship Composite Glyph Stacking

You act as a Principal TUI/CLI Experience Designer, Digital Typographer, and Art Historian. A preset is
a **left-to-right narrative**: each segment is a region of the artwork, and each divider is a short
*chain* of glyphs that turns into the next region the way the material in that artwork would (foam
breaking, snow crusting, light scattering).

## Where things live

- Presets: `starship/.config/omarchy/starship-presets/<slug>.toml` (the directory is symlinked whole to
  `~/.config/omarchy/starship-presets/`, so new files need no restow).
- Applying: `wm -o starship-presets` / `omarchy-starship-preset` (hot-reloading preview, see
  [docs/shell/waymaker-presets.md](../../../docs/shell/waymaker-presets.md)).
- Canonical reference preset: `aaa.toml` (The Great Wave off Kanagawa, Ukiyo-e Crest Edition).
- Glyph codepoints and names: [references/glyphs.md](references/glyphs.md).
- Validator: `scripts/validate.py` (see Step 5). Run it every time.
- Styles the user rejected, and what worked instead: [references/rejected-styles.md](references/rejected-styles.md).
  **Read it before designing.** In short: filled mass and continuous color beat thin box-drawing lines,
  one-cell pictograms, busy textile repeats, and unrelated flag or brand colors.

## The reference technique (Great Wave)

```
U+E0B6                    left round cap in the abyss color (the swell rises out of nothing)
$os                       Prussian Blue #071e3d + helm icon 󰠳
U+E0C7 U+E0C7 U+E0C0      big mirrored pixel squares (breaking foam) -> flame (convex crest)
$git_branch $git_status   Seafoam Slate #6d94a6
U+E0C7 U+E0C0 U+E0C4      foam -> crest -> small pixel squares (airborne spray)
$directory                Indigo swell #1f4e70
... same 3-glyph claw chain into the Ochre horizon #c7ad7f, $time, then a trailing chain into transparent
$character                ≈❯ seafoam, cinnabar #c84b31 on error (the hanko seal)
```

The claw works through a **highlight-then-hand-off** pattern. The leading glyphs paint a highlight
(pure white foam) over the segment being left and then over an intermediate texture color. The final
glyph hands off: its `fg` is the previous glyph's `bg`, and its `bg` is the next segment. The
intermediate color (`color_dark_bubbles`, `color_wet_sand`) shows only in the gaps of the glyphs, so the
chain reads as one continuous body of material breaking apart rather than three seams.

## Workflow

### Step 1: Pick the subject and write the narrative

Name the artwork, artist, and date (or the phenomenon and its physics). Map it onto the prompt in
reading order, one region per segment:

| Slot | Typical region | Role |
|---|---|---|
| `$os` | ground, abyss, night, base | darkest anchor plus one thematic icon |
| `$directory` | rising body | the main subject, highest legibility |
| `$git_branch$git_status` | the event | the most textured transition sits next to it |
| languages (`$c$rust$golang$nodejs$deno$python`) | secondary detail | share one segment |
| `$time` | horizon or sky | calm, low-chroma |
| `$character` | the signature | success = the motif, error = the culturally loaded alarm color |

The order of `$directory` and `$git_*` can swap if the story needs it (the reference puts git first).

### Step 2: Design the palette

- 6-10 colors in `[palettes.<snake_name>]`, each named `color_<role>` with a trailing comment carrying
  the historically or physically accurate pigment name: `# Prussian Blue (Berlin blue, Hokusai's imported pigment)`.
- Prefer real pigments for paintings (Prussian Blue, Vermilion, Lamp-black, Lead White, Gamboge, Indigo,
  Cadmium Yellow, Ultramarine, Raw Umber, Terre Verte) and physical sources for phenomena (oxygen 557.7 nm
  green, nitrogen violet, Rayleigh-scatter blue, wet sand, basalt).
- Every text segment needs **WCAG contrast >= 4.5:1** between its `fg` and `bg` (3:1 is the hard floor
  for bold icons). Pick the text color per segment: light text on dark bodies, near-black text on light
  bodies.
- Texture colors inside a chain need visible separation (contrast >= about 1.3:1 between adjacent layers)
  but not text-level contrast. Two near-identical layers make a glyph vanish.
- Keep one accent hue reserved for the error symbol so it is preattentive.

### Step 3: Invent the glyph chain

Every preset gets **its own chain signature**. Do not reuse the Great Wave's `E0C7 E0C0 E0C4` claw for
an unrelated subject. Earlier presets (`red-fuji`, since deleted, `kambara-snow`, `starry-night`) all copied it, and that
sameness is the monotony this technique is supposed to remove.

Rules:

1. A chain is 2-4 glyph-only segments placed back to back in `format`: `[G](fg:A bg:B)`. A segment can
   hold a short run of glyphs that share one style, such as a ramp: `[▂▄▆](fg:A bg:B)`.
2. The glyph is drawn in `fg` over `bg`. The first glyph's `bg` is the segment you are leaving. The last
   glyph's `fg` or `bg` must land on the segment you are entering.
3. Use highlight-then-hand-off: leading glyphs carry a highlight or texture `fg` over shifting `bg`s, and
   the final glyph's `fg` equals the previous glyph's `bg`. Break this only for deliberate cuts (rain
   slashes, ink breaks), and say why in Step 6.
4. Match each glyph's geometry to the physics: flames (`E0C0`-`E0C3`) are convex organic rises; pixel
   squares (`E0C4`-`E0C7`) are particles (spray, snow, stars, sparks, pollen); ice waveform (`E0C8`,
   `E0CA`) is crystalline fracture; slants (`E0B8`-`E0BF`) are wind, rain, and dune ridges; round caps
   (`E0B4`-`E0B7`) are soft horizons, moons, and petals; honeycomb (`E0CC`, `E0CD`) is cells and scales;
   trapezoids (`E0D2`, `E0D4`) are architecture.
5. Open the prompt with a cap glyph `fg:<first segment>` and no `bg`. Close the last chain on
   `bg:transparent`. Starship silently drops the unknown color, which leaves the terminal background,
   matching the existing presets.
6. Direction matters: right-pointing glyphs push the eye forward; mirrored glyphs pull back. Use a mirrored
   glyph mid-chain for turbulence (eddies, vortices) and keep the final glyph right-facing so the line
   still flows toward the prompt character.

Chain ideas to start from (invent better ones):

| Subject | Chain | Physics |
|---|---|---|
| Van Gogh vortex | `E0C2 E0C0 E0C5` | mirrored flame + flame = a counter-rotating eddy, then fine star dust |
| Sumi-e ink wash | `E0BC E0C6 E0B4` | brush entry cut, ink bleeding into fibers, soft wash fade |
| Aurora curtain | `E0C1 E0C0 E0C1` | thin/thick/thin flames layered green over violet = folding curtain |
| Sirocco dunes | `E0BA E0BC E0C4` | windward/leeward slip-face slants, then blown sand |
| Monsoon rain | `E0B9 E0BB E0B9` | thin diagonal separators stepping darker = rain cuts |
| Sakura drift | `E0B4 E0C5 E0B6` | round petal, scattered drift, petal landing |
| Glacier calving | `E0C8 E0CA E0C4` | ice fracture, mirrored shear, falling shards |
| Low-poly facets | `E0B8 E0BC E0B8 E0BC` | **triangle strip**: alternate lower-left and upper-left triangles, each `fg` = previous `bg`, so every color spans two cells as a ▼ or ▲ facet; alternate light and shadowed facets (>= 1.3:1). See `2-poly-*` |

#### Beyond Powerline: Unicode glyph families

Powerline-Extra is not the only material. Each cell is still one glyph in `fg` over `bg`, so these families
stack the same way. Give each physical layer its own family: shades for gradients, eighth blocks for
silhouettes, quadrants for fragments, Braille for particles, box drawing for outline. Codepoints, coverage,
and examples are in [references/glyphs.md](references/glyphs.md#unicode-glyph-families).

| Family | Glyphs | Physics |
|---|---|---|
| Shades | `░▒▓` | dithered gradient (ukiyo-e *bokashi*): `▓▒░` with `fg:prev bg:next` cross-fades |
| Eighth blocks | `▁▂▃▄▅▆▇` / `▀▔` | `fg` fills from the bottom: a rising profile, swell, dune or skyline; reverse it to fall |
| Quadrants | `▖▗▘▝▚▞▛▜▙▟` | fragments: dense to sparse (`▜▚▝`) shatters a crest or crumbles a cliff |
| Braille | `⡀⣀⣤⣶⣿`, `⠁⠂⠛`, `⣠⣴⣾` | 2x4 particles per cell: water level, spray, snow, stars; `⣠⣴⣾` climbs diagonally into a curl |
| Box drawing | `╱╲ ╭╮╯╰ ┄ ─` | outline only (key block, ink line): `╱╲` zigzag chop or a mountain, `╯╰` reaching peaks |
| Geometric | `▲ ● ◆ ○` | a single motif inside a chain (Fuji, a moon, a seal) |

Font coverage (JetBrainsMono Nerd Font): shades, blocks, quadrants, Braille, and box drawing are complete.
Geometric is partial (no `◢◣◤◥◖◗◠◡`). Legacy Computing (U+1FB00, smooth wedges and sextants) is
**missing**, so do not rely on it.

Reference set: `1-kanagawa-v5` (shades), `v6` (blocks and quadrants), `v7` (Braille), and `v9` (all
families, one per layer). Box drawing as the main material (the deleted `v8`) did not work; see below.

#### Drawings: Braille plotting and per-cell color

A divider can be a picture, not a texture. The `3-*` presets are the reference set.

- **Braille plotting.** Each Braille cell is a 2x4 dot grid, so a row of cells is a tiny bitmap. Use
  `scripts/braille.py`:
  - `line(ys)` draws a connected trace (ECG beat, wave crest);
  - `area(ys, hang=True)` fills a curtain hanging from the top (aurora);
  - `area(ys)` fills a swell from the bottom;
  - `dither(n)` makes a dense-to-sparse ramp (`⣿⣷⡷⡵⠕⠅⠂`) that dissolves one color into the next.
  Never hand-type the dot patterns.
- **Per-cell color.** Give every glyph of a drawing its own `fg`, sampled from `gradient.py` (aurora
  curtains, a sun dome, spectrum bars colored by height). This is where the "state of the art" look comes from.
- **Shape vocabulary.**
  - A peak is `E0BA` + `E0B8`.
  - A dome is `▂▄▆▇▇▆▄▂`.
  - A tetromino is two rows of half blocks (`▀█▀`).
  - A firework burst is `⢎⡱`.
  - A lit window is a quadrant on a full-block background.
- **Semantic error prompts.** Make the error state part of the drawing (ECG flatline, the Tetris Z
  piece), not just a recolor.

#### Gradient presets

For a palette-driven gradient instead of an artwork (for example the `chroma-*` presets, see
[docs/theme/starship-chroma-presets.md](../../../docs/theme/starship-chroma-presets.md)):

- Sample the stops with `scripts/gradient.py <count> <#hex>...`, which interpolates in OKLab (RGB muddies the
  midpoints). Fill the segments at `t = k/(n-1)`, and step each transition chain through extra samples
  between its two segments, handing the colors off from glyph to glyph.
- Pick dark or light text per fill. Where neither reaches 4.5:1, correct the text to pure black or white
  rather than moving the gradient.
- Add the line `# glyph-stacking: gradient` to the file. The validator then skips chain-layer contrast
  warnings (smooth steps are the intent) but still checks text contrast.
- Never draw a full-width gradient with a `[custom]` module: it forks on every prompt.

### Step 4: Write the TOML

Use this skeleton and keep the header comment format of the existing presets:

```toml
# ==============================================================================
#  Preset: <Title> (<Edition>)
#  Inspired by: <Artist> (<date>) - <Series or context>
#  Configured for: Omarchy / Starship Studio
# ==============================================================================

"$schema" = 'https://starship.rs/config-schema.json'

# The modules cascade through: <Region> -> <Region> -> <Region> -> <Region>
format = """
[<cap>](fg:color_a)\
$os\
[<g1>](fg:... bg:color_a)\
[<g2>](fg:... bg:...)\
[<g3>](fg:... bg:color_b)\
$directory\
...
$time\
[<g1>](fg:... bg:color_time)\
[<g2>](fg:... bg:...)\
[<g3>](fg:... bg:transparent)\

\n$character"""

palette = '<snake_name>'

[palettes.<snake_name>]
color_a = '#rrggbb' # <Pigment name> (<what it depicts>)
```

Then one table per module used in `format`, each with a numbered narrative comment (`# 1. THE DEEP ABYSS`):

- `[os]` needs `disabled = false` and a fixed thematic icon in `format` (`'[ <icon> ]($style)'`).
- `[directory]`, `[git_branch]` (`symbol`), and `[git_status]` (`'([$all_status$ahead_behind ]($style))'`).
- **Every** language module listed in `format` (`c`, `rust`, `golang`, `nodejs`, `deno`, `python`) needs a
  table with `symbol`, `style`, and `format`. Without one it renders in Starship's default colors and
  breaks the segment.
- `[time]` needs `disabled = false` and `time_format = "%R"`.
- `[character]` needs distinct `success_symbol` and `error_symbol` that carry the theme (for example the
  Great Wave's `≈❯`). Use hex here or palette names.
- Only real Starship modules. Invented tables such as `[wave_crest]` are ignored, or produce warnings.

**Writing glyphs:** Powerline-Extra glyphs are Private Use Area characters and get stripped by copy and
paste, chat transport, and some editors. In the reference that produced this skill they all arrived as
empty `[]`. Write the file with a short Python script using ``-style escapes, or verify after a
direct write. The validator flags every empty `[](...)`.

### Step 5: Validate and preview (required)

```sh
python3 .agents/skills/starship-glyph-stacking/scripts/validate.py starship/.config/omarchy/starship-presets/<slug>.toml
```

It checks that `starship` parses the file with no warnings, that every color token resolves to a palette
entry or hex value (Starship ignores typos **silently**), that no glyph slot is empty, the WCAG contrast of
each module's text and of each chain layer, that every `$module` has a table, and it prints the chain
signatures plus a rendered ANSI preview. Fix every `FAIL`, and justify or fix each `WARN`. Quote the
output; never claim a contrast number you did not run.

### Step 6: Present each preset

For each preset, in this order:

1. **Artistic and historical rationale**: the work, artist, date, and the region-by-region narrative from
   `$os` to `$character`.
2. **Chroma palette**: a table of hex, name, pigment or physical source, and role, plus the contrast
   ratios from the validator.
3. **Composite glyph architecture**: the chain as codepoints and names, the color stepping, and the visual
   physics it simulates.
4. **The TOML**: saved to the presets directory, with its path, and a pointer to `wm -o starship-presets`
   to try it.

## Hygiene

- New preset = new file. Do not overwrite an existing preset unless asked, and look at it first.
- Do not edit `aaa.toml` or other in-progress user presets while designing new ones.
- Remove any scratch generator scripts before finishing.
