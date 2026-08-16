#!/usr/bin/env bash
# 构建 Release 版"搁这儿"，用 Developer ID 签名（若有），打包为 .dmg，并可选公证+装订。
#
# 用法：
#   ./Scripts/make_dmg.sh                      # 构建 + 签名 + 打包
#   NOTARY_PROFILE=ForNowNotary ./Scripts/make_dmg.sh   # 额外：提交 Apple 公证并装订
#
# 公证前先一次性存好凭据（二选一）：
#   API Key： xcrun notarytool store-credentials "ForNowNotary" \
#               --key /path/AuthKey_XXXXXXXXXX.p8 --key-id XXXXXXXXXX --issuer <issuer-uuid>
#   Apple ID：xcrun notarytool store-credentials "ForNowNotary" \
#               --apple-id <email> --team-id 8NF4K823FV --password <app 专用密码>
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="ForNow"
VOL_NAME="搁这儿"
CONFIG="Release"
DERIVED="$(pwd)/build"

# 自动选用 Developer ID Application 证书；没有则回退 ad-hoc。
SIGN_ID="$(security find-identity -v -p codesigning | awk -F'"' '/Developer ID Application/{print $2; exit}')"
if [ -n "$SIGN_ID" ]; then HARDEN=1; else SIGN_ID="-"; HARDEN=0; fi
echo "==> 签名身份：$SIGN_ID"

echo "==> XcodeGen"
xcodegen generate >/dev/null
echo "==> Building $CONFIG"
xcodebuild -scheme "$APP_NAME" -configuration "$CONFIG" -derivedDataPath "$DERIVED" build >/dev/null

APP="$DERIVED/Build/Products/$CONFIG/$APP_NAME.app"
[ -d "$APP" ] || { echo "error: 未找到 $APP"; exit 1; }

echo "==> 签名 App"
if [ "$HARDEN" = 1 ]; then
  # --deep：递归重签嵌套二进制（Sparkle.framework 内的 Autoupdate/Updater.app
  # 出厂为 ad-hoc 签名，公证要求 Developer ID + 安全时间戳）。
  codesign --deep --force --options runtime --timestamp --sign "$SIGN_ID" "$APP"
else
  codesign --force --sign "-" "$APP"
fi
codesign --verify --strict "$APP" && echo "    签名校验 OK"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist" 2>/dev/null || echo 0.0.0)"
DIST="$(pwd)/dist"; mkdir -p "$DIST"
DMG="$DIST/${APP_NAME}-${VERSION}.dmg"; rm -f "$DMG"

STAGE="$(mktemp -d)"; trap 'rm -rf "$STAGE"' EXIT
cp -R "$APP" "$STAGE/$APP_NAME.app"
ln -s /Applications "$STAGE/Applications"

echo "==> 打包 DMG"
hdiutil create -volname "$VOL_NAME" -srcfolder "$STAGE" -fs HFS+ -ov -format UDZO "$DMG" >/dev/null
[ "$HARDEN" = 1 ] && { echo "==> 签名 DMG"; codesign --force --timestamp --sign "$SIGN_ID" "$DMG"; }

# 可选：提交 Apple 公证并装订到 DMG。
if [ -n "${NOTARY_PROFILE:-}" ]; then
  echo "==> 提交公证（profile: ${NOTARY_PROFILE}，等待结果…）"
  xcrun notarytool submit "$DMG" --keychain-profile "${NOTARY_PROFILE}" --wait
  echo "==> 装订公证票据"
  xcrun stapler staple "$DMG"
  xcrun stapler validate "$DMG" && echo "    装订校验 OK"
  spctl -a -t open --context context:primary-signature -vv "$DMG" 2>&1 | sed 's/^/    /' || true
else
  echo "==> 跳过公证（未设置 NOTARY_PROFILE）"
fi

echo "==> 完成：$DMG"
du -h "$DMG" | cut -f1 | sed 's/^/    大小: /'
echo "    版本: $VERSION"
