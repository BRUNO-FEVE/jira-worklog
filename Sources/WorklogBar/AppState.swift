import Foundation
import SwiftUI
#if canImport(WidgetKit)
import WidgetKit
#endif

@MainActor
final class AppState: ObservableObject {
    @Published var baseURLString: String = UserDefaults.standard.string(forKey: "jiraBaseURL") ?? "" {
        didSet { UserDefaults.standard.set(baseURLString, forKey: "jiraBaseURL") }
    }
    @Published var email: String = UserDefaults.standard.string(forKey: "jiraEmail") ?? "" {
        didSet { UserDefaults.standard.set(email, forKey: "jiraEmail") }
    }
    @Published var token: String = Keychain.load(account: "token") ?? ""
    @Published var launchAtLogin: Bool = LoginItem.isEnabled {
        didSet {
            guard launchAtLogin != oldValue else { return }
            do {
                if launchAtLogin {
                    try LoginItem.enable()
                } else {
                    try LoginItem.disable()
                }
            } catch {
                errorMessage = "Could not update login item: \(error.localizedDescription)"
            }
        }
    }

    @Published var dailyTargetHours: Double = UserDefaults.standard.object(forKey: "dailyTargetHours") as? Double ?? 8 {
        didSet { UserDefaults.standard.set(dailyTargetHours, forKey: "dailyTargetHours") }
    }
    @Published var reminderEnabled: Bool = UserDefaults.standard.bool(forKey: "reminderEnabled") {
        didSet { UserDefaults.standard.set(reminderEnabled, forKey: "reminderEnabled") }
    }
    @Published var reminderMinutes: Int = UserDefaults.standard.object(forKey: "reminderMinutes") as? Int ?? 17 * 60 {
        didSet { UserDefaults.standard.set(reminderMinutes, forKey: "reminderMinutes") }
    }

    @Published var assigned: [Issue] = []
    @Published var week: WeekGrid = .empty
    @Published var weekOffset = 0
    @Published var todayLogged = 0
    @Published var myself: Myself?
    @Published var isLoading = false
    @Published var weekLoading = false
    @Published var errorMessage: String?

    private var reminderTimer: Timer?

