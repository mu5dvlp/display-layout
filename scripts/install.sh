#!/bin/zsh
# DisplayLayout をビルドして ~/Applications に .app として配置し、
# ログイン項目(System Events)に登録してログイン時に自動起動するよう設定する。更新時も再実行するだけでよい。
# ※ LaunchAgent ではなくログイン項目を使う理由: ad-hoc署名 + LaunchAgent だと macOS が
#   起動のたびに「バックグラウンドでのアクティビティ」通知を出すため。
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$HOME/Applications/DisplayLayout.app"
BUNDLE_ID="com.reimiogi.displaylayout"
PLIST="$HOME/Library/LaunchAgents/$BUNDLE_ID.plist"  # 旧LaunchAgent方式からの移行措置

cd "$PROJECT_DIR"
swift build -c release

# 既存インスタンスを止めてから差し替える
# 旧LaunchAgent方式からの移行措置: 旧エージェントが残っていれば解除して plist も削除
launchctl bootout "gui/$(id -u)/$BUNDLE_ID" 2>/dev/null || true
rm -f "$PLIST"
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

# ログイン項目に登録(重複防止のため既存エントリを削除してから追加)
osascript <<EOF
tell application "System Events"
    repeat while (exists login item "DisplayLayout")
        delete login item "DisplayLayout"
    end repeat
    make login item at end with properties {path:"$APP_DIR", hidden:true}
end tell
EOF

open "$APP_DIR"
echo "インストール完了: $APP_DIR"
echo "ログイン項目登録完了: DisplayLayout (hidden)"
