# Typographic Sub-Cell Physics, Vertical Channeling & Semiotic Collision Audit

## 1. Sub-Cell Vertical Banding in Monospace & Nerd Fonts

In terminal grids, every single-width glyph occupies one logical character cell (`wcwidth = 1`), yet its **actual rasterized ink bounding box (`x0..x1, y0..y1`)** and **pixel ink mass** vary dramatically. Rather than guessing from character names, always rasterize candidate glyphs against the active terminal font (e.g., `/usr/share/fonts/TTF/JetBrainsMonoNerdFontPropo-Regular.ttf` at `64px`) before committing to a TUI badge or marker.

### Reference Vertical Zones (`JetBrainsMono Nerd Font Propo`, `64px` canvas, origin `(16, 16)`)

| Typographic Zone | Reference Character | Vertical Span (`y0..y1`) | Pixel Ink Area | Perceptual Role |
| :--- | :---: | :---: | :---: | :--- |
| **Upper / Pseudo-Superscript Band** | `²`, `⠛`, `▘`, ``, `󱕔` | `17..62` | `215–840 px²` | Elevated shoulder / gutter badge; clears lowercase baseline (`81`) with zero x-height crowding |
| **Cap-Height Band** | `A`, `✦`, `✳` | `35..82` | `380–620 px²` | Primary row icons and uppercase anchors |
| **x-Height Band** | `n`, `e`, `m` | `46..81` | `310–460 px²` | Dense lexical reading channel; flanking symbols at this height trigger Bouma crowding |
| **Full-Cell / Centered PUA Band** | Most Nerd Font icons (``, `󰊢`) | `28..88` | `450–1100 px²` | Standalone $X=1$ category or header icons; too tall to act as a superscript shoulder mark |

---

## 2. Validated Native Upper-Band ("Pseudo-Superscript") Candidates

Cross-referenced across Unicode Block/Braille primitives, `nerdsight` (`glyphnames.json`), and native font `cmap` coverage (excluding missing glyphs such as Latin superscripts `ᵃ…ᶻ`, which trigger fallback font drift):

| Glyph | Codepoint | Plane / Source | `y0..y1` | Ink (`px²`) | Strengths & Trade-offs |
| :---: | :--- | :--- | :---: | :---: | :--- |
| **`▘` / `▝`** | `U+2598` / `U+259D` | BMP Quadrant | `17..59` | `798–840` | GPU-drawn box primitive in Ghostty/Kitty/Alacritty; razor-sharp at any DPI; `▘` hugs right of text, `▝` hugs left of an icon |
| **`⠛`** | `U+281B` | BMP Braille (`1245`) | `20..55` | `624` | Symmetric $2\times2$ upper dot cluster; $2.2\times$ ink of `²`; universal `wcwidth = 1`; immune to spinner ambiguity |
| **``** | `U+F0DE` | BMP Nerd Font (`fa-sort_asc`) | `36..59` | `539` | Solid upward triangle sitting strictly at `²` height (`59` vs `58`); strong *"promoted / top pick"* affordance |
| **`⠉`** | `U+2809` | BMP Braille (`14`) | `20..34` | `312` | Ultra-high twin-dot bar floating above cap-height (`34 < 35`); minimal vertical footprint |
| **`󱕔`** | `U+F1554` | SMP PUA-A (`md-vanish_quarter`) | `34..62` | `227` | Semantic *"sparkle"* in upper-left quadrant, **but** lives in Plane-15 PUA-A (`> U+FFFF`) — vulnerable to clipboard/parser stripping |
| **`°` / `⁺`** | `U+00B0` / `U+207A` | BMP Punctuation | `34..53` / `44..61` | `217` / `142` | Classic typographic superscripts; clean but low luminance weight in dimmed lists |

---

## 3. Mandatory Glyph Audit Laws

