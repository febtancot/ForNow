import Foundation

/// 应用本地存储路径。所有内容仅保存在本机。
public enum AppPaths {
    public static let folderName = "ForNow"

    public static func supportDirectory(fileManager: FileManager = .default) -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return base.appendingPathComponent(folderName, isDirectory: true)
    }

    public static func filesDirectory(fileManager: FileManager = .default) -> URL {
        supportDirectory(fileManager: fileManager).appendingPathComponent("Files", isDirectory: true)
    }

    public static func metadataURL(fileManager: FileManager = .default) -> URL {
        supportDirectory(fileManager: fileManager).appendingPathComponent("metadata.json")
    }

    public static func trashMetadataURL(fileManager: FileManager = .default) -> URL {
        supportDirectory(fileManager: fileManager).appendingPathComponent("trash.json")
    }
}
