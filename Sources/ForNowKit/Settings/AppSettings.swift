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
        self.attachedDisplayIDs = Set(defaults.stringArray(forKey: Keys.attachedDisplayIDs) ?? [])
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

    /// 用户明确选择的小药丸吸附屏幕。空集合表示自动模式：优先带刘海的屏幕，
    /// 否则使用主屏幕。显示器断开时保留其 id，重新接入后自动恢复。
    @Published public private(set) var attachedDisplayIDs: Set<String>

    public func setAttachedDisplayIDs(_ displayIDs: Set<String>) {
        attachedDisplayIDs = displayIDs
        defaults.set(displayIDs.sorted(), forKey: Keys.attachedDisplayIDs)
    }

    public func resetAttachedDisplays() {
        setAttachedDisplayIDs([])
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
    }

    private static func clampedPanelWidth(_ width: Double) -> Double {
        min(max(width, minimumPanelWidth), maximumPanelWidth)
    }
}
