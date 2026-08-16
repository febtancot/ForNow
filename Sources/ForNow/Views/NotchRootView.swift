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
            ClosedCapsuleBar(hovering: hovering)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 2)
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
    }
}

/// 收起态的胶囊条：左侧 mic（点击录音/停止，录音中显示时长）、右侧托盘图标+计数（点击打开）。
/// 两个分段都是独立按钮，因此 VoiceOver 可分别触达；窗口其余区域点击同样打开面板。
struct ClosedCapsuleBar: View {
    @EnvironmentObject private var controller: NotchController
    @EnvironmentObject private var store: StashStore
    /// 直接观察录音器：录音状态/计时的变化只重绘本胶囊条，不触发面板整体重渲染。
    @EnvironmentObject private var recorder: RecordingController
    let hovering: Bool

    var body: some View {
        HStack(spacing: 0) {
            micSegment
            Rectangle()
                .fill(Color.white.opacity(0.2))
                .frame(width: 1, height: 12)
            traySegment
        }
        .foregroundStyle(.white)
        .background(Capsule().fill(Color.black.opacity(hovering ? 0.92 : 0.7)))
        .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 1))
    }

    private var micSegment: some View {
        Button { controller.toggleRecording() } label: {
            HStack(spacing: 4) {
                Image(systemName: recorder.isRecording ? "mic.fill" : "mic")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(recorder.isRecording ? AnyShapeStyle(.red) : AnyShapeStyle(.white))
                if recorder.isRecording {
                    Text(StashItem.durationText(seconds: recorder.elapsedSeconds))
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .help(recorder.isRecording ? "停止录音并暂存" : "开始录音")
        .accessibilityLabel(recorder.isRecording ? "停止录音并暂存" : "开始录音")
    }

    private var traySegment: some View {
        Button { controller.open() } label: {
            HStack(spacing: 6) {
                Image(systemName: "tray.and.arrow.down.fill")
                    .font(.system(size: 11, weight: .semibold))
                if store.count > 0 {
                    Text("\(store.count)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .help("打开暂存面板")
        .accessibilityLabel("搁这儿，\(store.count) 个暂存项目")
        .accessibilityHint("打开暂存面板")
    }
}
