import Foundation

struct Issue: Identifiable, Decodable, Hashable {
    struct Fields: Decodable, Hashable {
        struct Status: Decodable, Hashable {
            struct Category: Decodable, Hashable { let key: String? }
            let name: String
            let statusCategory: Category?
        }
        struct IssueType: Decodable, Hashable { let name: String }
        let summary: String
        let status: Status?
        let issuetype: IssueType?
    }
    let key: String
    let fields: Fields
    var id: String { key }
}

struct SearchResponse: Decodable {
    let issues: [Issue]
}

struct Transition: Decodable, Identifiable {
    struct Target: Decodable { let name: String }
    let id: String
    let name: String
    let to: Target?
}

struct TransitionsResponse: Decodable {
    let transitions: [Transition]
}

struct Myself: Decodable {
    let accountId: String?
    let name: String?
    let displayName: String
}

struct WorklogAuthor: Decodable {
    let accountId: String?
    let name: String?
}

struct Worklog: Decodable, Identifiable {
    let id: String
    let author: WorklogAuthor
    let started: String
    let timeSpentSeconds: Int
    let comment: String?

    private enum CodingKeys: String, CodingKey { case id, author, started, timeSpentSeconds, comment }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        author = try c.decode(WorklogAuthor.self, forKey: .author)
        started = try c.decode(String.self, forKey: .started)
        timeSpentSeconds = try c.decode(Int.self, forKey: .timeSpentSeconds)
        // Cloud v3 renders comments as ADF objects; only keep plain-string comments.
        comment = (try? c.decodeIfPresent(String.self, forKey: .comment)) ?? nil
    }
}

struct WorklogPage: Decodable {
    let worklogs: [Worklog]
}

struct WeekGrid {
    struct Entry: Identifiable {
        let id: String
        let seconds: Int
        let comment: String?
    }

    struct Row: Identifiable {
        let issueKey: String
        let summary: String
        var seconds: [Int]        // 7 entries, Monday-first
        var entries: [[Entry]]    // individual worklogs per day
        var id: String { issueKey }
        var total: Int { seconds.reduce(0, +) }
    }

    var days: [Date]
    var rows: [Row]

    static var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 2  // Monday
        return cal
    }

    static var empty: WeekGrid { forWeek(offset: 0) }

    static func forWeek(offset: Int) -> WeekGrid {
        let cal = calendar
        let base = cal.date(byAdding: .weekOfYear, value: offset, to: Date()) ?? Date()
        let start = cal.dateInterval(of: .weekOfYear, for: base)?.start ?? base
        let days = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
        return WeekGrid(days: days, rows: [])
    }

    var label: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        guard let first = days.first, let last = days.last else { return "" }
        return "\(fmt.string(from: first)) – \(fmt.string(from: last))"
    }

    var containsToday: Bool { dayIndex(of: Date()) != nil }

    func dayIndex(of date: Date) -> Int? {
        days.firstIndex { Self.calendar.isDate($0, inSameDayAs: date) }
    }

    func total(on date: Date) -> Int {
        guard let idx = dayIndex(of: date) else { return 0 }
        return totalPerDay(idx)
    }

    func totalPerDay(_ idx: Int) -> Int {
        rows.reduce(0) { $0 + $1.seconds[idx] }
    }

    var grandTotal: Int { rows.reduce(0) { $0 + $1.total } }
}

enum Format {
    static func hours(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0 { return "\(h)h" }
        return "\(m)m"
    }

    /// Accepts "1h 30m", "2h", "45m", "1.5" (bare numbers are hours).
    static func parseDuration(_ input: String) -> Int? {
        let s = input.lowercased().replacingOccurrences(of: ",", with: ".")
        let regex = try! NSRegularExpression(pattern: #"(\d+(?:\.\d+)?)\s*([hm]?)"#)
        let ns = s as NSString
        var total = 0.0
        var any = false
        for m in regex.matches(in: s, range: NSRange(location: 0, length: ns.length)) {
            guard let value = Double(ns.substring(with: m.range(at: 1))) else { continue }
            let unit = m.range(at: 2).length > 0 ? ns.substring(with: m.range(at: 2)) : "h"
            total += unit == "m" ? value * 60 : value * 3600
            any = true
        }
        guard any, total > 0 else { return nil }
        return Int(total)
    }
}
