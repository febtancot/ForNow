#!/usr/bin/env bash
# 构建并启动"搁这儿"。
set -euo pipefail
cd "$(dirname "$0")/.."

xcodegen generate

DERIVED="$(pwd)/build"
xcodebuild -scheme ForNow -configuration Debug -derivedDataPath "$DERIVED" build

APP="$DERIVED/Build/Products/Debug/ForNow.app"
echo "==> Launching $APP"
# 先杀掉旧实例，避免多个菜单栏图标。
killall ForNow >/dev/null 2>&1 || true
open "$APP"
