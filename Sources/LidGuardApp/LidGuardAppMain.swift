import SwiftUI

@main
struct LidGuardMenuBarApp: App {
    @StateObject private var store = AppStore()

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(store: store)
        } label: {
            Image(systemName: store.status?.mode == .active ? "laptopcomputer.and.arrow.down" : "laptopcomputer")
                .accessibilityLabel("合盖守护")
        }
        .menuBarExtraStyle(.window)
    }
}
