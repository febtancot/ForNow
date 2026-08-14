# 搁这儿 / ForNow — 产品知识库

> 文件、文字、链接，先搁这儿。
> 本文件是产品的"活知识库"：每完成一个阶段都在此更新功能、决策、状态与变更记录。
> 规范见 [`CLAUDE.md`](./CLAUDE.md)，需求源头见 [`Notch_Stash_PRD.md`](./Notch_Stash_PRD.md)。

## 一句话

一款 macOS 轻量暂存工具，把 MacBook 顶部的 Notch（刘海）变成随手可用的临时口袋：
拖文件进刘海、或点刘海打开面板用 `⌘V` 放入剪贴板内容，需要时再把项目拖出到任意应用。
**只解决一件事**：在还没决定内容最终去处时，先有一个触手可及的中转位置。所有内容仅存本机。

## 目标用户

- 频繁在 Finder / 浏览器 / 聊天 / 办公软件间搬运内容的人。
- 收集图片、文档、素材的设计师、创作者、产品经理。
- 经常向 ChatGPT / Claude / 邮件 / Teams 批量上传文件的人。

## 核心场景

1. **拖入暂存**：拖动文件靠近刘海 → 面板下拉展开 → 松手入库 → 短暂成功反馈后自动收起。
2. **粘贴剪贴板**：点刘海打开面板 → `⌘V` → 按类型（文件/图片/链接/文字）建项，置顶。
3. **取出继续用**：打开面板 → 把一个或多个项目拖出到 Finder/邮件/聊天/上传区；默认保留，不误删。

## 已实现功能（对照 PRD）

| 能力 | 状态 | 说明 |
| --- | --- | --- |
| 点击刘海开合面板 | ✅ | 整个刘海宽度（缺口下方热区）可点；Esc/点外收起 |
| 拖近自动展开 | ✅ | 拖内容进入刘海热区自动展开，落下入库后自动收起 |
| `⌘V` 粘贴入库 | ✅ | 优先级 文件>图片>链接>富文本>纯文本（`PasteboardImporter`，有单测）；输入条聚焦时由输入条原生处理 |
| 快速录入 | ✅ | 面板底部输入条，打开面板即自动聚焦，直接打字，回车入库置顶并收起；纯文字建文字项、http(s) 地址自动建链接项；文字超长时输入条自动扩展为多行（上限 8 行后内部滚动）|
| 四类内容 | ✅ | 文件/图片/文字/链接；图标、缩略图、尺寸、摘要、加入时间 |
| 拖出 | ✅ | 每行 `.onDrag` 提供文件 URL / 文本 / 链接；默认保留原项 |
| 单选/多选/全选 | ✅ | 单击选中、⌘-单击多选、⌘A 全选；蓝色高亮 |
| 复制所选 | ✅ | 底部按钮或 `⌘C`；文件→文件URL、链接→URL、文字→字符串 |
| 删除/清空 | ✅ | Delete 删所选、右键删除、底部"清空"二次确认 |
| 打开/预览 | ✅ | 双击打开文件/图片/链接；双击文字弹出原文预览窗；文件/图片右键快速预览（QLPreviewPanel）|
| 列表图标 | ✅ | 文件/文件夹用真实 Finder 图标；图片缩略图；文字/链接用符号 |
| 本地持久化 | ✅ | 文件复制进 `~/Library/Application Support/ForNow/Files/<uuid>/原名`，元数据 JSON；重启仍在 |
| 重名处理 | ✅ | 内部用 uuid 子目录保证唯一，界面显示原名 |
| 菜单栏备用入口 | ✅ | 状态栏图标（SF Symbol `tray.and.arrow.down.fill`，13pt，模板自适应）|
| 设置 | ✅ | 登录启动、全屏启用、声音、动画；全局快捷键录制 |
| 全局快捷键 | ✅ | 默认 ⌃⌥Space（Carbon `RegisterEventHotKey`）|
| 反馈 | ✅ | toast + 声音；深色模式、VoiceOver 标签 |
| 无刘海/外接屏回退 | ✅ | `NotchMetrics` 检测刘海，缺失时顶部中央热区（有单测）|
| 版本检查/自动更新 | ✅ | Sparkle 2：启动时 + 每日最多一次自动检查，菜单栏「检查更新…」手动触发，设置「更新」页显示版本/上次检查 |

