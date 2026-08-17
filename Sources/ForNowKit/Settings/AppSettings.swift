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
        self.enableInFullScreen = defaults.object(forKey: Keys.enableInFullScreen) as? Bool ?? true
        self.soundFeedback = defaults.object(forKey: Keys.soundFeedback) as? Bool ?? true
        self.animations = defaults.object(forKey: Keys.animations) as? Bool ?? true
        let storedPanelWidth = defaults.object(forKey: Keys.panelWidth).map { _ in defaults.double(forKey: Keys.panelWidth) }
        self.panelWidth = Self.clampedPanelWidth(storedPanelWidth ?? Self.defaultPanelWidth)
        self.hotKey = GlobalHotKey.load(from: defaults) ?? .default
    }

    @Published public var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: Keys.launchAtLogin) }
    }

    /// 全屏应用中是否启用（默认启用）。
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

    @Published public var hotKey: GlobalHotKey {
        didSet { hotKey.save(to: defaults) }
    }

    private enum Keys {
        static let launchAtLogin = "settings.launchAtLogin"
        static let enableInFullScreen = "settings.enableInFullScreen"
        static let soundFeedback = "settings.soundFeedback"
        static let animations = "settings.animations"
        static let panelWidth = "settings.panelWidth"
    }

    private static func clampedPanelWidth(_ width: Double) -> Double {
        min(max(width, minimumPanelWidth), maximumPanelWidth)
    }
}
