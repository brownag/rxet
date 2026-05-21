#!/bin/bash
# xet-sync: Simple wrapper for batch model downloading/syncing
# Usage: ./xet-sync.sh models.json [--force] [--check-only]

set -e

CONFIG="${1:-.models.json}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check prerequisites
if [ -z "$HF_TOKEN" ]; then
    echo "Error: HF_TOKEN not set"
    echo "Set it with: export HF_TOKEN='hf_...'"
    exit 1
fi

if [ ! -f "$CONFIG" ]; then
    echo "Error: Config file not found: $CONFIG"
    exit 1
fi

# Run sync
Rscript "$SCRIPT_DIR/xet-sync.R" "$CONFIG" "$@"
