#!/usr/bin/env bash
# 从站点已保存的版本化安装包重新生成 Sparkle appcast，并部署修正后的更新源。
# 用于调整 feed 级元数据（如完整版本历史链接），不会重新构建或发布同名 DMG。
set -euo pipefail

SITE_SRC="${SITE_SRC:-$HOME/AI projects/fornow_site}"
SITE_URL="https://fornow.liveby.app"
SPARKLE_VERSION="2.9.5"
TOOLS_DIR="$HOME/Library/Caches/ForNow/sparkle-${SPARKLE_VERSION}"
GENERATE_APPCAST="$TOOLS_DIR/bin/generate_appcast"

[ -d "$SITE_SRC/updates" ] || { echo "error: 未找到 $SITE_SRC/updates"; exit 1; }
[ -x "$GENERATE_APPCAST" ] || { echo "error: 未找到 $GENERATE_APPCAST"; exit 1; }
[ -x "$SITE_SRC/deploy.sh" ] || { echo "error: 未找到 $SITE_SRC/deploy.sh"; exit 1; }

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp -R "$SITE_SRC/updates/." "$STAGE/"

# generate_appcast 只会把 --full-release-notes-url 写入新条目；移除临时副本中的
# 旧 feed 后重建，确保保留的每个版本都有一致的完整版本历史入口。
rm -f "$STAGE/appcast.xml"
"$GENERATE_APPCAST" \
  --download-url-prefix "$SITE_URL/updates/" \
  --link "$SITE_URL/" \
  --full-release-notes-url "$SITE_URL/#update" \
  "$STAGE"

ITEM_COUNT="$(grep -c '<item>' "$STAGE/appcast.xml")"
FULL_NOTES_COUNT="$(grep -c '<sparkle:fullReleaseNotesLink>https://fornow.liveby.app/#update</sparkle:fullReleaseNotesLink>' "$STAGE/appcast.xml")"
[ "$ITEM_COUNT" -gt 0 ] && [ "$ITEM_COUNT" -eq "$FULL_NOTES_COUNT" ] \
  || { echo "error: appcast 的完整版本历史链接不完整"; exit 1; }
cp "$STAGE/appcast.xml" "$SITE_SRC/updates/appcast.xml"

"$SITE_SRC/deploy.sh"

echo "==> appcast 已重新生成并部署：$SITE_URL/updates/appcast.xml"
