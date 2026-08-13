import AppKit

/// 承载暂存面板的无边框浮动面板：不激活应用即可接收键盘（Cmd+V / Esc），跨 Space 与全屏可见。
final class NotchWindow: NSPanel {
    init() {
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
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        animationBehavior = .none
    }

    // 允许成为 key（接收 Cmd+V / Esc），但不成为 main，避免抢占应用激活。
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
