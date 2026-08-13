import SwiftUI
import ForNowKit

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("通用", systemImage: "gearshape") }
        }
        .frame(width: 460, height: 340)
    }

    private var generalTab: some View {
        Form {
            Section("启动") {
                Toggle("登录时启动", isOn: $settings.launchAtLogin)
                Toggle("全屏应用中启用", isOn: $settings.enableInFullScreen)
            }
            Section("反馈") {
                Toggle("声音反馈", isOn: $settings.soundFeedback)
                Toggle("动画效果", isOn: $settings.animations)
            }
            Section("全局快捷键") {
                LabeledContent("显示 / 隐藏面板") {
                    HStack(spacing: 10) {
                        HotKeyRecorderView(hotKey: $settings.hotKey)
                        Button("恢复默认") { settings.hotKey = .default }
                            .buttonStyle(.link)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}
