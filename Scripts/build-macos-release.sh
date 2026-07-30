#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "$script_dir/.." && pwd)"
output_dir="$project_root/Dist"
app_name="${SLATE_APP_NAME:-序事}"
app_path="$output_dir/$app_name.app"
archive_path="$output_dir/$app_name-macOS-${SLATE_VERSION:-unknown}.zip"
checksum_path="$archive_path.sha256"

required_variables=(
  SLATE_VERSION
  SLATE_BUILD_NUMBER
  SLATE_SIGNING_IDENTITY
  SLATE_NOTARY_PROFILE
)

for variable_name in "${required_variables[@]}"; do
  if [[ -z "${!variable_name:-}" ]]; then
    echo "缺少发布参数：$variable_name" >&2
    exit 1
  fi
done

if [[ ! "$SLATE_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]]; then
  echo "SLATE_VERSION 必须是语义化版本号，例如 1.1.0。" >&2
  exit 1
fi

if [[ ! "$SLATE_BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]]; then
  echo "SLATE_BUILD_NUMBER 必须是正整数。" >&2
  exit 1
fi

if [[ "$SLATE_SIGNING_IDENTITY" == "-" ]]; then
  echo "正式发布必须使用 Developer ID Application 签名，不能使用临时签名。" >&2
  exit 1
fi

if ! command -v xcrun >/dev/null 2>&1; then
  echo "未找到 xcrun；请安装完整 Xcode。" >&2
  exit 1
fi

if ! xcrun --find notarytool >/dev/null 2>&1; then
  echo "未找到 notarytool；请使用包含公证工具的 Xcode。" >&2
  exit 1
fi

export SLATE_BUNDLE_ID="${SLATE_BUNDLE_ID:-com.thevipsong.slate}"
if [[ ! "$SLATE_BUNDLE_ID" =~ ^[A-Za-z0-9]+([.-][A-Za-z0-9]+)+$ ]]; then
  echo "SLATE_BUNDLE_ID 不是有效的反向域名标识。" >&2
  exit 1
fi

"$script_dir/build-app.sh"

if [[ ! -f "$app_path/Contents/Resources/AppIcon.icns" ]]; then
  echo "正式发布包缺少 AppIcon.icns。" >&2
  exit 1
fi

codesign --verify --deep --strict --verbose=2 "$app_path"

rm -f "$archive_path" "$checksum_path"
ditto -c -k --keepParent "$app_path" "$archive_path"

xcrun notarytool submit "$archive_path" \
  --keychain-profile "$SLATE_NOTARY_PROFILE" \
  --wait

xcrun stapler staple "$app_path"
xcrun stapler validate "$app_path"
codesign --verify --deep --strict --verbose=2 "$app_path"
spctl --assess --type execute --verbose=4 "$app_path"

rm -f "$archive_path"
ditto -c -k --keepParent "$app_path" "$archive_path"
shasum -a 256 "$archive_path" > "$checksum_path"

echo "macOS 正式发布包：$archive_path"
echo "SHA-256：$checksum_path"
