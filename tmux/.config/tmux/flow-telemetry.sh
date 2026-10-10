#!/usr/bin/env bash
# flow-telemetry.sh — Evidence-based personal flow & deep work telemetry launcher.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$SCRIPT_DIR/flow-telemetry.py" "$@"
