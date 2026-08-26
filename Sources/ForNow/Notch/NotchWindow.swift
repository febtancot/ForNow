import AppKit

/// 承载暂存面板的无边框浮动面板：不激活应用即可接收键盘（Cmd+V / Esc），并可跨普通 Space 显示。
final class NotchWindow: NSPanel {
    /// 面板打开时内容的理想高度。宽度保持当前值，仅调整高度。
    /// 输入条多行扩展时由此驱动窗口长高（避免 SwiftUI 逐帧动画大段文字重排）。
    var contentHeight: CGFloat = 0 {
        didSet {
            guard contentHeight != oldValue else { return }
            setContentSize(NSSize(width: frame.width, height: contentHeight))
        }
    }

    init(enableInFullScreen: Bool) {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 190, height: 30),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .statusBar
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        setFullScreenParticipationEnabled(enableInFullScreen)
        animationBehavior = .none
    }

    /// `.fullScreenAuxiliary` 会让面板与其他 App 的全屏窗口同处一个 Space。
    /// 默认不设置它，确保全屏视频和其他沉浸式内容位于胶囊上层。
    func setFullScreenParticipationEnabled(_ enabled: Bool) {
        var behavior: NSWindow.CollectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .ignoresCycle
        ]
        if enabled {
            behavior.insert(.fullScreenAuxiliary)
        }
        collectionBehavior = behavior
    }

    // 允许成为 key（接收 Cmd+V / Esc），但不成为 main，避免抢占应用激活。
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
