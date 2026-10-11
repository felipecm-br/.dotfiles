#!/usr/bin/env bash
# cockpit-snapshot.sh — shell wrapper for cockpit-snapshot.py
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$SCRIPT_DIR/cockpit-snapshot.py" "$@"
