import AppKit
import FinderSync

final class ForNowFinderSync: FIFinderSync {
    override init() {
        super.init()
        // 根目录覆盖本机磁盘与挂载卷。Finder 只会在用户实际打开的目录中
        // 请求菜单；扩展不扫描目录，也不读取文件内容。
        FIFinderSyncController.default().directoryURLs = [
            URL(fileURLWithPath: "/", isDirectory: true)
        ]
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        guard menuKind == .contextualMenuForItems,
              hostApplicationURL() != nil,
              let selectedURLs = FIFinderSyncController.default().selectedItemURLs(),
              !ExternalFileImportContract.normalizedFileURLs(selectedURLs).isEmpty
        else {
            return nil
        }

        let menu = NSMenu(title: "ForNow")
        let item = NSMenuItem(
            title: "添加到 ForNow",
            action: #selector(addSelectionToForNow),
            keyEquivalent: ""
        )
        item.target = self
        menu.addItem(item)
        return menu
    }

    @objc private func addSelectionToForNow() {
        guard let applicationURL = hostApplicationURL(),
              let selectedURLs = FIFinderSyncController.default().selectedItemURLs()
        else {
            return
        }

        let urls = ExternalFileImportContract.normalizedFileURLs(selectedURLs)
        guard !urls.isEmpty else { return }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.addsToRecentItems = false
        NSWorkspace.shared.open(
            urls,
            withApplicationAt: applicationURL,
            configuration: configuration
        ) { _, error in
            if let error {
                NSLog("ForNow Finder 扩展无法交付所选项目：%@", error.localizedDescription)
            }
        }
    }

    private func hostApplicationURL() -> URL? {
        guard let applicationURL = ExternalFileImportContract.containingApplicationURL(
            forExtensionBundleURL: Bundle.main.bundleURL
        ),
        Bundle(url: applicationURL)?.bundleIdentifier
            == ExternalFileImportContract.receiverBundleIdentifier
        else {
            return nil
        }
        return applicationURL
    }
}
