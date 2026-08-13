import AppKit
import SwiftUI
import Combine
import ForNowKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = StashStore.makeDefault()
    let settings = AppSettings()

    private var statusController: StatusItemController?
    private var notchController: NotchController?
    private let hotKeyManager = HotKeyManager()
    private var cancellables: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let notch = NotchController(store: store, settings: settings)
        let status = StatusItemController(store: store, settings: settings)
        status.onTogglePanel = { [weak notch] in notch?.toggle() }

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
    }
}
