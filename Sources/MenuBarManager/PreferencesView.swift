import AppKit
import SwiftUI

/// The preferences window. Settings are the same `AppSettings` object the
/// status items observe, so the menu, the chevron, and this window cannot drift.
struct PreferencesView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(AppInfo.name)
                    .font(.title2.weight(.semibold))
                Text("Choose which status icons stay in the menu bar.")
                    .foregroundStyle(.secondary)
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 14) {
                    Toggle(isOn: $settings.iconsHidden) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Hide menu bar icons")
                            Text("Stretches the divider so icons on its left leave the screen.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Auto-hide")
                        Picker("Auto-hide", selection: $settings.autoHide) {
                            ForEach(AutoHideOption.allCases) { option in
                                Text(option.title).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        Text(settings.autoHide.helpText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
            } label: {
                Text("Visibility")
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Launch at login", isOn: launchAtLoginBinding)
                    Text(launchCaption)
                        .font(.caption)
                        .foregroundStyle(settings.launchAtLoginMessageIsError ? Color.red : Color.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
            } label: {
                Text("Startup")
            }

            Text("Hold ⌘ and drag icons. Icons to the left of the divider hide. Icons between the divider and the chevron stay visible. macOS remembers those positions.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(width: 480, alignment: .leading)
        .fixedSize(horizontal: true, vertical: true)
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { settings.launchAtLoginEnabled },
            set: { enabled in
                // `setLaunchAtLogin` writes other published fields. Doing that
                // inside the toggle's update pass makes SwiftUI drop the change.
                DispatchQueue.main.async {
                    settings.setLaunchAtLogin(enabled)
                }
            }
        )
    }

    private var launchCaption: String {
        if let message = settings.launchAtLoginMessage {
            return message
        }
        return "Uses SMAppService. Build MenuBarManager.app and launch that bundle; swift run cannot register a login item."
    }
}

/// Hosts `PreferencesView` in one reusable `NSWindow`.
final class PreferencesWindowController: NSObject, NSWindowDelegate {
    private let settings: AppSettings
    private var window: NSWindow?
    private var didCenter = false

    init(settings: AppSettings) {
        self.settings = settings
    }

    func show() {
        settings.refreshLaunchAtLogin()
        let window = ensureWindow()
        if !didCenter {
            window.center()
            didCenter = true
        }
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        AppActivation.activate()
    }

    private func ensureWindow() -> NSWindow {
        if let window {
            return window
        }

        let hosting = NSHostingController(rootView: PreferencesView(settings: settings))
        // Ask the hosting view for the SwiftUI layout size (macOS 13+).
        hosting.sizingOptions = [.intrinsicContentSize, .preferredContentSize]
        hosting.view.layoutSubtreeIfNeeded()

        let fitted = hosting.view.intrinsicContentSize
        // `noIntrinsicMetric` is -1. Ignore that, and ignore a runaway size.
        let width = (fitted.width >= 400 && fitted.width <= 800) ? fitted.width : 480
        let height = (fitted.height >= 280 && fitted.height <= 700) ? fitted.height : 460
        let size = NSSize(width: width, height: height)

        let window = NSWindow(contentViewController: hosting)
        window.title = "Preferences"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.moveToActiveSpace]
        window.delegate = self
        window.setContentSize(size)
        window.contentMinSize = NSSize(width: 460, height: 360)
        self.window = window
        return window
    }
}
