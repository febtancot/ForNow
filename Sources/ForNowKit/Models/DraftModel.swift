import Foundation
import Combine

/// 快速录入输入条的独立状态模型。
///
/// 独立于 `NotchController`，使逐字输入/粘贴大段文字只重绘输入条本身，
/// 而不触发整个面板（项目列表、底部统计、Toast）的观察者连锁重渲染。
@MainActor
public final class DraftModel: ObservableObject {
    /// 输入条草稿内容。发布给输入条视图（唯一观察者），打字/粘贴只重绘输入条本身。
    @Published public var draft = "" {
        didSet {
            guard draft != oldValue else { return }
            scheduleDraftDidChange()
        }
    }
    /// 输入条是否持有键盘焦点。聚焦时 ⌘V/⌘A/Delete 等交给文本框原生处理。
    public var isTyping = false

    /// 草稿内容变化（异步、去抖合并，粘贴大段文字只触发一次）。
    /// 面板监听它来同步窗口高度。
    public let draftDidChange = PassthroughSubject<Void, Never>()
    /// 回车提交草稿（提交与否由外部决定，如空草稿只收起）。
    public var onSubmit: (() -> Void)?

    private var scheduled = false

    public init() {}

    private func scheduleDraftDidChange() {
        guard !scheduled else { return }
        scheduled = true
        Task { [weak self] in
            await Task.yield()
            guard let self else { return }
            self.scheduled = false
            self.draftDidChange.send()
        }
    }
}
