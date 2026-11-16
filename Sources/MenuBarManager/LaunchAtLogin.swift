import Foundation
import ServiceManagement

/// Turns the packaged app into a login item with `SMAppService` (macOS 13+).
///
/// This only works for a real `MenuBarManager.app` bundle. `swift run` executes
/// a bare binary, and ServiceManagement reports that it cannot find the app.
enum LaunchAtLogin {
    static var isAppBundle: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    /// Enabled, or registered and waiting for approval in System Settings.
    static var isEnabled: Bool {
        switch SMAppService.mainApp.status {
        case .enabled, .requiresApproval:
            return true
        case .notRegistered, .notFound:
            return false
        @unknown default:
            return false
        }
    }

    static var needsApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    /// Non-error guidance, when macOS is waiting on the user.
    static var hint: String? {
        guard needsApproval else { return nil }
        return "Allow \(AppInfo.name) in System Settings → General → Login Items."
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled && !isAppBundle {
            throw LaunchAtLoginError.notBundled
        }

        let service = SMAppService.mainApp
        if enabled {
            // `requiresApproval` is already registered; calling register again throws.
            switch service.status {
            case .enabled, .requiresApproval:
                break
            case .notRegistered, .notFound:
                try service.register()
            @unknown default:
                try service.register()
            }
        } else if service.status == .enabled || service.status == .requiresApproval {
            try service.unregister()
        }
    }
}

enum LaunchAtLoginError: LocalizedError {
    case notBundled

    var errorDescription: String? {
        switch self {
        case .notBundled:
            return "Launch at login only works from MenuBarManager.app. Run scripts/build-app.sh, then open the app it creates. swift run cannot register a login item."
        }
    }
}
