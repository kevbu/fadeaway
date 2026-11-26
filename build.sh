#!/bin/zsh
# Builds FadeAway.app next to this script. Pass "install" to copy it to ~/Applications.
set -euo pipefail
cd "$(dirname "$0")"

APP="build/FadeAway.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Info.plist "$APP/Contents/Info.plist"
swift build -c release
BIN="$(swift build -c release --show-bin-path)"
cp "$BIN/FadeAway" "$APP/Contents/MacOS/FadeAway"

# App Intents metadata (Focus Filter). SwiftPM does not run the processor, so run it here.
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
TARGET="$(uname -m)-apple-macos13.0"
SOURCES=(Sources/FadeAway/*.swift)
echo '["AppIntent","EntityQuery","AppEntity","TransientEntity","AppEnum","AppShortcutProviding","AppShortcutsProvider","AnyResolverProviding","AppIntentsPackage","DynamicOptionsProvider","SetFocusFilterIntent"]' > "$TMP/protocols.json"
swiftc -typecheck -wmo -swift-version 5 -module-name FadeAway -target "$TARGET" -I "$BIN" \
  "${SOURCES[@]}" \
  -emit-const-values-path "$TMP/FadeAway.swiftconstvalues" \
  -Xfrontend -const-gather-protocols-file -Xfrontend "$TMP/protocols.json"
printf '%s\n' "${SOURCES[@]:a}" > "$TMP/sources.txt"
echo "$TMP/FadeAway.swiftconstvalues" > "$TMP/constvalues.txt"
xcrun appintentsmetadataprocessor \
  --output "$APP/Contents/Resources" \
  --toolchain-dir "$(xcode-select -p)/Toolchains/XcodeDefault.xctoolchain" \
  --module-name FadeAway \
  --sdk-root "$(xcrun --show-sdk-path)" \
  --xcode-version "$(xcodebuild -version | awk '/Build version/ { print $3 }')" \
  --platform-family macOS \
  --deployment-target 13.0 \
  --target-triple "$TARGET" \
  --source-file-list "$TMP/sources.txt" \
  --swift-const-vals-list "$TMP/constvalues.txt" \
  --force
if [[ ! -f "$APP/Contents/Resources/Metadata.appintents/extract.actionsdata" ]]; then
  echo "error: App Intents metadata was not generated" >&2
  exit 1
fi

# The Focus Filter needs a Team ID: linkd rejects ad-hoc signed apps ("requiresValidatedBundle"),
# and System Settings then keeps "Add" disabled. Use SIGN_IDENTITY, else the first Apple Development identity.
IDENTITY="${SIGN_IDENTITY:-$(security find-identity -v -p codesigning | awk -F'"' '/Apple Development/ { print $2; exit }')}"
if [[ -z "$IDENTITY" ]]; then
  IDENTITY="-"
  echo "warning: no Apple Development identity found, signing ad-hoc. The Focus Filter will not work." >&2
fi
codesign --force --sign "$IDENTITY" "$APP"
echo "Built $APP (signed with: $IDENTITY)"

if [[ "${1:-}" == "install" ]]; then
  mkdir -p ~/Applications
  rm -rf ~/Applications/FadeAway.app
  cp -R "$APP" ~/Applications/
  echo "Installed to ~/Applications/FadeAway.app"
fi
