import AppKit
import SwiftUI
import UniformTypeIdentifiers
import ForNowKit
import Combine

/// 管理 Notch 暂存面板的显示、开合、定位与全局事件监听。
@MainActor
final class NotchController: ObservableObject {
    @Published private(set) var isOpen = false
    /// 当前展开面板所在的显示器；其余已配置显示器仍保持收起态小药丸。
    @Published private(set) var activeDisplayID: String?
    /// 拖入内容悬停时高亮（供面板反馈）。
    @Published var isDropTargeted = false
    /// 克制的操作反馈提示（如"已复制"）。
    @Published var toast: String?
    /// 当前选中的项目 id（支持单选/多选/全选）。
    @Published var selection: Set<UUID> = []
    /// 面板当前是否显示应用内回收站。
    @Published var isShowingTrash = false
    /// 面板列表滚动到顶部的请求计数（如录音入库后展示新项目）。
    @Published var scrollToTopRequest = 0
    /// 滚动请求的优先目标；锁定项目置顶时，新录音可能不再是列表第一项。
    @Published var scrollTargetItemID: UUID?
    /// 当前展开面板宽度；由左右边缘拖动实时更新。
    @Published private(set) var panelWidth: CGFloat
    /// 仅当系统确认 DayDrop 已安装且能够处理正式联动入口时为 true。
    @Published private(set) var canOpenDayDropTodayFolder = false
    /// 已安装的 DayDrop 是否支持把 Finder 窗口定位到调用方指定的显示器。
    private var dayDropSupportsTargetDisplay = false

    /// 快速录入输入条的独立状态（独立观察，打字/粘贴不触发面板整体重渲染）。
    let draftModel = DraftModel()
    /// 面板内单实例音频播放器（播放/暂停、进度、拖动定位）。
    let audioPlayer = AudioPlaybackController()
    /// 录音状态机（mic 点击开始/停止，停止后音频入库）。
    lazy var recorder = RecordingController(store: store) { [weak self] message in
        self?.feedback(message)
    }

    let store: StashStore
    let settings: AppSettings

    private var windows: [String: NotchWindow] = [:]
    private var attachedDisplayOrder: [String] = []
    private let textPreview = TextPreviewController()
    private var globalClickMonitor: Any?
    private var localKeyMonitor: Any?
    private var toastTask: Task<Void, Never>?
    private var cancellables: Set<AnyCancellable> = []
    /// 面板是否因拖入而展开（用于拖入落下后自动收起）。
    private var openedByDrag = false
    private var resizeEdge: HorizontalEdge?
    private var resizeStartWidth: CGFloat?
    private var resizeStartMouseX: CGFloat?

