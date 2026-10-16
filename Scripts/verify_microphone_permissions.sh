#!/usr/bin/env bash
# 校验最终签名后的 App，防止重签名丢失录音权限后仍继续打包。
set -euo pipefail

APP="${1:?用法: verify_microphone_permissions.sh /path/ForNow.app}"
ENTITLEMENTS_FILE="$(mktemp)"
trap 'rm -f "$ENTITLEMENTS_FILE"' EXIT

codesign --display --entitlements - --xml "$APP" > "$ENTITLEMENTS_FILE"
if [ "$(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.device.audio-input' "$ENTITLEMENTS_FILE" 2>/dev/null)" != "true" ]; then
  echo "error: App 签名缺少麦克风 audio-input 权限，停止打包。" >&2
  exit 1
fi

if [ -z "$(/usr/libexec/PlistBuddy -c 'Print :NSMicrophoneUsageDescription' "$APP/Contents/Info.plist" 2>/dev/null)" ]; then
  echo "error: App 缺少麦克风使用说明，停止打包。" >&2
  exit 1
fi

echo "    麦克风权限声明校验 OK"
