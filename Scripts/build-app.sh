#!/bin/zsh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Slate"
BUILD_DIR="$PROJECT_DIR/.build/release"
OUTPUT_DIR="$PROJECT_DIR/Dist"
APP_DIR="$OUTPUT_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

cd "$PROJECT_DIR"
swift build -c release --disable-sandbox

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$BUILD_DIR/TodoList" "$MACOS_DIR/TodoList"

# 复制 app 图标（如存在）
if [ -f "$PROJECT_DIR/Resources/AppIcon.icns" ]; then
    cp "$PROJECT_DIR/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

plutil -create xml1 "$CONTENTS_DIR/Info.plist"
plutil -insert CFBundleName -string "$APP_NAME" "$CONTENTS_DIR/Info.plist"
plutil -insert CFBundleDisplayName -string "$APP_NAME" "$CONTENTS_DIR/Info.plist"
plutil -insert CFBundleIdentifier -string "app.local.Slate" "$CONTENTS_DIR/Info.plist"
plutil -insert CFBundleExecutable -string "TodoList" "$CONTENTS_DIR/Info.plist"
plutil -insert CFBundleIconFile -string "AppIcon" "$CONTENTS_DIR/Info.plist"
plutil -insert CFBundlePackageType -string "APPL" "$CONTENTS_DIR/Info.plist"
plutil -insert CFBundleShortVersionString -string "1.0.0" "$CONTENTS_DIR/Info.plist"
plutil -insert CFBundleVersion -string "1" "$CONTENTS_DIR/Info.plist"
plutil -insert LSMinimumSystemVersion -string "15.0" "$CONTENTS_DIR/Info.plist"
plutil -insert NSHighResolutionCapable -bool true "$CONTENTS_DIR/Info.plist"

codesign --force --deep --sign - "$APP_DIR"

echo "已生成：$APP_DIR"
