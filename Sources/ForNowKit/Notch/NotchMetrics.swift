import CoreGraphics

/// 由屏幕参数计算暂存窗口的位置与尺寸（纯函数，便于测试）。
///
/// 坐标系与 AppKit 全局坐标一致：原点在主屏左下角，y 向上。
public struct NotchMetrics: Equatable, Sendable {
    public let screenFrame: CGRect
    public let hasNotch: Bool
    public let notchWidth: CGFloat
    public let notchHeight: CGFloat

    /// - Parameters:
    ///   - safeAreaTop: `NSScreen.safeAreaInsets.top`，有刘海时约等于刘海高度。
    ///   - auxLeftWidth/auxRightWidth: `NSScreen.auxiliaryTopLeftArea/RightArea` 的宽度，无刘海时为 nil。
    public init(screenFrame: CGRect, safeAreaTop: CGFloat, auxLeftWidth: CGFloat?, auxRightWidth: CGFloat?) {
        self.screenFrame = screenFrame
        if let left = auxLeftWidth, let right = auxRightWidth,
           left > 0, right > 0, left + right < screenFrame.width {
            self.hasNotch = true
            self.notchWidth = screenFrame.width - left - right
            self.notchHeight = safeAreaTop > 0 ? safeAreaTop : 32
        } else {
            self.hasNotch = false
            self.notchWidth = 0
            self.notchHeight = 0
        }
    }

    /// 顶部居中的窗口 frame（顶边贴屏幕顶）。
    public func topCenteredFrame(width: CGFloat, height: CGFloat) -> CGRect {
        CGRect(x: (screenFrame.midX - width / 2).rounded(),
               y: (screenFrame.maxY - height).rounded(),
               width: width, height: height)
    }

    /// 收起状态：覆盖刘海宽度、并向下延伸出一条可点击/接收拖入的热区（刘海缺口本身无可点击像素，
    /// 真正能命中的是缺口正下方这条带子）。无刘海时为顶部中央的小标签（PRD §7 的备用热区）。
    ///
    /// - Parameter interactiveBelow: 刘海缺口下方额外的可命中高度。需容纳收起态胶囊
    ///   （约 19pt 高 + 2pt 边距），否则胶囊顶部会伸进菜单栏/刘海带被遮挡。
    public func closedFrame(fallbackWidth: CGFloat = 190, interactiveBelow: CGFloat = 26) -> CGRect {
        let width = hasNotch ? max(notchWidth, 160) : fallbackWidth
        let height: CGFloat = hasNotch ? (notchHeight + interactiveBelow) : 34
        return topCenteredFrame(width: width, height: height)
    }

    /// 展开状态：顶部居中，尺寸受屏幕约束。
    public func openFrame(width: CGFloat, height: CGFloat) -> CGRect {
        let clampedWidth = min(width, screenFrame.width - 40)
        let clampedHeight = min(height, screenFrame.height - 120)
        return topCenteredFrame(width: clampedWidth, height: clampedHeight)
    }
}
