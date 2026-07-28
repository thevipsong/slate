#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "$script_dir/.." && pwd)"
android_root="$project_root/android"
output_dir="$project_root/Dist"
properties_path="$android_root/keystore.properties"

if [[ -z "${JAVA_HOME:-}" && -d /opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home ]]; then
  export JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home
fi

if [[ -z "${ANDROID_HOME:-}" ]]; then
  user_home="$(cd && pwd)"
  export ANDROID_HOME="$user_home/Library/Android/sdk"
fi

if [[ ! -f "$properties_path" ]]; then
  echo "缺少发布签名配置。请先运行 ./Scripts/generate-android-signing.sh。" >&2
  exit 1
fi

mkdir -p "$output_dir"
(
  cd "$android_root"
  ./gradlew testDebugUnitTest assembleRelease
)

source_apk="$android_root/app/build/outputs/apk/release/app-release.apk"
target_apk="$output_dir/Slate-Android-release.apk"
cp "$source_apk" "$target_apk"

apksigner_path="$ANDROID_HOME/build-tools/36.0.0/apksigner"
if [[ -x "$apksigner_path" ]]; then
  "$apksigner_path" verify --verbose "$target_apk"
fi

echo "Android 发布版 APK: $target_apk"
