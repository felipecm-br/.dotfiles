# Rejected Styles

Presets the user tried and deleted (October 2026) because they looked ugly or would not be used.
Read this before designing a new preset: the patterns below failed in practice, while the kept
sets (`chroma-*`, `2-poly-*`, most `3-*`, `4-giza`) show what works.

## What failed

| Pattern | Removed presets | Why it failed |
|---|---|---|
| **Box-drawing outlines as the main material** (`╱ ╲ ╳ ╭ ╮ ─ │`) | `1-kanagawa-v8` (key-block line), `3-circuit-board` (copper traces), `3-dna-helix` (`╳` crossings), `3-seigaiha-waves` (`╭╮` scallops), `power-mjolnir-thunder` (`╱╲` lightning), `power-web-swing` (`╳ ─ ╲│╱` webbing) | Thin one-pixel strokes on a solid fill read as gaps or rendering glitches, not as structure. The bar loses its weight next to filled segments. |
| **Tiny pictograms in one or two cells** | `3-space-invaders` (quadrant sprites), `3-grand-piano` (`▐▌` keys), `4-kyoto` (`▛▜` torii), `4-london` (roundel), `4-paris` (mansard roofs), `4-new-york`, `4-rio-de-janeiro`, `4-china`, `4-santorini` | At prompt size the drawing is too small to recognize and looks like mojibake. Landmarks need a silhouette that spans many cells (as `4-giza` does with big triangles), not an icon. |
| **Repeating textile or tile patterns** | `3-fair-isle` (checker + diamonds), `4-marrakech` (zellige), `3-stained-glass` (half-block lead cames), `4-ipanema` (calçadão waves) | Busy, high-frequency texture competes with the text and makes the prompt noisy to scan. |
| **Many unrelated saturated colors** | `4-new-york` (MTA bullets), `4-london` (Tube lines), `3-glitch-art` (RGB channel split), `4-rio-de-janeiro` / `4-paris` (flag colors) | No color continuity between segments: each seam is a hard jump, so the line reads as a list of badges instead of one flowing body. |
| **Recycled chain signatures** | `red-fuji` (Great Wave claw), `power-hadouken-v3` (third iteration of the same charge), `power-rasengan` | Same look as an existing preset with a new palette; nothing new to justify a separate file. |
| **Plain early-style presets** | `nordic-aurora`, `sudden-shower-atake` | Single-glyph separators with no layering; superseded by the gradient and drawing techniques. |

## What works (keep doing)

- **Smooth OKLab gradients** with per-cell color hand-offs (`chroma-*`): the user called these the most creative set.
- **Large, bold shapes made of filled glyphs**: triangle peaks (`3-andes-ridges`, `4-giza`), low-poly facets (`2-poly-*`), blocks (`3-tetris`, `3-mondrian`, `3-chessboard`).
- **Braille plotting with a per-glyph gradient** (`3-aurora-borealis`, `3-ecg-monitor`, `3-spectrum-analyzer`, `3-fireworks`).
- **Skylines and horizons that rise in eighth blocks under a gradient sky** (`3-neon-skyline`, `3-synthwave-sunset`).

Rule of thumb: prefer **filled mass and continuous color** over **thin lines, small icons, and busy repeats**.