    init() {
        reminderTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.checkReminder() }
        }
    }

    var isConfigured: Bool { client != nil }

    var client: JiraClient? {
        let trimmed = baseURLString.trimmingCharacters(in: .whitespaces)
        let cleaned = trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed
        guard let url = URL(string: cleaned), url.host != nil, !token.isEmpty else { return nil }
        return JiraClient(config: JiraConfig(baseURL: url, email: email, token: token))
    }

    var menuTitle: String {
        todayLogged > 0 ? Format.hours(todayLogged) : "log"
    }

    func browseURL(for issueKey: String) -> URL? {
        client.map { $0.config.baseURL.appending(path: "/browse/\(issueKey)") }
    }

    func saveToken(_ newToken: String) {
        token = newToken
        Keychain.save(newToken, account: "token")
    }

    func refresh() async {
        guard let client else {
            errorMessage = JiraError.notConfigured.errorDescription
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            async let me = client.myself()
            async let issues = client.assignedIssues()
            myself = try await me
            assigned = try await issues
            try await loadWeek(client: client)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    var dailyTargetSeconds: Int { Int(dailyTargetHours * 3600) }

    var reminderDate: Date {
        Calendar.current.date(
            bySettingHour: reminderMinutes / 60,
            minute: reminderMinutes % 60,
            second: 0,
            of: Date()
        ) ?? Date()
    }

    func setReminderTime(_ date: Date) {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        reminderMinutes = (c.hour ?? 17) * 60 + (c.minute ?? 0)
    }

    private func checkReminder() async {
        guard reminderEnabled, isConfigured, dailyTargetSeconds > 0 else { return }
        let cal = Calendar.current
        let now = Date()
        let weekday = cal.component(.weekday, from: now)
        guard (2...6).contains(weekday) else { return }  // weekdays only
        let nowMinutes = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
        guard nowMinutes >= reminderMinutes, nowMinutes < reminderMinutes + 2 else { return }

        let dayFmt = DateFormatter()
        dayFmt.dateFormat = "yyyy-MM-dd"
        let todayKey = dayFmt.string(from: now)
        guard UserDefaults.standard.string(forKey: "reminderLastFired") != todayKey else { return }
        UserDefaults.standard.set(todayKey, forKey: "reminderLastFired")

        if weekOffset == 0 { await reloadWeek() }
        let missing = dailyTargetSeconds - todayLogged
        guard missing > 0 else { return }
        let body = todayLogged == 0
            ? "You haven't logged any time today (target \(Format.hours(dailyTargetSeconds)))."
            : "Logged \(Format.hours(todayLogged)) of \(Format.hours(dailyTargetSeconds)) today — \(Format.hours(missing)) missing."
        Notifier.show(title: "WorklogBar", body: body)
    }

    func updateWorklog(issueKey: String, worklogId: String, seconds: Int, comment: String?) async -> Bool {
        guard let client else { return false }
        errorMessage = nil
        do {
            try await client.updateWorklog(issueKey: issueKey, worklogId: worklogId, seconds: seconds, comment: comment)
            try await loadWeek(client: client)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func deleteWorklog(issueKey: String, worklogId: String) async -> Bool {
        guard let client else { return false }
        errorMessage = nil
        do {
            try await client.deleteWorklog(issueKey: issueKey, worklogId: worklogId)
            try await loadWeek(client: client)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func loadTransitions(issueKey: String) async -> [Transition] {
        guard let client else { return [] }
        do {
            return try await client.transitions(issueKey: issueKey)
        } catch {
            errorMessage = error.localizedDescription
            return []
        }
    }

    func applyTransition(issueKey: String, transitionId: String) async -> Bool {
        guard let client else { return false }
        errorMessage = nil
        do {
            try await client.applyTransition(issueKey: issueKey, transitionId: transitionId)
            assigned = try await client.assignedIssues()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func shiftWeek(_ delta: Int) async {
        weekOffset += delta
        await reloadWeek()
    }

    func goToCurrentWeek() async {
        weekOffset = 0
        await reloadWeek()
    }

    func reloadWeek() async {
        guard let client else { return }
        weekLoading = true
        errorMessage = nil
        do {
            try await loadWeek(client: client)
        } catch {
            errorMessage = error.localizedDescription
        }
        weekLoading = false
    }

    func logWork(issueKey: String, date: Date, seconds: Int, comment: String? = nil) async -> Bool {
        guard let client else { return false }
        errorMessage = nil
        do {
            let started = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: date) ?? date
            try await client.addWorklog(issueKey: issueKey, started: started, seconds: seconds, comment: comment)
            try await loadWeek(client: client)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func loadWeek(client: JiraClient) async throws {
        var grid = WeekGrid.forWeek(offset: weekOffset)

        let dayFmt = DateFormatter()
        dayFmt.locale = Locale(identifier: "en_US_POSIX")
        dayFmt.dateFormat = "yyyy-MM-dd"
        let weekStart = dayFmt.string(from: grid.days[0])
        let endExclusive = Calendar.current.date(byAdding: .day, value: 1, to: grid.days[6]).map(dayFmt.string(from:)) ?? weekStart

        let startedFmt = DateFormatter()
        startedFmt.locale = Locale(identifier: "en_US_POSIX")
        startedFmt.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"

        let issues = try await client.issuesWithMyWorklogs(from: weekStart, before: endExclusive)
        let logsByIssue = try await withThrowingTaskGroup(of: (String, [Worklog]).self) { group in
            for issue in issues {
                group.addTask { (issue.key, try await client.worklogs(issueKey: issue.key)) }
            }
            var result: [String: [Worklog]] = [:]
            for try await (key, logs) in group { result[key] = logs }
            return result
        }

        for issue in issues {
            var seconds = [Int](repeating: 0, count: 7)
            var entries: [[WeekGrid.Entry]] = Array(repeating: [], count: 7)
            for log in logsByIssue[issue.key] ?? [] where isMine(log.author) {
                guard let started = startedFmt.date(from: log.started),
                      let idx = grid.dayIndex(of: started) else { continue }
                seconds[idx] += log.timeSpentSeconds
                entries[idx].append(.init(id: log.id, seconds: log.timeSpentSeconds, comment: log.comment))
            }
            if seconds.contains(where: { $0 > 0 }) {
                grid.rows.append(.init(issueKey: issue.key, summary: issue.fields.summary, seconds: seconds, entries: entries))
            }
        }
        week = grid
        if grid.containsToday {
            todayLogged = grid.total(on: Date())
            publishSnapshot(grid)
        }
    }

    private func publishSnapshot(_ grid: WeekGrid) {
        let days = (0..<7).map { WidgetSnapshot.Day(date: grid.days[$0], seconds: grid.totalPerDay($0)) }
        SnapshotStore.save(WidgetSnapshot(
            todaySeconds: todayLogged,
            targetSeconds: dailyTargetSeconds,
            updatedAt: Date(),
            days: days
        ))
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    private func isMine(_ author: WorklogAuthor) -> Bool {
        guard let me = myself else { return true }
        if let mine = me.accountId, let theirs = author.accountId { return mine == theirs }
        if let mine = me.name, let theirs = author.name { return mine == theirs }
        return false
    }
}
