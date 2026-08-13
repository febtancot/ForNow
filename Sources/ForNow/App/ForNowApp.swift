import SwiftUI

@main
struct ForNowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.openSettings) private var openSettings

    var body: some Scene {
        // 菜单栏程序（LSUIElement）无主窗口；Settings 场景提供设置窗口。
        Settings {
            // 场景内容里拿到的 openSettings 动作，经 AppDelegate 桥接给
            // 状态栏菜单的"设置…"（AppKit 侧没有可用的 settings-window API）。
            SettingsView()
                .environmentObject(appDelegate.store)
                .environmentObject(appDelegate.settings)
        }
        .onChange(of: appDelegate.settingsVersion, initial: true) { _, _ in
            appDelegate.onOpenSettings = { openSettings() }
        }
    }
}
