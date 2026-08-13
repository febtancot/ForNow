import SwiftUI

/// 顶部两角为直角、底部两角为圆角的矩形 —— 让面板顶边与屏幕/刘海齐平。
struct BottomRoundedRectangle: Shape {
    var radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let r = min(radius, min(rect.width, rect.height) / 2)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY),
                          control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - r),
                          control: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// 面板背景：自适应深/浅色的材质 + 细描边。
struct PanelBackground: View {
    var isDropTargeted: Bool = false

    var body: some View {
        BottomRoundedRectangle(radius: 24)
            .fill(.regularMaterial)
            .overlay(
                BottomRoundedRectangle(radius: 24)
                    .stroke(isDropTargeted ? Color.accentColor : Color.primary.opacity(0.08),
                            lineWidth: isDropTargeted ? 2 : 1)
            )
    }
}
