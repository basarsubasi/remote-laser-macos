#!/usr/bin/env bash
# Run RemoteLaser from source with optional flags forwarded to the binary.
# Examples:
#   ./run.sh
#   ./run.sh --port 9000
#   ./run.sh --speed 0.25 --sensitivity 2.5 --port 9090
set -euo pipefail
cd "$(dirname "$0")"

exec swift run RemoteLaser "$@"