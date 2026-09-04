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
            scheduleDraftDidChange(forceMeasurement: draft.isEmpty)
        }
    }
    /// 输入条是否持有键盘焦点。聚焦时 ⌘V/⌘A/Delete 等交给文本框原生处理。
    public var isTyping = false

    /// 草稿内容变化（异步、去抖合并，粘贴大段文字只触发一次）。
    /// 面板监听它来同步窗口高度。
    public let draftDidChange = PassthroughSubject<Void, Never>()
    /// 回车提交草稿（提交与否由外部决定，如空草稿只收起）。
    public var onSubmit: (() -> Void)?

    /// 输入条当前内容高度（空草稿为单行高度，超长截断为 8 行），供 ScrollView 定高与窗口驱动用。
    /// 只读，仅随合并后的变化事件更新。
    @Published public private(set) var fieldContentHeight: CGFloat = DraftTextMetrics.lineHeight

    private var scheduled = false
    private var requiresImmediateMeasurement = false
    private var trailingMeasurementTask: Task<Void, Never>?
    private var lastMeasuredAt: Date?
    private var fieldAvailableWidth: CGFloat = 324
    private var hasReceivedFieldAvailableWidth = false
    /// 连续输入时最多每 100ms 测量一次；尾沿任务保证停手后仍会使用最终文本重测。
    private let minimumMeasurementInterval: TimeInterval

    public init() {
        self.minimumMeasurementInterval = 0.1
    }

    init(minimumMeasurementInterval: TimeInterval) {
        self.minimumMeasurementInterval = max(minimumMeasurementInterval, 0)
    }

    /// 更新输入文本视口的真实宽度。宽度变化会触发重测，避免面板缩放或清空按钮出现后
    /// 显示宽度与固定测量宽度不一致。
    public func setFieldAvailableWidth(_ width: CGFloat) {
        guard width.isFinite, width > 0,
              abs(width - fieldAvailableWidth) >= 0.5 else { return }
        let isFirstReportedWidth = !hasReceivedFieldAvailableWidth
        fieldAvailableWidth = width
        hasReceivedFieldAvailableWidth = true
        // 首次拿到真实布局宽度立即测量；连续拖宽与按钮显隐仍遵守限频并保留尾沿。
        scheduleDraftDidChange(forceMeasurement: isFirstReportedWidth)
    }

    private func scheduleDraftDidChange(forceMeasurement: Bool = false) {
        if forceMeasurement {
            requiresImmediateMeasurement = true
        }
        guard !scheduled else { return }
        scheduled = true
        Task { [weak self] in
            await Task.yield()
            guard let self else { return }
            self.scheduled = false
            let forceMeasurement = self.requiresImmediateMeasurement
            self.requiresImmediateMeasurement = false
            self.measureAndPublishWhenDue(force: forceMeasurement)
        }
    }

    private func measureAndPublishWhenDue(force: Bool) {
        let now = Date()
        let elapsed = lastMeasuredAt.map { now.timeIntervalSince($0) }
        let measurementIsDue = elapsed.map { $0 >= minimumMeasurementInterval } ?? true
        if force || measurementIsDue {
            trailingMeasurementTask?.cancel()
            trailingMeasurementTask = nil
            measureAndPublish(at: now)
            return
        }

        let remaining = minimumMeasurementInterval
            - (elapsed ?? minimumMeasurementInterval)
        guard trailingMeasurementTask == nil else { return }
        trailingMeasurementTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(max(remaining, 0) * 1_000_000_000))
            guard !Task.isCancelled, let self else { return }
            self.trailingMeasurementTask = nil
            self.measureAndPublish(at: Date())
        }
    }

    private func measureAndPublish(at date: Date) {
        lastMeasuredAt = date
        let measured = DraftTextMetrics.height(for: draft, width: fieldAvailableWidth)
        if measured != fieldContentHeight {
            fieldContentHeight = measured
        }
        // 先测量后广播：订阅方（窗口高度）读到的总是当前文本与宽度对应的高度。
        draftDidChange.send()
    }
}
