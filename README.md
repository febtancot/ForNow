# 搁这儿 / ForNow

> 文件、文字、链接，先搁这儿。

![Version](https://img.shields.io/badge/version-0.6.0-2563EB)
![macOS](https://img.shields.io/badge/macOS-14%2B-111827)
[![License: MIT](https://img.shields.io/badge/license-MIT-F5C518)](LICENSE)

「搁这儿」是一款 macOS 轻量暂存工具。它把 MacBook 屏幕顶部的 Notch（刘海）
变成临时口袋：内容还没有确定最终去处时，可以先拖入或粘贴保存，需要时再拖到
Finder、邮件、聊天窗口或上传区域。

所有暂存内容仅保存在本机。

- [产品主页与下载](https://fornow.liveby.app)
- [版本更新记录](https://fornow.liveby.app/#update)
- [当前功能与技术决策](PRODUCT_KNOWLEDGE.md)

## 安装

运行要求：macOS 14.0 或更高版本。

1. 从[产品主页](https://fornow.liveby.app)下载 DMG。
2. 打开 DMG，将 `ForNow.app` 拖入「应用程序」文件夹。
3. 启动「搁这儿」。应用常驻菜单栏，不显示 Dock 图标。

正式安装包使用 Developer ID 签名，并已通过 Apple 公证。首次使用录音功能时，macOS 会请求麦克风权限。

## 快速开始

### 添加内容

可以通过以下方式把内容加入暂存：

- 将文件、文件夹、图片或音频拖向刘海区域，面板会自动展开。
- 点击刘海打开面板，然后按 `⌘V` 粘贴剪贴板中的文件、图片、文字或链接。
- 点击面板底部的输入区，输入文字或 HTTP(S) URL 后按回车。
- 点击收起态胶囊左侧或面板标题旁的麦克风按钮，开始或停止录音。
- 安装支持联动入口的 DayDrop 后，收起态胶囊会自动出现文件夹按钮；点击后由 DayDrop 准备并打开今日下载文件夹。
- 安装包含 For Now 联动的 DayDrop 后，可在 DayDrop 的 **下载文件**或**整理记录**中右键现有文件，选择 **添加到 For Now**。For Now 会复制项目、复用现有去重规则，并展开面板显示结果。
- 安装包含 For Now 联动的 DayDrop 后，可在 DayDrop 的 **下载文件**或**整理记录**中右键现有文件，选择 **添加到 For Now**。For Now 会复制项目、复用现有去重规则，并展开面板显示结果。

文件、图片和音频按内容计算 SHA-256。重复加入相同内容时，应用保留原项目并将其高亮，不再创建副本。

### 使用内容

- 将一个或多个项目拖出面板，放入 Finder、邮件、聊天窗口或文件上传区域。拖出后，原项目默认保留。
- 双击文件、文件夹、图片或链接以打开内容；双击文字可查看完整原文。
- 鼠标移到项目图标上，可直接打开文件夹、预览文件和图片，或播放音频。
- 音频在面板内播放，不会跳转到外部播放器。活动音频支持暂停和拖动进度。

### 整理与恢复

- 单击选择项目；按住 `⌘` 单击可多选。
- 右键选择「锁定」后，项目会固定在列表顶部，并且不会被删除或清空。
- 删除和清空操作会把未锁定项目移入应用内回收站。
- 回收站保留已清除项目 30 天，支持单项恢复或全部恢复。到期后，应用会永久删除项目及受管文件。
- 拖动展开面板的左右边缘可以调整宽度；设置中可以恢复默认宽度。
- 默认小药丸仍吸附在 MacBook 刘海下方；有外接显示器时，可在设置中选择任意一块或多块屏幕。外接屏入口位于菜单栏下方中央。

没有可用刘海的屏幕环境会使用默认屏幕菜单栏下方中央作为入口。已选择的显示器断开时会临时回到默认屏幕，重新接入后自动恢复。菜单栏图标始终提供打开面板、设置和检查更新的备用入口。

## 键盘操作

以下快捷键在面板列表处于活动状态时生效：

| 操作 | 快捷键 |
| --- | --- |
| 显示或隐藏面板 | `⌃⌥Space`，可在设置中修改 |
| 粘贴并暂存 | `⌘V` |
| 复制所选项目 | `⌘C` |
| 全选 | `⌘A` |
| 移到回收站 | `Delete` |
| 清除选择或收起面板 | `Esc` |

输入区聚焦时，`⌘V`、`⌘A`、`Delete` 和 `Esc` 由文本输入区处理。

## 本地数据与隐私

「搁这儿」不提供云同步。文件副本、录音和元数据保存在：

```text
~/Library/Application Support/ForNow/
├── Files/          # 文件、图片和录音副本
├── metadata.json   # 当前暂存项目
└── trash.json      # 回收站项目
```

拖入文件时，应用会把文件复制到自己的存储目录。移动或删除原文件不会立即影响暂存副本。将项目移入回收站后，受管文件仍会保留，直到项目恢复或超过 30 天。

## 设置与更新

点击菜单栏图标并选择「设置…」，可以配置：

- 登录时启动；
- 是否在全屏应用中启用；
- 声音反馈和动画效果；
- 面板宽度及恢复默认宽度；
- 小药丸吸附的屏幕，可同时选择多块已连接显示器；
- 显示或隐藏面板的全局快捷键；
- 手动检查更新和查看更新记录。

应用使用 [Sparkle 2](https://sparkle-project.org/) 检查更新。启动时会检查一次，此后每天最多自动检查一次，也可以从菜单栏或设置中手动检查。

## 开发环境

需要安装：

- macOS 14.0 或更高版本；
- Xcode 26；
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)；
- 可访问 Swift Package Manager，以解析 Sparkle 2.9.5。

```bash
git clone https://github.com/febtancot/ForNow.git
cd ForNow
brew install xcodegen

# 生成 Xcode 工程。首次构建、修改 project.yml 或增删文件后需要执行。
xcodegen generate

# 构建并启动 Debug 版本。
./Scripts/run.sh
```

也可以打开生成的 `ForNow.xcodeproj`，选择 `ForNow` scheme 后运行。

## 构建与验证

```bash
# Debug 构建
xcodebuild -scheme ForNow \
  -configuration Debug \
  -derivedDataPath ./build \
  build

# 运行单元测试
xcodebuild -scheme ForNow \
  -destination 'platform=macOS' \
  -derivedDataPath ./build \
  test

# 生成本地 Release DMG
./Scripts/make_dmg.sh
```

当前 `ForNowKitTests` 包含 105 个单元测试，不依赖应用宿主。单元测试覆盖数据模型、存储、去重、历史 TXT 文字项归并、回收站、剪贴板与拖放归类、Finder 扩展宿主解析、外部文件接收契约、快捷键模型、音频播放状态、屏幕选择回退、面板几何和 DayDrop 联动契约等纯逻辑。

命令行构建和单元测试不能证明刘海点击、边缘拖动、系统拖放、Finder 扩展启用、Finder 或 DayDrop 右键到面板的跨进程交付、麦克风录音、实际音频输出或 VoiceOver 交互已经通过。发布前仍需在真实 Mac 上完成这些交互检查。

## 项目结构

| 路径 | 用途 |
| --- | --- |
| `Sources/ForNowKit/` | 数据模型、存储、去重、设置、音频播放状态和其他可测试逻辑 |
| `Sources/ForNow/` | AppKit、SwiftUI、Notch 面板、录音与系统集成 |
| `Tests/ForNowKitTests/` | 不依赖应用宿主的单元测试 |
| `Scripts/run.sh` | 生成工程、构建 Debug 版本并启动应用 |
| `Scripts/make_dmg.sh` | 构建、签名并生成 DMG；可选 Apple 公证 |
| `Scripts/make_release.sh` | 生成正式发布包、Sparkle feed 并部署产品站 |
| `Scripts/regenerate_appcast.sh` | 只重建和部署 Sparkle appcast 元数据 |

主要模块：

| 模块 | 类型 | 职责 |
| --- | --- | --- |
| `ForNowKit` | 静态库 | 数据模型、存储、剪贴板归类、Notch 几何和设置 |
| `ForNow` | 菜单栏 App | Notch 窗口、SwiftUI 面板、录音、快捷键和系统集成 |
| `ForNowKitTests` | 单元测试 | 验证 `ForNowKit`，不依赖应用宿主 |

更多资料：

- [`PRODUCT_KNOWLEDGE.md`](PRODUCT_KNOWLEDGE.md)：当前实现、关键交互、验证状态和阶段变更记录。
- [`Notch_Stash_PRD.md`](Notch_Stash_PRD.md)：最初的产品需求与范围。
- [`IMPLEMENTATION_PLAN.md`](IMPLEMENTATION_PLAN.md)：初始架构和实施计划。
- [`CLAUDE.md`](CLAUDE.md)：仓库维护、验证和提交规则。

## 发布维护

本节仅适用于维护者。正式发布需要 Developer ID Application 证书、Apple 公证凭据、
Sparkle EdDSA 私钥、Cloudflare Pages 权限和产品站源码。

### 一次性配置

1. 运行 `~/Library/Caches/ForNow/sparkle-2.9.5/bin/generate_keys` 生成 Sparkle 更新签名密钥。
2. 将公钥写入 `Info.plist` 的 `SUPublicEDKey`。
3. 将私钥保存在 Keychain，并离线备份；不要提交私钥。
4. 使用 `xcrun notarytool store-credentials "ForNowNotary" ...` 保存 Apple 公证凭据。
5. 运行 `npx wrangler whoami`，确认当前账号可以部署 Cloudflare Pages 项目 `fornow`。
6. 确认产品站源码位于 `~/AI projects/fornow_site/`。

### 发布新版本

1. 在 `project.yml` 中递增 `MARKETING_VERSION` 和 `CURRENT_PROJECT_VERSION`。
2. 在产品站源码的 `updates/ForNow-<版本>.md` 中编写发布说明。
3. 在产品站 `index.html` 中添加版本更新条目。
4. 运行完整发布流程：

   ```bash
   NOTARY_PROFILE=ForNowNotary ./Scripts/make_release.sh
   ```

5. 验证 appcast 和 DMG：

   ```bash
   curl -fsSL https://fornow.liveby.app/updates/appcast.xml
   spctl -a -t open --context context:primary-signature -vv dist/ForNow-<版本>.dmg
   ```

需要修正完整版本历史链接等 feed 级元数据、但不重新发布 DMG 时，运行：

```bash
./Scripts/regenerate_appcast.sh
```

发布时必须遵守以下规则：

- 不删除站点 `updates/` 中的历史 DMG；增量更新文件依赖这些版本。
- 不手工修改 `appcast.xml`；该文件包含 Sparkle EdDSA 签名，应由脚本生成。
- 不重复发布同名版本；版本号和 build number（构建号）只能递增。
- 没有 Developer ID 证书时，`make_dmg.sh` 会生成 ad-hoc 签名包。该产物只能用于本机测试，不能作为正式发布证据。

本地调试 Sparkle feed 时，只能使用 HTTP 或 HTTPS URL。Sparkle 2.9.5 不接受 `file://` feed：

```bash
defaults write com.fornow.app SUFeedURL "http://127.0.0.1:8000/appcast.xml"
defaults delete com.fornow.app SULastCheckTime

# 调试完成后恢复正式 feed。
defaults delete com.fornow.app SUFeedURL
```

## 当前不包含

当前版本不提供以下能力：

- iCloud 或其他云同步；
- 剪贴板历史；
- 标签和多暂存架；
- 自动清理策略；
- 压缩、重命名、格式转换等 Quick Actions；
- AI 摘要。

## License

本项目采用 [MIT License](LICENSE)。
