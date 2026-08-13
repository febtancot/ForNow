import Foundation
import ServiceManagement

/// 登录时启动（SMAppService，macOS 13+）。
enum LoginItem {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            // 开发期未签名/未安装到 /Applications 时可能失败；不阻断使用。
            NSLog("[ForNow] 登录项设置失败：\(error.localizedDescription)")
        }
    }
}
