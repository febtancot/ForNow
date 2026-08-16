import SwiftUI
import ForNowKit

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var updater: UpdaterModel

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("通用", systemImage: "gearshape") }
            updateTab
                .tabItem { Label("更新", systemImage: "arrow.down.circle") }
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

    private var updateTab: some View {
        Form {
            Section("版本") {
                LabeledContent("当前版本", value: versionText)
                LabeledContent("上次检查") {
                    if let date = updater.lastCheckDate {
                        Text(date.formatted(date: .abbreviated, time: .shortened))
                    } else {
                        Text("从未")
                    }
                }
            }
            Section {
                Button("检查更新") { updater.checkForUpdates() }
                Link("查看更新日志", destination: UpdaterModel.changelogURL)
            }
        }
        .formStyle(.grouped)
    }

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(version) (\(build))"
    }
}
