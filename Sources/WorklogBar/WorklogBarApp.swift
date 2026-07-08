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

    // MenuBarExtra flattens its label to a template image, which mangles
    // Canvas/gradient views — pre-render the glyph to a color NSImage instead.
    private static let menuIcon: NSImage = {
        let renderer = ImageRenderer(content: JiraGlyph(size: 16))
        renderer.scale = 2
        let image = renderer.nsImage ?? NSImage()
        image.size = NSSize(width: 16, height: 16)
        image.isTemplate = false
        return image
    }()

    var body: some Scene {
        MenuBarExtra {
            RootView()
                .environmentObject(state)
        } label: {
            HStack(spacing: 4) {
                Image(nsImage: Self.menuIcon)
                    .renderingMode(.original)
                if !state.menuTitle.isEmpty {
                    Text(state.menuTitle)
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}
