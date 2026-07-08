import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

@main
struct WorklogBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var state = AppState()

    var body: some Scene {
        MenuBarExtra {
            RootView()
                .environmentObject(state)
        } label: {
            Label(state.menuTitle, systemImage: "clock.badge.checkmark")
        }
        .menuBarExtraStyle(.window)
    }
}
