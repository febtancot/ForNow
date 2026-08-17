import SwiftUI
import ForNowKit

/// 展开后的暂存面板：标题、项目列表、底部统计与清空。
struct OpenPanelView: View {
    @EnvironmentObject private var store: StashStore
    @EnvironmentObject private var controller: NotchController
    /// 直接观察录音器：头部 mic 按钮的样式与计时随录音状态实时刷新。
    @EnvironmentObject private var recorder: RecordingController
    @State private var confirmingClear = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.3)
            content
            Divider().opacity(0.3)
            footer
            if !controller.isShowingTrash {
                Divider().opacity(0.3)
                QuickEntryField()
            }
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
            Text(controller.isShowingTrash ? "回收站" : "搁这儿").font(.headline)
            if !controller.isShowingTrash {
                micButton
            }
            Spacer()
            if !controller.isShowingTrash, !store.items.isEmpty {
                Button(allSelected ? "取消全选" : "全选") { toggleSelectAll() }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button { controller.showTrash(!controller.isShowingTrash) } label: {
                HStack(spacing: 4) {
                    Image(systemName: controller.isShowingTrash ? "tray" : "trash")
                    if !controller.isShowingTrash, store.trashCount > 0 {
                        Text("\(store.trashCount)")
                            .font(.caption2.weight(.semibold))
                    }
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help(controller.isShowingTrash ? "返回暂存" : "查看回收站")
            .accessibilityLabel(controller.isShowingTrash ? "返回暂存" : "回收站，\(store.trashCount) 项")
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

    /// 头部常驻 mic：空闲时点击开始录音；录音中显示红色停止按钮与实时时长。
    private var micButton: some View {
        Button { controller.toggleRecording() } label: {
            if recorder.isRecording {
                HStack(spacing: 4) {
                    Image(systemName: "stop.circle.fill")
                        .foregroundStyle(.red)
                    Text("录音中 \(StashItem.durationText(seconds: recorder.elapsedSeconds))")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                }
            } else {
                Image(systemName: "mic")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .help(recorder.isRecording ? "停止录音并暂存" : "开始录音")
        .accessibilityLabel(recorder.isRecording ? "停止录音并暂存" : "开始录音")
    }

    private var allSelected: Bool {
        !store.items.isEmpty && controller.selection.count == store.items.count
    }

    private func toggleSelectAll() {
        allSelected ? controller.clearSelection() : controller.selectAll()
    }

    @ViewBuilder private var content: some View {
        if controller.isShowingTrash {
            trashContent
        } else if store.items.isEmpty {
            EmptyStateView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(store.items) { item in
                            StashItemRow(item: item)
                        }
                    }
                    .padding(10)
                }
                // 程序化置顶请求（如录音入库后展示新项目）——列表滚动时把最新项滚回视野。
                .onChange(of: controller.scrollToTopRequest) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(store.items.first?.id, anchor: .top)
                    }
                }
            }
        }
    }

    @ViewBuilder private var trashContent: some View {
        if store.trashItems.isEmpty {
            TrashEmptyStateView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(store.trashItems) { entry in
                        TrashItemRow(entry: entry)
                    }
                }
                .padding(10)
            }
        }
    }

    @ViewBuilder private var footer: some View {
        if controller.isShowingTrash {
            HStack(spacing: 12) {
                Text("\(store.trashCount) 项 · \(store.trashByteSizeText) · 保留 30 天")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if !store.trashItems.isEmpty {
                    Button { controller.restoreAllFromTrash() } label: {
                        Label("全部恢复", systemImage: "arrow.uturn.backward")
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        } else {
            HStack(spacing: 12) {
                if controller.selection.isEmpty {
                    Text("\(store.count) 个项目 · \(store.activeByteSizeText)")
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
                        Label("移到回收站", systemImage: "trash")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("将所选移到回收站")
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
    }

    private var clearAllButton: some View {
        Button(role: .destructive) { confirmingClear = true } label: {
            Label("清空", systemImage: "trash")
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .disabled(store.items.isEmpty)
        .confirmationDialog("将全部暂存项目移到回收站？", isPresented: $confirmingClear, titleVisibility: .visible) {
            Button("移到回收站", role: .destructive) { controller.clearAll() }
            Button("取消", role: .cancel) {}
        } message: {
            Text(clearAllMessage)
        }
    }

    private var clearAllMessage: String {
        let lockedCount = store.items.filter(\.locked).count
        let unlockedCount = store.count - lockedCount
        let base = "\(unlockedCount) 个未锁定项目将保留在回收站 30 天，期间可以恢复。"
        return lockedCount > 0 ? base + "（\(lockedCount) 项已锁定，将继续保留在暂存中）" : base
    }
}

/// 快速录入输入条：点击聚焦后打字，回车入库。打开面板不自动聚焦，
/// 以免 ⌘V 落入输入条而失效传统的「打开面板 → ⌘V 直接入库」模式。
/// 绑定独立的 `DraftModel`，打字/粘贴只重绘本视图，不触发面板整体重渲染。
struct QuickEntryField: View {
    @EnvironmentObject private var draftModel: DraftModel
    @FocusState private var focused: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "square.and.pencil")
                .foregroundStyle(.secondary)
                .font(.system(size: 13))
                .padding(.top, 3)
            ScrollView {
                TextField("快速录入：打字后回车暂存", text: $draftModel.draft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .focused($focused)
                    .onSubmit { draftModel.onSubmit?() }
            }
            .frame(height: draftModel.fieldContentHeight, alignment: .top)
            // 粘贴超长文本时输入条在定高框内滚动，系统显示滚动指示。
            .scrollIndicators(.visible)
            if !draftModel.draft.isEmpty {
                Button { draftModel.draft = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .padding(.top, 3)
                .help("清空输入")
                .accessibilityLabel("清空输入")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .onDisappear { draftModel.isTyping = false }
        .onChange(of: focused) { draftModel.isTyping = focused }
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
            Text("点击输入条打字录入，或拖入文件、按 ⌘V 粘贴")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
    }
}

struct TrashEmptyStateView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "trash")
                .font(.system(size: 30))
                .foregroundStyle(.secondary)
            Text("回收站是空的")
                .font(.headline)
            Text("清除的项目会在这里保留 30 天")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(24)
    }
}
