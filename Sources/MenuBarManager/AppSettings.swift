import Combine
import Foundation

/// How long icons stay visible after the user shows them.
///
/// Raw values are seconds and are the values written to `UserDefaults`.
enum AutoHideOption: Int, CaseIterable, Identifiable {
    case off = 0
    case five = 5
    case ten = 10
    case thirty = 30

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .off: return "Off"
        case .five: return "5 seconds"
        case .ten: return "10 seconds"
        case .thirty: return "30 seconds"
        }
    }

    /// One line of explanation under the preferences control.
    var helpText: String {
        switch self {
        case .off:
            return "Icons stay visible until you hide them."
        default:
            return "After you show the icons, they hide again after \(rawValue) seconds."
        }
    }
}

/// Preferences that belong to this app.
///
/// `iconsHidden` and `autoHide` live in `UserDefaults`. Launch-at-login is
/// not mirrored there: `SMAppService` is the source of truth, because the
/// user can also change the login item in System Settings.
final class AppSettings: ObservableObject {
    enum Key {
        static let iconsHidden = "iconsHidden"
        static let autoHideSeconds = "autoHideSeconds"
    }

    private let defaults: UserDefaults

    /// Called after a UserDefaults-backed preference changes.
    /// `StatusBarController` assigns this so the divider and timer stay in sync
    /// with both the menu and the SwiftUI window.
    var onChange: (() -> Void)?

    @Published var iconsHidden: Bool {
        didSet {
            guard oldValue != iconsHidden else { return }
            defaults.set(iconsHidden, forKey: Key.iconsHidden)
            onChange?()
        }
    }

    @Published var autoHide: AutoHideOption {
        didSet {
            guard oldValue != autoHide else { return }
            defaults.set(autoHide.rawValue, forKey: Key.autoHideSeconds)
            onChange?()
        }
    }

    /// `true` when the login item is enabled or waiting for the user to approve it.
    @Published private(set) var launchAtLoginEnabled: Bool

    /// Extra context for the preferences window (approval needed, or the last error).
    @Published private(set) var launchAtLoginMessage: String?

    @Published private(set) var launchAtLoginMessageIsError = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.iconsHidden: false,
            Key.autoHideSeconds: AutoHideOption.off.rawValue
        ])

        // Default is "shown". The divider needs to be on screen the first time
        // so the user can see which side icons will hide on.
        iconsHidden = defaults.bool(forKey: Key.iconsHidden)
        let storedSeconds = defaults.integer(forKey: Key.autoHideSeconds)
        autoHide = AutoHideOption(rawValue: storedSeconds) ?? .off

        launchAtLoginEnabled = LaunchAtLogin.isEnabled
        launchAtLoginMessage = LaunchAtLogin.hint
    }

    func refreshLaunchAtLogin() {
        launchAtLoginEnabled = LaunchAtLogin.isEnabled
        launchAtLoginMessage = LaunchAtLogin.hint
        launchAtLoginMessageIsError = false
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LaunchAtLogin.setEnabled(enabled)
            launchAtLoginMessageIsError = false
            launchAtLoginMessage = LaunchAtLogin.hint
        } catch {
            launchAtLoginMessageIsError = true
            launchAtLoginMessage = error.localizedDescription
        }
        launchAtLoginEnabled = LaunchAtLogin.isEnabled
    }
}