## 交互模型（关键细节）

- **刘海命中区**：刘海缺口本身无可点击像素，真正命中的是缺口正下方一条覆盖刘海宽度、下延 ~18pt 的热区；透明命中层用 `Color.white.opacity(0.001)`（`Color.clear` 只响应悬停、不响应点击）。
- **首次点击**：面板用 `NotchHostingView` 重写 `acceptsFirstMouse` 返回 true，应用未激活时首击也生效。
- **选中即时 / 双击激活**：单击立即选中；双击（时间戳识别，阈值 0.35s，避免 SwiftUI 消歧延迟）→ 文件/图片/链接打开、**文字弹出原文预览窗**（可滚动、可选中复制）。
- **图标**：文件/文件夹用真实 Finder 图标（自动区分文件夹与各类型文件）；图片用缩略图；文字/链接用 SF Symbol。
- **键盘（面板打开时）**：Esc 先清选择再收起、`⌘V` 粘贴、`⌘C` 复制所选、`⌘A` 全选、Delete 删所选。
- **快速录入（输入条，面板底部）**：面板打开自动聚焦、可直接打字；回车（或点击「收起」）提交——空草稿只收起、非空建项置顶（http(s) 地址建链接项）并收起；Esc 有草稿先清空、无草稿收起；输入条聚焦期间 `⌘V`/`⌘A`/Delete 由文本框原生处理（不走列表快捷键）。输入条为可自动扩展的多行输入区（上限 8 行，超出后**定高滚动、显示滚动条**）。**状态隔离与高度测量**：草稿/聚焦状态在独立 `DraftModel`（仅输入条观察），打字/粘贴只重绘输入条；高度测量用 `DraftTextMetrics`（TextKit 惰性排版、只排前 8 行，成本与行长成正比、与全文长度无关，另对超长文本截断测量前缀），窗口高度由合并去抖的 `draftDidChange` 事件驱动 `NotchWindow.contentHeight` 直接调整，粘贴大段文字不卡顿、无逐帧动画重排。
- **设置窗口入口**：状态栏菜单「设置…」→ `StatusItemController` 回调 → `AppDelegate.onOpenSettings` → SwiftUI `openSettings` 动作（由 `ForNowApp` 场景内容经 `onChange(of: settingsVersion, initial: true)` 注入；`settingsVersion` 由 `settings.objectWillChange` 驱动递增，保证 body 至少评估一次）。AppKit 的 `showSettingsWindow:` 在新版 SDK 已移除、不可用。

## 技术架构

- 技术栈：Swift 5 语言模式 / Xcode 26 / AppKit + SwiftUI；XcodeGen 生成工程，`xcodebuild` 构建；目标 macOS 14+。
- `ForNowKit`（**静态库**）：数据模型、存储、剪贴板归类、Notch 几何、设置、快捷键模型 —— 纯逻辑、可单测。
- `ForNow`（**菜单栏 App**，`LSUIElement`）：Notch 窗口/面板、系统集成，依赖 ForNowKit。
- `ForNowKitTests`：47 个单测，无需 app host。
- 关键文件：`NotchController`（窗口/开合/拖入/粘贴/选择/反馈）、`DraftModel`（输入条独立状态）、`DraftTextMetrics`（截断高度测量）、`NotchMetrics`（几何）、`StashStore`（仓库）、`DiskFileStorage`/`JSONMetadataStore`（持久化）、`PasteboardImporter`（归类）、`StatusItemController`（菜单栏）、`UpdaterModel`（Sparkle 更新桥接，KVO → SwiftUI）。

## 关键决策与取舍