### 3.1 Semiotic Collision Trap (`"⠋"` vs `"⠛"`)
A glyph with ideal sub-cell geometry MUST still be rejected if its shape collides with an existing operational signifier in the ecosystem:
- **Trap Example:** `"⠋"` (`U+280B`, Braille Dots-124, `y = 20..55`, `468 px²`) sits cleanly in the superscript band, **but** `⠋` is frame 0 of the 6-dot Braille **AI Agent Busy/Working spinner** (`⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏`). Rendering a static `⠋` beside an idle model row triggers a false preattentive *"currently spinning / busy"* signal.
- **Resolution:** Use the **4-dot symmetric upper block `⠛` (`U+281B`, Dots-1245)** or **2-dot top bar `⠉` (`U+2809`, Dots-14)**, which never appear in standard 3-dot spinner frames.

### 3.2 Native Coverage & BMP Portability Law (`≤ U+FFFF` over Plane-15 PUA-A)
1. **Verify Native `cmap` Presence:** Never assume Unicode blocks (such as Latin superscripts `ᵃ…ᶻ` in `U+1D43..U+1DBB`) exist in monospace Nerd Fonts. Missing glyphs fall back to proportional system fonts with mismatched baselines and advance widths.
2. **Prefer BMP (`≤ U+FFFF`) over Plane-15 PUA-A (`U+F0000+`) for Inline Data Columns:** Supplementary PUA-A icons (`4-byte UTF-8`) are frequently stripped or collapsed by web inputs, terminal clipboards, or naive regexes, whereas BMP characters (`U+2598`, `U+281B`, `U+F0DE`) survive copy-paste, `jq`, `sed`, `zsh`, and `wcwidth` pipelines intact.

### 3.3 Invariant-$X$ Left Gutter vs. Ragged Word-Suffix Law
- **Ragged Suffix Cost:** Appending a marker to variable-length names (`Opus⠛` at $X=22$ vs `Claude Sonnet 5.5⠛` at $X=35$) scatters the target across horizontal columns, forcing $O(N)$ horizontal micro-saccades.
- **Invariant-$X$ Gutter Superiority:** Placing the marker in a dedicated 1-cell column **to the left of the row icon** (`X = const`) leaves every non-marked row empty (`' '`) in that vertical lane. A single upper-band glyph (`⠛`) breaking an otherwise empty vertical channel achieves **$<15\text{ ms}$ Treisman feature pop-out** inside the exact same $2^\circ$ foveal cone as the $X=1$ cyan focus bar (`│`).
- **Anti-Crowding Chromatic Separation:** When a left-gutter marker (`⠛`) sits directly adjacent to an agent/category icon (`✦`, `✳`), separate them across **both** vertical band (`y = 20..55` vs `y = 35..82`) **and** chromatic/luminance channel (e.g., bright `white`/`cyan` marker next to `blue` passive icon) so adjacent geometric strokes never fuse under Bouma crowding ($0.5\times$ eccentricity).

---

## 4. Reproducible Sub-Pixel Font Audit Snippet

Run this read-only Pillow check (e.g., via `nerdsight`'s `.venv` or any Python environment with `Pillow`) to verify exact bounding boxes, ink mass, and native presence (non-tofu) in the active terminal font:

```python
from PIL import Image, ImageDraw, ImageFont

FONT_PATH = "/usr/share/fonts/TTF/JetBrainsMonoNerdFontPropo-Regular.ttf"
font = ImageFont.truetype(FONT_PATH, 64)

def measure(ch: str):
    img = Image.new("L", (128, 128), 0)
    ImageDraw.Draw(img).text((16, 16), ch, fill=255, font=font)
    bbox = img.getbbox()
    ink = sum(1 for p in img.getdata() if p > 64) if bbox else 0
    return bbox, ink, font.getlength(ch), img.tobytes()

_, _, _, tofu = measure("\uFFFE")
for ch in ["A", "n", "²", "✦", "⠋", "⠛", "⠉", "▘", "▝", ""]:
    bbox, ink, adv, raw = measure(ch)
    native = raw != tofu
    print(f"U+{ord(ch):05X} {ch}  native={native}  adv={adv:4.1f}  bbox={bbox}  ink={ink:4d}")
```
