import SwiftUI
import AppKit
import ForNowKit

/// 列表中的单个暂存项目。
struct StashItemRow: View {
    let item: StashItem
    @EnvironmentObject private var store: StashStore
    @EnvironmentObject private var controller: NotchController
    @State private var hovering = false
    @State private var lastClickAt: Date?

    private var isSelected: Bool { controller.isSelected(item.id) }

    /// 类型标签：`.file` 若实际是目录则显示"文件夹"。
    private var kindLabel: String {
        if item.kind == .file, let url = store.absoluteURL(for: item) {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                return "文件夹"
            }
        }
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
                Text(subtitle)
                    .lineLimit(1)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
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
                .help("删除")
                .accessibilityLabel("删除 \(item.displayName)")
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(kindLabel)，\(item.displayName)\(isSelected ? "，已选中" : "")\(item.locked ? "，已锁定" : "")")
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
        if item.kind == .file || item.kind == .image || item.kind == .link || item.kind == .audio {
            Button {
                ItemActions.open(item, store: store)
            } label: {
                Label("打开", systemImage: "arrow.up.forward.app")
            }
        }
        if item.kind == .file || item.kind == .image || item.kind == .audio {
            Button {
                controller.quickLook(item)
            } label: {
                Label("快速预览", systemImage: "eye")
            }
            Button {
                ItemActions.revealInFinder(item, store: store)
            } label: {
                Label("在 Finder 中显示", systemImage: "folder")
            }
        }
        Divider()
        Button(role: .destructive) {
            controller.removeItems(targets)
        } label: {
            Label(targets.count > 1 ? "删除 \(targets.count) 项" : "删除", systemImage: "trash")
        }
    }

    /// 双击激活：文字→预览原文；文件/图片/链接→打开。
    private func activate() {
        if item.kind == .text {
            controller.previewText(item)
        } else {
            ItemActions.open(item, store: store)
        }
    }

    @ViewBuilder private var thumbnail: some View {
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
