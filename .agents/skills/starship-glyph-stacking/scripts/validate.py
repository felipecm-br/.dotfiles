#!/usr/bin/env python3
"""Validate a Composite Glyph Stacking Starship preset.

Usage: validate.py <preset.toml> [--no-preview]

Checks what Starship itself does not report: unresolved color tokens (silently
ignored), empty glyph slots (stripped Private Use Area characters), missing
module tables, and WCAG contrast of text segments and chain layers.
Exit code 1 when any FAIL is found.
"""
import os
import re
import shutil
import subprocess
import sys
import tomllib

NAMED = {"black", "red", "green", "blue", "yellow", "purple", "cyan", "white",
         "bright-black", "bright-red", "bright-green", "bright-blue",
         "bright-yellow", "bright-purple", "bright-cyan", "bright-white"}
MODIFIERS = {"bold", "italic", "underline", "dimmed", "inverted", "blink",
             "hidden", "strikethrough", "none"}
NO_TABLE_NEEDED = {"character", "line_break", "fill", "all"}
GLYPH_NAMES = {
    0xE0B0: "right_hard", 0xE0B1: "right_soft", 0xE0B2: "left_hard", 0xE0B3: "left_soft",
    0xE0B4: "right_half_circle", 0xE0B5: "right_half_circle_thin",
    0xE0B6: "left_half_circle", 0xE0B7: "left_half_circle_thin",
    0xE0B8: "lower_left_tri", 0xE0B9: "backslash", 0xE0BA: "lower_right_tri",
    0xE0BB: "forwardslash", 0xE0BC: "upper_left_tri", 0xE0BD: "forwardslash",
    0xE0BE: "upper_right_tri", 0xE0BF: "backslash",
    0xE0C0: "flame_thick", 0xE0C1: "flame_thin", 0xE0C2: "flame_thick_mirrored",
    0xE0C3: "flame_thin_mirrored", 0xE0C4: "pixel_small", 0xE0C5: "pixel_small_mirrored",
    0xE0C6: "pixel_big", 0xE0C7: "pixel_big_mirrored", 0xE0C8: "ice_waveform",
    0xE0CA: "ice_waveform_mirrored", 0xE0CC: "honeycomb", 0xE0CD: "honeycomb_outline",
    0xE0CE: "lego", 0xE0CF: "lego_thin", 0xE0D0: "lego_facing", 0xE0D1: "lego_sideways",
    0xE0D2: "trapezoid", 0xE0D4: "trapezoid_mirrored",
    0xE0D6: "right_hard_inverse", 0xE0D7: "left_hard_inverse",
}

# Glyph-art ranges: Powerline/Nerd PUA, box drawing, block elements and shades,
# geometric shapes, Braille, Legacy Computing.
ART_RANGES = [(0xE000, 0xF8FF), (0x2500, 0x259F), (0x25A0, 0x25FF),
              (0x2800, 0x28FF), (0x1FB00, 0x1FBFF)]


def is_art(c):
    return any(lo <= ord(c) <= hi for lo, hi in ART_RANGES)


fails, warns = [], []


def fail(msg):
    fails.append(msg)
    print(f"FAIL  {msg}")


def warn(msg):
    warns.append(msg)
    print(f"WARN  {msg}")


def info(msg):
    print(f"      {msg}")


def parse_style(style, palette, where):
    """Return (fg_hex, bg_hex) after resolving tokens; report unresolved ones."""
    fg = bg = None
    for tok in style.split():
        kind, _, val = tok.rpartition(":")
        if not kind and val.lower() in MODIFIERS:
            continue
        if kind not in ("", "fg", "bg"):
            fail(f"{where}: unknown style token '{tok}'")
            continue
        if kind == "bg" and val == "transparent":
            continue  # dropped by starship on purpose: terminal background
        hexv = resolve(val, palette)
        if hexv is None:
            if val in NAMED or val.isdigit():
                continue
            fail(f"{where}: color '{val}' is not a palette key or hex (starship ignores it silently)")
            continue
        if kind == "bg":
            bg = hexv
        else:
            fg = hexv
    return fg, bg


def resolve(val, palette):
    if re.fullmatch(r"#[0-9a-fA-F]{6}", val):
        return val.lower()
    if val in palette:
        return resolve(palette[val], {})
    return None


