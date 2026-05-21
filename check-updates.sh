#!/bin/bash
# check-updates: Monitor for upstream model changes
# Run periodically (e.g., via cron) to detect when models are updated

CONFIG="${1:-.models.json}"
LOG_FILE="${2:-model-updates.log}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -z "$HF_TOKEN" ]; then
    echo "Error: HF_TOKEN not set"
    exit 1
fi

if [ ! -f "$CONFIG" ]; then
    echo "Error: Config file not found: $CONFIG"
    exit 1
fi

# Check for updates (no downloads)
CHANGES=$(Rscript "$SCRIPT_DIR/xet-sync.R" "$CONFIG" --check-only 2>&1 | grep "UPDATE\|DOWNLOAD (new)" || true)

if [ -n "$CHANGES" ]; then
    {
        echo "=== Updates found at $(date) ==="
        echo "$CHANGES"
        echo ""
    } >> "$LOG_FILE"

    echo "Model updates detected! See $LOG_FILE for details."

    # Optional: send notification
    # echo "Model updates available" | mail -s "XET Sync Alert" user@example.com

    exit 0
else
    echo "No updates found."
    exit 0
fi
