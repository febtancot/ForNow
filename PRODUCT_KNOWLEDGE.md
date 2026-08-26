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
| 面板宽度 | ✅ | 默认 384pt；展开后可拖动左右完整边缘横向调整，保持顶部居中；原生 AppKit 鼠标会话持续追踪拖动，窗口移动时不会中断或重新起算；宽度按屏幕/刘海安全范围限制并跨重启保存，设置中可恢复默认宽度 |
| 拖近自动展开 | ✅ | 拖内容进入刘海热区自动展开，落下入库后自动收起 |
| `⌘V` 粘贴入库 | ✅ | 优先级 文件>图片>链接>富文本>纯文本（`PasteboardImporter`，有单测）；输入条聚焦时由输入条原生处理 |
| 快速录入 | ✅ | 面板底部输入条，**点击聚焦**后打字，回车入库置顶并收起；纯文字建文字项、http(s) 地址自动建链接项；文字超长时输入条自动扩展为多行（上限 8 行后内部滚动）|
| 录音 | ✅ | 收起态分段胶囊左侧 mic 段点击开始、再点停止入库置顶（m4a、波形图标、时长+大小；录音中变红显示实时时长）；面板头部标题旁**常驻 mic** 同样可开始/停止；首次点击弹麦克风权限；**停止前快照时长，避免 `AVAudioRecorder.stop()` 后时长归零而误判为过短**；停止入库后面板自动展开、高亮并滚到新录音；支持复制/拖出/在 Finder 显示 |
| 面板内音频播放 | ✅ | 音频图标悬停显示播放/暂停遮罩（活动时控制常显）；播放后原位显示可拖动进度条、当前时间/总时长；双击和右键「播放」复用同一控制，不再唤起外部播放器；同一时间只播放一条，切换项目停止上一条；收起面板继续播放，删除/清空活动音频时停止 |
| 五类内容 | ✅ | 文件/图片/文字/链接/录音；图标、缩略图、尺寸、摘要、加入日期时间 |
| 文件去重 | ✅ | 两层防线：面板内已管理文件/目录/录音按受管 URL 直接识别，拖回面板不复制；文件/图片/音频按内容哈希（SHA-256）识别外部同内容副本。`.txt` 等同时提供文件 URL 与纯文本的拖放 provider 强制优先读取 `public.file-url`，不会降级成文字项；若历史版本已生成内容相同的未锁定文字项，会移入应用内回收站（可恢复，锁定项保留）。重复拖入/粘贴只保留一份，提示「已存在」并高亮原项目；旧文件加载时补算哈希 |
| 外部录音拖入 | ✅ | 拖放声明支持 `public.audio`；优先读取音频文件承诺并在 provider 回调有效期内复制，也支持 data representation 回退；适配语音备忘录等不直接提供 file URL 的来源 |
| 拖出 | ✅ | 文件/图片/录音提供文件 URL；**文字同时提供 .txt 文件与纯文本**（拖入 Finder 得到 txt、拖入文本框得到文字）；链接提供 URL；默认保留原项 |
| 单选/多选/全选 | ✅ | 单击选中、⌘-单击多选、⌘A 全选；蓝色高亮；全选/取消全选按钮位于左下角、快捷文本输入区上方 |
| 复制所选 | ✅ | 底部按钮或 `⌘C`；文件→文件URL、链接→URL、文字→字符串 |
| 删除/清空 | ✅ | Delete、右键与底部「清空」均把未锁定项目移入应用内回收站；清空前二次确认，锁定项跳过 |
| 回收站 | ✅ | 面板头部可切换回收站；显示过去 30 天清除的文件/图片/文字/链接/录音及清除时间，支持单项或全部恢复；到期自动永久删除；恢复时拦截重复内容和底层文件缺失 |
| 锁定 | ✅ | 右键「锁定/解锁」（多选时批量）；锁定行显示锁图标并永远稳定置顶，不受清空/删除影响；新增、恢复与重启加载均保持锁定分区；旧元数据无 `locked` 键自动按未锁定加载（有单测）|
| 暂存备注 | ✅ | 右键单个项目可添加或编辑最多 500 字的本地备注；备注在文件名下方单独显示，空白保存会移除备注；随元数据持久化，进入回收站并恢复后仍保留，旧元数据无 `note` 键时按无备注加载 |
| 打开/预览 | ✅ | 双击打开文件/图片/链接；双击文字弹出原文预览窗；文件夹图标悬停直接打开，文件/图片图标悬停直接快速预览（QLPreviewPanel），右键入口保留 |
| 列表图标 | ✅ | 文件/文件夹用真实 Finder 图标；图片缩略图；文字/链接用符号；音频/文件夹/文件/图片在悬停时叠加对应快捷操作 |
| 本地持久化 | ✅ | 文件复制进 `~/Library/Application Support/ForNow/Files/<uuid>/原名`，元数据 JSON；重启仍在 |
| 重名处理 | ✅ | 内部用 uuid 子目录保证唯一，界面显示原名 |
| 菜单栏备用入口 | ✅ | 状态栏图标（SF Symbol `tray.and.arrow.down.fill`，13pt，模板自适应）|
| 设置 | ✅ | 登录启动、全屏显示胶囊（默认关闭，避免覆盖视频）、声音、动画；全局快捷键录制；打开即置前（激活 App，不被其他窗口遮挡）|
| 全局快捷键 | ✅ | 默认 ⌃⌥Space（Carbon `RegisterEventHotKey`）|
| 反馈 | ✅ | toast + 声音；深色模式、VoiceOver 标签 |
| 多屏吸附 | ✅ | 默认仍在刘海下；设置列出当前显示器（含左右/上下位置），可单选或多选，并保留「刷新显示器列表」。应用常驻监听 Core Graphics 显示器重配置；忽略配置开始事件，合并同轮多屏回调，并在 `NSScreen` UUID 列表连续稳定后自动同步设置列表与小药丸窗口。设置页出现、应用重新激活及 AppKit 屏幕参数通知仍提供快速刷新。每块已选屏幕各有一个收起态小药丸，点击哪块就只在哪块展开；外接/无刘海屏在菜单栏下沿保留 2pt 间距，视觉位置不再沉到 34pt 窗口底部。显示器 UUID 跨重启保存，断开时临时回退默认屏，重连自动恢复 |
| DayDrop 联动 | ✅ | 设置提供独立 DayDrop 介绍页、双向能力说明及官网 `https://daydrop.liveby.app`；系统确认 `com.liuyuhang.DayDrop` 已安装，且同一个安装副本处理正式 URL 入口时，收起态分段胶囊增加文件夹按钮。文件夹段只向胶囊最右侧和上下扩大命中区，不越过与中间暂存段的分隔线。兼容版 DayDrop 声明目标显示器能力后，ForNow 在 `daydrop://open-today-folder` 请求中附带点击屏幕的稳定 ID，由 DayDrop 自己准备目录并把 Finder 窗口放到同一屏；旧版自动使用无参数入口。未安装、入口被其他应用或另一份开发构建接管时不显示；ForNow 不读取 DayDrop 沙盒数据或推导归档路径 |
| DayDrop 外部文件接收 | ✅ | 能力版本 1 的 open-document 接收端接受 DayDrop 今日下载、下载文件或整理记录传入的现有本机文件 URL，复用 `StashStore.addFiles` 完成复制、SHA-256 去重与持久化，并以“搁这儿-ForNow”作为界面名称反馈成功、重复和失败数量 |
| 版本检查/自动更新 | ✅ | Sparkle 2：启动时 + 每日最多一次自动检查，菜单栏「检查更新…」手动触发，设置「更新」页显示版本/上次检查；菜单栏与设置「更新」页有「查看更新日志」（直达官网 `#update` 锚点）|

