# 搁这儿 / ForNow — Implementation Plan

macOS 暂存工具 MVP。技术栈：Swift 5 (language mode) / Xcode 26 / AppKit + SwiftUI，
XcodeGen 生成工程，`xcodebuild` 命令行构建。目标系统 macOS 14+。

架构：
- `ForNowKit`（framework）— 纯逻辑 + 可单元测试的核心：数据模型、存储、剪贴板归类、
  Notch 几何计算、设置。无 UI 依赖，headless 可测。
- `ForNow`（app, LSUIElement 菜单栏程序）— 窗口/视图/系统集成，依赖 ForNowKit。
- `ForNowKitTests` — 针对 ForNowKit 的单元测试，无需 app host。

---

## Stage 1: 工程骨架与构建管线
**Goal**: XcodeGen + xcodebuild 可产出可运行的菜单栏 App（.app bundle，ad-hoc 签名）。
**Success Criteria**: `xcodebuild build` 绿；运行后出现菜单栏图标，无 Dock 图标。
**Tests**: 构建通过即可。
**Status**: Complete

## Stage 2: 数据模型与持久化
**Goal**: StashItem 模型 + StashStore + JSON 元数据持久化 + 文件复制到暂存目录。
**Success Criteria**: 增/删/清空/重启后仍在；重名文件生成唯一内部名，界面显示原名。
**Tests**: StashStoreTests、DiskFileStorageTests、JSONMetadataStoreTests 全绿。
**Status**: Complete

## Stage 3: Notch 窗口与面板 UI
**Goal**: 定位到刘海的无边框 NSPanel；SwiftUI 列表/卡片面板；点击开合、Esc/点外收起；
无刘海时回退到顶部中央热区/菜单栏。
**Success Criteria**: 点击可开合；显示数量与占用空间；空状态、深色模式正常。
**Tests**: NotchMetricsTests（由屏幕参数计算窗口 frame 的纯函数）。
**Status**: Complete

## Stage 4: 交互 — 拖入 / 粘贴 / 拖出 / 项目操作
**Goal**: 拖文件到 Notch 入库；Cmd+V 按优先级（文件>图片>链接>富文本>纯文本）归类入库；
项目可拖出；复制/打开/在 Finder 显示/删除/清空（二次确认）/快速预览。
**Success Criteria**: 达成第 10 节验收标准的交互项。
**Tests**: PasteboardImporterTests（注入假 pasteboard，验证优先级与归类）。
**Status**: Complete

## Stage 5: 菜单栏 / 设置 / 全局快捷键 / 打磨
**Goal**: 菜单栏菜单；设置（登录启动、全屏启用、声音、动画）；全局快捷键
（默认 Control+Option+Space）；深色模式、减少动效、VoiceOver。
**Success Criteria**: 达成第 10 节全部验收标准；备用入口可用。
**Tests**: AppSettingsTests、HotKey 组合编解码测试。
**Status**: Complete

---

### 已知取舍（MVP）
- 未开启 App Sandbox：简化文件访问与全局快捷键（上架前再补 sandbox + 授权流程）。
- 元数据用 JSON 文件（Codable）而非 SQLite：更简单、易测；满足"本地、可持久"。
- 全局快捷键用 Carbon `RegisterEventHotKey`（无需辅助功能授权）。

---

## 验证结果（2026-08-13）

- **构建**：`xcodebuild build` 绿（app + 静态库 ForNowKit，ad-hoc 签名，arm64）。
- **单元测试**：38 个用例全绿，覆盖数据模型、文件存储（含重名/目录/删除）、JSON 持久化
  （模拟重启）、剪贴板归类优先级、Notch 几何、快捷键编解码。
- **运行**：`.app` 正常启动为菜单栏程序，无 Dock 图标，无崩溃、无错误日志。

### 需在真机上肉眼验收的交互
本环境未授予「屏幕录制」权限（`screencapture` 仅得到全黑图），且无 UI 自动化，
以下交互建议由使用者手动确认：
- 点击 Notch 小条开合面板、拖文件靠近自动展开、Esc/点击外部收起。
- `⌘V` 粘贴文字/图片/链接/文件；从面板把项目拖入其他应用。
- 右键菜单：复制 / 打开 / 在 Finder 显示 / 快速预览 / 删除；清空二次确认。
- 全局快捷键（默认 ⌃⌥Space）唤出面板；设置里的开关与快捷键录制。

运行：`./Scripts/run.sh`（或 `open build/Build/Products/Debug/ForNow.app`）。
