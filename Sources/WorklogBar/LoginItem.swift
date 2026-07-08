import Foundation
import ServiceManagement

/// Launch-at-login. Bundled .app builds use SMAppService (shows up in
/// System Settings → Login Items); the bare SPM executable falls back
/// to a user LaunchAgent plist.
enum LoginItem {
    private static let label = "com.worklogbar.app"

    private static var isBundled: Bool {
        Bundle.main.bundleIdentifier != nil
    }

    private static var agentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/LaunchAgents/\(label).plist")
    }

    static var isEnabled: Bool {
        if isBundled {
            return SMAppService.mainApp.status == .enabled
        }
        return FileManager.default.fileExists(atPath: agentURL.path)
    }

    static func enable() throws {
        if isBundled {
            try SMAppService.mainApp.register()
            return
        }
        guard let exePath = Bundle.main.executablePath else { return }
        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [exePath],
            "RunAtLoad": true,
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try FileManager.default.createDirectory(
            at: agentURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: agentURL)
    }

    static func disable() throws {
        if isBundled {
            try SMAppService.mainApp.unregister()
            return
        }
        if FileManager.default.fileExists(atPath: agentURL.path) {
            try FileManager.default.removeItem(at: agentURL)
        }
    }
}
