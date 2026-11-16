import AppKit

/// Process entry point.
///
/// This is an AppKit app, not a SwiftUI `App`. A SwiftUI lifecycle wants a
/// scene (and usually a Dock icon). A menu-bar utility only needs
/// `NSStatusItem`s plus the occasional preferences window.
///
/// The Dock icon is hidden two ways:
/// - `LSUIElement` in `Resources/Info.plist` (the packaged `.app`)
/// - `NSApp.setActivationPolicy(.accessory)` below (`swift run` has no plist)
@main
struct MenuBarManagerMain {
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        // NSApplication.delegate is weak. Keep `delegate` alive for the whole run.
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) {
            application.run()
        }
    }
}

/// Owns the objects that have to outlive `applicationDidFinishLaunching`.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBar: StatusBarController?
    private var preferences: PreferencesWindowController?

    func applicationDidFinishLaunching(_: Notification) {
        let settings = AppSettings()
        let preferences = PreferencesWindowController(settings: settings)
        self.preferences = preferences
        // Both controllers retain `settings`, so the delegate does not need to.
        statusBar = StatusBarController(settings: settings, preferences: preferences)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        // Closing Preferences must not quit the menu-bar app.
        false
    }

    func applicationSupportsSecureRestorableState(_: NSApplication) -> Bool {
        true
    }
}

enum AppInfo {
    static let name = "MenuBarManager"
    static let author = "Qiyuan Zhu"

    static var version: String {
        guard
            let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            !short.isEmpty
        else {
            return "1.0.0"
        }
        return short
    }
}

enum AppActivation {
    /// An `LSUIElement` / accessory app is not brought forward unless asked.
    static func activate() {
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
