import Foundation

/// DayDrop 或其他本机应用向 For Now 发送文件时使用的公开契约。
public enum ExternalFileImportContract {
    public static let capabilityVersion = 1

    /// 只接受本机文件 URL，去掉重复项，并保持发送方的顺序。
    public static func normalizedFileURLs(_ urls: [URL]) -> [URL] {
        var seen = Set<String>()
        return urls.compactMap { url in
            guard url.isFileURL else { return nil }
            let normalized = url.standardizedFileURL
            guard !normalized.path.isEmpty,
                  seen.insert(normalized.path).inserted
            else {
                return nil
            }
            return normalized
        }
    }

    public static func feedbackMessage(
        addedCount: Int,
        duplicateCount: Int,
        failureCount: Int
    ) -> String {
        var parts: [String] = []
        if addedCount > 0 { parts.append("已暂存 \(addedCount) 项") }
        if duplicateCount > 0 { parts.append("\(duplicateCount) 项已存在") }
        if failureCount > 0 { parts.append("\(failureCount) 项失败") }
        return parts.isEmpty ? "没有可暂存的文件" : parts.joined(separator: "，")
    }
}
