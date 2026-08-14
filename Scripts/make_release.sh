#!/usr/bin/env bash
# 发布新版本：构建+签名+公证 DMG → 写入 gh-pages 分支 → 生成 Sparkle appcast → 推送 → 可选 GitHub Release。
#
# 用法：
#   NOTARY_PROFILE=ForNowNotary ./Scripts/make_release.sh                     # 完整发布
#   SKIP_GITHUB_RELEASE=1 NOTARY_PROFILE=ForNowNotary ./Scripts/make_release.sh   # 只推 Pages，不建 Release
#
# 前置（一次性，见 README「发布新版本」）：
#   - Keychain 中已有 Sparkle EdDSA 私钥（generate_keys 生成，公钥在 app Info.plist 的 SUPublicEDKey）
#   - 仓库已启用 GitHub Pages（source = gh-pages 分支根目录）
#
# 铁律：
#   - 永不删除 updates/ 和 old_updates/ 里的历史 DMG（增量更新 .delta 依赖它们）
#   - appcast.xml 只由本脚本生成，不做手工修改
#   - 同名版本只发布一次（版本号只升不降）
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="ForNow"
PAGES_SITE="https://febtancot.github.io/ForNow"
SPARKLE_VERSION="2.9.5"
# 工具目录路径必须稳定：Keychain 授权（ACL）绑定二进制路径，换路径会重新弹授权框。
TOOLS_DIR="$HOME/Library/Caches/ForNow/sparkle-${SPARKLE_VERSION}"
WORKTREE=".gh-pages"
UPDATES_DIR="$WORKTREE/updates"

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

# ── 3. gh-pages 工作树（幂等）───────────────────────────────────────────
if ! git worktree list | grep -q " $WORKTREE "; then
  if git show-ref --verify --quiet refs/remotes/origin/gh-pages; then
    git worktree add "$WORKTREE" origin/gh-pages
  else
    # 首次：创建空分支再挂工作树（旧版 git 无 worktree add --orphan）。
    git switch --orphan gh-pages
    git commit --allow-empty -m "chore: init gh-pages"
    git switch -
    git worktree add "$WORKTREE" gh-pages
  fi
fi
git -C "$WORKTREE" pull --ff-only origin gh-pages 2>/dev/null || true
mkdir -p "$UPDATES_DIR"

# ── 4. 放入 DMG + 发布说明（与 DMG 同名、.md，自动嵌入 appcast）───────────
cp "$DMG" "$UPDATES_DIR/"
NOTES="${1:-}"
if [ -z "$NOTES" ] || [ ! -f "$NOTES" ]; then
  NOTES="$UPDATES_DIR/${APP_NAME}-${VERSION}.md"
  cat > "$NOTES" <<EOF
## ForNow ${VERSION}

- 更新内容待补充（发布前编辑 updates/${APP_NAME}-${VERSION}.md 后重新运行本脚本）
EOF
fi
cp "$NOTES" "$UPDATES_DIR/${APP_NAME}-${VERSION}.md"

# ── 5. 生成 appcast（在 updates 目录内跑；私钥自动从 Keychain 读取）───────
echo "==> 生成 appcast（首次会弹 Keychain 授权框，请选“始终允许”）"
"$TOOLS_DIR/bin/generate_appcast" \
  --download-url-prefix "$PAGES_SITE/updates/" \
  --link "$PAGES_SITE/" \
  "$UPDATES_DIR"

# ── 6. 提交并推送 gh-pages ──────────────────────────────────────────────
git -C "$WORKTREE" add updates
git -C "$WORKTREE" commit -m "release: ForNow ${VERSION} appcast" --allow-empty
git -C "$WORKTREE" push origin gh-pages

# ── 7. 可选：GitHub Release（人类可见的下载页；Sparkle 不依赖它）───────────
if [ -z "${SKIP_GITHUB_RELEASE:-}" ]; then
  echo "==> 创建 GitHub Release v${VERSION}"
  git tag "v${VERSION}" && git push origin "v${VERSION}"
  gh release create "v${VERSION}" "$DMG" \
    --title "ForNow ${VERSION}" \
    --notes-file "$UPDATES_DIR/${APP_NAME}-${VERSION}.md"
fi

# ── 8. 验证输出 ─────────────────────────────────────────────────────────
echo "==> 完成。验证："
echo "    appcast: $PAGES_SITE/updates/appcast.xml"
echo "    DMG:     $PAGES_SITE/updates/${APP_NAME}-${VERSION}.dmg"
curl -fsSL "$PAGES_SITE/updates/appcast.xml" | head -5 \
  || echo "    （Pages 可能还在发布中，稍等 1–2 分钟再试）"