## 交互模型（关键细节）

- **刘海命中区**：刘海缺口本身无可点击像素，真正命中的是缺口正下方一条覆盖刘海宽度、下延 ~18pt 的热区；透明命中层用 `Color.white.opacity(0.001)`（`Color.clear` 只响应悬停、不响应点击）。
- **首次点击**：面板用 `NotchHostingView` 重写 `acceptsFirstMouse` 返回 true，应用未激活时首击也生效。
- **全屏层级**：胶囊在普通桌面继续使用 `.statusBar` 层级并跨 Space 显示。仅移除 `.fullScreenAuxiliary` 不能阻止 `.canJoinAllSpaces` 的 layer-25 药丸覆盖 Chrome/YouTube 的 layer-0 全屏视频；关闭「在全屏应用中显示胶囊」时，`FullScreenVisibilityMonitor` 每 350ms 在后台读取 WindowServer 快照，以 Quartz 显示器 bounds 为坐标基准，识别覆盖某块屏幕至少 99.5% 的其他进程 layer-0 窗口，并只 `orderOut` 该屏药丸。退出全屏后自动恢复，其他未全屏显示器和普通桌面的置顶不受影响；显式开启设置时跳过隐藏并恢复 `.fullScreenAuxiliary`。
- **展开面板宽度**：默认 384pt。展开后左右边缘各有 10pt 透明拖拽命中区，悬停显示细线并切换横向缩放光标；面板始终以刘海为中心，边缘移动 1pt 对应总宽度变化 2pt。拖动区由 AppKit `NSView` 原生接收 `mouseDown`、`mouseDragged` 和 `mouseUp`，以首次按下时的宽度和屏幕绝对 X 坐标为固定基准；即使宿主窗口在缩放中持续移动，也不会像 SwiftUI `DragGesture` 那样中断、重建或重新起算。全局范围为 320–720pt，实际还会按当前屏幕宽度及 `刘海宽度 + 96pt` 安全下限动态限制。拖拽结束（或拖拽中收起）通过 `AppSettings.panelWidth` 写入 UserDefaults，重启继续使用；设置「面板」显示当前宽度并可恢复默认 384pt，已展开面板会立即同步；VoiceOver 可按 32pt 步长增减。
- **多屏窗口模型**：`NotchController` 按设置为每块目标屏幕维护独立 `NotchWindow`，共享同一份暂存、草稿、录音和播放状态。所有目标屏幕可同时显示收起态小药丸，但任一时刻只允许一块屏幕展开；点击另一块屏幕会把面板切换过去。默认目标优先带刘海的屏幕，其次主屏；全局快捷键和菜单栏入口也遵循这个顺序。无刘海屏使用 `visibleFrame.maxY` 作为吸附线，胶囊在窗口内改为顶部对齐并保留 2pt 间距；刘海屏仍在刘海下方按原逻辑底部对齐。屏幕参数变化后立即重建/重定位窗口。
- **DayDrop 能力发现**：`DayDropIntegrationContract` 固定 bundle id 与 `daydrop://open-today-folder` 契约。`NotchController` 同时检查 Launch Services 中的已安装应用、URL handler 路径和 handler bundle id，只在安装副本本身提供入口时发布可用状态，避免旁边的旧包或 DerivedData 开发构建误触发；应用启动、退出及胶囊重新出现时刷新。DayDrop 的 Info.plist 声明 `DayDropOpenTodayFolderTargetDisplayVersion >= 1` 时，打开请求附带点击位置对应的 ColorSync 显示器 UUID；旧版继续使用稳定无参数 URL。目录授权、创建、归属登记和 Finder 打开均留在 DayDrop 内执行。
- **DayDrop 文件接收**：`ForNowExternalFileImportVersion=1` 是 DayDrop 检查的显式能力标记。`AppDelegate.application(_:open:)` 只接收本机文件 URL，在启动尚未完成时合并排队；启动完成后调用现有 `StashStore.addFiles`，不另建存储路径或绕过内容去重。结果通过 Notch 面板显示，重复项会高亮已有项目。
- **选中即时 / 双击激活**：单击立即选中；双击（时间戳识别，阈值 0.35s，避免 SwiftUI 消歧延迟）→ 文件/图片/链接打开、录音在当前行播放/暂停、**文字弹出原文预览窗**（可滚动、可选中复制）。
- **图标与悬停快捷操作**：文件/文件夹用真实 Finder 图标（自动区分文件夹与各类型文件）；图片用缩略图；文字/链接用 SF Symbol。鼠标进入行后，音频图标叠加播放/暂停、文件夹图标叠加打开、普通文件和图片图标叠加快速预览；按钮直接覆盖在 34×34 图标命中区，不再占用行尾空间。音频活动期间按钮保持可见，便于随时暂停；VoiceOver 行操作仍提供等价的播放、打开或预览动作。
- **键盘（面板打开时）**：Esc 先清选择再收起、`⌘V` 粘贴、`⌘C` 复制所选、`⌘A` 全选、Delete 删所选。
- **锁定**：右键行 →「锁定」（多选时批量，已全锁则显示「解锁」）；锁定行尾显示锁图标、悬停删除按钮隐藏；`StashStore` 对活动列表做稳定分区，锁定项始终位于顶部，锁定/解锁、新项目插入、回收站恢复与历史元数据加载都会重新保证顺序，同时保留各分区内相对次序；「清空」与 Delete/右键删除都跳过锁定项，需先解锁才能删除。
- **暂存备注**：右键单个项目 →「添加备注/编辑备注」，在独立编辑器中输入最多 500 字；保存时移除首尾空白，纯空白按删除备注处理。列表把多行备注压成单行，放在项目名称与类型/大小/日期之间，VoiceOver 行描述同步读出备注。`StashItem.note` 与其他元数据一起写入 `metadata.json`，移入 `trash.json` 和恢复时保持不变；旧元数据缺少 `note` 时按无备注加载。
- **全选位置**：全选/取消全选从头部移到面板左下角的操作栏，位于快捷文本输入区正上方；`⌘A` 保持可用。
- **回收站**：Delete、行尾删除、右键「移到回收站」和底部「清空」只迁移元数据，不立即删除受管文件；回收站由独立 `trash.json` 保存 `TrashedItem(item, trashedAt)`，面板头部垃圾桶入口显示数量，列表显示类型与清除时间，支持行尾/右键单项恢复和底部「全部恢复」。项目保留满 30 天后，在启动加载或打开回收站时永久删除真实文件。恢复保持原 id、创建时间和文件路径并插到暂存顶部；若当前暂存已有相同内容或文件已经缺失，则保留在回收站并提示。跨 `metadata.json`/`trash.json` 写入采用数据安全顺序，启动时以活动列表为准归并同 id，避免中断写入导致恢复文件被到期清理。
- **录音（分段胶囊 mic 段 + 面板头部常驻 mic）**：收起态胶囊条左侧 mic 段点击开始（首次弹麦克风权限）、再点停止入库，录音中变红并显示实时时长；右侧托盘段（及窗口其余区域）点击打开面板；展开面板头部标题旁同样常驻 mic（空闲 mic 图标、录音中红色「录音中 m:ss」），两态都能开始/停止；不足 0.5 秒视为误触丢弃；音频存 m4a（`AVAudioRecorder`，AAC 44.1kHz 单声道），文件名「录音-时间戳.m4a」、列表显示「录音 · 时刻」；**停止入库后面板自动展开、高亮新录音并把列表滚到顶部**（`scrollToTopRequest`）；音频行副标题显示时长（`durationText`）。实时计时由 `RecordingController.elapsedSeconds` 发布（0.5s 计时器随录音启停、cleanup 复位）；时长文案统一走 `StashItem.durationText(seconds:)`（m:ss 格式）。**胶囊条与头部 mic 按钮直接观察 `recorder`**（`@EnvironmentObject`），录音状态/计时变化只重绘这两处，不触发面板整体重渲染；收起窗口下沿热区高 26pt（`NotchMetrics.closedFrame(interactiveBelow:)`），胶囊完整落在菜单栏/刘海带下方不被遮挡。
- **面板内播放**：`AudioPlaybackController` 用单个 `AVAudioPlayer` 管理活动项目，200ms 同步真实进度；同项切换播放/暂停，新项先停止旧项，自然结束/系统中断/解码失败会清理状态。活动音频行显示 `Slider` 与 `当前 / 总时长`，拖动直接写入 `currentTime`。音频的双击、行尾按钮和右键菜单统一走面板内播放器，`ItemActions.open` 不再为音频调用 `NSWorkspace`；收起面板不停止播放，删除/清空活动项目以及开始录音前会停止，录音进行中禁止播放以避免扬声器内容被重新录入。
- **文件去重**：拖放判型先读取 `public.file-url` 的原始 representation，再回退到通用 URL、图片、链接和纯文本，确保 Finder `.txt` 作为文件进入哈希链路。第一层按规范化后的受管 URL 识别面板自身拖出的文件、目录和录音，在复制前直接返回原项目（目录也可拦截）；第二层为文件/图片/音频计算 SHA-256（`ContentHasher`，流式读取不整载内存，存入 `StashItem.contentHash`），`StashStore.insert` 与已有（含同批）项目比对，内容相同则跳过入库并清理其暂存副本。拖入/粘贴提示「已存在」并高亮原项目，有重复时不自动收起面板。**旧数据兼容**：`load()` 时为无哈希的历史文件、图片和录音补算并写回元数据；TXT 文件还会与历史错误生成的文字项比较规范化内容（去 BOM、统一换行），内容完全相同的未锁定文字项移入应用内回收站，锁定项不动；每次加载和 TXT 重复拖入都会执行。
- **日期显示**：每行副标题时间戳为「日期 + 时间」（如 8月16日 22:30）。
- **快速录入（输入条，面板底部）**：面板打开**不**自动聚焦（保证 ⌘V 走传统粘贴入库），点击输入条才开始打字；回车（或点击「收起」）提交——空草稿只收起、非空建项置顶（http(s) 地址建链接项）并收起；Esc 有草稿先清空、无草稿收起；输入条聚焦期间 `⌘V`/`⌘A`/Delete 由文本框原生处理（不走列表快捷键）。输入条为可自动扩展的多行输入区（上限 8 行，超出后**定高滚动、显示滚动条**）。**状态隔离与高度测量**：草稿/聚焦状态在独立 `DraftModel`（仅输入条观察），打字/粘贴只重绘输入条；高度测量用 `DraftTextMetrics`（TextKit 惰性排版、只排前 8 行，成本与行长成正比、与全文长度无关，另对超长文本截断测量前缀），窗口高度由合并去抖的 `draftDidChange` 事件驱动 `NotchWindow.contentHeight` 直接调整，粘贴大段文字不卡顿、无逐帧动画重排。
- **设置窗口入口**：状态栏菜单「设置…」→ `StatusItemController` 回调 → `AppDelegate.onOpenSettings` → SwiftUI `openSettings` 动作（由 `ForNowApp` 场景内容经 `onChange(of: settingsVersion, initial: true)` 注入；`settingsVersion` 由 `settings.objectWillChange` 驱动递增，保证 body 至少评估一次）。AppKit 的 `showSettingsWindow:` 在新版 SDK 已移除、不可用。通用页「面板」区显示当前宽度，并提供「恢复默认宽度」；恢复后持久化 384pt，并通过 `AppSettings.$panelWidth` 实时更新已打开的面板。

