#!/usr/bin/env bash
# Toggle CPU info popup
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
exec bash "$SCRIPT_DIR/toggle-popup.sh" cpuinfo "$SCRIPT_DIR/cpuinfo-popup.py"
