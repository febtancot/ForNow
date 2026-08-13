import Foundation
import Combine

/// 用户设置，持久化于 UserDefaults。
@MainActor
public final class AppSettings: ObservableObject {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.launchAtLogin = defaults.object(forKey: Keys.launchAtLogin) as? Bool ?? false
        self.enableInFullScreen = defaults.object(forKey: Keys.enableInFullScreen) as? Bool ?? true
        self.soundFeedback = defaults.object(forKey: Keys.soundFeedback) as? Bool ?? true
        self.animations = defaults.object(forKey: Keys.animations) as? Bool ?? true
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

    @Published public var hotKey: GlobalHotKey {
        didSet { hotKey.save(to: defaults) }
    }

    private enum Keys {
        static let launchAtLogin = "settings.launchAtLogin"
        static let enableInFullScreen = "settings.enableInFullScreen"
        static let soundFeedback = "settings.soundFeedback"
        static let animations = "settings.animations"
    }
}
