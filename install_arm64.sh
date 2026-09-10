#!/bin/bash
# Modern ARM64 entry point. See PORTING.md for supported hardware.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
exec ./install-2mic.sh "$@"
