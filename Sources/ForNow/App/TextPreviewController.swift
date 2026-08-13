import AppKit
import SwiftUI

/// 文本项目的预览窗口：没有对应文件的文字，双击后在此查看/选中原文。
@MainActor
final class TextPreviewController {
    private var window: NSWindow?

    func show(title: String, text: String) {
        let hosting = NSHostingView(rootView: TextPreviewView(text: text))

        let win: NSWindow
        if let existing = window {
            win = existing
        } else {
            win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 420),
                           styleMask: [.titled, .closable, .resizable, .miniaturizable],
                           backing: .buffered, defer: false)
            win.isReleasedWhenClosed = false
            win.setFrameAutosaveName("ForNowTextPreview")
            win.center()
            window = win
        }

        win.title = title.isEmpty ? "文本预览" : title
        win.contentView = hosting
        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
    }
}

private struct TextPreviewView: View {
    let text: String

    var body: some View {
        ScrollView {
            Text(text)
                .textSelection(.enabled)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
        }
        .frame(minWidth: 320, minHeight: 200)
    }
}
