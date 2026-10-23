#!/usr/bin/env bash
# gradient-frame.sh — paint a rounded multi-color frame around a borderless popup.
#
# Bash counterpart of the Waymaker/lazygitrs gradient frames: same presets,
# OKLab interpolation along the top-left → bottom-right diagonal (no seam).
# Bash modals opened with `popup_gradient_flags BORDER_GRADIENT` (theme-helper.sh)
# receive the palette in $BORDER_GRADIENT and call this after printing their
# content, so the frame lands on the popup's outer rows and columns.
#
# Usage (sourced):
#   . "$HOME/.config/tmux/gradient-frame.sh"
#   print_modal_body "$body"
#   gradient_frame_draw "$BORDER_GRADIENT" " $BADGE " "#e0af68"

# print_modal_body BODY — print a modal's rendered body. Inside a gradient
# (borderless) popup the body is shifted one row down and one column right, so
# it sits exactly where the tmux border used to leave it.
print_modal_body() {
  if [ -n "${BORDER_GRADIENT:-}" ]; then
    printf '\n %s\n' "${1//$'\n'/$'\n' }"
  else
    printf '%s\n' "$1"
  fi
}

# gradient_frame_draw PALETTE [TITLE] [TITLE_HEX]
# Returns 1 (drawing nothing) when PALETTE is empty or invalid.
gradient_frame_draw() {
  local palette="${1:-}" title="${2:-}" title_hex="${3:-}" size rows cols
  [ -n "$palette" ] || return 1
  size=$(stty size < /dev/tty 2>/dev/null) || return 1
  rows="${size% *}"
  cols="${size#* }"
  [ "$rows" -ge 2 ] && [ "$cols" -ge 2 ] || return 1

  awk -v palette="$palette" -v W="$cols" -v H="$rows" -v title="$title" -v title_hex="$title_hex" '
    function hexval(h) { return index("0123456789abcdef", tolower(h)) - 1 }
    function byte(s, i) { return hexval(substr(s, i, 1)) * 16 + hexval(substr(s, i + 1, 1)) }
    function lin(c) { c /= 255; return c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ^ 2.4 }
    function gam(c) { c = c <= 0.0031308 ? 12.92 * c : 1.055 * c ^ (1 / 2.4) - 0.055; c = int(c * 255 + 0.5); return c < 0 ? 0 : (c > 255 ? 255 : c) }
    function cbrt(x) { return x < 0 ? -((-x) ^ (1 / 3)) : x ^ (1 / 3) }
    function to_lab(hex, k,   r, g, b, l, m, s) {
      r = lin(byte(hex, 2)); g = lin(byte(hex, 4)); b = lin(byte(hex, 6))
      l = cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
      m = cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
      s = cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
      L[k] = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s
      A[k] = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s
      B[k] = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
    }
    function color(t,   x, i, f, lv, av, bv, l, m, s) {
      t = t < 0 ? 0 : (t > 1 ? 1 : t)
      x = t * (n - 1); i = int(x); if (i > n - 2) i = n - 2; f = x - i
      lv = L[i] + (L[i + 1] - L[i]) * f
      av = A[i] + (A[i + 1] - A[i]) * f
      bv = B[i] + (B[i + 1] - B[i]) * f
      l = (lv + 0.3963377774 * av + 0.2158037573 * bv) ^ 3
      m = (lv - 0.1055613458 * av - 0.0638541728 * bv) ^ 3
      s = (lv - 0.0894841775 * av - 1.2914855480 * bv) ^ 3
      return sprintf("\033[38;2;%d;%d;%dm", \
        gam(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s), \
        gam(-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s), \
        gam(-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s))
    }
    function cell(x, y, ch) {
      out = out sprintf("\033[%d;%dH", y + 1, x + 1) color((x / (W - 1) + y / (H - 1)) / 2) ch
    }
    BEGIN {
      P["aurora"] = "#3ee8b5,#45b8f0,#8f6cf5,#e46cc8"
      P["rainbow"] = "#ff5f6d,#ffa647,#f2e35b,#5be584,#4fb8f7,#9575f0"
      P["nebula"] = "#7b2fbf,#c2389e,#5a4ff0,#3fc2f0"
      P["blackhole"] = "#3d1f6e,#7a2a8c,#e0566b,#ffb36b"
      P["warm"] = "#e8573c,#f29e4c,#f1c453,#d9486b"
      P["cool"] = "#2ec4b6,#3a86ff,#5e60ce,#48bfe3"
      P["lavender"] = "#a67cf3,#c5a4fa,#9979d9"
      P["monochrome"] = "#6a6e78,#d4d7dd,#f4f5f7,#9a9ea8"
      spec = (tolower(palette) in P) ? P[tolower(palette)] : palette
      n = split(spec, hexes, ",")
      if (n < 2) exit 1
      for (k = 1; k <= n; k++) {
        if (hexes[k] !~ /^#[0-9a-fA-F]{6}$/) exit 1
        to_lab(hexes[k], k - 1)
      }
      out = "\0337"
      for (x = 1; x < W - 1; x++) { cell(x, 0, "─"); cell(x, H - 1, "─") }
      for (y = 1; y < H - 1; y++) { cell(0, y, "│"); cell(W - 1, y, "│") }
      cell(0, 0, "╭"); cell(W - 1, 0, "╮"); cell(0, H - 1, "╰"); cell(W - 1, H - 1, "╯")
      if (title != "") {
        tc = title_hex ~ /^#[0-9a-fA-F]{6}$/ ? sprintf("\033[38;2;%d;%d;%dm", byte(title_hex, 2), byte(title_hex, 4), byte(title_hex, 6)) : color(0)
        out = out "\033[1;3H\033[1m" tc title
      }
      printf "%s\033[0m\0338", out
    }
  '
}