## 技术架构

- 技术栈：Swift 5 语言模式 / Xcode 26 / AppKit + SwiftUI；XcodeGen 生成工程，`xcodebuild` 构建；目标 macOS 14+。
- `ForNowKit`（**静态库**）：数据模型、存储、剪贴板归类、Notch 几何、设置、快捷键模型 —— 纯逻辑、可单测。
- `ForNow`（**菜单栏 App**，`LSUIElement`）：Notch 窗口/面板、系统集成，依赖 ForNowKit。
- `ForNowKitTests`：117 个单测，无需 app host。
- 关键文件：`NotchController`（多屏窗口/开合/宽度调整/拖入/粘贴/选择/反馈/录音与播放协调）、`FullScreenVisibilityMonitor`（后台 WindowServer 轮询与逐屏显隐）、`FullScreenWindowDetector`（全屏覆盖纯逻辑）、`DropFileURLLoader`/`DropFileURLDecoder`（拖放文件 URL 优先读取与原始表示解码）、`DisplayIdentity`（ColorSync 显示器 UUID 与 Quartz bounds）、`DisplayAttachmentSelection`（自动选择、多选和断开回退纯逻辑）、`RecordingController`（AVAudioRecorder 录音状态机）、`AudioPlaybackController`（AVAudioPlayer 单实例播放/进度/定位）、`ContentHasher`（文件内容 SHA-256）、`DraftModel`（输入条独立状态）、`DraftTextMetrics`（截断高度测量）、`NotchMetrics`（含菜单栏下吸附线的几何）、`AppSettings`（持久化面板宽度与屏幕选择）、`StashStore`（暂存与回收站仓库）、`DiskFileStorage`/`JSONMetadataStore`/`JSONTrashMetadataStore`（持久化）、`PasteboardImporter`（归类）、`StatusItemController`（菜单栏）、`UpdaterModel`（Sparkle 更新桥接，KVO → SwiftUI）。

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