    init(store: StashStore, settings: AppSettings) {
        self.store = store
        self.settings = settings
        self.panelWidth = CGFloat(settings.panelWidth)

        draftModel.onSubmit = { [weak self] in self?.submitDraft() }
        draftModel.draftDidChange
            .sink { [weak self] in
                guard let self, self.isOpen,
                      let displayID = self.activeDisplayID,
                      let window = self.windows[displayID] else { return }
                window.contentHeight = self.openHeight()
                self.setFrame(self.openFrame(for: displayID), on: displayID, animate: false)
            }
            .store(in: &cancellables)

        settings.$panelWidth
            .dropFirst()
            .sink { [weak self] width in
                self?.applyPanelWidth(CGFloat(width), persist: false)
            }
            .store(in: &cancellables)

        settings.$attachedDisplayIDs
            .dropFirst()
            .sink { [weak self] displayIDs in
                // @Published 在属性写入前发送新值；必须直接使用回调参数，
                // 此处若回读 settings 会拿到旧集合，导致设置开关变化后窗口不刷新。
                self?.refreshAttachedWindows(configuredIDs: displayIDs)
            }
            .store(in: &cancellables)

        settings.$enableInFullScreen
            .dropFirst()
            .sink { [weak self] enabled in
                self?.windows.values.forEach {
                    $0.setFullScreenParticipationEnabled(enabled)
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in self?.refreshAttachedWindows() }
            .store(in: &cancellables)

        // DayDrop 启动或退出后刷新入口；胶囊视图出现时还会再主动刷新一次，
        // 覆盖 ForNow 长驻期间发生的安装或升级。
        for notificationName in [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification
        ] {
            NSWorkspace.shared.notificationCenter.publisher(for: notificationName)
                .sink { [weak self] _ in self?.refreshDayDropAvailability() }
                .store(in: &cancellables)
        }

        refreshAttachedWindows()
        refreshDayDropAvailability()
        panelWidth = clampedPanelWidth(panelWidth)
    }

    /// 供设置页在重新扫描显示器列表时同步重建、移除或重定位小药丸窗口。
    func refreshDisplays() {
        refreshAttachedWindows()
    }

    // MARK: - DayDrop 联动

    func refreshDayDropAvailability() {
        let workspace = NSWorkspace.shared
        let installedApplicationURL = workspace.urlForApplication(
            withBundleIdentifier: DayDropIntegrationContract.bundleIdentifier
        )
        let schemeHandlerURL = workspace.urlForApplication(
            toOpen: DayDropIntegrationContract.openTodayFolderURL
        )
        let schemeHandlerBundleIdentifier = schemeHandlerURL
            .flatMap { Bundle(url: $0)?.bundleIdentifier }
        let schemeHandlerInfoDictionary = schemeHandlerURL
            .flatMap { Bundle(url: $0)?.infoDictionary }

        canOpenDayDropTodayFolder = DayDropIntegrationContract.canOpenTodayFolder(
            installedApplicationURL: installedApplicationURL,
            schemeHandlerApplicationURL: schemeHandlerURL,
            schemeHandlerBundleIdentifier: schemeHandlerBundleIdentifier
        )
        dayDropSupportsTargetDisplay = canOpenDayDropTodayFolder
            && DayDropIntegrationContract.supportsTargetDisplay(
                infoDictionary: schemeHandlerInfoDictionary
            )
    }

    func openDayDropTodayFolder(on displayID: String) {
        refreshDayDropAvailability()
        guard canOpenDayDropTodayFolder else {
            NSSound.beep()
            return
        }

        let targetURL = dayDropSupportsTargetDisplay
            ? DayDropIntegrationContract.openTodayFolderURL(targetDisplayID: displayID)
            : nil
        let url = targetURL ?? DayDropIntegrationContract.openTodayFolderURL

        guard NSWorkspace.shared.open(url) else {
            canOpenDayDropTodayFolder = false
            dayDropSupportsTargetDisplay = false
            NSSound.beep()
            return
        }
    }

    // MARK: - 开合

    func toggle() { isOpen ? close() : open() }

    func isOpen(on displayID: String) -> Bool {
        isOpen && activeDisplayID == displayID
    }

    /// 展开指定屏幕上的面板；未指定时优先使用已选的刘海屏，其次主屏。
    func open(on requestedDisplayID: String? = nil) {
        guard let displayID = resolvedOpenDisplayID(requestedDisplayID),
              let window = windows[displayID] else { return }
        if isOpen, activeDisplayID == displayID { return }

        if let previousID = activeDisplayID, previousID != displayID {
            setFrame(closedFrame(for: previousID), on: previousID, animate: settings.animations)
            windows[previousID]?.orderFrontRegardless()
        }

        let wasOpen = isOpen
        activeDisplayID = displayID
        isOpen = true
        openedByDrag = false
        panelWidth = clampedPanelWidth(CGFloat(settings.panelWidth))
        window.contentHeight = openHeight()
        setFrame(openFrame(for: displayID), on: displayID, animate: settings.animations)
        window.makeKeyAndOrderFront(nil)
        if !wasOpen { installMonitors() }
    }

    func close() {
        guard isOpen else { return }
        if resizeStartWidth != nil { endPanelResize() }
        let closingDisplayID = activeDisplayID
        isOpen = false
        activeDisplayID = nil
        isDropTargeted = false
        openedByDrag = false
        // 先移除键盘监听，避免清空草稿触发输入条重绘时仍在拦截按键。
        removeMonitors()
        draftModel.draft = ""
        draftModel.isTyping = false
        selection.removeAll()
        isShowingTrash = false
        if let displayID = closingDisplayID {
            setFrame(closedFrame(for: displayID), on: displayID, animate: settings.animations)
            windows[displayID]?.orderFrontRegardless()
        }
    }

    /// 拖动内容靠近 Notch 时自动展开。
    func openForDrag(on displayID: String) {
        guard !isOpen(on: displayID) else { return }
        open(on: displayID)
        openedByDrag = true
    }

    // MARK: - 选择（单选 / 多选 / 全选）

    func isSelected(_ id: UUID) -> Bool { selection.contains(id) }

    /// 点选一行。`additive`（⌘-点击）时切换该行的选中状态，否则单选。
    func selectRow(_ id: UUID, additive: Bool) {
        if additive {
            if selection.contains(id) { selection.remove(id) } else { selection.insert(id) }
        } else {
            selection = [id]
        }
    }

    func selectAll() {
        guard !isShowingTrash else { return }
        selection = Set(store.items.map(\.id))
    }

    func clearSelection() {
        selection.removeAll()
    }

    /// 右键某行时的作用对象：若该行在多选内则作用于整个选择，否则仅该行。
    func effectiveItems(for item: StashItem) -> [StashItem] {
        if selection.contains(item.id), selection.count > 1 {
            return store.items.filter { selection.contains($0.id) }
        }
        return [item]
    }

    func copySelection() {
        let items = store.items.filter { selection.contains($0.id) }
        guard !items.isEmpty else { NSSound.beep(); return }
        ItemActions.copyItems(items, store: store)
        feedback("已复制 \(items.count) 项")
    }

    func deleteSelection() {
        guard !selection.isEmpty else { return }
        let lockedCount = store.items.filter { selection.contains($0.id) && $0.locked }.count
        stopPlaybackIfRemoving(store.items.filter { selection.contains($0.id) })
        let removed = store.remove(ids: selection)
        selection.removeAll()
        if lockedCount > 0 {
            feedback(removed > 0 ? "已移入回收站 \(removed) 项，\(lockedCount) 项已锁定" : "所选已锁定，先解锁再删除")
        } else {
            feedback("已移入回收站 \(removed) 项")
        }
    }

    func copyItems(_ items: [StashItem]) {
        guard !items.isEmpty else { return }
        ItemActions.copyItems(items, store: store)
        feedback(items.count > 1 ? "已复制 \(items.count) 项" : "已复制")
    }

    func removeItems(_ items: [StashItem]) {
        guard !items.isEmpty else { return }
        let lockedCount = items.filter(\.locked).count
        let ids = Set(items.map(\.id))
        stopPlaybackIfRemoving(items)
        let removed = store.remove(ids: ids)
        selection.subtract(ids)
        if lockedCount > 0 {
            feedback(removed > 0 ? "已移入回收站 \(removed) 项，\(lockedCount) 项已锁定" : "已锁定，先解锁再删除")
        } else {
            feedback(removed > 1 ? "已移入回收站 \(removed) 项" : "已移入回收站")
        }
    }

    /// 锁定/解锁一批项目（上下文菜单）。全锁定时整体解锁，否则整体锁定。
    func toggleLock(_ items: [StashItem]) {
        guard !items.isEmpty else { return }
        let allLocked = items.allSatisfy(\.locked)
        store.setLocked(!allLocked, for: Set(items.map(\.id)))
        if items.count > 1 {
            feedback(allLocked ? "已解锁 \(items.count) 项" : "已锁定 \(items.count) 项")
        } else {
            feedback(allLocked ? "已解锁" : "已锁定")
        }
    }

    /// 清空全部未锁定项目；若正在播放的项目会被清空，先停止播放。
    func clearAll() {
        let unlockedCount = store.items.filter { !$0.locked }.count
        let lockedCount = store.items.count - unlockedCount
        stopPlaybackIfRemoving(store.items)
        store.removeAll()
        if unlockedCount > 0 {
            feedback(lockedCount > 0
                     ? "已移入回收站 \(unlockedCount) 项，\(lockedCount) 项已锁定"
                     : "已移入回收站 \(unlockedCount) 项")
        }
    }

    func showTrash(_ show: Bool) {
        selection.removeAll()
        isShowingTrash = show
        if show { store.purgeExpiredTrash() }
    }

    func restoreFromTrash(_ entry: TrashedItem) {
        reportRestore(store.restoreFromTrash(ids: [entry.id]))
    }

    func restoreAllFromTrash() {
        reportRestore(store.restoreFromTrash(ids: Set(store.trashItems.map(\.id))))
    }

    private func reportRestore(_ result: TrashRestoreResult) {
        let restoredCount = result.restored.count
        if restoredCount > 0, result.duplicates.isEmpty, result.missingFiles.isEmpty {
            feedback(restoredCount == 1 ? "已恢复到暂存" : "已恢复 \(restoredCount) 项到暂存")
        } else if restoredCount > 0 {
            feedback("已恢复 \(restoredCount) 项，\(result.duplicates.count) 项重复，\(result.missingFiles.count) 项文件缺失")
        } else if !result.duplicates.isEmpty {
            feedback("暂存中已有相同文件，未恢复")
        } else if !result.missingFiles.isEmpty {
            feedback("原文件已缺失，无法恢复")
        }
    }

    private func stopPlaybackIfRemoving(_ items: [StashItem]) {
        guard let activeID = audioPlayer.activeItemID,
              items.contains(where: { $0.id == activeID && !$0.locked }) else { return }
        audioPlayer.stop()
    }

    // MARK: - 几何

    private func refreshAttachedWindows(configuredIDs: Set<String>? = nil) {
        let screensByID = Dictionary(uniqueKeysWithValues: NSScreen.screens.compactMap { screen in
            DisplayIdentity.identifier(for: screen).map { ($0, screen) }
        })
        let availableIDs = NSScreen.screens.compactMap(DisplayIdentity.identifier(for:))
        let defaultID = Self.defaultScreen(in: NSScreen.screens).flatMap(DisplayIdentity.identifier(for:))
        let targetIDs = DisplayAttachmentSelection.resolvedIDs(
            configuredIDs: configuredIDs ?? settings.attachedDisplayIDs,
            availableIDs: availableIDs,
            defaultID: defaultID
        )

        if isOpen, let activeDisplayID, !targetIDs.contains(activeDisplayID) {
            close()
        }

        let targetSet = Set(targetIDs)
        for (displayID, window) in Array(windows) where !targetSet.contains(displayID) {
            window.orderOut(nil)
            window.contentView = nil
            windows.removeValue(forKey: displayID)
        }

        attachedDisplayOrder = targetIDs
        panelWidth = clampedPanelWidth(CGFloat(settings.panelWidth))
        for displayID in targetIDs {
            guard let screen = screensByID[displayID] else { continue }
            let window = windows[displayID] ?? makeWindow(for: displayID)
            windows[displayID] = window
            window.contentHeight = openHeight()
            let frame = isOpen(on: displayID)
                ? metrics(for: screen).openFrame(width: panelWidth, height: window.contentHeight)
                : metrics(for: screen).closedFrame()
            window.setFrame(frame, display: true, animate: false)
            window.orderFrontRegardless()
        }
    }

    private func makeWindow(for displayID: String) -> NotchWindow {
        let window = NotchWindow(enableInFullScreen: settings.enableInFullScreen)
        let root = NotchRootView(displayID: displayID)
            .environmentObject(store)
            .environmentObject(settings)
            .environmentObject(self)
            .environmentObject(draftModel)
            .environmentObject(audioPlayer)
            .environmentObject(recorder)
        let hosting = NotchHostingView(rootView: AnyView(root))
        hosting.autoresizingMask = [.width, .height]
        window.contentView = hosting
        return window
    }

    private static func defaultScreen(in screens: [NSScreen]) -> NSScreen? {
        screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main ?? screens.first
    }

    private func resolvedOpenDisplayID(_ requestedDisplayID: String?) -> String? {
        if let requestedDisplayID, windows[requestedDisplayID] != nil { return requestedDisplayID }
        if let notchedID = attachedDisplayOrder.first(where: { id in
            (screen(for: id)?.safeAreaInsets.top ?? 0) > 0
        }) { return notchedID }
        if let mainID = NSScreen.main.flatMap(DisplayIdentity.identifier(for:)), windows[mainID] != nil { return mainID }
        return attachedDisplayOrder.first
    }

    private func screen(for displayID: String) -> NSScreen? {
        NSScreen.screens.first(where: { DisplayIdentity.identifier(for: $0) == displayID })
    }

    /// 胶囊视觉位置需要区分刘海屏与普通外接屏：前者贴在刘海下方，后者贴近菜单栏下沿。
    func displayHasNotch(_ displayID: String) -> Bool {
        (screen(for: displayID)?.safeAreaInsets.top ?? 0) > 0
    }

    private func metrics(for screen: NSScreen) -> NotchMetrics {
        return NotchMetrics(screenFrame: screen.frame,
                            visibleFrame: screen.visibleFrame,
                            safeAreaTop: screen.safeAreaInsets.top,
                            auxLeftWidth: screen.auxiliaryTopLeftArea?.width,
                            auxRightWidth: screen.auxiliaryTopRightArea?.width)
    }

    private func metrics(for displayID: String? = nil) -> NotchMetrics? {
        let resolvedID = displayID ?? activeDisplayID ?? resolvedOpenDisplayID(nil)
        return resolvedID.flatMap(screen(for:)).map(metrics(for:))
    }

    private func closedFrame(for displayID: String) -> CGRect {
        metrics(for: displayID)?.closedFrame() ?? .zero
    }

    private func openFrame(for displayID: String) -> CGRect {
        guard let window = windows[displayID] else { return .zero }
        return metrics(for: displayID)?.openFrame(width: panelWidth, height: window.contentHeight) ?? .zero
    }

    // MARK: - 横向调整宽度

    /// 由 AppKit 的 mouseDown 显式固定一次拖动会话，窗口 frame 变化时不重新起算。
    func beginPanelResize(from edge: HorizontalEdge, mouseScreenX: CGFloat) {
        guard isOpen else { return }
        resizeEdge = edge
        resizeStartWidth = panelWidth
        resizeStartMouseX = mouseScreenX
    }

    /// 用 AppKit 事件的屏幕绝对坐标计算距离；面板保持居中，边缘移动 1pt 对应总宽度变化 2pt。
    func updatePanelResize(mouseScreenX: CGFloat) {
        guard isOpen,
              let edge = resizeEdge,
              let startWidth = resizeStartWidth,
              let startMouseX = resizeStartMouseX else { return }
        let mouseDelta = mouseScreenX - startMouseX
        let signedDelta = edge == .trailing ? mouseDelta : -mouseDelta
        applyPanelWidth(startWidth + signedDelta * 2, persist: false)
    }

    func endPanelResize() {
        guard resizeStartWidth != nil else { return }
        resizeEdge = nil
        resizeStartWidth = nil
        resizeStartMouseX = nil
        settings.setPanelWidth(Double(panelWidth))
    }

    /// 辅助功能等非拖拽入口按固定步长调整并立即持久化。
    func adjustPanelWidth(by delta: CGFloat) {
        applyPanelWidth(panelWidth + delta, persist: true)
    }

    private func applyPanelWidth(_ proposedWidth: CGFloat, persist: Bool) {
        let width = clampedPanelWidth(proposedWidth)
        guard width != panelWidth else {
            if persist { settings.setPanelWidth(Double(width)) }
            return
        }
        panelWidth = width
        if isOpen, let activeDisplayID {
            setFrame(openFrame(for: activeDisplayID), on: activeDisplayID, animate: false)
        }
        if persist { settings.setPanelWidth(Double(width)) }
    }

    private func clampedPanelWidth(_ proposedWidth: CGFloat) -> CGFloat {
        guard let currentMetrics = metrics() else {
            return min(max(proposedWidth, CGFloat(AppSettings.minimumPanelWidth)),
                       CGFloat(AppSettings.maximumPanelWidth))
        }
        let screenMaximum = max(0, currentMetrics.screenFrame.width - 40)
        let maximum = min(CGFloat(AppSettings.maximumPanelWidth), screenMaximum)
        let notchSafeMinimum = currentMetrics.hasNotch ? currentMetrics.notchWidth + 96 : 0
        let desiredMinimum = max(CGFloat(AppSettings.minimumPanelWidth), notchSafeMinimum)
        let minimum = min(desiredMinimum, maximum)
        return min(max(proposedWidth, minimum), maximum)
    }

    /// 面板打开时按输入条高度计算的内容高度。
    private func openHeight() -> CGFloat {
        Self.openHeight(fieldHeight: draftModel.fieldContentHeight)
    }

    private static func openHeight(fieldHeight: CGFloat) -> CGFloat {
        let clamped = min(max(fieldHeight, DraftTextMetrics.lineHeight),
                          DraftTextMetrics.lineHeight * 8)
        return 470 + clamped - DraftTextMetrics.lineHeight
    }

    private func setFrame(_ frame: CGRect, on displayID: String, animate: Bool) {
        windows[displayID]?.setFrame(frame, display: true, animate: animate)
    }

    // MARK: - 全局事件

    private func installMonitors() {
        // 点击面板外部 → 收起。
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.close()
        }
        // 面板键盘操作：Esc 清选择/收起、⌘V 粘贴、⌘C 复制所选、⌘A 全选、Delete 删除所选。
        // 输入条聚焦时，除 Esc 和回车外的按键都交给文本框原生处理。
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if self.draftModel.isTyping {
                if event.keyCode == 53, flags.isEmpty { // Esc：退出输入模式
                    self.escapeDraft()
                    return nil
                }
                if event.keyCode == 36, flags.isEmpty { // 回车：提交录入
                    self.submitDraft()
                    return nil
                }
                return event // 其余（含 ⌘V 粘贴进输入条）由文本框处理
            }
            if event.keyCode == 53, flags.isEmpty { // Esc：先清选择，否则收起
                if self.selection.isEmpty { self.close() } else { self.clearSelection() }
                return nil
            }
            if flags == .command {
                switch event.keyCode {
                case 9: self.handlePaste(); return nil   // V
                case 8: self.copySelection(); return nil // C
                case 0: self.selectAll(); return nil     // A
                default: break
                }
            }
            if flags.isEmpty, event.keyCode == 51 || event.keyCode == 117, !self.selection.isEmpty {
                self.deleteSelection() // Delete / Forward Delete
                return nil
            }
            return event
        }
    }

    private func removeMonitors() {
        if let monitor = globalClickMonitor { NSEvent.removeMonitor(monitor); globalClickMonitor = nil }
        if let monitor = localKeyMonitor { NSEvent.removeMonitor(monitor); localKeyMonitor = nil }
    }

    // MARK: - 拖入入库

    /// 将拖入的 provider 按顺序解析并作为一批插入。
    func importProviders(_ providers: [NSItemProvider]) {
        Task { [weak self] in
            guard let self else { return }
            var items: [StashItem] = []
            var managedDuplicates: [StashItem] = []
            for provider in providers {
                switch await self.stagedItem(for: provider) {
                case .item(let item):
                    items.append(item)
                case .duplicate(let existing):
                    managedDuplicates.append(existing)
                case nil:
                    break
                }
            }
            let contentDuplicates = self.store.insert(items)
            let duplicates = self.uniqueItems(managedDuplicates + contentDuplicates)
            guard !items.isEmpty || !duplicates.isEmpty else { return }
            let addedCount = items.count - contentDuplicates.count
            if duplicates.isEmpty {
                self.feedback("已暂存 \(addedCount) 项")
                if self.openedByDrag { self.scheduleAutoClose() }
            } else {
                // 有重复时不自动收起：高亮已有项目，让用户看到。
                self.selection = Set(duplicates.map(\.id))
                self.feedback(self.duplicateFeedback(added: addedCount,
                                                     duplicates: duplicates))
            }
        }
    }

    /// 去重反馈文案：全部重复时强调"已高亮"，部分重复时报告两边数量。
    private func duplicateFeedback(added: Int, duplicates: [StashItem]) -> String {
        let existingText = duplicates.count == 1
            ? "「\(duplicates[0].displayName)」已存在"
            : "\(duplicates.count) 项已存在"
        return added > 0 ? "已暂存 \(added) 项，\(existingText)" : "\(existingText)，高亮显示"
    }

    private enum StagedDrop {
        case item(StashItem)
        case duplicate(StashItem)
    }

    private struct TemporaryDropFile {
        let url: URL
        let directory: URL
    }

    /// 单个 provider 按优先级归类：文件 > 音频文件承诺 > 图片 > 链接 > 文字。
    private func stagedItem(for provider: NSItemProvider) async -> StagedDrop? {
        let url = await loadURL(provider)
        if let url, url.isFileURL {
            if let existing = store.existingItem(forManagedURL: url) {
                return .duplicate(existing)
            }
            return (try? store.stageFile(at: url)).map(StagedDrop.item)
        }
        if let audioFile = await loadAudioFileRepresentation(provider) {
            defer { try? FileManager.default.removeItem(at: audioFile.directory) }
            return (try? store.stageFile(at: audioFile.url)).map(StagedDrop.item)
        }
        if let audio = await loadAudioData(provider) {
            return (try? store.stageAudioData(audio.data,
                                              suggestedName: audio.name,
                                              fileExtension: audio.ext)).map(StagedDrop.item)
        }
        if let image = await loadImage(provider) {
            return (try? store.stageImageData(image.data,
                                              suggestedName: "拖入图片",
                                              fileExtension: image.ext)).map(StagedDrop.item)
        }
        if let url {
            return .item(StashItem.makeLink(urlString: url.absoluteString, title: nil))
        }
        if let text = await loadText(provider),
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .item(StashItem.makeText(text))
        }
        return nil
    }

    private func loadURL(_ provider: NSItemProvider) async -> URL? {
        // Finder 的 .txt 等文档同时声明 public.file-url 与 public.text；部分 provider
        // 无法通过 loadObject(URL.self) 还原文件 URL。先读取最权威的 file-url 原始表示，
        // 避免回退到 String 后把真实文档错误建成文字项、绕过文件哈希去重。
        await DropFileURLLoader.load(from: provider)
    }

    private func loadText(_ provider: NSItemProvider) async -> String? {
        guard provider.canLoadObject(ofClass: String.self) else { return nil }
        return await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: String.self) { string, _ in
                continuation.resume(returning: string)
            }
        }
    }

    /// 读取语音备忘录等来源提供的音频文件承诺。provider 回调返回的 URL 只在回调期间有效，
    /// 因此先复制到自有临时目录，随后再交给 StashStore 入库。
    private func loadAudioFileRepresentation(_ provider: NSItemProvider) async -> TemporaryDropFile? {
        guard let type = preferredAudioType(for: provider) else { return nil }
        let suggestedName = provider.suggestedName
        let preferredExtension = type.preferredFilenameExtension ?? "m4a"
        return await withCheckedContinuation { continuation in
            provider.loadFileRepresentation(forTypeIdentifier: type.identifier) { sourceURL, _ in
                guard let sourceURL else {
                    continuation.resume(returning: nil)
                    return
                }
                let directory = FileManager.default.temporaryDirectory
                    .appendingPathComponent("ForNowDrop/\(UUID().uuidString)", isDirectory: true)
                let name = Self.dropFileName(suggested: suggestedName,
                                             fallback: sourceURL.lastPathComponent,
                                             fileExtension: preferredExtension)
                let destination = directory.appendingPathComponent(name)
                do {
                    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                    try FileManager.default.copyItem(at: sourceURL, to: destination)
                    continuation.resume(returning: TemporaryDropFile(url: destination, directory: directory))
                } catch {
                    try? FileManager.default.removeItem(at: directory)
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    /// 少数 provider 只暴露音频 data representation；作为文件承诺读取失败时的回退。
    private func loadAudioData(_ provider: NSItemProvider) async -> (data: Data, name: String, ext: String)? {
        guard let type = preferredAudioType(for: provider) else { return nil }
        let ext = type.preferredFilenameExtension ?? "m4a"
        let name = Self.dropFileName(suggested: provider.suggestedName,
                                     fallback: "拖入录音",
                                     fileExtension: ext)
        let data: Data? = await withCheckedContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: type.identifier) { data, _ in
                continuation.resume(returning: data)
            }
        }
        guard let data else { return nil }
        return (data, name, ext)
    }

    private func preferredAudioType(for provider: NSItemProvider) -> UTType? {
        let types = provider.registeredTypeIdentifiers
            .compactMap(UTType.init)
            .filter { $0.conforms(to: .audio) }
        return types.first(where: { $0.preferredFilenameExtension != nil }) ?? types.first
    }

    private nonisolated static func dropFileName(suggested: String?,
                                                  fallback: String,
                                                  fileExtension: String) -> String {
        let trimmed = suggested?.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseName = trimmed.flatMap { $0.isEmpty ? nil : $0 } ?? fallback
        var name = URL(fileURLWithPath: baseName).lastPathComponent
            .replacingOccurrences(of: ":", with: "-")
        let ext = fileExtension.trimmingCharacters(in: CharacterSet(charactersIn: ". "))
        if !ext.isEmpty, (name as NSString).pathExtension.isEmpty {
            name += "." + ext
        }
        return name
    }

    private func loadImage(_ provider: NSItemProvider) async -> (data: Data, ext: String)? {
        let imageTypes = provider.registeredTypeIdentifiers
            .compactMap { UTType($0) }
            .filter { $0.conforms(to: .image) }
        guard let type = imageTypes.first(where: { $0.preferredFilenameExtension != nil }) ?? imageTypes.first else {
            return nil
        }
        let data: Data? = await withCheckedContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: type.identifier) { data, _ in
                continuation.resume(returning: data)
            }
        }
        guard let data else { return nil }
        return (data, type.preferredFilenameExtension ?? "png")
    }

    private func uniqueItems(_ candidates: [StashItem]) -> [StashItem] {
        var seen: Set<UUID> = []
        return candidates.filter { seen.insert($0.id).inserted }
    }

    // MARK: - 粘贴入库

    private func handlePaste() {
        let content = PasteboardImporter.classify(NSPasteboardReader())
        let result = PasteboardCommit.commit(content, to: store)
        if result.addedCount > 0 || !result.duplicates.isEmpty {
            if result.duplicates.isEmpty {
                feedback(pasteMessage(for: content))
            } else {
                selection = Set(result.duplicates.map(\.id))
                feedback(duplicateFeedback(added: result.addedCount, duplicates: result.duplicates))
            }
        } else {
            NSSound.beep()
        }
    }

    private func pasteMessage(for content: PasteboardContent) -> String {
        switch content {
        case .files(let urls): return "已暂存 \(urls.count) 个文件"
        case .image: return "已暂存图片"
        case .link: return "已暂存链接"
        case .text: return "已暂存文字"
        case .empty: return ""
        }
    }

    // MARK: - 快速录入

    /// 提交输入条草稿：非空白文字入库、置顶；若是链接则按链接建项，随后收起。
    func submitDraft() {
        let trimmed = draftModel.draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            close()
            return
        }
        if let url = URL(string: trimmed), url.scheme?.lowercased().hasPrefix("http") == true {
            store.addLink(urlString: trimmed, title: nil)
        } else {
            store.addText(draftModel.draft)
        }
        feedback("已录入")
        close()
    }

    /// Esc 在输入模式下：有草稿先清空，否则收起。
    func escapeDraft() {
        if draftModel.draft.isEmpty {
            close()
        } else {
            draftModel.draft = ""
        }
    }

    // MARK: - 录音

    /// 点击 mic：开始录音；录音中再次点击停止并入库。
    /// 停止入库后自动展开面板并高亮新录音，方便用户看到文件已就位。
    func toggleRecording(on displayID: String? = nil) {
        if recorder.isRecording {
            if let item = recorder.stopAndStash() {
                feedback("已录制 · \(item.durationText ?? "")")
                open(on: displayID)
                selection = [item.id]
                scrollTargetItemID = item.id
                scrollToTopRequest += 1 // 列表若已滚动，把新录音滚回视野
            } else {
                NSSound.beep()
            }
        } else {
            // 避免扬声器正在播放的内容被麦克风重新录入。
            audioPlayer.stop()
            recorder.start()
        }
    }

    // MARK: - 面板内音频播放

    func toggleAudioPlayback(_ item: StashItem) {
        guard item.kind == .audio else { return }
        guard !recorder.isRecording else {
            feedback("请先停止录音再播放")
            return
        }
        guard let url = store.absoluteURL(for: item),
              FileManager.default.fileExists(atPath: url.path) else {
            feedback("录音文件不存在")
            return
        }
        if !audioPlayer.toggle(itemID: item.id, fileURL: url) {
            feedback("无法播放这段录音")
        }
    }

    // MARK: - 快速预览

    func quickLook(_ item: StashItem) {
        guard let url = store.absoluteURL(for: item) else { return }
        QuickLookCoordinator.shared.present([url])
    }

    /// 预览文字原文（无对应文件的文本项，双击查看）。
    func previewText(_ item: StashItem) {
        guard item.kind == .text, let text = item.text, !text.isEmpty else { return }
        close()
        textPreview.show(title: item.displayName, text: text)
    }

    // MARK: - 反馈

    func feedback(_ message: String) {
        if settings.soundFeedback {
            NSSound(named: "Pop")?.play()
        }
        showToast(message)
    }

    func showToast(_ message: String) {
        guard !message.isEmpty else { return }
        toast = message
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_300_000_000)
            if !Task.isCancelled { self?.toast = nil }
        }
    }

    private func scheduleAutoClose() {
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_100_000_000)
            self?.close()
        }
    }
}
