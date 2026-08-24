import AppKit
import SwiftUI
import ForNowKit

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var updater: UpdaterModel
    @State private var connectedDisplays = ConnectedDisplay.current()
    let onRefreshDisplays: () -> Void

    init(onRefreshDisplays: @escaping () -> Void = {}) {
        self.onRefreshDisplays = onRefreshDisplays
    }

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("通用", systemImage: "gearshape") }
            dayDropTab
                .tabItem { Label("DayDrop", systemImage: "folder.badge.gearshape") }
            updateTab
                .tabItem { Label("更新", systemImage: "arrow.down.circle") }
        }
        .frame(width: 480, height: 500)
        .onAppear {
            refreshDisplays()
        }
        .onReceive(NotificationCenter.default.publisher(
            for: NSApplication.didChangeScreenParametersNotification
        )) { _ in
            refreshDisplays()
        }
        .onReceive(NotificationCenter.default.publisher(
            for: NSApplication.didBecomeActiveNotification
        )) { _ in
            refreshDisplays()
        }
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
            Section("面板") {
                LabeledContent("宽度") {
                    HStack(spacing: 10) {
                        Text("\(Int(settings.panelWidth)) pt")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        Button("恢复默认宽度") { settings.resetPanelWidth() }
                            .buttonStyle(.link)
                            .disabled(settings.panelWidth == AppSettings.defaultPanelWidth)
                    }
                }
                Text("也可以拖动展开面板的左右边缘调整。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("吸附屏幕") {
                ForEach(connectedDisplays) { display in
                    Toggle(isOn: displayBinding(for: display.id)) {
                        HStack(spacing: 8) {
                            Image(systemName: display.hasNotch ? "laptopcomputer" : "display")
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(display.name) · \(display.positionLabel)")
                                if display.id == defaultDisplayID {
                                    Text(display.hasNotch ? "默认 · 刘海下方" : "默认 · 菜单栏下方中央")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else if display.hasNotch {
                                    Text("刘海下方")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("菜单栏下方中央")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .disabled(isOnlyEffectiveDisplay(display.id))
                }

                Text("可同时选择多块屏幕；所选屏幕断开时会临时回到默认屏幕。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Button {
                        refreshDisplays()
                    } label: {
                        Label("刷新显示器列表", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.link)

                    Spacer()
                    Button("恢复默认") { settings.resetAttachedDisplays() }
                        .buttonStyle(.link)
                        .disabled(settings.attachedDisplayIDs.isEmpty)
                }
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

    private var dayDropTab: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label {
                        Text("DayDrop")
                            .font(.headline)
                    } icon: {
                        Image(systemName: "folder.badge.gearshape")
                            .foregroundStyle(Color.accentColor)
                    }

                    Text("DayDrop 是 macOS 下载文件整理工具，可按日期归档下载内容，并快速打开当天文件夹。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 4)
            }

            Section("与 ForNow 配合使用") {
                DayDropFeatureRow(
                    title: "从药丸打开今日文件夹",
                    description: "检测到兼容版本后，收起态药丸会显示文件夹按钮。点击后由 DayDrop 准备并打开当天归档目录。",
                    systemImage: "folder.fill"
                )

                DayDropFeatureRow(
                    title: "从 DayDrop 条目添加到搁这儿-ForNow",
                    description: "在 DayDrop 的今日下载、下载文件或整理记录中右键现有文件，即可交给搁这儿-ForNow；复制、去重和保存仍由搁这儿-ForNow 完成。",
                    systemImage: "doc.on.doc"
                )
            }

            Section("了解与下载") {
                Link(destination: DayDropIntegrationContract.homepageURL) {
                    Label("访问 DayDrop 官网", systemImage: "globe")
                }
                Text(DayDropIntegrationContract.homepageURL.absoluteString)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
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

    private var defaultDisplayID: String? {
        connectedDisplays.first(where: \.hasNotch)?.id
            ?? NSScreen.main.flatMap(DisplayIdentity.identifier(for:))
            ?? connectedDisplays.first?.id
    }

    private var effectiveConnectedDisplayIDs: Set<String> {
        let available = connectedDisplays.map(\.id)
        return Set(DisplayAttachmentSelection.resolvedIDs(
            configuredIDs: settings.attachedDisplayIDs,
            availableIDs: available,
            defaultID: defaultDisplayID
        ))
    }

    private func displayBinding(for displayID: String) -> Binding<Bool> {
        Binding(
            get: { effectiveConnectedDisplayIDs.contains(displayID) },
            set: { enabled in
                var selected = settings.attachedDisplayIDs.isEmpty
                    ? effectiveConnectedDisplayIDs
                    : settings.attachedDisplayIDs
                if enabled {
                    selected.insert(displayID)
                } else {
                    selected.remove(displayID)
                }

                guard !selected.isEmpty else { return }
                if let defaultDisplayID, selected == Set([defaultDisplayID]) {
                    settings.resetAttachedDisplays()
                } else {
                    settings.setAttachedDisplayIDs(selected)
                }
            }
        )
    }

    private func isOnlyEffectiveDisplay(_ displayID: String) -> Bool {
        effectiveConnectedDisplayIDs == Set([displayID])
    }

    private func refreshDisplays() {
        connectedDisplays = ConnectedDisplay.current()
        onRefreshDisplays()
    }
}

private struct DayDropFeatureRow: View {
    let title: String
    let description: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 22)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct ConnectedDisplay: Identifiable, Equatable {
    let id: String
    let name: String
    let hasNotch: Bool
    let positionLabel: String

    static func current() -> [ConnectedDisplay] {
        let anchor = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 })
            ?? NSScreen.main
            ?? NSScreen.screens.first
        return NSScreen.screens.compactMap { screen in
            guard let id = DisplayIdentity.identifier(for: screen) else { return nil }
            return ConnectedDisplay(id: id,
                                    name: screen.localizedName,
                                    hasNotch: screen.safeAreaInsets.top > 0,
                                    positionLabel: position(of: screen, relativeTo: anchor))
        }
    }

    private static func position(of screen: NSScreen, relativeTo anchor: NSScreen?) -> String {
        guard let anchor else { return "屏幕" }
        if screen === anchor { return "默认屏幕" }
        let horizontalDistance = screen.frame.midX - anchor.frame.midX
        let verticalDistance = screen.frame.midY - anchor.frame.midY
        if abs(horizontalDistance) >= abs(verticalDistance) {
            return horizontalDistance < 0 ? "左侧屏幕" : "右侧屏幕"
        }
        return verticalDistance < 0 ? "下方屏幕" : "上方屏幕"
    }
}
