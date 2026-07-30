#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "$script_dir/.." && pwd)"
private_dir="$project_root/Private"
keystore_path="$private_dir/slate-release.jks"
properties_path="$project_root/android/keystore.properties"

if [[ -e "$keystore_path" || -e "$properties_path" ]]; then
  echo "签名文件已存在；为避免破坏后续升级能力，本次未覆盖。" >&2
  exit 1
fi

if [[ -z "${JAVA_HOME:-}" && -d /opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home ]]; then
  export JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home
fi

keytool_path="${JAVA_HOME:+$JAVA_HOME/bin/}keytool"
if ! command -v "$keytool_path" >/dev/null 2>&1; then
  echo "找不到 keytool，请先安装 JDK 17 或更高版本。" >&2
  exit 1
fi

umask 077
mkdir -p "$private_dir"

store_password="$(openssl rand -hex 24)"
key_password="$store_password"

"$keytool_path" -genkeypair \
  -keystore "$keystore_path" \
  -storetype PKCS12 \
  -storepass "$store_password" \
  -keypass "$key_password" \
  -alias slate \
  -keyalg RSA \
  -keysize 4096 \
  -validity 10000 \
  -dname "CN=Slate, OU=Mobile, O=Slate, L=Shanghai, ST=Shanghai, C=CN"

{
  printf 'storeFile=../Private/slate-release.jks\n'
  printf 'storePassword=%s\n' "$store_password"
  printf 'keyAlias=slate\n'
  printf 'keyPassword=%s\n' "$key_password"
} > "$properties_path"

echo "已生成 Android 发布签名：$keystore_path"
echo "请将 Private 目录与 android/keystore.properties 离线备份；丢失后将无法覆盖升级同一 App。"
