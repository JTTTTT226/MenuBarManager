import AppKit

/// Widths for the divider status item. See `StatusBarController` for why.
enum DividerMetrics {
    /// Visible gap while icons are shown. Wide enough to see and to ⌘-drag.
    static let shownLength: CGFloat = 16

    /// Width used while icons are hidden.
    ///
    /// macOS lays status items out from the right and will not honor a length
    /// above 10,000 points. That is wider than any display, so one constant
    /// pushes every icon to the left of the divider off-screen on every monitor.
    static let hiddenLength: CGFloat = 10_000
}

/// The two menu-bar items, the click behavior, and the right-click menu.
///
/// ## How hiding works
///
/// macOS has no API for hiding another app's menu-bar icon. This app fakes it
/// with layout, which is the same idea behind utilities like Hidden Bar:
///
/// 1. Create the chevron first. New status items are inserted to the left of
///    existing ones, so the chevron sits closest to the system icons.
/// 2. Create the divider second, so it sits immediately to the left of the chevron.
/// 3. Leave the divider short (`DividerMetrics.shownLength`) to show icons,
///    or set its `length` to `DividerMetrics.hiddenLength` to hide them.
///
/// A 10,000-point item is much wider than the menu bar. Everything to its left
/// is pushed past the screen edge. The chevron stays visible because it is to
/// the right of the divider. System icons that stay to the right of the chevron
/// (Control Center, and anything the user ⌘-drags there) stay visible too.
///
/// ## Choosing which icons hide
///
/// Hold ⌘ and drag a status item. That gesture belongs to macOS, not to this
/// app. Drop an icon to the left of the divider to hide it with the chevron.
/// Drop it between the divider and the chevron to keep it visible.
/// `autosaveName` asks macOS to remember those positions, including ours.
final class StatusBarController: NSObject {
    private let settings: AppSettings
    private let preferences: PreferencesWindowController
    private let images = StatusImages.make()

    /// Rightmost of our two items. Created first so it stays next to system icons.
    private let toggleItem: NSStatusItem

    /// Sits to the left of `toggleItem`. Its length is the whole hide trick.
    private let dividerItem: NSStatusItem

    private var autoHideTimer: Timer?

    init(settings: AppSettings, preferences: PreferencesWindowController) {
        self.settings = settings
        self.preferences = preferences
        // Order matters. The first item created is the rightmost.
        toggleItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        dividerItem = NSStatusBar.system.statusItem(withLength: DividerMetrics.shownLength)
        super.init()

        configureDivider()
        configureToggle()
        restoreIfTheUserDraggedUsOff()

        settings.onChange = { [weak self] in
            self?.apply()
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        apply()
        // The status bar sometimes drops a length set before the item is on screen.
        // Write it again after this turn, without restarting the auto-hide timer.
        DispatchQueue.main.async { [weak self] in
            self?.applyLength()
        }
    }

    deinit {
        autoHideTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Status items

    private func configureToggle() {
        toggleItem.autosaveName = "MenuBarManager.toggle"
        guard let button = toggleItem.button else { return }
        button.target = self
        button.action = #selector(toggleClicked(_:))
        // Default delivery is left-click only. Ask for right-click too.
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
    }

    private func configureDivider() {
        dividerItem.autosaveName = "MenuBarManager.divider"
        guard let button = dividerItem.button else { return }
        button.image = images.divider
        button.imagePosition = .imageOnly
        // The hidden length is 10,000. Scaling the artwork to that width would
        // paint a huge block instead of a hairline.
        button.imageScaling = .scaleNone
        button.toolTip = "Icons to the left of this line can be hidden. ⌘-drag icons to either side."
        button.setAccessibilityLabel("Divider")
    }

    /// Cmd-dragging a status item off the bar removes it. This app's only UI
    /// is these two items, so put them back if a previous launch lost them.
    private func restoreIfTheUserDraggedUsOff() {
        toggleItem.isVisible = true
        dividerItem.isVisible = true
    }

    /// A display change can reset status-item lengths. Put the current width back.
    @objc private func screensChanged() {
        applyLength()
    }

    private func applyLength() {
        dividerItem.length = settings.iconsHidden ? DividerMetrics.hiddenLength : DividerMetrics.shownLength
    }

    private func apply() {
        let hidden = settings.iconsHidden
        applyLength()

        if let button = toggleItem.button {
            let label = hidden ? "Show hidden menu bar icons" : "Hide menu bar icons"
            if let image = hidden ? images.reveal : images.hide {
                button.image = image
                button.title = ""
            } else {
                button.image = nil
                button.title = hidden ? "›" : "‹"
            }
            button.toolTip = label
            button.setAccessibilityLabel(label)
        }

        scheduleAutoHide()
    }

    // MARK: - Clicks

    @objc private func toggleClicked(_: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            settings.iconsHidden.toggle()
            return
        }

        // ⌘-click is the start of a menu-bar drag. Don't also toggle.
        if event.modifierFlags.contains(.command) {
            return
        }

        let controlClick = event.modifierFlags.contains(.control)
        if event.type == .rightMouseUp || controlClick {
            showMenu(from: sender)
        } else {
            settings.iconsHidden.toggle()
        }
    }

    /// Pop the menu up ourselves.
    ///
    /// Assigning `statusItem.menu` would make a normal click open the menu
    /// instead of toggling. `performClick` from inside this button's action
    /// also re-enters the click handler, so the menu is positioned manually.
    private func showMenu(from button: NSStatusBarButton) {
        settings.refreshLaunchAtLogin()
        let menu = makeMenu()
        // Anchor at the bottom of the status item so the menu opens downward,
        // on screen, instead of into the sliver above the menu bar.
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: 0), in: button)
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let visibility = NSMenuItem(
            title: settings.iconsHidden ? "Show Icons" : "Hide Icons",
            action: #selector(toggleVisibility(_:)),
            keyEquivalent: ""
        )
        visibility.target = self
        menu.addItem(visibility)

