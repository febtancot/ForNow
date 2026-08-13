import SwiftUI

@main
struct ForNowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // 菜单栏程序（LSUIElement）无主窗口；Settings 场景提供设置窗口。
        Settings {
            SettingsView()
                .environmentObject(appDelegate.store)
                .environmentObject(appDelegate.settings)
        }
    }
}
