import Foundation
import CryptoKit

/// 文件内容哈希（SHA-256 十六进制），用于识别重复文件。
enum ContentHasher {
    /// 流式读取计算哈希，避免大文件整体载入内存；读取失败（如目录）返回 nil。
    static func sha256Hex(ofFileAt url: URL) -> String? {
        do {
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            var hasher = SHA256()
            while true {
                guard let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty else { break }
                hasher.update(data: chunk)
            }
            return hasher.finalize().map { String(format: "%02x", $0) }.joined()
        } catch {
            return nil
        }
    }
}
