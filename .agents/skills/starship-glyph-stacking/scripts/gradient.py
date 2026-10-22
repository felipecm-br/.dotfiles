#!/usr/bin/env python3
"""Sample a multi-stop gradient at evenly spaced points, interpolating in OKLab.

Usage: gradient.py <count> <#hex> <#hex> [...] [--rgb]

Stops are spread evenly from 0 to 1 (as notMyShell's PRESET_STOPS are).
Prints one "t  #hex" line per sample. --rgb mixes linearly in sRGB instead,
for comparison: RGB mixing muddies the midpoints between distant hues.
Importable: sample(stops, t) and samples(stops, count).
"""
import sys


def _to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def _to_srgb(c):
    c = max(0.0, min(1.0, c))
    return 12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055


def hex_to_oklab(h):
    r, g, b = (_to_linear(int(h[i:i + 2], 16) / 255) for i in (1, 3, 5))
    l = (0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b) ** (1 / 3)
    m = (0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b) ** (1 / 3)
    s = (0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b) ** (1 / 3)
    return (0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
            1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
            0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s)


def oklab_to_hex(lab):
    L, a, b = lab
    l = (L + 0.3963377774 * a + 0.2158037573 * b) ** 3
    m = (L - 0.1055613458 * a - 0.0638541728 * b) ** 3
    s = (L - 0.0894841775 * a - 1.2914855480 * b) ** 3
    rgb = (4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
           -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
           -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s)
    return "#" + "".join(f"{round(_to_srgb(c) * 255):02x}" for c in rgb)


def _mix_rgb(h1, h2, f):
    c1 = [int(h1[i:i + 2], 16) for i in (1, 3, 5)]
    c2 = [int(h2[i:i + 2], 16) for i in (1, 3, 5)]
    return "#" + "".join(f"{round(a + (b - a) * f):02x}" for a, b in zip(c1, c2))


def sample(stops, t, rgb=False):
    """Color at position t in [0, 1] of evenly spaced stops."""
    stops = [s.lower() for s in stops]
    if len(stops) == 1 or t <= 0:
        return stops[0]
    if t >= 1:
        return stops[-1]
    pos = t * (len(stops) - 1)
    i = int(pos)
    f = pos - i
    if rgb:
        return _mix_rgb(stops[i], stops[i + 1], f)
    a, b = hex_to_oklab(stops[i]), hex_to_oklab(stops[i + 1])
    return oklab_to_hex(tuple(x + (y - x) * f for x, y in zip(a, b)))


def samples(stops, count, rgb=False):
    if count == 1:
        return [stops[0].lower()]
    return [sample(stops, k / (count - 1), rgb) for k in range(count)]


def main():
    args = [a for a in sys.argv[1:] if a != "--rgb"]
    if len(args) < 2 or not args[0].isdigit():
        print(__doc__)
        sys.exit(2)
    count, stops = int(args[0]), args[1:]
    for k, h in enumerate(samples(stops, count, "--rgb" in sys.argv)):
        print(f"{k / max(count - 1, 1):.3f}  {h}")


if __name__ == "__main__":
    main()
