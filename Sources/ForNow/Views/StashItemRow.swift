import SwiftUI
import AppKit
import ForNowKit

/// 列表中的单个暂存项目。
struct StashItemRow: View {
    let item: StashItem
    @EnvironmentObject private var store: StashStore
    @EnvironmentObject private var controller: NotchController
    @EnvironmentObject private var audioPlayer: AudioPlaybackController
    @State private var hovering = false
    @State private var lastClickAt: Date?

    private var isSelected: Bool { controller.isSelected(item.id) }
    private var isAudioActive: Bool { item.kind == .audio && audioPlayer.isActive(item.id) }
    private var isAudioPlaying: Bool { isAudioActive && audioPlayer.isPlaying }

    private var isDirectory: Bool {
        guard item.kind == .file, let url = store.absoluteURL(for: item) else { return false }
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }

    /// 类型标签：`.file` 若实际是目录则显示"文件夹"。
    private var kindLabel: String {
        if isDirectory { return "文件夹" }
        return item.kind.localizedName
    }

    var body: some View {
        HStack(spacing: 10) {
            thumbnail
                .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                    .lineLimit(1)
                    .font(.system(size: 12, weight: .medium))
                if isAudioActive {
                    activeAudioProgress
                } else {
                    Text(subtitle)
                        .lineLimit(1)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 4)
            if item.locked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .help("已锁定，不会被清空")
                    .accessibilityLabel("已锁定")
            }
            if hovering, !item.locked {
                Button {
                    controller.removeItems([item])
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("移到回收站")
                .accessibilityLabel("将 \(item.displayName) 移到回收站")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.accentColor.opacity(0.25)
                                 : Color.primary.opacity(hovering ? 0.06 : 0))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.accentColor.opacity(0.6) : .clear, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .onHover { hovering = $0 }
        // 单击立即选中（⌘-单击多选）；用时间戳手动识别双击打开，
        // 避免 SwiftUI 单/双击消歧造成的选中延迟。
        .onTapGesture {
            let additive = NSEvent.modifierFlags.contains(.command)
            controller.selectRow(item.id, additive: additive)
            let now = Date()
            if !additive, let last = lastClickAt, now.timeIntervalSince(last) < 0.35 {
                activate()
                lastClickAt = nil
            } else {
                lastClickAt = now
            }
        }
        .onDrag { ItemActions.dragProvider(item, store: store) }
        .contextMenu { contextMenu }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(kindLabel)，\(item.displayName)\(isSelected ? "，已选中" : "")\(item.locked ? "，已锁定" : "")")
        .accessibilityAction(named: Text(primaryActionTitle)) { performPrimaryAction() }
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    @ViewBuilder private var contextMenu: some View {
        let targets = controller.effectiveItems(for: item)
        Button {
            controller.copyItems(targets)
        } label: {
            Label(targets.count > 1 ? "复制 \(targets.count) 项" : "复制", systemImage: "doc.on.doc")
        }
        Button {
            controller.toggleLock(targets)
        } label: {
            if targets.allSatisfy(\.locked) {
                Label(targets.count > 1 ? "解锁 \(targets.count) 项" : "解锁", systemImage: "lock.open")
            } else {
                Label(targets.count > 1 ? "锁定 \(targets.count) 项" : "锁定", systemImage: "lock")
            }
        }
        if item.kind == .text {
            Button { controller.previewText(item) } label: {
                Label("预览原文", systemImage: "eye")
            }
        }
        if item.kind == .audio {
            Button { controller.toggleAudioPlayback(item) } label: {
                Label(audioPlayer.isPlaying && audioPlayer.isActive(item.id) ? "暂停" : "播放",
                      systemImage: audioPlayer.isPlaying && audioPlayer.isActive(item.id) ? "pause.fill" : "play.fill")
            }
        }
        if item.kind == .file || item.kind == .image || item.kind == .link {
            Button {
                ItemActions.open(item, store: store)
            } label: {
                Label("打开", systemImage: "arrow.up.forward.app")
            }
        }
        if item.kind == .file || item.kind == .image {
            Button {
                controller.quickLook(item)
            } label: {
                Label("快速预览", systemImage: "eye")
            }
        }
        if item.kind == .file || item.kind == .image || item.kind == .audio {
            Button { ItemActions.revealInFinder(item, store: store) } label: {
                Label("在 Finder 中显示", systemImage: "folder")
            }
        }
        Divider()
        Button(role: .destructive) {
            controller.removeItems(targets)
        } label: {
            Label(targets.count > 1 ? "移到回收站 \(targets.count) 项" : "移到回收站", systemImage: "trash")
        }
    }

    /// 双击激活：文字→预览原文；录音→面板内播放/暂停；文件/图片/链接→打开。
    private func activate() {
        if item.kind == .text {
            controller.previewText(item)
        } else if item.kind == .audio {
            controller.toggleAudioPlayback(item)
        } else {
            ItemActions.open(item, store: store)
        }
    }

    private var activeAudioProgress: some View {
        HStack(spacing: 6) {
            Slider(value: Binding(get: { audioPlayer.currentTime },
                                  set: { audioPlayer.seek(to: $0) }),
                   in: 0...max(audioPlayer.duration, 0.1))
                .controlSize(.mini)
                .frame(maxWidth: 96)
                .accessibilityLabel("播放进度")
                .accessibilityValue("\(StashItem.durationText(seconds: audioPlayer.currentTime)) / \(StashItem.durationText(seconds: audioPlayer.duration))")
            Text("\(StashItem.durationText(seconds: audioPlayer.currentTime)) / \(StashItem.durationText(seconds: audioPlayer.duration))")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var thumbnail: some View {
        ZStack {
            thumbnailContent
            if showsThumbnailAction {
                Button { performThumbnailAction() } label: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.58))
                        .overlay {
                            Image(systemName: thumbnailActionSymbol)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                }
                .buttonStyle(.plain)
                .help(thumbnailActionTitle)
                .accessibilityLabel("\(thumbnailActionTitle) \(item.displayName)")
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.12), value: showsThumbnailAction)
    }

    @ViewBuilder private var thumbnailContent: some View {
        if item.kind == .image, let url = store.absoluteURL(for: item) {
            ThumbnailView(url: url)
        } else if item.kind == .file, let url = store.absoluteURL(for: item) {
            // 真实 Finder 图标：文件夹显示文件夹图标，各类型文件各显其图标。
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.15))
                .overlay(
                    Image(systemName: item.kind.symbolName)
                        .foregroundStyle(.secondary)
                )
        }
    }