- **静态库而非动态框架**：内嵌动态框架 ad-hoc 签名报 "bundle format unrecognized"，改静态库彻底规避。
- **Sparkle 2 经 SPM 引入**（2.9.5，官方 binaryTarget xcframework）：XcodeGen 的 `package:` 依赖由 Xcode 自动链接 + 嵌入 `Contents/Frameworks`（无需 build phase/构建设置）。与 ForNowKit 静态库无冲突。
- **Sparkle 嵌套二进制重签**：SPM xcframework 内 Autoupdate/Updater.app 出厂为 ad-hoc 签名，公证要求 Developer ID + 安全时间戳——`make_dmg.sh` 用 `codesign --deep` 整包重签解决（已实测公证 Accepted）。
- **更新签名与 App 签名分离**：appcast 用 EdDSA 私钥（Keychain account `ed25519`）签名，公钥在 `Info.plist` 的 `SUPublicEDKey`；私钥离线备份于 `~/Documents/fornow-sparkle-private-key.txt`（gitignore）。此签名独立于 Developer ID，ad-hoc 本地构建也能验证更新。
- **本地 feed 调试**：Sparkle 2.9.5 拒绝 `file://` feed（错误 2001「下载请求 URL 必须用 http/https」），本地测试须用 `http://127.0.0.1` 服务；`defaults write com.fornow.app SUFeedURL ...` 覆盖生效（删除后回退 Info.plist）。
- **未开启 App Sandbox**：简化文件访问 / Apple 事件 / 全局快捷键；上架前需补沙箱 + 授权流程。
- **JSON 元数据而非 SQLite**：更简单、易测；满足"本地、可持久"。
- **Carbon 全局快捷键**：无需辅助功能授权。
- **菜单栏用 SF Symbol 模板图**：原生、单色透明、随明暗自适应；App 图标用彩色插画。

## 当前状态与验证

- 构建绿、47 单测绿、`.app` 正常启动为菜单栏程序、无崩溃/错误日志。
- **仅命令行无法验证**：本环境无屏幕录制权限（截图全黑）、无 UI 自动化，故刘海点击/拖拽/粘贴/快捷键等交互需真机肉眼验收。

## 非 MVP / 路线图

自动清理策略（用后删/24h/7天/自定义）、固定重要项、按应用/任务多暂存架、最近关闭恢复、
Quick Actions（压缩/重命名/转图/分享链接）、iCloud 或端到端加密同步。

## 构建与运行

```bash
xcodegen generate                                   # 增删文件后必做
xcodebuild -scheme ForNow -configuration Debug -derivedDataPath ./build build
xcodebuild -scheme ForNow -destination 'platform=macOS' -derivedDataPath ./build test
./Scripts/run.sh                                    # 构建并启动
./Scripts/make_dmg.sh                               # 构建 Release 并打包 dist/ForNow-<版本>.dmg
```

## 分发 / 打包

- `./Scripts/make_dmg.sh` → Release 构建 → **Developer ID 签名（hardened runtime + 时间戳，`codesign --deep` 重签含 Sparkle 嵌套二进制）** → 输出 `dist/ForNow-<版本>.dmg`（内含 App + `/Applications` 软链，拖拽安装）并签名 DMG。`dist/` 不入库。
- 签名证书：`Developer ID Application: Xueliu Shen (8NF4K823FV)`。
- **公证**：先一次性存凭据（App Store Connect API Key 方式）
  `xcrun notarytool store-credentials "ForNowNotary" --key <AuthKey_*.p8> --key-id <KeyID> --issuer <IssuerID>`，
  再 `NOTARY_PROFILE=ForNowNotary ./Scripts/make_dmg.sh` 自动 submit + staple + 校验。
  （或 Apple ID 方式：`--apple-id <email> --team-id 8NF4K823FV --password <App 专用密码>`。）
- 未公证的构建换机首开会被 Gatekeeper 拦（右键「打开」，或 `xattr -dr com.apple.quarantine <App>`）；公证+装订后可直接打开。
- **自动更新（Sparkle 2.9.5）**：更新源 `https://febtancot.github.io/ForNow/updates/appcast.xml`（gh-pages 分支，DMG + appcast + delta + 同名 .md 发布说明）；`./Scripts/make_release.sh` 全流程（构建公证 → 进 gh-pages worktree → generate_appcast 签名 → 推送 → 可选 GitHub Release，`SKIP_GITHUB_RELEASE=1` 跳过）。铁律：旧 DMG 永不删、appcast 只由脚本生成、同名版本只发一次。