- 0.7.6（build 10）已发布：保留「刷新显示器列表」，并新增 Core Graphics 常驻重配置监听，在 `NSScreen` UUID 列表稳定后自动同步设置与小药丸窗口；新显示器不会自动加入用户选择。107 单测通过，Universal DMG 完成 Developer ID 签名、Apple 公证与票据装订，Sparkle appcast 和 Cloudflare Pages 生产站已更新。本机已从 0.7.5 通过 Sparkle 完成下载、安装与重启，并显示 0.7.6（10）。真实外接屏热插拔后的自动刷新仍需在日常硬件切换中继续观察。
- 0.7.7（build 11）已发布：外接屏胶囊在热区顶部对齐，今日文件夹段扩大最右侧和上下命中区，并通过 DayDrop 1.2.1 把 Finder 窗口放到点击屏幕。110 单测通过，Universal DMG 完成 Developer ID 签名、公证与票据装订；Sparkle appcast、独立发布说明和 Cloudflare Pages 生产站已更新。本机已从 0.7.6 通过线上 Sparkle 流程安装并重启到正式 0.7.7，随后与正式 DayDrop 1.2.1 在 Studio Display 完成实际点击落屏验证。
- 0.7.8（build 12）已发布：默认关闭全屏显示时，Chrome/YouTube 全屏只隐藏对应显示器的药丸，退出全屏自动恢复，其他显示器继续可用；全屏开关实时作用于所有窗口。117 项单测通过，Universal DMG 完成 Developer ID 签名、Apple 公证与票据装订；Sparkle appcast、build 11 增量包、独立发布说明和 Cloudflare Pages 生产站已更新。本机已通过线上 Sparkle 从 0.7.7（11）更新并重启到正式 0.7.8（12）。真实 Chrome/YouTube 逐屏显隐在发布前的已安装 Debug 构建中通过；正式版完成签名、哈希与 Sparkle 安装验收，但因用户正在操作 Chrome，发布后未再次抢占浏览器重复该交互。
- **自动验证边界**：源码、单测、构建、签名、公证、浏览器检查和辅助功能驱动的 UI 操作，都不能替代真实刘海点击、Finder 拖放、快捷键手感或外接屏热插拔验收；这些交互仍需在实际硬件上确认。

## 非 MVP / 路线图

