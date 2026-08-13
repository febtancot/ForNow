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
