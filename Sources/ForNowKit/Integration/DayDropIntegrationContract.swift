import Foundation

/// ForNow 与 DayDrop 之间的公开联动契约。
///
/// ForNow 不读取 DayDrop 的沙盒数据，也不自行推导归档路径；它只在系统确认
/// 自定义 URL 由 DayDrop 提供时显示入口，再把“打开今日文件夹”交还给 DayDrop 执行。
public enum DayDropIntegrationContract {
    public static let bundleIdentifier = "com.liuyuhang.DayDrop"
    public static let openTodayFolderURL = URL(string: "daydrop://open-today-folder")!

    /// 同时确认 DayDrop 已被 Launch Services 发现，且 URL Scheme 没有被其他应用接管。
    public static func canOpenTodayFolder(
        installedApplicationURL: URL?,
        schemeHandlerApplicationURL: URL?,
        schemeHandlerBundleIdentifier: String?
    ) -> Bool {
        guard let installedApplicationURL,
              let schemeHandlerApplicationURL,
              schemeHandlerBundleIdentifier == bundleIdentifier
        else {
            return false
        }

        return normalizedApplicationURL(installedApplicationURL)
            == normalizedApplicationURL(schemeHandlerApplicationURL)
    }

    private static func normalizedApplicationURL(_ url: URL) -> URL {
        url.standardizedFileURL.resolvingSymlinksInPath()
    }
}
