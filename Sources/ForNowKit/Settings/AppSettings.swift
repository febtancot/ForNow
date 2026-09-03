import Foundation
import Combine

/// 用户设置，持久化于 UserDefaults。
@MainActor
public final class AppSettings: ObservableObject {
    public static let defaultPanelWidth = 384.0
    public static let minimumPanelWidth = 320.0
    public static let maximumPanelWidth = 720.0

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.launchAtLogin = defaults.object(forKey: Keys.launchAtLogin) as? Bool ?? false
        // 默认避开全屏 Space，防止胶囊覆盖视频等沉浸式内容。
        // 已明确修改过此选项的用户仍沿用其持久化选择。
        self.enableInFullScreen = defaults.object(forKey: Keys.enableInFullScreen) as? Bool ?? false
        self.soundFeedback = defaults.object(forKey: Keys.soundFeedback) as? Bool ?? true
        self.animations = defaults.object(forKey: Keys.animations) as? Bool ?? true
        let storedPanelWidth = defaults.object(forKey: Keys.panelWidth).map { _ in defaults.double(forKey: Keys.panelWidth) }
        self.panelWidth = Self.clampedPanelWidth(storedPanelWidth ?? Self.defaultPanelWidth)
        let storedDisplayIDs = Set(defaults.stringArray(forKey: Keys.attachedDisplayIDs) ?? [])
        self.displayAttachmentSelection = Self.loadDisplayAttachmentSelection(
            mode: defaults.string(forKey: Keys.displayAttachmentMode),
            storedDisplayIDs: storedDisplayIDs
        )
        self.hotKey = GlobalHotKey.load(from: defaults) ?? .default
    }

    @Published public var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: Keys.launchAtLogin) }
    }

    /// 是否允许胶囊加入其他应用的全屏 Space（默认关闭）。
    @Published public var enableInFullScreen: Bool {
        didSet { defaults.set(enableInFullScreen, forKey: Keys.enableInFullScreen) }
    }

    @Published public var soundFeedback: Bool {
        didSet { defaults.set(soundFeedback, forKey: Keys.soundFeedback) }
    }

    @Published public var animations: Bool {
        didSet { defaults.set(animations, forKey: Keys.animations) }
    }

    /// 展开面板的用户自定义宽度；实际显示时还会按当前屏幕和刘海宽度动态限制。
    @Published public private(set) var panelWidth: Double

    public func setPanelWidth(_ width: Double) {
        panelWidth = Self.clampedPanelWidth(width)
        defaults.set(panelWidth, forKey: Keys.panelWidth)
    }

    public func resetPanelWidth() {
        setPanelWidth(Self.defaultPanelWidth)
    }

    /// 收起态胶囊的显示器选择。默认自动选择一块屏幕，也可明确选择多块或全部关闭。
    /// 指定显示器断开时仍保留其 id，重新接入后自动恢复。
    @Published public private(set) var displayAttachmentSelection: DisplayAttachmentSelection

    /// 兼容既有调用方的已选显示器视图。自动模式与全部关闭均没有明确选择的 ID；
    /// 需要区分这两种状态时应读取 `displayAttachmentSelection`。
    public var attachedDisplayIDs: Set<String> {
        displayAttachmentSelection.selectedDisplayIDs
    }

    public func setAttachedDisplayIDs(_ displayIDs: Set<String>) {
        // 保留旧 API 语义：空集合表示恢复自动默认。明确全关应使用 `.disabled`。
        setDisplayAttachmentSelection(displayIDs.isEmpty ? .automatic : .selected(displayIDs))
    }

    public func setDisplayAttachmentSelection(_ selection: DisplayAttachmentSelection) {
        let normalizedSelection: DisplayAttachmentSelection
        if case let .selected(displayIDs) = selection, displayIDs.isEmpty {
            normalizedSelection = .disabled
        } else {
            normalizedSelection = selection
        }

        displayAttachmentSelection = normalizedSelection
        switch normalizedSelection {
        case .automatic:
            defaults.set(DisplayAttachmentMode.automatic.rawValue, forKey: Keys.displayAttachmentMode)
            defaults.set([], forKey: Keys.attachedDisplayIDs)
        case let .selected(displayIDs):
            // 先保存选择，再切换模式；若进程在两次写入之间结束，旧模式仍会安全生效。
            defaults.set(displayIDs.sorted(), forKey: Keys.attachedDisplayIDs)
            defaults.set(DisplayAttachmentMode.selected.rawValue, forKey: Keys.displayAttachmentMode)
        case .disabled:
            defaults.set(DisplayAttachmentMode.disabled.rawValue, forKey: Keys.displayAttachmentMode)
            defaults.set([], forKey: Keys.attachedDisplayIDs)
        }
    }

    public func resetAttachedDisplays() {
        setDisplayAttachmentSelection(.automatic)
    }

    @Published public var hotKey: GlobalHotKey {
        didSet { hotKey.save(to: defaults) }
    }

    private enum Keys {
        static let launchAtLogin = "settings.launchAtLogin"
        static let enableInFullScreen = "settings.enableInFullScreen"
        static let soundFeedback = "settings.soundFeedback"
        static let animations = "settings.animations"
        static let panelWidth = "settings.panelWidth"
        static let attachedDisplayIDs = "settings.attachedDisplayIDs"
        static let displayAttachmentMode = "settings.displayAttachmentMode"
    }

    private enum DisplayAttachmentMode: String {
        case automatic
        case selected
        case disabled
    }

    private static func loadDisplayAttachmentSelection(
        mode: String?,
        storedDisplayIDs: Set<String>
    ) -> DisplayAttachmentSelection {
        if let storedMode = mode.flatMap(DisplayAttachmentMode.init(rawValue:)) {
            switch storedMode {
            case .automatic:
                return .automatic
            case .selected:
                // selected + 空数组只可能来自不完整或损坏的写入，安全回退到默认屏。
                return storedDisplayIDs.isEmpty ? .automatic : .selected(storedDisplayIDs)
            case .disabled:
                return .disabled
            }
        }

        // 旧版本没有 mode key：缺少或为空的 ID 集合原本都表示自动模式。
        // 未知 mode 同样按旧值回退，避免静默隐藏全部胶囊。
        return storedDisplayIDs.isEmpty ? .automatic : .selected(storedDisplayIDs)
    }

    private static func clampedPanelWidth(_ width: Double) -> Double {
        min(max(width, minimumPanelWidth), maximumPanelWidth)
    }
}
