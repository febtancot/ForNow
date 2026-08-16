import SwiftUI
import ForNowKit

/// 面板根视图：根据开合状态在"收起小条"与"展开面板"间切换。
struct NotchRootView: View {
    @EnvironmentObject private var controller: NotchController
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        ZStack(alignment: .top) {
            if controller.isOpen {
                OpenPanelView()
                    .transition(.opacity)
            } else {
                ClosedPillView()
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(settings.animations ? .easeInOut(duration: 0.18) : nil, value: controller.isOpen)
    }
}

/// 收起状态：整个刘海区域都可点击/接收拖入；胶囊仅作视觉提示，
/// 鼠标移到刘海任意位置即高亮。点击打开；拖入内容靠近时自动展开。
struct ClosedPillView: View {
    @EnvironmentObject private var controller: NotchController
    @EnvironmentObject private var store: StashStore
    @State private var hovering = false

    var body: some View {
        ZStack {
            // 铺满整个窗口（= 刘海区域）的命中层。用极低不透明度而非 Color.clear，
            // 因为 Color.clear 只参与悬停、不参与点击命中（点了没反应的根因）。
            Color.white.opacity(0.001)
            pill
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 1)
            MicButton()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(.leading, 8)
                .padding(.bottom, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture { controller.open() }
        .onDrop(of: supportedDropTypes,
                isTargeted: Binding(get: { false },
                                    set: { if $0 { controller.openForDrag() } })) { providers in
            controller.openForDrag()
            controller.importProviders(providers)
            return true
        }
        .accessibilityElement()
        .accessibilityLabel("搁这儿，\(store.count) 个暂存项目")
        .accessibilityHint("打开暂存面板")
        .accessibilityAddTraits(.isButton)
    }

    private var pill: some View {
        HStack(spacing: 6) {
            Image(systemName: "tray.and.arrow.down.fill")
                .font(.system(size: 11, weight: .semibold))
            if store.count > 0 {
                Text("\(store.count)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color.black.opacity(hovering ? 0.92 : 0.7)))
        .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 1))
    }
}

/// 刘海左侧的录音按钮：点击开始录音，再点停止并入库。
struct MicButton: View {
    @EnvironmentObject private var controller: NotchController

    var body: some View {
        Button { controller.toggleRecording() } label: {
            Image(systemName: controller.recorder.isRecording ? "mic.fill" : "mic")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(controller.recorder.isRecording ? AnyShapeStyle(.red) : AnyShapeStyle(.white))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.black.opacity(0.7)))
                .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help(controller.recorder.isRecording ? "停止录音并暂存" : "开始录音")
        .accessibilityLabel(controller.recorder.isRecording ? "停止录音并暂存" : "开始录音")
    }
}
