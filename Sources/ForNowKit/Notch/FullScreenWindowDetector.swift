import CoreGraphics

/// WindowServer 中用于判断某个显示器是否被其他应用完整覆盖的最小快照。
public struct WindowCoverageSnapshot: Sendable {
    public let ownerPID: Int32
    public let layer: Int
    public let alpha: Double
    public let bounds: CGRect

    public init(ownerPID: Int32, layer: Int, alpha: Double, bounds: CGRect) {
        self.ownerPID = ownerPID
        self.layer = layer
        self.alpha = alpha
        self.bounds = bounds
    }
}

/// 识别原生全屏窗口以及 Chrome/YouTube 这类占满显示器的无边框视频窗口。
public enum FullScreenWindowDetector {
    /// 允许少量取整误差；窗口至少覆盖目标显示器 99.5% 的面积才视为全屏。
    private static let minimumCoverage = 0.995

    public static func coveredDisplayIDs(
        displayBoundsByID: [String: CGRect],
        windows: [WindowCoverageSnapshot],
        excludingOwnerPID: Int32
    ) -> Set<String> {
        let candidates = windows.filter {
            $0.ownerPID != excludingOwnerPID && $0.layer == 0 && $0.alpha > 0.01
        }

        return Set(displayBoundsByID.compactMap { displayID, displayBounds in
            guard displayBounds.width > 0, displayBounds.height > 0 else { return nil }
            let displayArea = displayBounds.width * displayBounds.height
            let isCovered = candidates.contains { window in
                let intersection = displayBounds.intersection(window.bounds)
                guard !intersection.isNull else { return false }
                let coveredArea = intersection.width * intersection.height
                return coveredArea / displayArea >= minimumCoverage
            }
            return isCovered ? displayID : nil
        })
    }
}
