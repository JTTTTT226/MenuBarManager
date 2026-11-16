# MenuBarManager

[![CI](https://github.com/JTTTTT226/MenuBarManager/actions/workflows/ci.yml/badge.svg)](https://github.com/JTTTTT226/MenuBarManager/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A small macOS menu bar utility that hides status icons. Click the chevron and every icon to the left of a divider slides off the menu bar. Click again and they come back.

It is a portfolio project: one Swift package, AppKit status items, a SwiftUI preferences window, and no private API. The behavior is in the same family as [Hidden Bar](https://github.com/dwarvesf/hidden) and Bartender, trimmed to the part that is worth reading.

Requires **macOS 13 (Ventura)** or later and **Swift 5.9**.

## Features

- Two status items: a chevron that toggles, and a divider that does the hiding
- Right-click the chevron for Hide/Show, auto-hide, launch at login, Preferences, About, and Quit
- Auto-hide after 5, 10, or 30 seconds, or leave it off
- Auto-hide waits while the pointer is still in the menu bar, so a drag is not cut off
- Preferences window for the same settings
- Hide/show state and the auto-hide interval are stored in `UserDefaults`
- Launch at login via `SMAppService` (macOS 13)
- No Dock icon (`LSUIElement`, and an accessory activation policy when you `swift run`)
- macOS remembers icon positions, including the chevron and the divider

## How it works

macOS will not hide another app's menu bar icon for you. MenuBarManager only changes the width of **its own** divider item.

Status items are laid out from the right. The chevron is created first, so it sits next to the system icons. The divider is created second, so it sits just to the left of the chevron. Icons further left are other apps (and any icon you have dragged there).

```text
Icons visible. The divider is 16 points wide.

  Slack    Dropbox    |    ‹        Battery    Control Center
                      ^    ^
                 divider   chevron (this app)

Icons hidden. The divider's length is 10000 points, wider than the screen,
so everything to its left is pushed off.

                 ›        Battery    Control Center
```

`10_000` is also the longest `NSStatusItem.length` macOS accepts. The chevron flips from `‹` (click to hide) to `›` (click to show). A display change can reset that length, so the app writes it back when screens change.

While the icons are hidden, the divider image is not scaled up with the item. Scaling a 1-point line to 10,000 points would draw a solid block. The image stays a hairline; almost all of the item is empty width.

## Arrange icons with ⌘-drag

Hold the **Command** key and drag a menu bar icon sideways. That gesture is built into macOS. This app does not move other apps' icons itself.

- Drop an icon to the **left of the divider** to include it in the hide.
- Drop an icon **between the divider and the chevron** to keep it visible when the rest are hidden.
- Leave system items that cannot be dragged (often Control Center and the clock) where they are. They stay visible because they remain to the right of the chevron.

Positions are saved with `NSStatusItem.autosaveName`, so the arrangement is still there next launch. The first launch leaves icons visible on purpose, so you can see the divider before anything is hidden.

⌘-click on the chevron does not toggle. Command-click is how a drag starts.

## Preferences

Open **Preferences…** from the chevron's menu (⌘, while the menu is open).

| Setting | Where it is stored |
| --- | --- |
| Hide menu bar icons | `UserDefaults` key `iconsHidden` |
| Auto-hide (off / 5 / 10 / 30 seconds) | `UserDefaults` key `autoHideSeconds` |
| Launch at login | `SMAppService`, not UserDefaults |

Launch at login is not copied into `UserDefaults`. System Settings can change the same login item, so the app reads `SMAppService.mainApp.status` instead of a second copy that would go stale.

The login item only registers from the real `MenuBarManager.app` bundle. `swift run` is a bare executable and ServiceManagement cannot find an app to launch. The preferences window says so if you try.

## Build and run

Install Xcode 15 or newer, or the Swift 5.9 command-line tools. No Xcode project is required. Opening `Package.swift` in Xcode works if you want the debugger.

From the repository root:

```bash
swift build
swift run
```

`swift run` is the fastest way to try the chevron. It still hides the Dock icon by setting the accessory activation policy. Launch at login will not succeed in that mode.

To build the double-clickable app:

```bash
./scripts/build-app.sh
open MenuBarManager.app
```

The script runs `swift build -c release`, copies the binary into `MenuBarManager.app`, adds [`Resources/Info.plist`](Resources/Info.plist) (`LSUIElement` is `true`), and ad-hoc signs the bundle. The `.app` is gitignored.

The ad-hoc signature is enough for a local login item. It is not a notarized Developer ID signature, so the first time you open the app macOS may refuse it. Right-click `MenuBarManager.app`, choose **Open**, or allow it under **System Settings → Privacy & Security**. If you move the app after registering the login item, open System Settings and approve it again. `SMAppService` binds the login item to that signed bundle.

## Project layout

```text
Package.swift                  Executable Swift package, macOS 13+
Sources/MenuBarManager/
    AppMain.swift              @main, AppDelegate, no Dock icon
    StatusBarController.swift  Chevron, divider, menu, auto-hide timer
    AppSettings.swift          UserDefaults-backed preferences
    LaunchAtLogin.swift        SMAppService wrapper
    PreferencesView.swift      SwiftUI preferences + NSWindow host
Resources/Info.plist           Bundle metadata, including LSUIElement
scripts/build-app.sh           Release build → MenuBarManager.app
.github/workflows/ci.yml       Builds the app on macos-latest
```

The process is started with AppKit on purpose. A SwiftUI `App` wants a scene and tends to grow a Dock icon. SwiftUI is used only for the preferences window, inside an `NSHostingController`.

## Limits

- Hiding is geometry. There is no API call that sets another icon to hidden, so a notch can cover icons that were pushed left. Show them again with the chevron.
- Some Apple items cannot be ⌘-dragged on recent macOS versions.
- A future macOS menu bar may ignore very large status-item lengths. The hide would stop working until this approach changed.
- The left/right description above assumes a left-to-right menu bar.
- `10_000` points is the platform maximum. It is simple and always wide enough. It is also larger than a menu bar needs, which on some systems costs more layout work than "twice the widest screen".

## Roadmap

- A global keyboard shortcut to show and hide
- A second divider, for icons that stay hidden even while the bar is expanded
- Size the divider from the widest connected display, still capped at 10,000
- A way to reach icons that land under the camera notch
- Remember a separate arrangement per display

## License

[MIT](LICENSE) © 2026 Qiyuan Zhu
