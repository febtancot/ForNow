import SwiftUI
import ForNowKit

/// 录制全局快捷键：点击后按下带修饰键的组合即可设置。
struct HotKeyRecorderView: View {
    @Binding var hotKey: GlobalHotKey
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        Button {
            recording ? stop() : start()
        } label: {
            Text(recording ? "按下快捷键…" : hotKey.displayString)
                .font(.system(.body, design: .rounded))
                .frame(minWidth: 96)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(recording ? Color.accentColor.opacity(0.2) : Color(nsColor: .quaternaryLabelColor),
                            in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .help("点击后按下新的快捷键；Esc 取消")
        .onDisappear(perform: stop)
    }

    private func start() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // Esc 取消
                stop()
                return nil
            }
            let modifiers = Self.modifiers(from: event.modifierFlags)
            guard !modifiers.isEmpty else { return event } // 需至少一个修饰键
            hotKey = GlobalHotKey(keyCode: UInt32(event.keyCode), modifiers: modifiers)
            stop()
            return nil
        }
    }

    private func stop() {
        recording = false
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    private static func modifiers(from flags: NSEvent.ModifierFlags) -> GlobalHotKey.Modifiers {
        var result: GlobalHotKey.Modifiers = []
        if flags.contains(.command) { result.insert(.command) }
        if flags.contains(.option) { result.insert(.option) }
        if flags.contains(.control) { result.insert(.control) }
        if flags.contains(.shift) { result.insert(.shift) }
        return result
    }
}
