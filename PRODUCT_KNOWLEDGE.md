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
| `⌘V` 粘贴入库 | ✅ | 优先级 文件>图片>链接>富文本>纯文本（`PasteboardImporter`，有单测）|
| 四类内容 | ✅ | 文件/图片/文字/链接；图标、缩略图、尺寸、摘要、加入时间 |
| 拖出 | ✅ | 每行 `.onDrag` 提供文件 URL / 文本 / 链接；默认保留原项 |
| 单选/多选/全选 | ✅ | 单击选中、⌘-单击多选、⌘A 全选；蓝色高亮 |
| 复制所选 | ✅ | 底部按钮或 `⌘C`；文件→文件URL、链接→URL、文字→字符串 |
| 删除/清空 | ✅ | Delete 删所选、右键删除、底部"清空"二次确认 |
| 打开/在 Finder 显示/快速预览 | ✅ | 双击打开文件/图片/链接；右键含快速预览（QLPreviewPanel）|
| 本地持久化 | ✅ | 文件复制进 `~/Library/Application Support/ForNow/Files/<uuid>/原名`，元数据 JSON；重启仍在 |
| 重名处理 | ✅ | 内部用 uuid 子目录保证唯一，界面显示原名 |
| 菜单栏备用入口 | ✅ | 状态栏图标（SF Symbol `tray.and.arrow.down.fill`，13pt，模板自适应）|
| 设置 | ✅ | 登录启动、全屏启用、声音、动画；全局快捷键录制 |
| 全局快捷键 | ✅ | 默认 ⌃⌥Space（Carbon `RegisterEventHotKey`）|
| 反馈 | ✅ | toast + 声音；深色模式、VoiceOver 标签 |
| 无刘海/外接屏回退 | ✅ | `NotchMetrics` 检测刘海，缺失时顶部中央热区（有单测）|

## 交互模型（关键细节）

- **刘海命中区**：刘海缺口本身无可点击像素，真正命中的是缺口正下方一条覆盖刘海宽度、下延 ~18pt 的热区；透明命中层用 `Color.white.opacity(0.001)`（`Color.clear` 只响应悬停、不响应点击）。
- **首次点击**：面板用 `NotchHostingView` 重写 `acceptsFirstMouse` 返回 true，应用未激活时首击也生效。
- **选中即时**：单击立即选中；双击用时间戳手动识别（阈值 0.35s），避免 SwiftUI 单/双击消歧的 ~0.3s 延迟。
- **键盘（面板打开时）**：Esc 先清选择再收起、`⌘V` 粘贴、`⌘C` 复制所选、`⌘A` 全选、Delete 删所选。

## 技术架构

- 技术栈：Swift 5 语言模式 / Xcode 26 / AppKit + SwiftUI；XcodeGen 生成工程，`xcodebuild` 构建；目标 macOS 14+。
- `ForNowKit`（**静态库**）：数据模型、存储、剪贴板归类、Notch 几何、设置、快捷键模型 —— 纯逻辑、可单测。
- `ForNow`（**菜单栏 App**，`LSUIElement`）：Notch 窗口/面板、系统集成，依赖 ForNowKit。
- `ForNowKitTests`：38 个单测，无需 app host。
- 关键文件：`NotchController`（窗口/开合/拖入/粘贴/选择/反馈）、`NotchMetrics`（几何）、`StashStore`（仓库）、`DiskFileStorage`/`JSONMetadataStore`（持久化）、`PasteboardImporter`（归类）、`StatusItemController`（菜单栏）。

## 关键决策与取舍

- **静态库而非动态框架**：内嵌动态框架 ad-hoc 签名报 "bundle format unrecognized"，改静态库彻底规避。
- **未开启 App Sandbox**：简化文件访问 / Apple 事件 / 全局快捷键；上架前需补沙箱 + 授权流程。
- **JSON 元数据而非 SQLite**：更简单、易测；满足"本地、可持久"。
- **Carbon 全局快捷键**：无需辅助功能授权。
- **菜单栏用 SF Symbol 模板图**：原生、单色透明、随明暗自适应；App 图标用彩色插画。

## 当前状态与验证

- 构建绿、38 单测绿、`.app` 正常启动为菜单栏程序、无崩溃/错误日志。
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

- `./Scripts/make_dmg.sh` → Release 构建 → **Developer ID 签名（hardened runtime + 时间戳）** → 输出 `dist/ForNow-<版本>.dmg`（内含 App + `/Applications` 软链，拖拽安装）并签名 DMG。`dist/` 不入库。
- 签名证书：`Developer ID Application: Xueliu Shen (8NF4K823FV)`。
- **公证**：先一次性存凭据（App Store Connect API Key 方式）
  `xcrun notarytool store-credentials "ForNowNotary" --key <AuthKey_*.p8> --key-id <KeyID> --issuer <IssuerID>`，
  再 `NOTARY_PROFILE=ForNowNotary ./Scripts/make_dmg.sh` 自动 submit + staple + 校验。
  （或 Apple ID 方式：`--apple-id <email> --team-id 8NF4K823FV --password <App 专用密码>`。）
- 未公证的构建换机首开会被 Gatekeeper 拦（右键「打开」，或 `xattr -dr com.apple.quarantine <App>`）；公证+装订后可直接打开。

## 阶段变更记录

- **2026-08-13 · MVP 完成**：五阶段（骨架、模型与持久化、Notch 窗口与面板、拖入/粘贴/拖出/项目操作、菜单栏/设置/快捷键）全部落地，38 单测。
- **2026-08-13 · 交互增强**：刘海整区可点、修复点击不生效、多选 + 复制所选、修复选中延迟。
- **2026-08-13 · 品牌**：App 图标（彩色口袋插画）、菜单栏图标（SF Symbol，13pt）。
- **2026-08-13 · 分发**：`Scripts/make_dmg.sh` 全流程（Developer ID 签名 + hardened runtime → DMG → Apple 公证 → staple）；产出首个**已签名且已公证**的 `ForNow-0.1.0.dmg`（`spctl`: Notarized Developer ID）。
