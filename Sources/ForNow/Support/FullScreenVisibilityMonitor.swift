import AppKit
import CoreGraphics
import ForNowKit

/// 持续识别每块显示器上的全屏内容，覆盖 Chrome/YouTube 不触发 AppKit
/// 全屏辅助窗口语义的情况。WindowServer 查询在后台执行，主线程只应用结果。
@MainActor
final class FullScreenVisibilityMonitor {
    typealias DisplayBoundsProvider = @MainActor () -> [String: CGRect]
    typealias CoverageHandler = @MainActor (Set<String>) -> Void

    private let displayBoundsProvider: DisplayBoundsProvider
    private let onCoverageChange: CoverageHandler
    private var timer: Timer?
    private var checkTask: Task<Void, Never>?

    init(displayBoundsProvider: @escaping DisplayBoundsProvider,
         onCoverageChange: @escaping CoverageHandler) {
        self.displayBoundsProvider = displayBoundsProvider
        self.onCoverageChange = onCoverageChange
    }

    func start() {
        guard timer == nil else { return }
        refreshNow()

        let timer = Timer(timeInterval: 0.35, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshNow()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func refreshNow() {
        guard checkTask == nil else { return }
        let displayBoundsByID = displayBoundsProvider()
        guard !displayBoundsByID.isEmpty else {
            onCoverageChange([])
            return
        }

        let ownPID = ProcessInfo.processInfo.processIdentifier
        checkTask = Task { @MainActor [weak self] in
            let coveredDisplayIDs = await Task.detached(priority: .utility) {
                Self.coveredDisplayIDs(
                    displayBoundsByID: displayBoundsByID,
                    excludingOwnerPID: ownPID
                )
            }.value

            guard let self else { return }
            self.checkTask = nil
            self.onCoverageChange(coveredDisplayIDs)
        }
    }

    deinit {
        timer?.invalidate()
        checkTask?.cancel()
    }

    nonisolated private static func coveredDisplayIDs(
        displayBoundsByID: [String: CGRect],
        excludingOwnerPID: Int32
    ) -> Set<String> {
        guard let windowInfo = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return []
        }

        let snapshots = windowInfo.compactMap { info -> WindowCoverageSnapshot? in
            guard
                let ownerPID = (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value,
                let layer = (info[kCGWindowLayer as String] as? NSNumber)?.intValue,
                let boundsDictionary = info[kCGWindowBounds as String] as? NSDictionary,
                let bounds = CGRect(dictionaryRepresentation: boundsDictionary as CFDictionary)
            else { return nil }

            let alpha = (info[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1
            return WindowCoverageSnapshot(
                ownerPID: ownerPID,
                layer: layer,
                alpha: alpha,
                bounds: bounds
            )
        }

        return FullScreenWindowDetector.coveredDisplayIDs(
            displayBoundsByID: displayBoundsByID,
            windows: snapshots,
            excludingOwnerPID: excludingOwnerPID
        )
    }
}