## 阶段变更记录

- **2026-08-13 · MVP 完成**：五阶段（骨架、模型与持久化、Notch 窗口与面板、拖入/粘贴/拖出/项目操作、菜单栏/设置/快捷键）全部落地，38 单测。
- **2026-08-13 · 交互增强**：刘海整区可点、修复点击不生效、多选 + 复制所选、修复选中延迟。
- **2026-08-13 · 品牌**：App 图标（彩色口袋插画）、菜单栏图标（SF Symbol，13pt）。
- **2026-08-13 · 分发**：`Scripts/make_dmg.sh` 全流程（Developer ID 签名 + hardened runtime → DMG → Apple 公证 → staple）；产出首个**已签名且已公证**的 `ForNow-0.1.0.dmg`（`spctl`: Notarized Developer ID）。
- **2026-08-13 · 设置窗口修复**：菜单栏「设置…」点击无效 —— 旧 AppKit selector `showSettingsWindow:` 在新版 SDK 的 `NSApplication` 上已移除；改经 SwiftUI `openSettings` 动作桥接打开（`ForNowApp` 场景内容注入 → `AppDelegate` → 状态栏菜单），38 单测通过。
- **2026-08-13 · 图标与预览**：列表改用真实 Finder 文件/文件夹图标（区分文件夹与类型）；双击文字项弹出原文预览窗口（`TextPreviewController`）。
- **2026-08-13 · 快速录入**：面板打开自动聚焦输入条，打字回车即入库（文字/链接）；`NotchController` 新增草稿与聚焦状态，全局键盘监听分流 Esc/回车，聚焦时 `⌘V` 等交给输入条原生处理。输入条置于面板底部并加大，后改为多行自动扩展（上限 8 行）。
- **2026-08-14 · 输入性能修复**：输入条粘贴大段文字卡顿——根因是草稿放在 `NotchController` 上，每次内容变化都广播触发整个面板重渲染（列表每行文件系统查询、底部统计递归磁盘扫描），且 `.animation(value:)` 对多行扩展逐帧动画重排大文本。将草稿/聚焦状态迁入独立 `DraftModel`（仅输入条观察，`@Published` 只影响该小组件）；窗口高度改由 `draftDidChange` 事件（异步合并去抖）驱动 `NotchWindow.contentHeight` 直接调整（`NSHostingController` 轻量测量，替代 SwiftUI 逐帧几何回传）；去除输入条内容动画。新增 `DraftModelTests`（2 例：同循环合并为一次事件、相同值不重复触发），40 单测绿。
- **2026-08-14 · 输入性能二轮修复**：粘贴仍有卡顿——测量用 SwiftUI `Text` 全文排版，每次击键在主线程做 O(全文) 布局。改为 `DraftTextMetrics`（TextKit 惰性排版、最多排 8 行，另对超长文本截断测量前缀，成本与行长成正比）；高度测量节流（每秒一次、值不变不发布）。同时输入条改为 ScrollView 定高滚动（系统可见滚动条），去掉 `lineLimit(1...8)` 内部滚动。新增 `DraftTextMetricsTests`（5 例：截断契约、空文单行、换行、封顶 8 行、宽度无关），45 单测绿。
- **2026-08-14 · 长文本提交复位修复**：长文本提交后重开面板，输入条高度停在多行上限（铅笔图标悬空未归位）——根因是节流把"清空草稿→单行"的最终测量吞掉，且事件先于测量发出。修复：清空后测量不受节流限制、事件改在测量之后发送（订阅方读到的总是最新高度）、窗口高度 sink 加 `isOpen` 守卫（收起后不再被驱动）。新增 2 例回归测试，47 单测绿。
- **2026-08-14 · v0.2.0 发布**：版本升至 0.2.0（`MARKETING_VERSION`，build 2）；打包签名 + 公证 + 装订的 `dist/ForNow-0.2.0.dmg`（`spctl`: Notarized Developer ID），供分发。
