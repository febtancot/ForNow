import AppKit
import CoreGraphics

extension Notification.Name {
    /// Core Graphics 已完成一轮显示器重配置，且 NSScreen 列表已连续稳定。
    static let forNowDisplayConfigurationDidStabilize = Notification.Name(
        "com.fornow.app.display-configuration-did-stabilize"
    )
}

/// 常驻监听本机显示器热插拔、排列和模式变化，并在 AppKit 屏幕列表稳定后通知应用刷新。
@MainActor
final class DisplayReconfigurationMonitor {
    typealias SnapshotProvider = @MainActor () -> [String]
    typealias StableConfigurationHandler = @MainActor () -> Void

    private let snapshotProvider: SnapshotProvider
    private let onStableConfiguration: StableConfigurationHandler
    private var stabilizationTask: Task<Void, Never>?
    private var isRegistered = false

    init(snapshotProvider: @escaping SnapshotProvider,
         onStableConfiguration: @escaping StableConfigurationHandler) {
        self.snapshotProvider = snapshotProvider
        self.onStableConfiguration = onStableConfiguration

        let error = CGDisplayRegisterReconfigurationCallback(
            forNowDisplayReconfigurationCallback,
            Unmanaged.passUnretained(self).toOpaque()
        )
        isRegistered = error == .success
        if !isRegistered {
            NSLog("ForNow: failed to register display reconfiguration callback (%d)", error.rawValue)
        }
    }

    deinit {
        stabilizationTask?.cancel()
        if isRegistered {
            CGDisplayRemoveReconfigurationCallback(
                forNowDisplayReconfigurationCallback,
                Unmanaged.passUnretained(self).toOpaque()
            )
        }
    }

    fileprivate func displayConfigurationDidChange() {
        // Quartz 会针对同一轮配置变化为多块屏幕各回调一次。取消旧任务可以把它们
        // 合并成一次刷新，并给 NSScreen 的 AppKit 映射留出更新时间。
        stabilizationTask?.cancel()
        stabilizationTask = Task { @MainActor [weak self] in
            guard let self else { return }

            do {
                try await Task.sleep(nanoseconds: 200_000_000)
                var previousSnapshot = snapshotProvider()

                // 连续两次 UUID 顺序一致即认为稳定；若扩展坞或显示器握手较慢，
                // 最多等待约 1 秒，最后仍刷新一次，避免吞掉有效配置事件。
                for _ in 0..<4 {
                    try await Task.sleep(nanoseconds: 200_000_000)
                    let currentSnapshot = snapshotProvider()
                    if currentSnapshot == previousSnapshot {
                        onStableConfiguration()
                        return
                    }
                    previousSnapshot = currentSnapshot
                }

                onStableConfiguration()
            } catch {
                // 新回调会取消旧任务；最终任务负责发布稳定结果。
            }
        }
    }
}

private func forNowDisplayReconfigurationCallback(
    _ display: CGDirectDisplayID,
    _ flags: CGDisplayChangeSummaryFlags,
    _ userInfo: UnsafeMutableRawPointer?
) {
    guard !flags.contains(.beginConfigurationFlag), let userInfo else { return }
    let monitor = Unmanaged<DisplayReconfigurationMonitor>
        .fromOpaque(userInfo)
        .takeUnretainedValue()
    Task { @MainActor [weak monitor] in
        monitor?.displayConfigurationDidChange()
    }
}
