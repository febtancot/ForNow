import AppKit
import SwiftUI
import UniformTypeIdentifiers
import ForNowKit

/// 管理 Notch 暂存面板的显示、开合、定位与全局事件监听。
@MainActor
final class NotchController: ObservableObject {
    @Published private(set) var isOpen = false
    /// 拖入内容悬停时高亮（供面板反馈）。
    @Published var isDropTargeted = false
    /// 克制的操作反馈提示（如"已复制"）。
    @Published var toast: String?
    /// 当前选中的项目 id（支持单选/多选/全选）。
    @Published var selection: Set<UUID> = []
    /// 快速录入输入条的草稿。放控制器里以便全局键盘处理（回车提交、Esc 清空）。
    @Published var draft = ""
    /// 输入条是否持有键盘焦点。聚焦时 ⌘V/⌘A/Delete 等交给文本框原生处理。
    @Published var isTyping = false

    let store: StashStore
    let settings: AppSettings

    private let window: NotchWindow
    private let textPreview = TextPreviewController()
    private var globalClickMonitor: Any?
    private var localKeyMonitor: Any?
    private var toastTask: Task<Void, Never>?
    /// 面板是否因拖入而展开（用于拖入落下后自动收起）。
    private var openedByDrag = false

    private let openSize = CGSize(width: 384, height: 470)

    init(store: StashStore, settings: AppSettings) {
        self.store = store
        self.settings = settings
        self.window = NotchWindow()

        let root = NotchRootView()
            .environmentObject(store)
            .environmentObject(settings)
            .environmentObject(self)
        let hosting = NotchHostingView(rootView: AnyView(root))
        hosting.autoresizingMask = [.width, .height]
        window.contentView = hosting

        setFrame(closedFrame(), animate: false)
        window.orderFrontRegardless()
    }

    // MARK: - 开合

    func toggle() { isOpen ? close() : open() }

    func open() {
        guard !isOpen else { return }
        isOpen = true
        openedByDrag = false
        setFrame(openFrame(), animate: settings.animations)
        window.makeKeyAndOrderFront(nil)
        installMonitors()
    }

    func close() {
        guard isOpen else { return }
        isOpen = false
        isDropTargeted = false
        openedByDrag = false
        draft = ""
        isTyping = false
        selection.removeAll()
        removeMonitors()
        setFrame(closedFrame(), animate: settings.animations)
        window.orderFrontRegardless()
    }

    /// 拖动内容靠近 Notch 时自动展开。
    func openForDrag() {
        guard !isOpen else { return }
        open()
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
        let count = selection.count
        store.remove(ids: selection)
        selection.removeAll()
        feedback("已删除 \(count) 项")
    }

    func copyItems(_ items: [StashItem]) {
        guard !items.isEmpty else { return }
        ItemActions.copyItems(items, store: store)
        feedback(items.count > 1 ? "已复制 \(items.count) 项" : "已复制")
    }

    func removeItems(_ items: [StashItem]) {
        guard !items.isEmpty else { return }
        let ids = Set(items.map(\.id))
        store.remove(ids: ids)
        selection.subtract(ids)
        feedback(items.count > 1 ? "已删除 \(items.count) 项" : "已删除")
    }

    // MARK: - 几何

    private func targetScreen() -> NSScreen {
        if let notched = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) {
            return notched
        }
        return NSScreen.main ?? NSScreen.screens.first!
    }

    private func metrics() -> NotchMetrics {
        let screen = targetScreen()
        return NotchMetrics(screenFrame: screen.frame,
                            safeAreaTop: screen.safeAreaInsets.top,
                            auxLeftWidth: screen.auxiliaryTopLeftArea?.width,
                            auxRightWidth: screen.auxiliaryTopRightArea?.width)
    }

    private func closedFrame() -> CGRect { metrics().closedFrame() }
    private func openFrame() -> CGRect { metrics().openFrame(width: openSize.width, height: openSize.height) }

    private func setFrame(_ frame: CGRect, animate: Bool) {
        window.setFrame(frame, display: true, animate: animate)
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
            if self.isTyping {
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
            for provider in providers {
                if let item = await self.stagedItem(for: provider) {
                    items.append(item)
                }
            }
            guard !items.isEmpty else { return }
            self.store.insert(items)
            self.feedback("已暂存 \(items.count) 项")
            if self.openedByDrag { self.scheduleAutoClose() }
        }
    }

    /// 单个 provider 按优先级归类：文件 > 图片 > 链接 > 文字。
    private func stagedItem(for provider: NSItemProvider) async -> StashItem? {
        let url = await loadURL(provider)
        if let url, url.isFileURL {
            return try? store.stageFile(at: url)
        }
        if let image = await loadImage(provider) {
            return try? store.stageImageData(image.data, suggestedName: "拖入图片", fileExtension: image.ext)
        }
        if let url {
            return StashItem.makeLink(urlString: url.absoluteString, title: nil)
        }
        if let text = await loadText(provider),
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return StashItem.makeText(text)
        }
        return nil
    }

    private func loadURL(_ provider: NSItemProvider) async -> URL? {
        guard provider.canLoadObject(ofClass: URL.self) else { return nil }
        return await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                continuation.resume(returning: url)
            }
        }
    }

    private func loadText(_ provider: NSItemProvider) async -> String? {
        guard provider.canLoadObject(ofClass: String.self) else { return nil }
        return await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: String.self) { string, _ in
                continuation.resume(returning: string)
            }
        }
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

    // MARK: - 粘贴入库

    private func handlePaste() {
        let content = PasteboardImporter.classify(NSPasteboardReader())
        if PasteboardCommit.commit(content, to: store) {
            feedback(pasteMessage(for: content))
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
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            close()
            return
        }
        if let url = URL(string: trimmed), url.scheme?.lowercased().hasPrefix("http") == true {
            store.addLink(urlString: trimmed, title: nil)
        } else {
            store.addText(draft)
        }
        feedback("已录入")
        close()
    }

    /// Esc 在输入模式下：有草稿先清空，否则收起。
    func escapeDraft() {
        if draft.isEmpty {
            close()
        } else {
            draft = ""
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
