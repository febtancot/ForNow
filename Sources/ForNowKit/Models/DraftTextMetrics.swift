import Foundation
import AppKit

/// 输入条草稿的高度测算。
///
/// 只测量截断后的文本前缀（TextKit 惰性排版，最多排 8 行）：
/// 成本与行数上限成正比，与全文长度无关——粘贴几万字后继续打字也不增加布局开销。
@MainActor
public enum DraftTextMetrics {
    /// 与输入条文本一致的字体（14pt 系统字体）。
    private static let font = NSFont.systemFont(ofSize: 14)
    /// 输入条最多展示的行数（超出后内部滚动）。
    private static let maxLines = 8
    /// 测量所用的文本前缀长度。8 行在任意合理宽度下所需字符数远小于此值。
    private static let measuredPrefix = 4000
    /// 单行内容高度。
    public static let lineHeight = ceil(font.ascender - font.descender)

    /// 文本在给定宽度下排版的行数（≥1，最多 `maxLines` 行），供测试与高度计算用。
    public static func lineCount(for text: String, width: CGFloat) -> Int {
        guard width > 0 else { return 1 }
        let truncated = text.count > measuredPrefix ? String(text.prefix(measuredPrefix)) : text
        let container = NSTextContainer(size: NSSize(width: width, height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        let layout = NSLayoutManager()
        layout.addTextContainer(container)
        let storage = NSTextStorage(string: truncated.isEmpty ? " " : truncated, attributes: [.font: font])
        storage.addLayoutManager(layout)
        // 逐行惰性排版，最多 maxLines 行；后续内容不参与排版。
        var count = 0
        var glyphIndex = 0
        while glyphIndex < layout.numberOfGlyphs, count < maxLines {
            var range = NSRange(location: 0, length: 0)
            layout.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &range)
            glyphIndex = range.upperBound
            count += 1
        }
        return max(count, 1)
    }

    /// 文本在给定宽度下、截断到 `maxLines` 行后的高度（空草稿为单行高度）。
    public static func height(for text: String, width: CGFloat) -> CGFloat {
        lineHeight * CGFloat(lineCount(for: text, width: width))
    }
}
