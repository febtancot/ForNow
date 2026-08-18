import Foundation

/// 将持久化的显示器选择解析为当前实际可创建窗口的显示器列表。
public enum DisplayAttachmentSelection {
    /// - Parameters:
    ///   - configuredIDs: 用户明确选择的显示器；空集合表示自动选择默认屏幕。
    ///   - availableIDs: 当前已连接显示器，顺序与系统屏幕列表一致。
    ///   - defaultID: 当前默认吸附屏幕（优先刘海屏，否则主屏）。
    /// - Returns: 当前要显示小药丸的 id。若所有已选屏幕均断开，会临时回退到默认屏幕。
    public static func resolvedIDs(
        configuredIDs: Set<String>,
        availableIDs: [String],
        defaultID: String?
    ) -> [String] {
        guard !availableIDs.isEmpty else { return [] }

        if configuredIDs.isEmpty {
            return defaultID.map { [$0] } ?? [availableIDs[0]]
        }

        let connected = availableIDs.filter(configuredIDs.contains)
        if !connected.isEmpty { return connected }
        return defaultID.map { [$0] } ?? [availableIDs[0]]
    }
}