def luminance(hexv):
    def ch(c):
        c = int(c, 16) / 255
        return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = (ch(hexv[i:i + 2]) for i in (1, 3, 5))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a, b):
    la, lb = sorted((luminance(a), luminance(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def glyph_label(text):
    def one(c):
        cp = ord(c)
        if cp in GLYPH_NAMES:
            return f"U+{cp:04X}:{GLYPH_NAMES[cp]}"
        if 0xE000 <= cp <= 0xF8FF:
            return f"U+{cp:04X}:?"
        return f"U+{cp:04X}:{c}"
    return " ".join(one(c) for c in text)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if len(args) != 1:
        print(__doc__)
        sys.exit(2)
    path = os.path.abspath(args[0])
    with open(path, "rb") as f:
        cfg = tomllib.load(f)

    print(f"== {os.path.basename(path)}")
    pal_name = cfg.get("palette")
    palette = cfg.get("palettes", {}).get(pal_name, {}) if pal_name else {}
    if not pal_name:
        warn("no 'palette' key; colors must all be hex")
    elif not palette:
        fail(f"palette '{pal_name}' has no [palettes.{pal_name}] table")
    for k, v in palette.items():
        if resolve(v, {}) is None:
            fail(f"palette entry {k} = '{v}' is not #rrggbb")
    if "$schema" not in cfg:
        warn("missing \"$schema\" declaration")

    fmt = cfg.get("format", "")

    # Empty glyph slots: stripped PUA characters.
    for m in re.finditer(r"\[\]\(([^)]*)\)", fmt):
        fail(f"empty glyph slot [](...{m.group(1)}): a Private Use Area glyph was lost")

    # Glyph chains: consecutive glyph-only text groups in format.
    seg_re = re.compile(r"\[([^\]]*)\]\(([^)]*)\)|\$([a-z_]+)")
    chains, cur, used_colors = [], [], set()
    for m in seg_re.finditer(fmt):
        text, style, mod = m.groups()
        if mod:
            if cur:
                chains.append(cur)
                cur = []
            continue
        used_colors.update(re.findall(r"color_[a-z0-9_]+", style))
        fg, bg = parse_style(style, palette, f"format [{glyph_label(text)}]")
        if text and all(is_art(c) for c in text):
            cur.append((text, style, fg, bg))
        elif cur:
            chains.append(cur)
            cur = []
    if cur:
        chains.append(cur)

    # Gradient presets opt out of chain-layer contrast warnings with this marker.
    gradient = "# glyph-stacking: gradient" in open(path, encoding="utf-8").read()
    print("-- glyph chains" + (" (gradient mode: layer contrast not checked)" if gradient else ""))
    signatures = set()
    for i, chain in enumerate(chains, 1):
        sig = " ".join(f"U+{ord(t[0][0]):04X}" for t in chain)
        signatures.add(sig)
        info(f"chain {i}: {glyph_label(''.join(t[0] for t in chain))}")
        for text, style, fg, bg in chain:
            if fg and bg:
                r = contrast(fg, bg)
                note = f"{r:.2f}:1"
                if gradient:
                    continue  # smooth steps are the intent; text contrast still applies
                if r < 1.15:
                    warn(f"chain {i} layer {text} ({style}) {note}: glyph is invisible")
                elif r < 1.3:
                    warn(f"chain {i} layer {text} ({style}) {note}: texture barely visible")
        if len(chain) > 1:
            bg_a, fg_b = chain[-2][3], chain[-1][2]
            if bg_a and fg_b and bg_a != fg_b:
                info(f"chain {i}: final glyph does not hand off ({bg_a} -> {fg_b}); fine if deliberate")
    if len(chains) > 1 and len(signatures) == 1:
        info("all chains share one signature; consider varying the final transition")
    if "U+E0C7 U+E0C0 U+E0C4" in signatures and "Kanagawa" not in open(path, encoding="utf-8").read():
        warn("chains copy the Great Wave claw (E0C7 E0C0 E0C4); invent a chain for this subject")

    # Module tables and text contrast.
    print("-- modules")
    modules = list(dict.fromkeys(re.findall(r"\$([a-z_]+)", fmt)))
    for mod in modules:
        if mod in NO_TABLE_NEEDED:
            continue
        table = cfg.get(mod)
        if not isinstance(table, dict):
            fail(f"${mod} is in format but has no [{mod}] table (renders in default colors)")
            continue
        if mod in ("os", "time") and table.get("disabled", True):
            fail(f"[{mod}] needs disabled = false")
        style = table.get("style")
        if not style:
            warn(f"[{mod}] has no style")
            continue
        used_colors.update(re.findall(r"color_[a-z0-9_]+", style))
        fg, bg = parse_style(style, palette, f"[{mod}].style")
        if fg and bg:
            r = contrast(fg, bg)
            msg = f"[{mod}] text {fg} on {bg}: {r:.2f}:1"
            if r < 3:
                fail(msg + " (below 3:1)")
            elif r < 4.5:
                warn(msg + " (below 4.5:1 AA)")
            else:
                info(msg)
        elif bg and not fg:
            warn(f"[{mod}] sets bg but no fg; text uses the terminal foreground")

    char = cfg.get("character", {})
    succ, err = char.get("success_symbol"), char.get("error_symbol")
    if not succ or not err:
        fail("[character] needs success_symbol and error_symbol")
    elif succ == err:
        fail("[character] success_symbol and error_symbol are identical")
    else:
        for name, sym in (("success_symbol", succ), ("error_symbol", err)):
            for style in re.findall(r"\]\(([^)]*)\)", sym):
                used_colors.update(re.findall(r"color_[a-z0-9_]+", style))
                parse_style(style, palette, f"[character].{name}")

    for k in sorted(set(palette) - used_colors):
        info(f"palette color {k} is unused")

    # Starship's own parse warnings and a rendered preview.
    if shutil.which("starship"):
        env = dict(os.environ, STARSHIP_CONFIG=path, STARSHIP_LOG="warn", STARSHIP_SHELL="")
        res = subprocess.run(["starship", "prompt"], env=env, capture_output=True, text=True)
        for line in re.sub(r"\x1b\[[0-9;]*m", "", res.stderr).splitlines():
            if "WARN" in line or "ERROR" in line:
                fail(f"starship: {line.strip()}")
        if "--no-preview" not in sys.argv:
            print("-- preview")
            print(re.sub(r"%\{|%\}", "", res.stdout))
    else:
        warn("starship not installed; parse and preview skipped")

    print(f"== {len(fails)} FAIL, {len(warns)} WARN")
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
