# ForNow / 搁这儿 — 项目规则

本文件是本项目对 Claude 的工作规则，随仓库版本化。通用开发哲学见全局 `~/.claude/CLAUDE.md`；
产品知识见 [`PRODUCT_KNOWLEDGE.md`](./PRODUCT_KNOWLEDGE.md)。

## 阶段性维护产品知识（规则）

每完成一个**阶段**（一个新功能或一次有意义的改动，且处于可编译、测试通过的稳定状态）：

1. 更新 [`PRODUCT_KNOWLEDGE.md`](./PRODUCT_KNOWLEDGE.md)：受影响的功能表、交互细节、关键决策、当前状态，
   并在文末「阶段变更记录」追加一条（日期用绝对日期）。
2. 需要时同步 `README.md` / `IMPLEMENTATION_PLAN.md`。

## 自动提交（规则 · 用户已授权）

用户已**长期授权**：每个阶段结束即自动提交，无需再询问。约束：

- 只提交**可编译且 `xcodebuild ... test` 通过**的稳定状态（遵守质量门槛，不提交半成品/坏状态）。
- 每个阶段一个逻辑提交；提交前把该阶段的产品知识更新一并包含进去。
- 直接提交到当前工作分支（本项目单人开发，默认 `main`）。不自动 `push`。
- 提交信息：首行简明祈使句（可用 `feat/fix/docs/refactor/chore:` 前缀），必要时空行加要点；
  结尾附：`Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`。

> 说明：这是"阶段性"自动提交（逻辑稳定点），不是每轮对话都提交；纯问答/探索不提交。

## 构建 / 测试工作流

- 使用 **XcodeGen**：**增删或重命名任何文件后，必须先 `xcodegen generate` 再 `xcodebuild`**，
  否则新文件不会被编译/测试（只改动已有文件则无需重新生成）。
- 常用命令：
  ```bash
  xcodegen generate
  xcodebuild -scheme ForNow -configuration Debug -derivedDataPath ./build build
  xcodebuild -scheme ForNow -destination 'platform=macOS' -derivedDataPath ./build test
  ./Scripts/run.sh
  ```
- SourceKit/LSP 会误报 `No such module 'ForNowKit'` 等（按文件孤立分析所致），以 `xcodebuild` 为准。
- 本环境无屏幕录制权限（截图全黑）、无 UI 自动化：UI 交互靠"启动+存活+日志"验证，视觉效果请人工确认。

## 不要提交的内容

`.gitignore` 已排除：`*.xcodeproj/`（XcodeGen 生成）、`build/`、`DerivedData/`、`.DS_Store`。