自动清理策略（用后删/24h/7天/自定义）、按应用/任务多暂存架、
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
- **自动更新（Sparkle 2.9.5）**：更新源 `https://fornow.liveby.app/updates/appcast.xml`（Cloudflare Pages 项目 `fornow`，与产品站同域；DMG + appcast + delta + 同名 .md 发布说明；站点源码在 `~/AI projects/fornow_site/`，`_headers` 对 appcast 短缓存 5 分钟、对 DMG/delta immutable）；`./Scripts/make_release.sh` 全流程（构建公证 → 组装站点 + updates → generate_appcast 签名 → 更新首页下载链接 → wrangler 部署 → 落回站点源码目录）。铁律：旧 DMG 永不删、appcast 只由脚本生成、同名版本只发一次。

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
- **2026-08-14 · v0.3.0 自动更新**：Sparkle 2.9.5 经 SPM 接入（启动 + 每日一次自动检查，菜单栏「检查更新…」，设置「更新」页）；更新源托管于产品站同域 Cloudflare Pages（`fornow.liveby.app/updates/appcast.xml`，`_headers` 对 appcast 短缓存 5 分钟）；EdDSA 私钥入 Keychain 并离线备份；`make_dmg.sh` 改 `codesign --deep`（Sparkle 嵌套二进制重签，公证要求）；新增 `Scripts/make_release.sh`（构建公证 → generate_appcast 签名 → wrangler 部署 → 落回站点源码）。踩坑：Sparkle 拒绝 `file://` feed（错误 2001）；wrangler 从 git 仓库运行会把当前分支当预览部署，生产部署须从非 git 临时目录 `--branch main`。47 单测绿；公证 Accepted；生产 feed 实测通过。
- **2026-08-14 · v0.3.1 更新日志入口**：官网 changelog 区锚点改 `#update`（应用内「查看更新日志」承接目标）；菜单栏与设置「更新」页新增「查看更新日志…」（`NSWorkspace.shared.open` / SwiftUI `Link`，URL 常量在 `UpdaterModel.changelogURL`）。发布 0.3.1（build 4）。
- **2026-08-16 · 修复 ⌘V 粘贴入库失效**：快速录入上线后面板打开即自动聚焦输入条，⌘V 被输入条吞掉，传统的「打开面板 → ⌘V 直接入库」失效。修复：去掉 `QuickEntryField` 的 `onAppear` 自动聚焦，面板打开不再处于编辑状态（⌘V/⌘C/⌘A/Delete/Esc 全走列表快捷键）；点击输入条才开始打字，聚焦状态仍由 `.onChange(of: focused)` 同步 `DraftModel.isTyping`；空态提示改「点击输入条打字录入，或拖入文件、按 ⌘V 粘贴」。47 单测绿。
- **2026-08-16 · v0.3.2 发布**：版本升至 0.3.2（build 5）发布 ⌘V 修复；站点 changelog 加 v0.3.2 卡片（`c-tag--fix`），发布说明 `updates/ForNow-0.3.2.md` 随 appcast 嵌入。本机经 Sparkle 更新验证。
- **2026-08-16 · 锁定**：`StashItem` 新增 `locked` 字段（手写解码兜底旧元数据，缺失键按未锁定加载）；`StashStore.removeAll`/`remove(ids:)` 跳过锁定项（返回实际删除数）、新增 `setLocked`；右键「锁定/解锁」批量切换、锁定行显示锁图标并隐藏悬停删除；「清空」对话框提示锁定保留数；删除反馈区分锁定项。新增 4 例测试（清空保留锁定项及文件、删除跳过、持久化、旧元数据兼容），51 单测绿。
- **2026-08-16 · 文字拖出 .txt**：文字项拖出原只提供纯文本，拖入 Finder 得到二进制 textClipping；现同时提供 .txt 文件（临时目录 `ForNowDrag/<id>/`，`StashItem.txtFileName` 清洗摘要为文件名）与纯文本两种表示。新增 1 例测试，52 单测绿。
- **2026-08-16 · 暂存项显示日期**：行副标题时间戳从仅时间改为「日期 + 时间」（`.abbreviated` + `.shortened`）。
- **2026-08-16 · 设置窗口置前**：LSUIElement 菜单栏程序点状态栏菜单不激活 App，设置窗口被其他窗口遮挡；`AppDelegate.openSettingsWindow` 打开设置后 `NSApp.activate(ignoringOtherApps:)` 并把关键窗口 orderFront。
- **2026-08-16 · 录音**：新增 `StashItemKind.audio` 与 `StashItem.makeAudio`/`durationText`/`durationSeconds`（手写解码兜底）；`StashStore.addAudio`（m4a 入库）；`RecordingController`（AVAudioRecorder，AAC 44.1kHz 单声道，`AVAudioApplication` 权限请求，不足 0.5s 丢弃）；notch 左侧 mic 胶囊（`MicButton`，录音中变红）+ 面板头部「录音中」停止按钮；音频行波形图标、时长副标题、可打开/复制/拖出/快速预览/在 Finder 显示；Info.plist 加 `NSMicrophoneUsageDescription`。新增 3 例测试（入库+时长、持久化、文案），55 单测绿。
- **2026-08-16 · 文件去重 + 录音自动展示**：`StashItem` 新增 `contentHash`（SHA-256，手写解码兜底旧元数据）；新增 `ContentHasher` 流式哈希（1MB 分块，不整载大文件）；`StashStore.insert` 对文件/图片按哈希去重（含同批内），跳过项清理暂存副本、返回已有项目；`addFiles` 改三元组、`addImageData` 返回 `(item?, duplicates)`；拖入/粘贴遇重复提示「已存在，高亮显示」并选中原项目（有重复时不自动收起面板）；录音停止入库后面板自动展开并高亮新录音。新增 3 例去重测试（二次添加跳过、同名同大小不同内容不误判、同批去重清理孤儿副本），58 单测绿。
- **2026-08-16 · 录音入口重构**：解决「面板打开时无法开始录音」——收起态 mic 与中央 pill 合并为**分段胶囊**（左 mic 段、右托盘段均为独立按钮，VoiceOver 可分别触达；窗口其余区域点击仍打开面板）；录音中 mic 段变红并显示实时时长；展开面板头部标题旁**常驻 mic**（空闲 mic 图标、录音中红色「录音中 m:ss」）；`RecordingController` 新增 `elapsedSeconds`（0.5s 计时器随录音启停、cleanup 复位）；`StashItem` 新增静态 `durationText(seconds:)`（入库时长与实时计时共用 m:ss 格式）。新增 1 例测试，59 单测绿。
- **2026-08-16 · 真机反馈五连修**：① mic 遮挡——收起窗口下沿热区 18→26pt（`NotchMetrics.closedFrame`），胶囊完整落在菜单栏/刘海带下方；② 计时跳动/按钮样式不更新——根因是视图读 `controller.recorder.*` 但只观察 `controller`，录音器发布不触发重绘；胶囊条与头部 mic 改直接观察 `recorder`（`@EnvironmentObject`），只重绘这两处；③ 录音文件不出现——入库后除展开面板+高亮外，新增 `scrollToTopRequest` 把列表滚到顶部（`ScrollViewReader`）；④ 面板内拖回旧文件仍重复入库——`StashStore.load()` 为无哈希历史项目补算并写回（一次性迁移），旧文件同样参与去重。新增 1 例补算测试，60 单测绿。
- **2026-08-17 · 拖回去重与录音入库修复**：受管 URL 在复制前识别，目录/文件/录音从面板拖回不再新增；音频纳入 SHA-256 去重与旧数据补算；拖放新增 `public.audio`、音频文件承诺及 data representation 回退。录音停止改为先快照 `currentTime` 再 `stop()`，避免真机时长归零导致录音被当作过短丢弃。64 单测绿；麦克风与语音备忘录拖放仍需真机交互复验。
- **2026-08-17 · 面板内音频播放**：新增 `AudioPlaybackController`（单实例 `AVAudioPlayer`、播放/暂停/恢复、200ms 进度、拖动定位、自然结束与失败清理）；音频行增加常驻播放按钮，活动行显示进度条和当前/总时长，双击与右键统一内联播放，移除音频外部打开/快速预览路径。切换音频停止上一条，收起面板继续播放；删除/清空活动音频或开始录音前停止播放，录音中禁止播放。新增 5 项状态机测试，69 单测绿；实际扬声器输出、拖动手感和视觉布局需本机交互验收。
- **2026-08-17 · 30 天应用内回收站**：删除、批量删除与清空改为把未锁定项目迁入独立持久化回收站，真实文件保留 30 天；面板头部新增回收站入口和数量，支持单项/全部恢复并显示清除时间。恢复保持原元数据和文件，重复内容或文件缺失时不移出回收站；启动/打开回收站清理到期项目并永久删除文件。两份元数据按安全顺序写入并在加载时归并同 id，避免中断写入误删。新增 5 项测试，74 单测绿；入口布局、滚动和恢复反馈仍需本机交互验收。
- **2026-08-17 · 图标悬停快捷操作**：音频播放/暂停从行尾迁到音频图标遮罩，文件夹图标悬停显示直接打开，普通文件和图片图标悬停显示快速预览；音频活动时按钮常显，避免移开鼠标后无法暂停。保留双击、右键与 VoiceOver 等价动作，不增加行宽占用。74 单测绿；悬停命中、遮罩对比度与拖拽手感需本机交互验收。
- **2026-08-17 · 锁定置顶与刘海安全布局**：`StashStore` 新增稳定锁定分区，锁定/解锁、新增项目、回收站恢复和重启加载后锁定项都永远位于顶部；新录音滚动目标改为具体项目 id。展开面板由 384pt 加宽到 440pt，让右上回收站入口避开刘海；全选/取消全选迁到左下操作栏、快捷文本上方。新增 3 项排序测试，77 单测绿；实际刘海避让和底部操作密度需本机视觉验收。
- **2026-08-17 · 可拖拽自定义面板宽度**：全选迁到底部后，默认展开宽度由 440pt 恢复为 384pt；左右完整边缘新增 10pt 拖拽区和缩放光标，窗口保持顶部居中对称伸缩。宽度受 320–720pt、屏幕边距及刘海安全下限共同约束，拖拽结束/中途收起时持久化到 `AppSettings.panelWidth`，并提供 VoiceOver 步进调整。新增 3 项设置测试，80 单测绿；边缘命中、连续缩放手感和不同屏幕切换需本机交互验收。
- **2026-08-17 · 面板宽度拖动稳定性与默认恢复**：修复居中窗口调整 frame 后反向扰动 SwiftUI drag translation、导致拖动时左右乱飘的问题；拖动起点和当前位置统一改用稳定的屏幕绝对鼠标 X 坐标。设置通用页新增「面板」区，显示当前宽度并支持恢复默认 384pt，恢复会持久化且实时作用于已展开面板。新增 1 项恢复与持久化测试，81 单测绿；连续拖动手感仍需本机交互验收。
- **2026-08-17 · v0.5.0 发布与官网同步**：版本升至 0.5.0（build 6），汇总发布 0.3.2 之后的锁定置顶、文字拖出 `.txt`、日期显示、录音与外部音频、内容去重、面板内播放、30 天回收站、图标悬停操作及可调面板宽度。`dist/ForNow-0.5.0.dmg` 完成 Developer ID 签名、Apple 公证和票据装订；Sparkle appcast 发布 build 6，并生成从 build 3/4/5 升级的增量包。官网更新为五类内容，移除已完成的路线图项目并补全 0.5.0 更新日志；修正 `_headers` 的规则重叠，确保 appcast 仅短缓存 5 分钟，版本化 DMG、delta 与发布说明长期缓存。81 单测绿；线上首页、发布说明、appcast 与 DMG 哈希已验证。
- **2026-08-17 · Sparkle 版本历史链接修复**：appcast 原只有版本专属 `sparkle:releaseNotesLink`，Sparkle 在没有 `sparkle:fullReleaseNotesLink` 时会把 0.5.0 Markdown 发布说明当作「查看版本历史记录」目标。发布流程新增 `--full-release-notes-url https://fornow.liveby.app/#update`，保留当前版本说明用于更新窗口，同时让完整历史入口统一跳转官网更新区；新增 `regenerate_appcast.sh`，可在不重发同名 DMG 的前提下从现有版本化归档重建并部署 feed。
- **2026-08-17 · 面板宽度拖动事件层修复**：上一轮虽改用屏幕绝对坐标，但事件仍由随窗口 frame 变化的 SwiftUI `DragGesture` 管理，拖动过程仍可能中断或重建。左右边缘改为 AppKit `NSView` 原生鼠标会话，从 `mouseDown` 固定起点并持续接收 `mouseDragged` / `mouseUp`，窗口居中缩放不再改变事件归属；81 单测绿，连续拖动、途中反向及达到边界后回拖仍需本机交互验收。
- **2026-08-17 · README 实用性重构**：仓库首页按普通用户、开发者和发布维护者三类读者重组；补齐安装、快速开始、快捷键、本地数据与隐私、设置、构建验证、目录结构和发布边界，移除已经落后于 0.5.0 的旧 MVP 摘要。命令、路径、测试数量、发布脚本和限制均按当前仓库复核。
- **2026-08-18 · 多屏小药丸吸附**：设置「吸附屏幕」列出显示器名称与相对位置，可把收起态小药丸放到一块或多块屏幕；默认仍为刘海屏。`NotchController` 从单窗口改为按显示器 UUID 管理窗口集合，多屏同时保留入口、只展开当前交互屏；外接屏按 `visibleFrame.maxY` 定位到菜单栏下方中央。显示器断开时临时回退默认屏、重连按持久化 UUID 恢复。新增屏幕选择、持久化、断开回退和外接屏几何测试，89 单测绿；多屏热插拔、同屏点击切换和实际菜单栏间距仍需本机交互验收。
- **2026-08-18 · 多屏设置实时生效修复**：修复设置中勾选 LG 等外接屏后开关与 UserDefaults 已更新、但第二个小药丸窗口直到重启才出现的问题。根因是 `@Published` 在属性真正写入前同步发布新集合，订阅回读 `settings.attachedDisplayIDs` 得到旧值；现直接把发布器回调的新集合传给窗口刷新。已在内建屏 + LG 双屏环境通过设置 UI 关闭/开启复现，并以窗口 frame/可见性验证实时增删。
- **2026-08-18 · TXT 拖入判型与去重修复**：修复 Finder `.txt` provider 同时声明文件 URL 与纯文本时，通用 URL 对象读取失败后被降级成文字项、导致相同文档绕过 SHA-256 去重的问题。新增 `DropFileURLLoader`，先读取并解码 `public.file-url` 原始 representation，再回退通用 URL；真实 `.txt` 继续作为文件入库，纯文本拖放仍是文字项。新增 UTF-8 file URL、非法/网页 URL 拒绝和“文件 URL + 纯文本共存”优先级测试，92 单测绿。
- **2026-08-18 · TXT 历史重复项归并**：真实数据复核确认新版本已生成唯一带哈希的 `response.raw.txt`，但旧版本此前生成的两个同内容文字项仍留在活动列表，造成“仍未去重”的可见结果。`StashStore` 现会在加载及 TXT（包括重复文件）进入哈希链路时，读取 TXT 文本、去 BOM 并统一换行，与历史文字项精确比较；内容相同且未锁定的文字项移入应用内回收站，锁定项保留。新增加载归并、重复 TXT 即时归并和锁定保护测试，95 单测绿。
- **2026-08-18 · v0.6.0 多显示器版本发布**：版本升至 0.6.0（build 7），发布主题为多显示器小药丸吸附：设置可选择一块或多块屏幕，默认仍在刘海下；外接屏位于菜单栏下方中央，支持断开回退、重连恢复与设置即时生效。`dist/ForNow-0.6.0.dmg`（SHA-256 `172b06932154a2a8817a3b38fadb3ee86d61aa4fa13e4b2cf0315eb101fa3ae7`）完成 Developer ID 签名、公证 `Accepted`（提交号 `b3069d60-9f12-45ce-ae15-81a046cd2e2a`）与票据装订；包内 App 为 Universal arm64/x86_64，Gatekeeper 显示 `source=Notarized Developer ID`。Sparkle appcast 已发布 build 7，并生成到 build 3/4/5/6 的增量包；Cloudflare Pages 生产部署 `75101a9a-b0db-4968-a351-c4508b5dd34d` 已上线。生产首页、发布说明、appcast、DMG 缓存头、线上/本地哈希和下载包完整性均已验证；本机 `/Applications/ForNow.app` 已更新并启动。TXT 内容重复识别仍列为已知问题。
- **2026-08-19 · DayDrop 今日文件夹联动**：新增 `DayDropIntegrationContract`，仅当 Launch Services 同时发现已安装的 `com.liuyuhang.DayDrop`，且 `daydrop://open-today-folder` handler 的路径与 bundle id 都匹配该安装副本时，在收起态分段胶囊显示文件夹按钮；旁边的 DerivedData 构建不会让旧安装包误显示。点击后由 DayDrop 完成今日目录准备、所有权记录与 Finder 打开；ForNow 不跨沙盒读取配置。新增 5 项契约测试；实际 Launch Services 刷新、药丸布局和 Finder 打开仍需安装包含新入口的 DayDrop 后真机验收。
- **2026-08-19 · 设置页 DayDrop 介绍**：设置新增 DayDrop 介绍，说明按日期整理下载内容的产品定位、药丸打开今日文件夹和 DayDrop 下载文件或整理记录添加到 ForNow 的前置条件，并提供可点击、可复制的官网 `https://daydrop.liveby.app`。官网地址由 `DayDropIntegrationContract.homepageURL` 统一提供。
- **2026-08-19 · DayDrop 条目右键反向联动**：新增外部文件接收能力版本与 `ExternalFileImportContract`；For Now 可从系统 open-document 事件接收 DayDrop 今日下载、下载文件或整理记录对应的现有文件，过滤非文件 URL，并复用现有复制/去重/持久化路径，随后展开面板反馈结果。实际 DayDrop 右键菜单、跨 App 文件交付和重启持久化仍需安装兼容的 DayDrop 与 For Now 后真机验收。
- **2026-08-19 · v0.7.0 DayDrop 联动版本发布**：版本升至 0.7.0（build 8），发布主题为 DayDrop 双向联动、设置内独立介绍与官网访问入口。`dist/ForNow-0.7.0.dmg`（SHA-256 `e27485cd1a8654c4d5ccb5b9f5fe143cf32c1dd3a664924b09dcfe6e90548e0a`）完成 Developer ID 签名、Apple 公证 `Accepted`（提交号 `1e89c8b2-59ce-4ebc-b5fb-8d03d2b12fcb`）与票据装订；包内 App 为 Universal arm64/x86_64，Gatekeeper 显示 `source=Notarized Developer ID`。Sparkle appcast 已发布 build 8，并生成到 build 3/4/5/6/7 的增量包；Cloudflare Pages 最终生产部署 `2d079d8f-6b53-4ab6-b34e-f52c827e675a` 已上线。生产首页、0.7.0 发布说明、appcast、DMG 缓存头、线上/本地哈希和下载包完整性均已验证；官网新增 DayDrop 独立区块与 `https://daydrop.liveby.app/` 访问入口，并通过 `styles.css?revision=0.7.0` 修复首次部署时旧 CSS 缓存导致的新卡片样式缺失。正式 DMG 已安装到 `/Applications/ForNow.app`，旧版备份到 `~/Library/Application Support/ForNow Installer Backups/ForNow-before-0.7.0-release-20260819-142351.app`；真实药丸显示 DayDrop 文件夹按钮，点击后 Finder 打开 `Day 2026-08-19`。DayDrop 条目右键到 ForNow 的完整 UI 交付仍未在本轮自动化中直接执行；TXT 内容重复识别继续列为已知问题。
- **2026-08-20 · 暂存备注**：`StashItem` 新增可选 `note` 元数据，旧 JSON 缺失字段时兼容加载；`StashStore.setNote` 统一处理 500 字上限、首尾空白和空备注移除，并立即写盘。项目右键菜单新增「添加备注/编辑备注」，编辑器提供字数计数，列表在名称下方显示单行备注，VoiceOver 描述同步包含备注；备注随回收站迁移和恢复保留。新增 4 项模型与仓库测试，完整 107 单测通过；Debug 版已实际验证右键、输入、保存、列表展示、编辑和移除，视觉密度仍可按使用反馈微调。
- **2026-08-20 · v0.7.5 暂存备注版本发布**：版本升至 0.7.5（build 9）。`dist/ForNow-0.7.5.dmg`（SHA-256 `95d10f1cbaea55dc772b530a158c8075ddd97f6bc35df5e112d884bb6445adb6`）完成 Developer ID 签名、Apple 公证 `Accepted`（提交号 `0eb0d1f9-971f-4cb8-9baa-3b23a0b048b9`）与票据装订；包内 App 为 Universal arm64/x86_64，Gatekeeper 显示 `source=Notarized Developer ID`。Sparkle appcast 已发布 build 9，并生成从 build 4/5/6/7/8 升级的增量包；Cloudflare Pages 生产部署 `bc9b93da-3cda-44dc-b16d-557547e59f7c` 已上线。官网新增暂存备注功能说明、带备注的面板示意、0.7.5 更新卡片和独立发布说明；桌面与 390 px 移动端无横向溢出，生产控制台无错误。生产首页、发布说明、appcast、DMG/delta 缓存头、线上/本地 DMG 哈希和下载包内版本/架构/签名均已验证。本机 `/Applications/ForNow.app` 已通过 Sparkle 更新为正式 0.7.5，主可执行文件与 DMG 内版本哈希一致，并实际显示现有备注。
- **2026-08-24 · 外接显示器列表刷新**：设置「吸附屏幕」新增「刷新显示器列表」按钮；设置页重新出现、应用回到前台或收到系统屏幕参数变化通知时也会自动重读 `NSScreen.screens`。每次刷新同时通知 `NotchController` 重建、移除或重定位小药丸窗口，避免设置列表和实际吸附窗口状态不一致。
- **2026-08-24 · Core Graphics 常驻显示器监听**：保留设置中的手动刷新，并新增进程级 `DisplayReconfigurationMonitor`。监听 Quartz 显示器重配置回调，跳过 begin 阶段、合并同轮多屏事件，每 200ms 复查 `NSScreen` UUID 列表，连续稳定或约 1 秒到期后同步设置列表与所有小药丸窗口；原 AppKit 通知继续作为快速路径。
- **2026-08-24 · v0.7.6 显示器刷新版本发布**：版本升至 0.7.6（build 10）。`dist/ForNow-0.7.6.dmg`（SHA-256 `728fe2f0d6cd248e1c3400ad6b5646a32b17fd4c2b6decfaee0e2770455457b4`）完成 Developer ID 签名、Apple 公证 `Accepted`（提交号 `59e7db95-b279-449e-acde-035f102b320c`）与票据装订；包内 App 为 Universal arm64/x86_64，Gatekeeper 显示 `source=Notarized Developer ID`。Sparkle appcast 已发布 build 10，并生成从 build 9 升级的增量包；Cloudflare Pages 生产部署 `26c416d1-5964-4a29-8adb-20faf33aeaae` 已上线。官网首页、独立发布说明、appcast、DMG 与缓存头均已验证，远程 DMG 哈希与本地、站点副本一致；1440 px 与 390 px 浏览器检查无横向溢出、图片缺失或页面错误。本机 `/Applications/ForNow.app` 已通过 Sparkle 从 0.7.5（9）更新到正式 0.7.6（10），安装后二进制哈希与 DMG 包内 App 一致。真实外接屏热插拔后的自动刷新仍需继续观察，不以发布验证替代硬件交互验收。
- **2026-08-25 · 外接屏胶囊与今日文件夹落屏**：无刘海外接屏的收起胶囊改为在 34pt 热区内顶部对齐，距菜单栏下沿 2pt；最右侧 DayDrop 文件夹段仅向右与上下增加 padding，左边界仍由分隔线固定，避免覆盖中间暂存按钮。ForNow 新增目标显示器能力探测，兼容版 DayDrop 可接收点击屏幕的稳定 ID，在完成原有授权与目录准备后把新 Finder 窗口居中放到同一屏；旧版 DayDrop 自动回退无参数入口。新增 3 项契约测试，ForNow 110 单测通过；两台外接屏的视觉间距、按钮实际命中和跨应用自动化授权仍需安装兼容 Debug 版后人工交互验收。
- **2026-08-26 · 三屏 Debug 安装与联动验收**：同版本号 Debug 测试构建已可恢复地替换 `/Applications/ForNow.app` 与 `/Applications/DayDrop.app`，旧副本分别保存在废纸篓的 `ForNow-replaced-20260826-0000-ft2UoK/ForNow.app` 和 `DayDrop-replaced-20260826-000021-x8pQrB/DayDrop.app`，用户数据未清理。运行中确认内建屏、Studio Display XDR、Mi Monitor 各有独立收起窗口；轮换到 Mi 的 `190×34` 窗口后，截图确认胶囊位于热区顶部。实际点击该窗口的 DayDrop 文件夹段后，Finder 新建 `Day 2026-08-26` 窗口并落在 Mi 范围内（WindowServer bounds `2576,-875,1000×700`）；Studio Display 目标请求也落在对应范围（`336,-1055,1000×700`）。点击同一 Mi 胶囊的中间暂存段只在 Mi 展开 `421×470` 面板，没有触发文件夹，随后成功收起。系统未再次显示自动化提示，已安装 DayDrop 的 Finder Apple Event 定位实际生效。测试版未生成 DMG、未公证、未发布网站，正式发行状态仍为 0.7.6（10）/ DayDrop 1.2.0（8）。
- **2026-08-26 · v0.7.7 外接屏胶囊版本发布**：版本升至 0.7.7（build 11）。`dist/ForNow-0.7.7.dmg`（SHA-256 `ea76b1914d46e852a40619a29e6a1b25e92d60126e0a06d63def83eef538973b`）完成 Developer ID 签名、Apple 公证 `Accepted`（提交号 `f7b05633-e806-4a23-aa71-3b261662f9ae`）与票据装订；包内 App 为 Universal `x86_64 arm64`，Gatekeeper 显示 `source=Notarized Developer ID`。Sparkle appcast 发布 build 11，Cloudflare Pages 生产部署 `e1efa873-fbff-433a-af99-6da0675aef69` 已上线；本地、站点与远程 DMG 哈希一致，桌面与 390 px 页面无横向溢出、破图或浏览器错误。配套 DayDrop 1.2.1（build 9，SHA-256 `bcc20f2ff25fa81ce8402a9b967f039ec3b6fe3a25333ca68fd625da5f112dda`）公证提交 `ee3c0335-c67f-4093-b164-7538ffe0ccf1` 及生产部署 `d69686e2-acf5-420d-8b0c-de46b0841210` 也已验证。`/Applications/ForNow.app` 已通过线上 Sparkle 从 0.7.6 完成安装和重启，主二进制与 DMG 内 App 一致；正式 DayDrop 1.2.1 通过公证 DMG 可恢复安装。使用两份正式安装版从 Studio Display 的 ForNow 胶囊点击后，Finder 新窗口落在该屏范围（`336,-1082,1000×700`）。DayDrop 的权限拒绝路径和显示器断开回退仍需单独交互验收。
- **2026-08-26 · 全屏视频层级第一轮修复（不完整）**：修复设置中的全屏开关只持久化、未实际控制窗口的问题，并默认移除 `.fullScreenAuxiliary`。自动化使用访达原生全屏时未见药丸，因而过早判断已修复；用户随后在 Chrome/YouTube 真实全屏中仍看到药丸。WindowServer 复核确认 YouTube 为 layer 0，而 `.statusBar` 药丸为 layer 25 且仍 onscreen，说明只修改 Space collection behavior 不足以处理 Chrome 视频全屏。
- **2026-08-26 · 第一轮全屏修复本地替换**：以 clean Debug 构建可恢复替换 `/Applications/ForNow.app`，版本仍为 0.7.7（11）。安装后主执行器与实际 Debug 代码 dylib 的 SHA-256 分别为 `0a5c16368459f12b63099630a914b0abee5f5fa0599c970de4f823c77a9606b1`、`141e3d9dff7b06c986d4a7d6cf1ff804058001688a3ea801173036ee0e6b57e9`。旧正式签名 0.7.7（11）保存在废纸篓的 `ForNow-replaced-20260826-z10TzP/ForNow.app`；此安装已被后续 Chrome 实测证明未解决目标问题。
- **2026-08-26 · Chrome/YouTube 全屏逐屏隐藏**：新增 `FullScreenVisibilityMonitor` 与可单测的 `FullScreenWindowDetector`。后台每 350ms 读取 onscreen WindowServer 快照，按各屏 Quartz bounds 识别覆盖率至少 99.5% 的其他进程 layer-0 窗口；默认只隐藏被覆盖屏幕的药丸，退出全屏自动恢复，显式开启全屏设置时跳过。新增 5 项检测测试，完整 117 项单测通过。三屏实测中，Studio Display 的 YouTube `2560×1440` 全屏出现后，该屏药丸从 onscreen 列表消失，内建屏与 Mi Monitor 药丸保留；退出 YouTube 全屏后 Studio 药丸自动恢复。随后以 clean Debug 构建可恢复替换 `/Applications/ForNow.app`，主执行器与 Debug 代码 dylib 的 SHA-256 分别为 `d97b3fee3953fc1ac81ee719a8ff15c28f2ade4118242630cf5bfa325bad060b`、`34832b3ba868f28fe8186056e3819a12549cb83ec14ba795acab8e0442af23b1`；已安装副本再次通过相同的 YouTube 全屏隐藏与退出恢复验收。上一轮未生效 Debug 版保存在废纸篓的 `ForNow-fullscreen-replaced-20260826-4q7Cm5/ForNow.app`，更早的正式签名备份继续保留，`~/Library/Application Support/ForNow` 未清理。此为本机 ad-hoc Debug 安装，未发布新 DMG、网站或 Sparkle 版本。
- **2026-08-26 · v0.7.8 全屏视频修复版本发布**：版本升至 0.7.8（build 12）。`dist/ForNow-0.7.8.dmg`（SHA-256 `4d232e4720ce44f34620558679b7b269f658321db8d45a570bb34953dc8be275`，4,523,965 bytes）完成 Developer ID 签名、Apple 公证 `Accepted`（提交号 `1712cb69-0a83-4787-8560-52fbc0f0d79b`）与票据装订；包内 App 为 Universal `x86_64 arm64`，Gatekeeper 显示 `source=Notarized Developer ID`。Sparkle appcast 发布 build 12，生成从 build 11/10/9/8/7 升级的已签名增量包；其中 `ForNow12-11.delta` 为 277,626 bytes。Cloudflare Pages 生产部署 `25c343ce-c04f-4f7a-8948-fb4f0df691cd` 已上线，首页、独立发布说明、appcast、DMG 和增量包均返回 200；appcast 保持 5 分钟缓存，版本化资源保持一年 immutable。站点源、线上 `downloads`、线上 `updates` 与本地 DMG 的 SHA-256 一致，远程 appcast 哈希也与站点源一致；桌面 1440 px 与移动端 390 px 浏览器检查无横向溢出或破图。生成 appcast 时旧归档同名文件出现 `Code=516` 警告，但新 appcast、增量包与线上哈希完整，因此确认未影响本次发布。本机已通过 Sparkle 真实发现 0.7.8、显示线上说明、下载并“安装并重启应用”；安装后为 0.7.8（12），Developer ID/Gatekeeper 通过，主可执行文件 SHA-256 `6919275980c7ffcedaff06b6a2daa6ac9f375c47c593f72a5f24a6610d948be0` 与 Release 构建一致，Application Support 数据未清理。
