import SwiftUI

/// MenuBarExtra(.window)'s NSPanel auto-sizes by querying the SwiftUI view
/// tree's unconstrained ideal size, which doesn't reliably respect a
/// .frame() modifier — an unbounded view (e.g. Color in an overlay) can
/// make it balloon well past the intended 480x440. As a hard backstop
/// independent of SwiftUI's layout internals, clamp any oversized resize
/// of the popover panel directly at the AppKit level.
final class AppDelegate: NSObject, NSApplicationDelegate {
    static let popoverSize = NSSize(width: 480, height: 440)
    private var resizeObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        resizeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResizeNotification,
            object: nil,
            queue: .main
        ) { note in
            guard let window = note.object as? NSWindow else { return }
            let size = window.frame.size
            let target = Self.popoverSize
            let tolerance: CGFloat = 1
            guard abs(size.width - target.width) > tolerance || abs(size.height - target.height) > tolerance else { return }
            var frame = window.frame
            frame.origin.y += frame.size.height - target.height
            frame.size = target
            window.setFrame(frame, display: true)
        }
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
