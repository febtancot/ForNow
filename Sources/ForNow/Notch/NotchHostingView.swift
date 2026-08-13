import AppKit
import SwiftUI

/// 承载面板的 hosting view。允许在应用非激活时也把首次点击直接传给内容
/// （否则收起态点击可能被当作"激活窗口"而吞掉，导致点了没反应）。
final class NotchHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    required init(rootView: Content) {
        super.init(rootView: rootView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
