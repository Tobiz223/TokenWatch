#!/usr/bin/env bash
# Build a real, double-clickable TokenWatch.app (macOS menu bar app).
# Run on macOS:  bash scripts/build-app.sh   then double-click TokenWatch.app
set -euo pipefail
cd "$(dirname "$0")/.."

echo "→ Building release binary…"
swift build -c release

BIN_DIR="$(swift build -c release --show-bin-path)"
APP="TokenWatch.app"
CONTENTS="$APP/Contents"

rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"

cp "$BIN_DIR/TokenWatch" "$CONTENTS/MacOS/TokenWatch"

# Copy the SwiftPM resource bundle (pricing.json) next to the binary so
# Bundle.module resolves it. The app also has a hard-coded fallback, so this
# is best-effort.
for b in "$BIN_DIR"/*.bundle; do
  [ -e "$b" ] && cp -R "$b" "$CONTENTS/MacOS/" || true
done

cat > "$CONTENTS/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>              <string>TokenWatch</string>
  <key>CFBundleDisplayName</key>       <string>TokenWatch</string>
  <key>CFBundleIdentifier</key>        <string>com.tokenwatch.app</string>
  <key>CFBundleVersion</key>           <string>1.0</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundlePackageType</key>       <string>APPL</string>
  <key>CFBundleExecutable</key>        <string>TokenWatch</string>
  <key>LSMinimumSystemVersion</key>    <string>13.0</string>
  <key>LSUIElement</key>               <true/>
</dict>
</plist>
PLIST

echo "✓ Built $APP"
echo "  Double-click it, or run: open $APP"
