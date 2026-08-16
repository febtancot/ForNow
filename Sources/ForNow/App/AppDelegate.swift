import AppKit
import SwiftUI
import Combine
import ForNowKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = StashStore.makeDefault()
    let settings = AppSettings()
    let updaterModel = UpdaterModel()

    private var statusController: StatusItemController?
    private var notchController: NotchController?
    private let hotKeyManager = HotKeyManager()
    private var cancellables: Set<AnyCancellable> = []

    /// 由 ForNowApp 的场景内容注入：打开设置窗口（SwiftUI `openSettings` 动作）。
    var onOpenSettings: (() -> Void)?
    /// 设置变化时递增，供 ForNowApp 的 body 读取以维持注入。
    var settingsVersion = 0

    /// 打开设置并把窗口置前：App 是 LSUIElement 菜单栏程序，点击状态栏菜单不会
    /// 激活 App，设置窗口会落在其他 App 窗口后面。
    func openSettingsWindow() {
        onOpenSettings?()
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.async { NSApp.keyWindow?.makeKeyAndOrderFront(nil) }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let notch = NotchController(store: store, settings: settings)
        let status = StatusItemController(store: store, settings: settings,
                                          updater: updaterModel.controller)
        status.onTogglePanel = { [weak notch] in notch?.toggle() }
        status.onOpenSettings = { [weak self] in self?.openSettingsWindow() }

        self.notchController = notch
        self.statusController = status

        // 让设置里的"登录时启动"反映系统真实状态。
        settings.launchAtLogin = LoginItem.isEnabled

        // 全局快捷键：随设置变化重新注册（订阅会立即用当前值注册一次）。
        settings.$hotKey
            .sink { [weak self] key in
                self?.hotKeyManager.register(key) { [weak self] in self?.notchController?.toggle() }
            }
            .store(in: &cancellables)

        // 登录时启动：随开关变化生效。
        settings.$launchAtLogin
            .sink { LoginItem.setEnabled($0) }
            .store(in: &cancellables)

        // 让 ForNowApp 的 body 在设置变化时重估（依赖 settingsVersion）。
        settings.objectWillChange
            .sink { [weak self] _ in self?.settingsVersion += 1 }
            .store(in: &cancellables)
    }
}
