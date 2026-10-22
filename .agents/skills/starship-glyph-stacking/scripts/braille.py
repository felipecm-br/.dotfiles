#!/usr/bin/env python3
"""Plot curves, filled areas and dither ramps with Braille cells (2x4 dots each).

Usage: braille.py line <y> <y> ...      one y per dot column, 0 = top row, 3 = bottom
       braille.py wave <cells> [period] [phase]
       braille.py dither <cells>        dense to sparse ramp (dissolve one color into the next)

Prints the Braille string and its codepoints. Importable: line(ys), area(ys, hang=False),
wave(cells, period, phase) -> ys, dither(cells).
"""
import math
import sys

LEFT, RIGHT = (0x01, 0x02, 0x04, 0x40), (0x08, 0x10, 0x20, 0x80)
# Densest to sparsest; each step drops dots so the bg color shows through more.
RAMP = "⣿⣷⡷⡵⠕⠅⠂⠀"


def _cells(ys, rows_for):
    out, prev = [], ys[0]
    for i in range(0, len(ys), 2):
        bits = 0
        for j, col in enumerate((LEFT, RIGHT)):
            if i + j >= len(ys):
                break
            for r in rows_for(prev, ys[i + j]):
                bits |= col[r]
            prev = ys[i + j]
        out.append(chr(0x2800 + bits))
    return "".join(out)


def line(ys):
    """A connected trace: vertical gaps between neighboring columns are filled."""
    return _cells(ys, lambda p, y: range(min(p, y), max(p, y) + 1))


def area(ys, hang=False):
    """Fill below the curve (a swell, a dune), or above it with hang=True (a curtain)."""
    return _cells(ys, lambda p, y: range(0, y + 1) if hang else range(y, 4))


def wave(cells, period=8, phase=0.0):
    """Sine y values for `cells` Braille cells (two dot columns per cell)."""
    return [round(1.5 - 1.5 * math.sin(2 * math.pi * (k + phase) / period)) for k in range(cells * 2)]


def dither(cells):
    """`cells` glyphs stepping evenly from dense to sparse along RAMP."""
    if cells == 1:
        return RAMP[0]
    return "".join(RAMP[round(k * (len(RAMP) - 2) / (cells - 1))] for k in range(cells))


def main():
    a = sys.argv[1:]
    if not a or a[0] not in ("line", "wave", "dither"):
        print(__doc__)
        sys.exit(2)
    if a[0] == "line":
        out = line([int(v) for v in a[1:]])
    elif a[0] == "wave":
        n = int(a[1])
        out = line(wave(n, float(a[2]) if len(a) > 2 else 8, float(a[3]) if len(a) > 3 else 0))
    else:
        out = dither(int(a[1]))
    print(out)
    print(" ".join(f"U+{ord(c):04X}" for c in out))


if __name__ == "__main__":
    main()
