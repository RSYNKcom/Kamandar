#!/usr/bin/env bash
# Stop and remove the Kamandar launchd web-app service. Leaves .env + logs alone.
set -euo pipefail

LABEL="com.kamandar.serve"
DEST="$HOME/Library/LaunchAgents/$LABEL.plist"
DOMAIN="gui/$(id -u)"

launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
rm -f "$DEST"
echo "kamandar: service '$LABEL' stopped and removed."
