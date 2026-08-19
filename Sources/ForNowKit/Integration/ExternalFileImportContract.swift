import Foundation

/// Finder 扩展或其他本机应用向 ForNow 发送文件时使用的公开契约。
public enum ExternalFileImportContract {
    public static let capabilityVersion = 1
    public static let receiverBundleIdentifier = "com.fornow.app"

    /// 从嵌入式 Finder 扩展的位置反向解析宿主 ForNow.app。
    public static func containingApplicationURL(forExtensionBundleURL url: URL) -> URL? {
        guard url.isFileURL, url.pathExtension == "appex" else { return nil }
        let plugInsURL = url.deletingLastPathComponent()
        guard plugInsURL.lastPathComponent == "PlugIns" else { return nil }
        let contentsURL = plugInsURL.deletingLastPathComponent()
        guard contentsURL.lastPathComponent == "Contents" else { return nil }
        let applicationURL = contentsURL.deletingLastPathComponent()
        guard applicationURL.pathExtension == "app" else { return nil }
        return applicationURL.standardizedFileURL
    }

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
