import Foundation
import ServiceManagement

enum LaunchAtLoginManager {
    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                guard SMAppService.mainApp.status != .enabled else { return }
                try SMAppService.mainApp.register()
            } else {
                guard SMAppService.mainApp.status == .enabled else { return }
                try SMAppService.mainApp.unregister()
            }
        } catch {
        }
    }

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }
}
