#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

BUNDLE_ID="com.remotelaser.app"
INSTALL_PATH="/Applications/RemoteLaser.app"
LAUNCH_PLIST="$HOME/Library/LaunchAgents/${BUNDLE_ID}.plist"

echo "Stopping RemoteLaser if running..."
pkill -x RemoteLaser 2>/dev/null || true
osascript -e 'tell application "RemoteLaser" to quit' 2>/dev/null || true

if [ -f "$LAUNCH_PLIST" ]; then
  launchctl unload "$LAUNCH_PLIST" 2>/dev/null || true
  rm -f "$LAUNCH_PLIST"
  echo "Removed LaunchAgent: $LAUNCH_PLIST"
fi

if [ -d "$INSTALL_PATH" ]; then
  rm -rf "$INSTALL_PATH"
  echo "Removed $INSTALL_PATH"
fi

rm -rf build .build Package.resolved
echo "Removed build artifacts."

tccutil reset Accessibility "$BUNDLE_ID" 2>/dev/null || true
tccutil reset All "$BUNDLE_ID" 2>/dev/null || true
echo "Reset TCC entries for $BUNDLE_ID (vestigial for phase 1 — no permissions are actually required)."

echo "Uninstall complete."