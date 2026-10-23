#!/usr/bin/env bash
# Read the live ZMK keymap from the keyboard (read-only) and draw every layer.
# Usage: scripts/zmk-keymap/run.sh [port] [--offline]
#   port       Studio RPC serial port (default /dev/ttyACM1)
#   --offline  skip the keyboard and re-render from the committed JSON snapshot
# Close any ZMK Studio tab first: only one process can hold the serial port.
# See docs/desktop/eyelash-sofle-keyboard.md.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
STUDIO="${ZMK_STUDIO_DIR:-$HOME/dev/github/zmk-studio}"
OUT="$repo/assets/keyboard"
NAME="eyelash-sofle-keymap"
PORT="/dev/ttyACM1"
OFFLINE=0
for arg in "$@"; do
  case "$arg" in
    --offline) OFFLINE=1 ;;
    *) PORT="$arg" ;;
  esac
done

[[ -d "$STUDIO/node_modules" ]] || {
  echo "ZMK Studio checkout with node_modules not found at $STUDIO (set ZMK_STUDIO_DIR)" >&2
  exit 1
}

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

if (( ! OFFLINE )); then
  NODE_PATH="$STUDIO/node_modules" "$STUDIO/node_modules/.bin/esbuild" "$here/dump-keymap.mjs" \
    --bundle --platform=node --format=esm --log-level=warning --outfile="$work/dump.mjs"
  node "$work/dump.mjs" "$PORT" "$OUT/$NAME.json"
fi

ZMK_STUDIO_DIR="$STUDIO" node "$here/render-keymap.mjs" "$OUT/$NAME.json" "$work" "$OUT/$NAME-table.md"

draw() { uvx -q --from keymap-drawer keymap draw "$work/keymap.yaml" "$@"; }
draw > "$OUT/$NAME.svg"
mapfile -t layers < <(node -e 'for (const l of require(process.argv[1]).keymap.layers) console.log(l.name)' "$OUT/$NAME.json")
pages=()
for layer in "${layers[@]}"; do
  draw --select-layers "$layer" > "$work/layer-$layer.svg"
  pages+=("$work/layer-$layer.svg")
done
# Page 1 is the full overview; then one page per layer.
rsvg-convert -f pdf -b white -o "$OUT/$NAME.pdf" "$OUT/$NAME.svg" "${pages[@]}"
echo "updated $OUT/$NAME.{json,svg,pdf} and $NAME-table.md"
