#!/bin/sh
# Builds WorklogBar.app without Xcode (no widget extension — that needs
# full Xcode; see project.yml). Output: build/WorklogBar.app
set -e
cd "$(dirname "$0")"

swift build -c release

APP=build/WorklogBar.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/WorklogBar "$APP/Contents/MacOS/WorklogBar"

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.worklogbar.app</string>
    <key>CFBundleName</key>
    <string>WorklogBar</string>
    <key>CFBundleDisplayName</key>
    <string>WorklogBar</string>
    <key>CFBundleExecutable</key>
    <string>WorklogBar</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.1</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

codesign --force -s - "$APP"
echo "Built $APP"
