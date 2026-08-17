import AppKit
import SwiftUI
import ForNowKit

/// 回收站项目行：只提供查看清除时间和恢复，不暴露拖出/打开等暂存区操作。
struct TrashItemRow: View {
    let entry: TrashedItem
    @EnvironmentObject private var store: StashStore
    @EnvironmentObject private var controller: NotchController
    @State private var hovering = false

    private var item: StashItem { entry.item }

    var body: some View {
        HStack(spacing: 10) {
            thumbnail
                .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                    .lineLimit(1)
                    .font(.system(size: 12, weight: .medium))
                Text("\(item.kind.localizedName) · 清除于 \(entry.trashedAt.formatted(date: .abbreviated, time: .shortened))")
                    .lineLimit(1)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            Button { controller.restoreFromTrash(entry) } label: {
                Image(systemName: "arrow.uturn.backward.circle.fill")
                    .font(.system(size: 18))
            }
            .buttonStyle(.plain)
            .foregroundStyle(hovering ? Color.accentColor : Color.secondary)
            .help("恢复到暂存")
            .accessibilityLabel("恢复 \(item.displayName) 到暂存")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(hovering ? 0.06 : 0))
        )
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .onHover { hovering = $0 }
        .contextMenu {
            Button { controller.restoreFromTrash(entry) } label: {
                Label("恢复到暂存", systemImage: "arrow.uturn.backward")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(item.kind.localizedName)，\(item.displayName)，清除于 \(entry.trashedAt.formatted())")
    }

    @ViewBuilder private var thumbnail: some View {
        if item.kind == .image, let url = store.absoluteURL(for: item) {
            ThumbnailView(url: url)
        } else if item.kind == .file, let url = store.absoluteURL(for: item) {
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
}
