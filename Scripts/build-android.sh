#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "$script_dir/.." && pwd)"
android_root="$project_root/android"
output_dir="$project_root/Dist"

if [[ -z "${JAVA_HOME:-}" && -d /opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home ]]; then
  export JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home
fi

if [[ -z "${ANDROID_HOME:-}" ]]; then
  user_home="$(cd && pwd)"
  export ANDROID_HOME="$user_home/Library/Android/sdk"
fi

if [[ ! -x "$android_root/gradlew" ]]; then
  echo "缺少 Android Gradle Wrapper。" >&2
  exit 1
fi

mkdir -p "$output_dir"
(
  cd "$android_root"
  ./gradlew testDebugUnitTest assembleDebug
)

cp "$android_root/app/build/outputs/apk/debug/app-debug.apk" \
  "$output_dir/序事-Android-debug.apk"

echo "Android APK: $output_dir/序事-Android-debug.apk"
