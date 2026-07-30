#!/bin/zsh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="${SLATE_APP_NAME:-序事}"
BUNDLE_ID="${SLATE_BUNDLE_ID:-com.thevipsong.slate}"
APP_VERSION="${SLATE_VERSION:-1.0.0}"
BUILD_NUMBER="${SLATE_BUILD_NUMBER:-1}"
SIGNING_IDENTITY="${SLATE_SIGNING_IDENTITY:--}"
bundle_id_pattern='^[A-Za-z0-9]+([.-][A-Za-z0-9]+)+$'
version_pattern='^[0-9]+(\.[0-9]+){1,2}([.-][0-9A-Za-z.-]+)?$'
build_number_pattern='^[1-9][0-9]*$'

if [[ -z "$APP_NAME" || "$APP_NAME" == "." || "$APP_NAME" == ".." || "$APP_NAME" == */* || "$APP_NAME" == *:* || "$APP_NAME" == *[[:cntrl:]]* ]]; then
    echo "SLATE_APP_NAME 不能为空，且不能包含斜杠、冒号或控制字符。" >&2
    exit 1
fi

if [[ ! "$BUNDLE_ID" =~ $bundle_id_pattern ]]; then
    echo "SLATE_BUNDLE_ID 不是有效的反向域名标识。" >&2
    exit 1
fi

if [[ ! "$APP_VERSION" =~ $version_pattern ]]; then
    echo "SLATE_VERSION 不是有效版本号。" >&2
    exit 1
fi

if [[ ! "$BUILD_NUMBER" =~ $build_number_pattern ]]; then
    echo "SLATE_BUILD_NUMBER 必须是正整数。" >&2
    exit 1
fi

BUILD_DIR="$PROJECT_DIR/.build/release"
OUTPUT_DIR="$PROJECT_DIR/Dist"
APP_DIR="$OUTPUT_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

cd "$PROJECT_DIR"
swift build -c release --disable-sandbox

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$BUILD_DIR/TodoList" "$MACOS_DIR/TodoList"

# 复制 app 图标（如存在）
if [ -f "$PROJECT_DIR/Resources/AppIcon.icns" ]; then
    cp "$PROJECT_DIR/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

plutil -create xml1 "$CONTENTS_DIR/Info.plist"
plutil -insert CFBundleName -string "$APP_NAME" "$CONTENTS_DIR/Info.plist"
plutil -insert CFBundleDisplayName -string "$APP_NAME" "$CONTENTS_DIR/Info.plist"
plutil -insert CFBundleIdentifier -string "$BUNDLE_ID" "$CONTENTS_DIR/Info.plist"
plutil -insert CFBundleExecutable -string "TodoList" "$CONTENTS_DIR/Info.plist"
plutil -insert CFBundleIconFile -string "AppIcon" "$CONTENTS_DIR/Info.plist"
plutil -insert CFBundlePackageType -string "APPL" "$CONTENTS_DIR/Info.plist"
plutil -insert CFBundleShortVersionString -string "$APP_VERSION" "$CONTENTS_DIR/Info.plist"
plutil -insert CFBundleVersion -string "$BUILD_NUMBER" "$CONTENTS_DIR/Info.plist"
plutil -insert LSMinimumSystemVersion -string "15.0" "$CONTENTS_DIR/Info.plist"
plutil -insert LSUIElement -bool true "$CONTENTS_DIR/Info.plist"
plutil -insert NSHighResolutionCapable -bool true "$CONTENTS_DIR/Info.plist"

if [[ "$SIGNING_IDENTITY" == "-" ]]; then
    codesign --force --sign - "$MACOS_DIR/TodoList"
    codesign --force --sign - "$APP_DIR"
else
    codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$MACOS_DIR/TodoList"
    codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$APP_DIR"
fi

echo "已生成：$APP_DIR ($BUNDLE_ID, $APP_VERSION/$BUILD_NUMBER)"