    private var showsThumbnailAction: Bool {
        guard item.kind == .audio || item.kind == .file || item.kind == .image else { return false }
        return hovering || isAudioActive
    }

    private var thumbnailActionSymbol: String {
        if item.kind == .audio { return isAudioPlaying ? "pause.fill" : "play.fill" }
        if isDirectory { return "arrow.up.forward" }
        return "eye.fill"
    }

    private var thumbnailActionTitle: String {
        if item.kind == .audio { return isAudioPlaying ? "暂停" : "播放" }
        if isDirectory { return "打开文件夹" }
        return "快速预览"
    }

    private var primaryActionTitle: String {
        switch item.kind {
        case .audio: return isAudioPlaying ? "暂停" : "播放"
        case .file: return isDirectory ? "打开文件夹" : "快速预览"
        case .image: return "快速预览"
        case .text: return "预览原文"
        case .link: return "打开链接"
        }
    }

    private func performThumbnailAction() {
        switch item.kind {
        case .audio:
            controller.toggleAudioPlayback(item)
        case .file where isDirectory:
            ItemActions.open(item, store: store)
        case .file, .image:
            controller.quickLook(item)
        case .text, .link:
            break
        }
    }

    private func performPrimaryAction() {
        if item.kind == .file, !isDirectory {
            controller.quickLook(item)
        } else if item.kind == .image {
            controller.quickLook(item)
        } else {
            activate()
        }
    }

    private var subtitle: String {
        var parts: [String] = [kindLabel]
        if item.kind == .audio, let duration = item.durationText {
            parts.append(duration)
        }
        if let dims = item.pixelSizeText {
            parts.append(dims)
        } else if let size = item.byteSizeText {
            parts.append(size)
        } else if item.kind == .link, let host = item.urlString.flatMap({ URL(string: $0)?.host }) {
            parts.append(host)
        }
        parts.append(item.createdAt.formatted(date: .abbreviated, time: .shortened))
        return parts.joined(separator: " · ")
    }
}

/// 异步加载并缓存图片缩略图。
struct ThumbnailView: View {
    let url: URL
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.15))
            }
        }
        .frame(width: 34, height: 34)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .task(id: url) {
            image = await Self.loadThumbnail(url)
        }
    }

    private static func loadThumbnail(_ url: URL) async -> NSImage? {
        await Task.detached(priority: .utility) {
            guard let cgImage = ImageMetadata.thumbnail(ofFileAt: url, maxPixel: 96) else { return nil }
            return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        }.value
    }
}
