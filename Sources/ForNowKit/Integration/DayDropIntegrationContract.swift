import Foundation

/// ForNow 与 DayDrop 之间的公开联动契约。
///
/// ForNow 不读取 DayDrop 的沙盒数据，也不自行推导归档路径；它只在系统确认
/// 自定义 URL 由 DayDrop 提供时显示入口，再把“打开今日文件夹”交还给 DayDrop 执行。
public enum DayDropIntegrationContract {
    public static let bundleIdentifier = "com.liuyuhang.DayDrop"
    public static let openTodayFolderURL = URL(string: "daydrop://open-today-folder")!
    public static let homepageURL = URL(string: "https://daydrop.liveby.app")!
    public static let targetDisplayCapabilityInfoKey = "DayDropOpenTodayFolderTargetDisplayVersion"
    public static let targetDisplayCapabilityVersion = 1

    /// 新版 DayDrop 可接收点击发生的显示器身份，并把 Finder 窗口放到同一块屏幕。
    /// 旧版没有声明能力时，调用方应继续使用不带查询参数的稳定入口。
    public static func supportsTargetDisplay(infoDictionary: [String: Any]?) -> Bool {
        guard let value = infoDictionary?[targetDisplayCapabilityInfoKey] else { return false }
        let version: Int?
        switch value {
        case let number as NSNumber:
            version = number.intValue
        case let string as String:
            version = Int(string)
        default:
            version = nil
        }
        return (version ?? 0) >= targetDisplayCapabilityVersion
    }

    /// 生成一次性的目标显示器请求。URL 不携带目录路径，DayDrop 仍负责授权、
    /// 今日目录准备和最终 Finder 打开。
    public static func openTodayFolderURL(targetDisplayID: String) -> URL? {
        let allowed = CharacterSet.alphanumerics
            .union(CharacterSet(charactersIn: "-_"))
        guard !targetDisplayID.isEmpty,
              targetDisplayID.utf8.count <= 128,
              targetDisplayID.unicodeScalars.allSatisfy(allowed.contains),
              var components = URLComponents(url: openTodayFolderURL, resolvingAgainstBaseURL: false)
        else {
            return nil
        }
        components.queryItems = [URLQueryItem(name: "display-id", value: targetDisplayID)]
        return components.url
    }

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
