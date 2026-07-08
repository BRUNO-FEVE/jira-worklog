import Foundation

/// Data the app shares with the widget extension via a JSON file.
struct WidgetSnapshot: Codable {
    struct Day: Codable {
        let date: Date
        let seconds: Int
    }
    let todaySeconds: Int
    let targetSeconds: Int
    let updatedAt: Date
    let days: [Day]

    static let placeholder = WidgetSnapshot(
        todaySeconds: 5 * 3600 + 15 * 60,
        targetSeconds: 8 * 3600,
        updatedAt: Date(),
        days: []
    )
}

enum SnapshotStore {
    static var url: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/Application Support/WorklogBar/snapshot.json")
    }

    static func save(_ snapshot: WidgetSnapshot) {
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(snapshot).write(to: url)
        } catch {
            // Snapshot is best-effort; the widget just shows stale data on failure.
        }
    }

    static func load() -> WidgetSnapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WidgetSnapshot.self, from: data)
    }
}
