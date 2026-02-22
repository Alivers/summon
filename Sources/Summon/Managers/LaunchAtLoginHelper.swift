import ServiceManagement

/// Thin wrapper around `SMAppService` for launch-at-login (macOS 13+).
enum LaunchAtLoginHelper {
    private static let service = SMAppService.mainApp

    static var isEnabled: Bool {
        get { service.status == .enabled }
        set {
            do {
                if newValue {
                    try service.register()
                } else {
                    try service.unregister()
                }
            } catch {
                // Silently ignore — registration can fail for ad-hoc signed apps
            }
        }
    }
}
