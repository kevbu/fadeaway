#!/bin/zsh
# Builds FadeAway.app next to this script. Pass "install" to copy it to ~/Applications.
set -euo pipefail
cd "$(dirname "$0")"

APP="build/FadeAway.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp Info.plist "$APP/Contents/Info.plist"
swiftc -O -swift-version 5 main.swift -o "$APP/Contents/MacOS/FadeAway"
codesign --force --sign - "$APP"
echo "Built $APP"

if [[ "${1:-}" == "install" ]]; then
  mkdir -p ~/Applications
  rm -rf ~/Applications/FadeAway.app
  cp -R "$APP" ~/Applications/
  echo "Installed to ~/Applications/FadeAway.app"
fi
