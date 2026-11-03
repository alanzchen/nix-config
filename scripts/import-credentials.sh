#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec nix shell "$ROOT#credential-python" --no-write-lock-file --command python3 "$ROOT/scripts/import-credentials.py" "$@"
