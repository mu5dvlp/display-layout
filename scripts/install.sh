#!/bin/zsh
# DisplayLayout をビルドして ~/Applications に .app として配置し、
# LaunchAgent でログイン時に自動起動するよう登録する。更新時も再実行するだけでよい。
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$HOME/Applications/DisplayLayout.app"
BUNDLE_ID="com.reimiogi.displaylayout"
PLIST="$HOME/Library/LaunchAgents/$BUNDLE_ID.plist"

cd "$PROJECT_DIR"
swift build -c release

# 既存インスタンスを止めてから差し替える
launchctl bootout "gui/$(id -u)/$BUNDLE_ID" 2>/dev/null || true
pkill -f "DisplayLayout.app/Contents/MacOS/DisplayLayout" 2>/dev/null || true

mkdir -p "$APP_DIR/Contents/MacOS"
cp .build/release/DisplayLayout "$APP_DIR/Contents/MacOS/DisplayLayout"

cat > "$APP_DIR/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>DisplayLayout</string>
    <key>CFBundleExecutable</key>
    <string>DisplayLayout</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

codesign --force --sign - "$APP_DIR" 2>/dev/null || true

mkdir -p "$(dirname "$PLIST")"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$BUNDLE_ID</string>
    <key>Program</key>
    <string>$APP_DIR/Contents/MacOS/DisplayLayout</string>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
    <key>AssociatedBundleIdentifiers</key>
    <string>$BUNDLE_ID</string>
</dict>
</plist>
EOF

launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "インストール完了: $APP_DIR"
echo "自動起動登録: $PLIST"
