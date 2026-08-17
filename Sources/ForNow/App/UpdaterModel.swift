import Combine
import Sparkle

/// Sparkle 2 更新管理器：持有 SPUStandardUpdaterController，
/// 并把"上次检查时间"桥接为 SwiftUI 可观察数据。
@MainActor
final class UpdaterModel: ObservableObject {
    /// 官网更新日志锚点（供菜单/设置里的「查看更新日志」）。
    static let changelogURL = URL(string: "https://fornow.liveby.app/#update")!

    let controller: SPUStandardUpdaterController

    @Published private(set) var lastCheckDate: Date?

    private var cancellables = Set<AnyCancellable>()

    init() {
        let controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        self.controller = controller
        lastCheckDate = controller.updater.lastUpdateCheckDate
        controller.updater.publisher(for: \.lastUpdateCheckDate)
            .sink { [weak self] date in self?.lastCheckDate = date }
            .store(in: &cancellables)
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
