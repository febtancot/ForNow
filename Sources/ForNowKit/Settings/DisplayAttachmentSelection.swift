import Foundation

/// 用户对收起态胶囊所在显示器的选择。
///
/// `automatic` 与 `disabled` 必须是两个独立状态：前者让首次使用时默认显示一个
/// 胶囊，后者表示用户明确关闭了所有显示器上的胶囊。
public enum DisplayAttachmentSelection: Equatable, Sendable {
    case automatic
    case selected(Set<String>)
    case disabled

    public var selectedDisplayIDs: Set<String> {
        guard case let .selected(displayIDs) = self else { return [] }
        return displayIDs
    }

    public var isAutomatic: Bool {
        self == .automatic
    }

    public var isDisabled: Bool {
        self == .disabled
    }

    /// 将选择解析为当前应显示收起态胶囊的显示器列表。
    ///
    /// 已明确选择的显示器全部断开时，会临时回退到默认屏幕；明确关闭全部胶囊时，
    /// 热插拔不会重新显示胶囊。
    public func resolvedIDs(
        availableIDs: [String],
        defaultID: String?
    ) -> [String] {
        guard !availableIDs.isEmpty else { return [] }

        switch self {
        case .automatic:
            return [validDefaultID(availableIDs: availableIDs, defaultID: defaultID)]
        case let .selected(configuredIDs):
            guard !configuredIDs.isEmpty else { return [] }
            let connected = availableIDs.filter(configuredIDs.contains)
            if !connected.isEmpty { return connected }
            return [validDefaultID(availableIDs: availableIDs, defaultID: defaultID)]
        case .disabled:
            return []
        }
    }

    /// 返回用户切换一块已连接显示器后的规范化选择。
    ///
    /// 关闭最后一块当前有效屏幕时直接进入 `disabled`，不会被历史上已断开的
    /// 显示器 ID 再次回退到默认屏幕。
    public func togglingDisplay(
        _ displayID: String,
        enabled: Bool,
        availableIDs: [String],
        defaultID: String?
    ) -> DisplayAttachmentSelection {
        guard availableIDs.contains(displayID) else { return self }

        var selectedIDs: Set<String>
        switch self {
        case .automatic:
            selectedIDs = Set(resolvedIDs(availableIDs: availableIDs, defaultID: defaultID))
        case let .selected(configuredIDs):
            selectedIDs = configuredIDs
        case .disabled:
            selectedIDs = []
        }

        if enabled {
            selectedIDs.insert(displayID)
        } else {
            selectedIDs.remove(displayID)
            if selectedIDs.isDisjoint(with: Set(availableIDs)) {
                return .disabled
            }
        }

        return Self.normalizedSelection(selectedIDs, defaultID: defaultID)
    }

    /// 全部胶囊关闭时，菜单栏或快捷键仍可按需展开面板。此方法选择临时面板的
    /// 落屏位置，并避开当前不允许覆盖的全屏显示器。
    public static func transientPanelDisplayID(
        requestedID: String?,
        availableIDs: [String],
        defaultID: String?,
        unavailableIDs: Set<String>
    ) -> String? {
        if let requestedID,
           availableIDs.contains(requestedID),
           !unavailableIDs.contains(requestedID) {
            return requestedID
        }
        if let defaultID,
           availableIDs.contains(defaultID),
           !unavailableIDs.contains(defaultID) {
            return defaultID
        }
        return availableIDs.first(where: { !unavailableIDs.contains($0) })
    }

    private static func normalizedSelection(
        _ displayIDs: Set<String>,
        defaultID: String?
    ) -> DisplayAttachmentSelection {
        guard !displayIDs.isEmpty else { return .disabled }
        if let defaultID, displayIDs == Set([defaultID]) {
            return .automatic
        }
        return .selected(displayIDs)
    }

    private func validDefaultID(availableIDs: [String], defaultID: String?) -> String {
        if let defaultID, availableIDs.contains(defaultID) {
            return defaultID
        }
        return availableIDs[0]
    }
}
