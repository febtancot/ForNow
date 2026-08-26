import AppKit
import ColorSync
import CoreGraphics

/// 为显示器生成可跨重启、重新连接复用的标识。系统运行时的 CGDirectDisplayID
/// 可能变化，因此设置持久化使用 ColorSync 提供的显示器 UUID。
enum DisplayIdentity {
    static func directDisplayID(for screen: NSScreen) -> CGDirectDisplayID? {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }
        return CGDirectDisplayID(number.uint32Value)
    }

    static func identifier(for screen: NSScreen) -> String? {
        guard let directDisplayID = directDisplayID(for: screen) else { return nil }
        guard let unmanagedUUID = CGDisplayCreateUUIDFromDisplayID(directDisplayID) else {
            // 少数虚拟显示器不提供 ColorSync UUID；仍保证本次连接期间可选择。
            return "runtime-\(directDisplayID)"
        }
        let uuid = unmanagedUUID.takeRetainedValue()
        return (CFUUIDCreateString(nil, uuid) as String?) ?? "runtime-\(directDisplayID)"
    }

    /// WindowServer 的窗口 bounds 使用 Quartz 显示器坐标（原点与 NSScreen 不同）。
    static func quartzBounds(for screen: NSScreen) -> CGRect? {
        directDisplayID(for: screen).map(CGDisplayBounds)
    }
}
