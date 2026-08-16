#!/usr/bin/env bash
# 发布新版本：构建+签名+公证 DMG → 生成 Sparkle appcast → 部署到 Cloudflare Pages（fornow.liveby.app）。
#
# 用法：
#   NOTARY_PROFILE=ForNowNotary ./Scripts/make_release.sh
#
# 前置（一次性，见 README「发布新版本」）：
#   - Keychain 中已有 Sparkle EdDSA 私钥（generate_keys 生成，公钥在 app Info.plist 的 SUPublicEDKey）
#   - wrangler 已登录（npx wrangler whoami），Pages 项目 fornow 绑定 fornow.liveby.app
#   - 产品站点源码在 ~/AI projects/fornow_site/（本脚本只做机械替换，changelog 新条目需人工添加）
#
# 铁律：
#   - 永不删除 updates/ 里的历史 DMG（增量更新 .delta 依赖它们）
#   - appcast.xml 只由本脚本生成，不做手工修改
#   - 同名版本只发布一次（版本号只升不降）
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="ForNow"
SITE_SRC="$HOME/AI projects/fornow_site"
SITE_URL="https://fornow.liveby.app"
SPARKLE_VERSION="2.9.5"
# 工具目录路径必须稳定：Keychain 授权（ACL）绑定二进制路径，换路径会重新弹授权框。
TOOLS_DIR="$HOME/Library/Caches/ForNow/sparkle-${SPARKLE_VERSION}"

[ -d "$SITE_SRC" ] || { echo "error: 未找到站点源码 $SITE_SRC"; exit 1; }

# ── 1. 准备 Sparkle 工具（幂等：已存在则跳过）────────────────────────────
ZIP_URL="https://github.com/sparkle-project/Sparkle/releases/download/${SPARKLE_VERSION}/Sparkle-for-Swift-Package-Manager.zip"
EXPECTED_SHA="34b9b2071f3de0012eca3faa3a9290bb94e62131e9a74f6dc91514a000097a6c"
if [ ! -x "$TOOLS_DIR/bin/generate_appcast" ]; then
  echo "==> 下载 Sparkle 工具 ${SPARKLE_VERSION}"
  mkdir -p "$TOOLS_DIR"
  curl -fL "$ZIP_URL" -o "$TOOLS_DIR/sparkle.zip"
  echo "$EXPECTED_SHA  $TOOLS_DIR/sparkle.zip" | shasum -a 256 -c - >/dev/null
  unzip -qo "$TOOLS_DIR/sparkle.zip" -d "$TOOLS_DIR"
  rm "$TOOLS_DIR/sparkle.zip"
fi

# ── 2. 构建 + 签名 + 公证（复用 make_dmg.sh）─────────────────────────────
"$PWD/Scripts/make_dmg.sh"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' \
  "build/Build/Products/Release/${APP_NAME}.app/Contents/Info.plist")"
DMG="dist/${APP_NAME}-${VERSION}.dmg"
[ -f "$DMG" ] || { echo "error: 未找到 $DMG"; exit 1; }
# 保险：正式发布必须已公证。
spctl -a -t open --context context:primary-signature -vv "$DMG" >/dev/null \
  || { echo "error: DMG 未通过公证，发布中止（请带 NOTARY_PROFILE 重跑）"; exit 1; }

# ── 3. 组装部署目录（临时目录，站点源码 + updates，不污染源目录）───────────
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
for f in index.html 404.html styles.css script.js favicon.png apple-touch-icon.png og-image.png downloads _headers; do
  [ -e "$SITE_SRC/$f" ] && cp -R "$SITE_SRC/$f" "$STAGE/"
done
mkdir -p "$STAGE/updates"

# 历史 DMG 与 appcast 从站点源目录的 updates/ 延续（保持 delta 可用）。
if [ -d "$SITE_SRC/updates" ]; then
  cp -R "$SITE_SRC/updates/." "$STAGE/updates/"
fi

# ── 4. 放入新 DMG + 发布说明（与 DMG 同名、.md，自动嵌入 appcast）──────────
cp "$DMG" "$STAGE/updates/"
NOTES="${1:-}"
if [ -z "$NOTES" ] && [ -f "$SITE_SRC/updates/${APP_NAME}-${VERSION}.md" ]; then
  NOTES="$SITE_SRC/updates/${APP_NAME}-${VERSION}.md"
fi
if [ -z "$NOTES" ] || [ ! -f "$NOTES" ]; then
  NOTES="$STAGE/updates/${APP_NAME}-${VERSION}.md"
  cat > "$NOTES" <<EOF
## ForNow ${VERSION}

- 更新内容待补充（发布前编辑 $SITE_SRC/updates/${APP_NAME}-${VERSION}.md 后重新运行本脚本）
EOF
fi
cp "$NOTES" "$STAGE/updates/${APP_NAME}-${VERSION}.md"

# 最新 DMG 复制一份到 downloads/，供首页下载按钮（updates/ 是 Sparkle 更新源）。
cp "$DMG" "$STAGE/downloads/${APP_NAME}-${VERSION}.dmg"

# ── 5. 生成 appcast（在 updates 目录内跑；私钥自动从 Keychain 读取）───────
echo "==> 生成 appcast（首次会弹 Keychain 授权框，请选“始终允许”）"
"$TOOLS_DIR/bin/generate_appcast" \
  --download-url-prefix "$SITE_URL/updates/" \
  --link "$SITE_URL/" \
  "$STAGE/updates"

# ── 6. 更新首页的下载链接与版本文案（机械替换两个模式）────────────────────
sed -i '' "s|downloads/${APP_NAME}-[0-9.]*\.dmg|downloads/${APP_NAME}-${VERSION}.dmg|g" "$STAGE/index.html"
sed -i '' "s|下载 ForNow [0-9.]*|下载 ForNow ${VERSION}|g" "$STAGE/index.html"

# ── 7. 部署到 Cloudflare Pages ───────────────────────────────────────────
# 从临时目录（非 git 仓库）部署并显式指定 --branch main：否则 wrangler 会把
# 当前 git 分支名当预览部署别名，生产域（fornow.liveby.app）不更新。
echo "==> 部署到 Cloudflare Pages（项目 fornow，生产分支 main）"
(cd "$STAGE" && npx --yes wrangler pages deploy . --project-name fornow --branch main)

# ── 8. 把更新产物落回站点源目录（updates/ 与 downloads/，供下次发布延续）───
mkdir -p "$SITE_SRC/updates"
cp -R "$STAGE/updates/." "$SITE_SRC/updates/"
cp "$DMG" "$SITE_SRC/downloads/${APP_NAME}-${VERSION}.dmg"

# ── 9. 验证输出 ─────────────────────────────────────────────────────────
echo "==> 完成。验证："
echo "    appcast: $SITE_URL/updates/appcast.xml"
echo "    DMG:     $SITE_URL/downloads/${APP_NAME}-${VERSION}.dmg"
curl -fsSL "$SITE_URL/updates/appcast.xml" | head -5 \
  || echo "    （CDN 缓存可能未刷新，稍等 1–2 分钟再试）"
