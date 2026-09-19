import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    private init() {}

    func show(store: AppStore) {
        let settingsWindow: NSWindow
        if let window {
            settingsWindow = window
        } else {
            let hostingController = NSHostingController(
                rootView: SettingsContentView(store: store)
            )
            let newWindow = NSWindow(contentViewController: hostingController)
            newWindow.title = "合盖守护设置"
            newWindow.styleMask = [.titled, .closable, .miniaturizable]
            newWindow.setContentSize(NSSize(width: 480, height: 390))
            newWindow.isReleasedWhenClosed = false
            newWindow.collectionBehavior = [.moveToActiveSpace]
            newWindow.center()
            window = newWindow
            settingsWindow = newWindow
        }

        NSApplication.shared.activate(ignoringOtherApps: true)
        settingsWindow.makeKeyAndOrderFront(nil)
    }
}
