import SwiftUI
import AppKit

/// Hosts SectionFormView in a standalone NSPanel instead of inside the
/// MenuBarExtra(.window) popover. That popover's NSPanel auto-sizes itself
/// from the SwiftUI content tree's ideal size on every layout pass, and does
/// not reliably respect an ancestor .frame() — every attempt to present the
/// form inline or as an overlay inside it caused the whole popover to
/// balloon. A plain NSPanel we create and size ourselves has no such
/// behavior, so the bug has no shared code path left to occur in.
@MainActor
enum SectionFormPanelController {
    private static var panel: NSPanel?

    static func show(existing: TicketSection?, state: AppState) {
        let panel = self.panel ?? {
            let p = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 320, height: 440),
                styleMask: [.titled, .closable, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            p.isFloatingPanel = true
            p.level = .floating
            p.hidesOnDeactivate = false
            p.isReleasedWhenClosed = false
            self.panel = p
            return p
        }()

        panel.title = existing == nil ? "New Section" : "Edit Section"
        let rootView = SectionFormView(existing: existing) { section in
            if existing != nil {
                state.updateSection(section)
            } else {
                state.addSection(section)
            }
            panel.close()
        } onCancel: {
            panel.close()
        }
        .environmentObject(state)

        panel.contentView = NSHostingView(rootView: rootView)
        panel.setContentSize(NSSize(width: 320, height: 440))
        panel.center()
        panel.makeKeyAndOrderFront(nil)
    }
}
