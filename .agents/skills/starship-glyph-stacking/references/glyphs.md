# Powerline / Powerline-Extra Glyph Reference

Codepoints are the source of truth. The glyph column may render as blank or tofu in tools without a Nerd Font, and private-use characters are often stripped in transit, so always cross-check with the codepoint (`python3 -c "print(hex(ord('<g>')))"`, or the validator's chain report).

Write glyphs into TOML from Python with `'\uE0C7'`, or in TOML basic strings (`"..."` and `"""..."""`) with `\uE0C7`. Literal strings (`'...'`) do not process escapes.

| Codepoint | Glyph | Nerd Font name | Shape | Texture uses |
|---|---|---|---|---|
| U+E0B0 |  | `pl-right_hard_divider` | solid right triangle | hard forward cut |
| U+E0B1 |  | `pl-right_soft_divider` | thin right chevron | outline only |
| U+E0B2 |  | `pl-left_hard_divider` | solid left triangle | hard backward cut |
| U+E0B3 |  | `pl-left_soft_divider` | thin left chevron | outline only |
| U+E0B4 |  | `ple-right_half_circle_thick` | solid right semicircle | soft horizon, petal, moon |
| U+E0B5 |  | `ple-right_half_circle_thin` | thin right arc | halo outline |
| U+E0B6 |  | `ple-left_half_circle_thick` | solid left semicircle | opening cap |
| U+E0B7 |  | `ple-left_half_circle_thin` | thin left arc | halo outline |
| U+E0B8 |  | `ple-lower_left_triangle` | lower-left wedge | ground slope, dune windward |
| U+E0B9 |  | `ple-backslash_separator` | thin \ slash | rain cut, wind streak |
| U+E0BA |  | `ple-lower_right_triangle` | lower-right wedge | slip face, rising ridge |
| U+E0BB |  | `ple-forwardslash_separator` | thin / slash | rain cut, wind streak |
| U+E0BC |  | `ple-upper_left_triangle` | upper-left wedge | brush entry, overhang |
| U+E0BD |  | `ple-forwardslash_separator_redundant` | thin / slash | alias |
| U+E0BE |  | `ple-upper_right_triangle` | upper-right wedge | sky wedge, roof pitch |
| U+E0BF |  | `ple-backslash_separator_redundant` | thin \ slash | alias |
| U+E0C0 |  | `ple-flame_thick` | thick right flame | convex wave crest, fire tongue, aurora fold |
| U+E0C1 |  | `ple-flame_thin` | thin right flame | flame outline, wisps |
| U+E0C2 |  | `ple-flame_thick_mirrored` | thick left flame | counter-current, eddy |
| U+E0C3 |  | `ple-flame_thin_mirrored` | thin left flame | outline eddy |
| U+E0C4 |  | `ple-pixelated_squares_small` | small pixel squares | spray, sand, star dust |
| U+E0C5 |  | `ple-pixelated_squares_small_mirrored` | small pixel squares (mirrored) | drift, falling particles |
| U+E0C6 |  | `ple-pixelated_squares_big` | big pixel squares | ink bleed, snow clumps |
| U+E0C7 |  | `ple-pixelated_squares_big_mirrored` | big pixel squares (mirrored) | breaking foam, crust |
| U+E0C8 |  | `ple-ice_waveform` | ice waveform | crystal fracture, frost |
| U+E0CA |  | `ple-ice_waveform_mirrored` | ice waveform (mirrored) | shear, calving |
| U+E0CC |  | `ple-honeycomb` | honeycomb | cells, scales, basalt columns |
| U+E0CD |  | `ple-honeycomb_outline` | honeycomb outline | lattice |
| U+E0CE |  | `ple-lego_separator` | lego separator | modular, tiles |
| U+E0CF |  | `ple-lego_separator_thin` | lego separator thin | tile outline |
| U+E0D0 |  | `ple-lego_block_facing` | lego block facing | bricks |
| U+E0D1 |  | `ple-lego_block_sideways` | lego block sideways | bricks |
| U+E0D2 |  | `ple-trapezoid_top_bottom` | trapezoid | architecture, pagoda eave |
| U+E0D4 |  | `ple-trapezoid_top_bottom_mirrored` | trapezoid (mirrored) | architecture |
| U+E0D6 |  | `ple-right_hard_divider_inverse` | inverse right triangle | notch |
| U+E0D7 |  | `ple-left_hard_divider_inverse` | inverse left triangle | notch |

## Thematic icons (Nerd Font Material Design, U+F0000+)

Pick one icon per preset for `[os]` and `[directory]`. To find candidates, search https://www.nerdfonts.com/cheat-sheet by keyword (wave, snowflake, star, fire, leaf, mountain, ship-wheel). Existing presets use `󰠳` (U+F0833, ship wheel) and `󰲋` (U+F0C8B, folder).

## Unicode glyph families

Each of these is one cell. The glyph is drawn in `fg` over `bg`, and terminals such as Ghostty, Kitty, and Alacritty draw blocks, shades, and box drawing natively, so they tile seamlessly from cell to cell.

| Range | Glyphs | Coverage in JetBrainsMono NF | Notes |
|---|---|---|---|
| U+2591-U+2593 shades | `░ ▒ ▓` | full | 25 / 50 / 75 % `fg`; a 3-cell ramp is a dithered cross-fade |
| U+2581-U+2588 lower eighths | `▁ ▂ ▃ ▄ ▅ ▆ ▇ █` | full | `fg` fills from the bottom; skip steps (`▂▄▆`) for a steeper slope |
| U+2580, U+2594 upper blocks | `▀ ▔` | full | overhang, lip, eave, cloud band |
| U+2589-U+258F, U+2590, U+2595 vertical blocks | `▉ ▊ ▋ ▌ ▍ ▎ ▏ ▐ ▕` | full | horizontal wipe in 1/8 steps |
| U+2596-U+259F quadrants | `▖ ▗ ▘ ▝ ▚ ▞ ▙ ▛ ▜ ▟` | full | fragments; order by filled quadrants (3, 2, 1) to shatter |
| U+2800-U+28FF Braille | `⡀ ⣀ ⣤ ⣶ ⣿ ⠁ ⠂ ⠛ ⣠ ⣴ ⣾` | full | 2x4 dot grid; `⣀⣤⣶⣿` water level, `⠛⠋⠁` spray thinning, `⣠⣴⣾` diagonal curl |
| U+2500-U+257F box drawing | `─ ┄ ╱ ╲ ╳ ╭ ╮ ╯ ╰ ═` | full | line only; `╱╲` zigzag or peak, `╯╰` rounded peaks, `╮╭` hanging drops |
| U+25A0-U+25FF geometric | `▲ △ ● ○ ◆ ◇ ◉ ■` | partial | missing: `◢ ◣ ◤ ◥ ◖ ◗ ◠ ◡ ◐ ◑` |
| U+1FB00-U+1FBFF Legacy Computing | sextants, smooth wedges | **none** | Ghostty may draw some natively, but other terminals will not; avoid |

To check another glyph, query the font's charset with `fc-query --format='%{charset}\n' /usr/share/fonts/TTF/JetBrainsMonoNerdFontMono-Bold.ttf`.
