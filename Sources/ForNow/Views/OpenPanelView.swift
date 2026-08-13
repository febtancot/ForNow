import SwiftUI
import ForNowKit

/// 展开后的暂存面板：标题、项目列表、底部统计与清空。
struct OpenPanelView: View {
    @EnvironmentObject private var store: StashStore
    @EnvironmentObject private var controller: NotchController
    @State private var confirmingClear = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.3)
            QuickEntryField()
            Divider().opacity(0.3)
            content
            Divider().opacity(0.3)
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(PanelBackground(isDropTargeted: controller.isDropTargeted))
        .clipShape(BottomRoundedRectangle(radius: 24))
        .onDrop(of: supportedDropTypes, isTargeted: $controller.isDropTargeted) { providers in
            controller.importProviders(providers)
            return true
        }
        .overlay(alignment: .bottom) {
            if let toast = controller.toast {
                ToastView(text: toast)
                    .padding(.bottom, 42)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.easeInOut(duration: 0.15), value: controller.toast)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text("搁这儿").font(.headline)
            Spacer()
            if !store.items.isEmpty {
                Button(allSelected ? "取消全选" : "全选") { toggleSelectAll() }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button { controller.close() } label: {
                Image(systemName: "chevron.up")
            }
            .buttonStyle(.plain)
            .help("收起")
            .accessibilityLabel("收起面板")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var allSelected: Bool {
        !store.items.isEmpty && controller.selection.count == store.items.count
    }

    private func toggleSelectAll() {
        allSelected ? controller.clearSelection() : controller.selectAll()
    }

    @ViewBuilder private var content: some View {
        if store.items.isEmpty {
            EmptyStateView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(store.items) { item in
                        StashItemRow(item: item)
                    }
                }
                .padding(10)
            }
        }
    }

    @ViewBuilder private var footer: some View {
        HStack(spacing: 12) {
            if controller.selection.isEmpty {
                Text("\(store.count) 个项目 · \(store.totalByteSizeText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                clearAllButton
            } else {
                Text("已选 \(controller.selection.count) 项")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button { controller.copySelection() } label: {
                    Label("复制", systemImage: "doc.on.doc")
                }
                .buttonStyle(.plain)
                .help("复制所选（⌘C）")
                Button(role: .destructive) { controller.deleteSelection() } label: {
                    Label("删除", systemImage: "trash")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("删除所选")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private var clearAllButton: some View {
        Button(role: .destructive) { confirmingClear = true } label: {
            Label("清空", systemImage: "trash")
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .disabled(store.items.isEmpty)
        .confirmationDialog("清空全部暂存项目？", isPresented: $confirmingClear, titleVisibility: .visible) {
            Button("清空全部", role: .destructive) { store.removeAll() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("此操作不可撤销，将删除全部 \(store.count) 个项目及其文件。")
        }
    }
}

/// 快速录入输入条：打开面板即自动聚焦，直接打字，回车入库。
struct QuickEntryField: View {
    @EnvironmentObject private var controller: NotchController
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "square.and.pencil")
                .foregroundStyle(.secondary)
                .font(.system(size: 12))
            TextField("快速录入：打字后回车暂存", text: $controller.draft)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($focused)
                .onSubmit { controller.submitDraft() }
            if !controller.draft.isEmpty {
                Button { controller.draft = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("清空输入")
                .accessibilityLabel("清空输入")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .onAppear {
            focused = true
            controller.isTyping = true
        }
        .onDisappear { controller.isTyping = false }
        .onChange(of: focused) { controller.isTyping = focused }
    }
}

/// 克制的操作反馈提示。
struct ToastView: View {
    let text: String
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(text)
                .font(.caption.weight(.medium))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.thinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.primary.opacity(0.1)))
        .shadow(radius: 4, y: 1)
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 30))
                .foregroundStyle(.secondary)
            Text("先搁这儿")
                .font(.headline)
            Text("直接打字录入，或拖入文件、按 ⌘V 粘贴")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
    }
}
