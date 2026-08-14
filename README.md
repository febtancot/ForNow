# 搁这儿 / ForNow

> 文件、文字、链接，先搁这儿。

一款 macOS 轻量暂存工具。把 MacBook 屏幕顶部的 Notch（刘海）区域变成随手可用的临时口袋：
拖文件进 Notch，或点击 Notch 打开面板，再用 `⌘V` 放入剪贴板里的文字、图片、文件或链接；
需要时把项目拖出到任意支持拖放的应用。所有内容仅保存在本机。

## 环境要求

- macOS 14.0+
- Xcode 26 / Swift 5+
- [XcodeGen](https://github.com/yonyz/XcodeGen)（`brew install xcodegen`）

## 构建与运行

```bash
# 生成 Xcode 工程（首次或修改 project.yml 后）
xcodegen generate

# 命令行构建
xcodebuild -scheme ForNow -configuration Debug build

# 运行单元测试
xcodebuild -scheme ForNow -destination 'platform=macOS' test

# 一键构建并启动（脚本封装了上述步骤）
./Scripts/run.sh
```

也可在 Xcode 中打开 `ForNow.xcodeproj` 直接运行。

## 架构

| 模块 | 类型 | 职责 |
| --- | --- | --- |
| `ForNowKit` | framework | 数据模型、存储、剪贴板归类、Notch 几何、设置 —— 纯逻辑，可单元测试 |
| `ForNow` | app（菜单栏程序） | Notch 窗口、SwiftUI 面板、系统集成，依赖 `ForNowKit` |
| `ForNowKitTests` | 单元测试 | 针对 `ForNowKit`，无需 app host |

详见 [`IMPLEMENTATION_PLAN.md`](./IMPLEMENTATION_PLAN.md)。

## MVP 范围

参见 [`Notch_Stash_PRD.md`](./Notch_Stash_PRD.md)。首版聚焦：Notch 触发、拖入/粘贴/拖出、
本地持久化、菜单栏与设置、全局快捷键；不含云同步、剪贴板历史、标签分类、AI 摘要等。

## 自动更新

应用内置 [Sparkle 2](https://sparkle-project.org/) 自动更新：启动时检查 + 每日最多一次，
菜单栏「检查更新…」手动触发。更新源托管在 GitHub Pages：

```
https://febtancot.github.io/ForNow/updates/appcast.xml
```

本地调试可临时覆盖 feed（用后记得删除）：

```bash
defaults write com.fornow.app SUFeedURL "http://127.0.0.1:8000/appcast.xml"
defaults delete com.fornow.app SULastCheckTime   # 立即触发下次检查
```

## 发布新版本

**一次性设置（首次发布前）：**

1. **生成更新签名密钥**：`~/Library/Caches/ForNow/sparkle-2.9.5/bin/generate_keys`
   （私钥入 Keychain；把打印的公钥填进 app `Info.plist` 的 `SUPublicEDKey`），
   并离线备份私钥：`generate_keys -x ~/Documents/fornow-sparkle-private-key.txt`（绝不进 git）。
2. **启用 GitHub Pages**（仓库 Settings → Pages → Source 选 `gh-pages` 分支根目录；
   或 `gh api repos/febtancot/ForNow/pages -X POST -f "source[branch]=gh-pages" -f "source[path]=/"`）。
3. Sparkle 命令行工具由 `Scripts/make_release.sh` 自动下载到 `~/Library/Caches/ForNow/sparkle-2.9.5/`。

**每次发布：**

```bash
# 1. project.yml 升 MARKETING_VERSION / CURRENT_PROJECT_VERSION（只升不降）
# 2. （可选）手写发布说明 updates/ForNow-<版本>.md；不写则脚本生成占位
# 3. 一条命令发布（首次跑会弹 Keychain 授权框，选“始终允许”）
NOTARY_PROFILE=ForNowNotary ./Scripts/make_release.sh
#    SKIP_GITHUB_RELEASE=1 可跳过 GitHub Release，只推更新源
# 4. 验证：curl https://febtancot.github.io/ForNow/updates/appcast.xml
#    （Pages 首次发布有 1–10 分钟延迟）
```

**三条铁律：**

- **永不删除** `gh-pages` 分支上 `updates/` 与 `old_updates/` 里的历史 DMG（增量更新 `.delta` 依赖它们）。
- **appcast.xml 只由脚本生成**，不做手工修改（它带 EdDSA 签名，手改即失效）。
- **同名版本只发布一次**（重复发布会破坏签名/增量更新/客户端缓存）。
