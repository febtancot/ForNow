import Foundation

/// 全局快捷键的纯数据表示（与 Carbon 无关，便于测试与持久化）。
/// `keyCode` 采用系统虚拟键码（如 Space = 49）。
public struct GlobalHotKey: Codable, Equatable, Sendable {
    public var keyCode: UInt32
    public var modifiers: Modifiers

    public struct Modifiers: OptionSet, Codable, Equatable, Sendable {
        public let rawValue: UInt32
        public init(rawValue: UInt32) { self.rawValue = rawValue }
        public static let command = Modifiers(rawValue: 1 << 0)
        public static let option  = Modifiers(rawValue: 1 << 1)
        public static let control = Modifiers(rawValue: 1 << 2)
        public static let shift   = Modifiers(rawValue: 1 << 3)
    }

    public init(keyCode: UInt32, modifiers: Modifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// 默认建议：Control + Option + Space。
    public static let `default` = GlobalHotKey(keyCode: 49, modifiers: [.control, .option])

    /// 供界面显示的组合，如 "⌃⌥Space"。
    public var displayString: String {
        var result = ""
        if modifiers.contains(.control) { result += "⌃" }
        if modifiers.contains(.option) { result += "⌥" }
        if modifiers.contains(.shift) { result += "⇧" }
        if modifiers.contains(.command) { result += "⌘" }
        result += Self.keyName(for: keyCode)
        return result
    }

    // MARK: - 持久化

    private static let defaultsKey = "settings.globalHotKey"

    public func save(to defaults: UserDefaults) {
        if let data = try? JSONEncoder().encode(self) {
            defaults.set(data, forKey: Self.defaultsKey)
        }
    }

    public static func load(from defaults: UserDefaults) -> GlobalHotKey? {
        guard let data = defaults.data(forKey: defaultsKey) else { return nil }
        return try? JSONDecoder().decode(GlobalHotKey.self, from: data)
    }

    // MARK: - 键名

    static func keyName(for keyCode: UInt32) -> String {
        if let name = namedKeys[keyCode] { return name }
        if let letter = letterKeys[keyCode] { return letter }
        if let digit = digitKeys[keyCode] { return digit }
        return "Key\(keyCode)"
    }

    private static let namedKeys: [UInt32: String] = [
        49: "Space", 36: "Return", 53: "Esc", 48: "Tab", 51: "Delete",
        123: "←", 124: "→", 125: "↓", 126: "↑",
    ]
    private static let letterKeys: [UInt32: String] = [
        0: "A", 11: "B", 8: "C", 2: "D", 14: "E", 3: "F", 5: "G", 4: "H",
        34: "I", 38: "J", 40: "K", 37: "L", 46: "M", 45: "N", 31: "O", 35: "P",
        12: "Q", 15: "R", 1: "S", 17: "T", 32: "U", 9: "V", 13: "W", 7: "X",
        16: "Y", 6: "Z",
    ]
    private static let digitKeys: [UInt32: String] = [
        29: "0", 18: "1", 19: "2", 20: "3", 21: "4", 23: "5", 22: "6", 26: "7", 28: "8", 25: "9",
    ]
}
