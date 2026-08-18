import AppKit
import ColorSync

/// 为显示器生成可跨重启、重新连接复用的标识。系统运行时的 CGDirectDisplayID
/// 可能变化，因此设置持久化使用 ColorSync 提供的显示器 UUID。
enum DisplayIdentity {
    static func identifier(for screen: NSScreen) -> String? {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }
        guard let unmanagedUUID = CGDisplayCreateUUIDFromDisplayID(number.uint32Value) else {
            // 少数虚拟显示器不提供 ColorSync UUID；仍保证本次连接期间可选择。
            return "runtime-\(number.uint32Value)"
        }
        let uuid = unmanagedUUID.takeRetainedValue()
        return (CFUUIDCreateString(nil, uuid) as String?) ?? "runtime-\(number.uint32Value)"
    }
}