        menu.addItem(autoHideItem())

        let launch = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin(_:)),
            keyEquivalent: ""
        )
        launch.target = self
        launch.state = settings.launchAtLoginEnabled ? .on : .off
        menu.addItem(launch)

        menu.addItem(NSMenuItem.separatorItem())

        let preferencesItem = NSMenuItem(
            title: "Preferences…",
            action: #selector(openPreferences(_:)),
            keyEquivalent: ","
        )
        preferencesItem.target = self
        menu.addItem(preferencesItem)

        let about = NSMenuItem(
            title: "About \(AppInfo.name)",
            action: #selector(showAbout(_:)),
            keyEquivalent: ""
        )
        about.target = self
        menu.addItem(about)

        menu.addItem(NSMenuItem.separatorItem())

        let quit = NSMenuItem(
            title: "Quit \(AppInfo.name)",
            action: #selector(quit(_:)),
            keyEquivalent: "q"
        )
        quit.target = self
        menu.addItem(quit)

        return menu
    }

    private func autoHideItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Auto-hide After", action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: "Auto-hide After")
        submenu.autoenablesItems = false

        for option in AutoHideOption.allCases {
            let choice = NSMenuItem(
                title: option.title,
                action: #selector(chooseAutoHide(_:)),
                keyEquivalent: ""
            )
            choice.target = self
            choice.tag = option.rawValue
            choice.state = option == settings.autoHide ? .on : .off
            submenu.addItem(choice)
        }

        item.submenu = submenu
        return item
    }

    @objc private func toggleVisibility(_: NSMenuItem) {
        settings.iconsHidden.toggle()
    }

    @objc private func chooseAutoHide(_ sender: NSMenuItem) {
        settings.autoHide = AutoHideOption(rawValue: sender.tag) ?? .off
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        let enable = !settings.launchAtLoginEnabled
        settings.setLaunchAtLogin(enable)

        if settings.launchAtLoginMessageIsError, let message = settings.launchAtLoginMessage {
            presentAlert(title: "Couldn't Change Launch at Login", message: message)
            return
        }
        if enable && LaunchAtLogin.needsApproval {
            presentAlert(
                title: "Approve Login Item",
                message: LaunchAtLogin.hint ?? "Allow \(AppInfo.name) in System Settings → General → Login Items."
            )
        }
    }

    @objc private func openPreferences(_: NSMenuItem) {
        preferences.show()
    }

    @objc private func showAbout(_: NSMenuItem) {
        let alert = NSAlert()
        alert.messageText = AppInfo.name
        alert.informativeText = """
        Hides menu bar icons by stretching a divider status item.

        Version \(AppInfo.version)
        Copyright © 2026 \(AppInfo.author)
        Released under the MIT License.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.window.level = .floating
        AppActivation.activate()
        alert.runModal()
    }

    @objc private func quit(_: NSMenuItem) {
        NSApp.terminate(nil)
    }

    private func presentAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.window.level = .floating
        AppActivation.activate()
        alert.runModal()
    }

    // MARK: - Auto-hide

    /// Starts, restarts, or cancels the auto-hide timer from the current settings.
    ///
    /// The timer only runs while the icons are visible. If it fires while the
    /// pointer is still in the menu bar, it waits and tries again so a ⌘-drag
    /// is not cut off.
    private func scheduleAutoHide(after seconds: Int? = nil) {
        autoHideTimer?.invalidate()
        autoHideTimer = nil

        guard !settings.iconsHidden else { return }
        let delay = seconds ?? settings.autoHide.rawValue
        guard delay > 0 else { return }

        let timer = Timer(timeInterval: TimeInterval(delay), repeats: false) { [weak self] _ in
            self?.autoHideFired()
        }
        RunLoop.main.add(timer, forMode: .common)
        autoHideTimer = timer
    }

    private func autoHideFired() {
        autoHideTimer = nil
        guard !settings.iconsHidden else { return }
        if mouseIsInMenuBar {
            scheduleAutoHide(after: 1)
            return
        }
        settings.iconsHidden = true
    }

    /// The menu bar is the strip above `visibleFrame` on each display.
    private var mouseIsInMenuBar: Bool {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.contains { screen in
            mouse.x >= screen.frame.minX && mouse.x <= screen.frame.maxX
                && mouse.y >= screen.visibleFrame.maxY && mouse.y <= screen.frame.maxY
        }
    }
}

/// Template images drawn once. Template images follow the menu bar's light/dark style.
private struct StatusImages {
    let hide: NSImage?
    let reveal: NSImage?
    let divider: NSImage

    static func make() -> StatusImages {
        StatusImages(
            hide: chevron(symbol: "chevron.left", description: "Hide menu bar icons"),
            reveal: chevron(symbol: "chevron.right", description: "Show menu bar icons"),
            divider: dividerLine()
        )
    }

    private static func chevron(symbol: String, description: String) -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
        guard let image = NSImage(systemSymbolName: symbol, accessibilityDescription: description)?
            .withSymbolConfiguration(configuration) else {
            return nil
        }
        image.isTemplate = true
        return image
    }

    /// A one-point vertical line. Kept narrow so `scaleNone` still looks like a divider
    /// when the status item itself is only `DividerMetrics.shownLength` points wide.
    private static func dividerLine() -> NSImage {
        let size = NSSize(width: 3, height: 18)
        let image = NSImage(size: size, flipped: false) { _ in
            NSColor.black.setFill()
            NSRect(x: 1, y: 3, width: 1, height: 12).fill()
            return true
        }
        image.isTemplate = true
        return image
    }
}
