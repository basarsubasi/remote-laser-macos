#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

BUNDLE_ID="com.remotelaser.app"
INSTALL_PATH="/Applications/RemoteLaser.app"
LAUNCH_PLIST="$HOME/Library/LaunchAgents/${BUNDLE_ID}.plist"

ENABLE_AUTOSTART=${1:-no}

./build.sh

echo "Installing to $INSTALL_PATH..."
rm -rf "$INSTALL_PATH"
cp -R build/RemoteLaser.app "$INSTALL_PATH"

if [ "$ENABLE_AUTOSTART" = "autostart" ]; then
  cat > "$LAUNCH_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>${BUNDLE_ID}</string>
  <key>ProgramArguments</key>
  <array>
    <string>${INSTALL_PATH}/Contents/MacOS/RemoteLaser</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><false/>
</dict>
</plist>
PLIST
  launchctl unload "$LAUNCH_PLIST" 2>/dev/null || true
  launchctl load "$LAUNCH_PLIST"
  echo "LaunchAgent created (auto-starts on login)."
else
  rm -f "$LAUNCH_PLIST"
  launchctl unload "$LAUNCH_PLIST" 2>/dev/null || true
fi

echo "Opening RemoteLaser..."
open "$INSTALL_PATH"

echo "Installed at $INSTALL_PATH"