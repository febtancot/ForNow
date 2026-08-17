import AppKit
import ForNowKit
import Sparkle

/// 菜单栏图标：无法点击 Notch 时的备用入口。
@MainActor
final class StatusItemController: NSObject {
    private let store: StashStore
    private let settings: AppSettings
    private let statusItem: NSStatusItem
    private weak var updater: SPUStandardUpdaterController?

    /// 由 AppDelegate 注入：切换暂存面板显示。
    var onTogglePanel: () -> Void = {}
    /// 由 AppDelegate 注入：打开设置窗口。
    var onOpenSettings: () -> Void = {}

    init(store: StashStore, settings: AppSettings, updater: SPUStandardUpdaterController) {
        self.store = store
        self.settings = settings
        self.updater = updater
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        statusItem.button?.image = Self.menuBarIcon()
        statusItem.button?.toolTip = "搁这儿 — 文件、文字、链接，先搁这儿。"

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    /// 菜单栏图标：系统 SF Symbol（模板图，透明、随菜单栏明暗自动适配）。
    private static func menuBarIcon() -> NSImage {
        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
        let image = NSImage(systemSymbolName: "tray.and.arrow.down.fill", accessibilityDescription: "搁这儿")?
            .withSymbolConfiguration(config)
        image?.isTemplate = true
        return image ?? NSImage()
    }

    @objc private func togglePanel() {
        onTogglePanel()
    }

    @objc private func openSettings() {
        onOpenSettings()
    }

    @objc private func openChangelog() {
        NSWorkspace.shared.open(UpdaterModel.changelogURL)
    }
}

extension StatusItemController: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let toggle = NSMenuItem(title: "打开暂存面板", action: #selector(togglePanel), keyEquivalent: "")
        toggle.target = self
        menu.addItem(toggle)

        menu.addItem(.separator())

        let info = NSMenuItem(title: "\(store.count) 个项目 · \(store.totalByteSizeText)",
                              action: nil, keyEquivalent: "")
        info.isEnabled = false
        menu.addItem(info)

        menu.addItem(.separator())

        let checkUpdates = NSMenuItem(
            title: "检查更新…",
            action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)),
            keyEquivalent: "")
        checkUpdates.target = updater
        menu.addItem(checkUpdates)

        let changelog = NSMenuItem(
            title: "查看更新日志…",
            action: #selector(openChangelog),
            keyEquivalent: "")
        changelog.target = self
        menu.addItem(changelog)

        let settingsItem = NSMenuItem(title: "设置…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let quit = NSMenuItem(title: "退出搁这儿",
                              action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }
}
