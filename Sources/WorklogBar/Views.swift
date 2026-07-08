import SwiftUI

struct RootView: View {
    @EnvironmentObject var state: AppState
    @State private var tab = 0

    var body: some View {
        VStack(spacing: 0) {
            HeaderView(tab: $tab)
            Divider()

            Group {
                switch tab {
                case 0: TicketsView()
                case 1: WeekView()
                default: ScrollView { SettingsView() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            if let err = state.errorMessage {
                Divider()
                Label(err, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
            }
        }
        .frame(width: 480, height: 440)
        .task {
            if state.isConfigured {
                await state.refresh()
            } else {
                tab = 2
            }
        }
    }
}

struct HeaderView: View {
    @EnvironmentObject var state: AppState
    @Binding var tab: Int

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                JiraGlyph(size: 18)
                Text("WorklogBar")
                    .font(.system(.body, design: .rounded, weight: .semibold))
                Spacer()
                if let me = state.myself {
                    Text(me.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if state.isLoading {
                    ProgressView().controlSize(.small)
                } else {
                    Button {
                        Task { await state.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .help("Refresh")
                }
                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Image(systemName: "power")
                }
                .buttonStyle(.borderless)
                .help("Quit WorklogBar")
            }

            Picker("", selection: $tab) {
                Label("Tickets", systemImage: "list.bullet").tag(0)
                Label("Week", systemImage: "calendar").tag(1)
                Label("Settings", systemImage: "gearshape").tag(2)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }
}

// MARK: - Tickets

struct TicketsView: View {
    @EnvironmentObject var state: AppState
    @State private var selected: Issue?

    var body: some View {
        VStack(spacing: 0) {
            if state.assigned.isEmpty {
                EmptyStateView(
                    icon: "tray",
                    text: state.isConfigured ? "No open tickets assigned to you." : "Configure Jira in Settings first."
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(state.assigned) { issue in
                            TicketRow(issue: issue, isSelected: selected == issue) {
                                withAnimation(.easeOut(duration: 0.15)) {
                                    selected = selected == issue ? nil : issue
                                }
                            }
                        }
                    }
                    .padding(6)
                }
            }
            if let issue = selected {
                Divider()
                LogTimeView(issue: issue) {
                    withAnimation(.easeOut(duration: 0.15)) { selected = nil }
                }
            }
        }
    }
}

struct TicketRow: View {
    @EnvironmentObject var state: AppState
    let issue: Issue
    let isSelected: Bool
    let onTap: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: typeIcon)
                    .foregroundStyle(typeColor)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 2) {
                    Text(issue.fields.summary)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(issue.key)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                        if issue.fields.status != nil {
                            StatusPill(issue: issue)
                        }
                    }
                }
                Spacer()

                if hovering {
                    Button {
                        if let url = state.browseURL(for: issue.key) {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        Image(systemName: "arrow.up.forward.square")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .help("Open in Jira")
                }
                Image(systemName: isSelected ? "chevron.down.circle.fill" : "plus.circle")
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : hovering ? Color.primary.opacity(0.06) : .clear)
        )
        .onHover { hovering = $0 }
    }

    private var typeIcon: String {
        let name = issue.fields.issuetype?.name.lowercased() ?? ""
        if name.contains("bug") { return "ladybug.fill" }
        if name.contains("stor") || name.contains("hist") { return "bookmark.fill" }
        if name.contains("epic") { return "bolt.fill" }
        return "checkmark.square.fill"
    }

    private var typeColor: Color {
        let name = issue.fields.issuetype?.name.lowercased() ?? ""
        if name.contains("bug") { return .red }
        if name.contains("stor") || name.contains("hist") { return .green }
        if name.contains("epic") { return .purple }
        return .blue
    }

}

struct StatusPill: View {
    @EnvironmentObject var state: AppState
    let issue: Issue

    @State private var showPicker = false
    @State private var transitions: [Transition] = []
    @State private var loading = false
    @State private var busy = false

    var body: some View {
        Button {
            showPicker = true
        } label: {
            HStack(spacing: 3) {
                Text(issue.fields.status?.name ?? "")
                Image(systemName: "chevron.down")
                    .font(.system(size: 7, weight: .bold))
            }
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(statusColor.opacity(0.15), in: Capsule())
            .foregroundStyle(statusColor)
        }
        .buttonStyle(.plain)
        .help("Change status")
        .popover(isPresented: $showPicker, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Move to")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 2)
                if loading {
                    ProgressView()
                        .controlSize(.small)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                } else if transitions.isEmpty {
                    Text("No transitions available")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(transitions) { transition in
                        TransitionButton(
                            transition: transition,
                            isCurrent: transition.to?.name == issue.fields.status?.name,
                            busy: busy
                        ) {
                            busy = true
                            Task {
                                if await state.applyTransition(issueKey: issue.key, transitionId: transition.id) {
                                    showPicker = false
                                }
                                busy = false
                            }
                        }
                    }
                }
            }
            .padding(10)
            .frame(width: 190)
            .task {
                loading = true
                transitions = await state.loadTransitions(issueKey: issue.key)
                loading = false
            }
            .environmentObject(state)
        }
    }

    private var statusColor: Color {
        switch issue.fields.status?.statusCategory?.key {
        case "done": return .green
        case "indeterminate": return .blue
        default: return .gray
        }
    }
}

struct TransitionButton: View {
    let transition: Transition
    let isCurrent: Bool
    let busy: Bool
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack {
                Text(transition.to?.name ?? transition.name)
                    .font(.callout)
                Spacer()
                if isCurrent {
                    Image(systemName: "checkmark")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .background(hovering && !isCurrent ? Color.primary.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .disabled(busy || isCurrent)
        .onHover { hovering = $0 }
    }
}

struct LogTimeView: View {
    @EnvironmentObject var state: AppState
    let issue: Issue
    var onDone: () -> Void

    @State private var durationText = ""
    @State private var comment = ""
    @State private var date = Date()
    @State private var busy = false

    private let presets = ["30m", "1h", "2h", "4h", "8h"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Log time on \(issue.key)")
                .font(.subheadline.weight(.semibold))

            TextField("What did you work on? (optional)", text: $comment)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 4) {
                ForEach(presets, id: \.self) { preset in
                    Button(preset) { durationText = preset }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }

            HStack(spacing: 8) {
                TextField("1h 30m", text: $durationText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
                DatePicker("", selection: $date, displayedComponents: .date)
                    .labelsHidden()
                Spacer()
                Button("Cancel", action: onDone)
                Button("Log time") {
                    guard let secs = Format.parseDuration(durationText) else { return }
                    busy = true
                    Task {
                        if await state.logWork(issueKey: issue.key, date: date, seconds: secs, comment: comment) {
                            onDone()
                        }
                        busy = false
                    }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(busy || Format.parseDuration(durationText) == nil)
            }
        }
        .padding(12)
        .background(.background.secondary)
    }
}

// MARK: - Week

struct WeekView: View {
    @EnvironmentObject var state: AppState

    private static let dayFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE\nd"
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            weekPicker
            Divider()
            content
        }
    }

    private var weekPicker: some View {
        HStack(spacing: 8) {
            Button {
                Task { await state.shiftWeek(-1) }
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.borderless)

            Text(state.weekOffset == 0 ? "This week" : state.week.label)
                .font(.subheadline.weight(.semibold))
                .frame(minWidth: 110)

            Button {
                Task { await state.shiftWeek(1) }
            } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.borderless)

            if state.weekOffset != 0 {
                Button("Today") {
                    Task { await state.goToCurrentWeek() }
                }
                .controlSize(.small)
            }

            Spacer()

            if state.weekLoading {
                ProgressView().controlSize(.small)
            }
            Text(Format.hours(state.week.grandTotal))
                .font(.subheadline.monospacedDigit().weight(.bold))
                .foregroundStyle(Color.accentColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var content: some View {
        let grid = state.week
        if grid.rows.isEmpty {
            EmptyStateView(icon: "calendar.badge.clock", text: "No time logged this week.")
        } else {
            ScrollView {
                Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 0) {
                    GridRow {
                        Text("Ticket")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(Array(grid.days.enumerated()), id: \.offset) { i, day in
                            Text(Self.dayFmt.string(from: day))
                                .font(.caption2.weight(isToday(day) ? .bold : .semibold))
                                .foregroundStyle(isToday(day) ? Color.accentColor : .secondary)
                                .multilineTextAlignment(.trailing)
                                .gridColumnAlignment(.trailing)
                        }
                        Text("Σ")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .gridColumnAlignment(.trailing)
                    }
                    .padding(.vertical, 6)

                    Divider()

                    ForEach(grid.rows) { row in
                        GridRow {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(row.issueKey)
                                    .font(.caption.monospaced().weight(.semibold))
                                Text(row.summary)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: 130, alignment: .leading)
                            .help(row.summary)

                            ForEach(0..<7, id: \.self) { i in
                                WeekCellButton(
                                    issueKey: row.issueKey,
                                    summary: row.summary,
                                    date: grid.days[i],
                                    seconds: row.seconds[i],
                                    highlight: isToday(grid.days[i])
                                )
                            }
                            Text(Format.hours(row.total))
                                .font(.caption.monospacedDigit().weight(.semibold))
                        }
                        .padding(.vertical, 5)
                        Divider().opacity(0.4)
                    }

                    GridRow {
                        Text("Total")
                            .font(.caption.weight(.bold))
                        ForEach(0..<7, id: \.self) { i in
                            dayTotalCell(i, grid: grid)
                        }
                        Text(Format.hours(grid.grandTotal))
                            .font(.caption.monospacedDigit().weight(.bold))
                            .foregroundStyle(Color.accentColor)
                    }
                    .padding(.vertical, 6)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            }
        }
    }

    private func dayTotalCell(_ i: Int, grid: WeekGrid) -> some View {
        let total = grid.totalPerDay(i)
        let day = grid.days[i]
        let target = state.dailyTargetSeconds
        let cal = Calendar.current
        let isWorkday = (2...6).contains(cal.component(.weekday, from: day))
        let isPastOrToday = cal.startOfDay(for: day) <= cal.startOfDay(for: Date())
        let flagged = target > 0 && isWorkday && isPastOrToday

        let style: AnyShapeStyle
        var hint = ""
        if flagged {
            if total >= target {
                style = AnyShapeStyle(Color.green)
                hint = "Daily target of \(Format.hours(target)) met"
            } else if total > 0 {
                style = AnyShapeStyle(Color.orange)
                hint = "\(Format.hours(target - total)) below the \(Format.hours(target)) target"
            } else {
                style = AnyShapeStyle(Color.red)
                hint = "Nothing logged — target is \(Format.hours(target))"
            }
        } else {
            style = total > 0 ? AnyShapeStyle(Color.primary) : AnyShapeStyle(.quaternary)
        }
        return Text(total > 0 ? Format.hours(total) : (flagged ? "0" : "·"))
            .font(.caption.monospacedDigit().weight(.bold))
            .foregroundStyle(style)
            .help(hint)
    }

    private func isToday(_ day: Date) -> Bool {
        Calendar.current.isDateInToday(day)
    }
}

struct WeekCellButton: View {
    @EnvironmentObject var state: AppState
    let issueKey: String
    let summary: String
    let date: Date
    let seconds: Int
    let highlight: Bool

    @State private var hovering = false
    @State private var showForm = false

    var body: some View {
        Button {
            showForm = true
        } label: {
            Text(seconds > 0 ? Format.hours(seconds) : (hovering ? "+" : "·"))
                .font(.caption.monospacedDigit())
                .foregroundStyle(cellStyle)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(hovering ? Color.primary.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 4))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help("Log time on \(issueKey)")
        .popover(isPresented: $showForm, arrowEdge: .bottom) {
            CellLogForm(issueKey: issueKey, summary: summary, date: date) { showForm = false }
                .environmentObject(state)
        }
    }

    private var cellStyle: AnyShapeStyle {
        if hovering && seconds == 0 { return AnyShapeStyle(.secondary) }
        return seconds > 0
            ? AnyShapeStyle(highlight ? Color.accentColor : Color.primary)
            : AnyShapeStyle(.quaternary)
    }
}

struct CellLogForm: View {
    @EnvironmentObject var state: AppState
    let issueKey: String
    let summary: String
    let date: Date
    var onDone: () -> Void

    @State private var durationText = ""
    @State private var comment = ""
    @State private var busy = false
    @State private var editingId: String?

    private static let titleFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f
    }()

    private var entries: [WeekGrid.Entry] {
        guard let idx = state.week.dayIndex(of: date),
              let row = state.week.rows.first(where: { $0.issueKey == issueKey }) else { return [] }
        return row.entries[idx]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(issueKey) · \(Self.titleFmt.string(from: date))")
                    .font(.subheadline.weight(.semibold))
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if !entries.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(entries) { entry in
                        HStack(spacing: 6) {
                            Text(Format.hours(entry.seconds))
                                .font(.caption.monospacedDigit().weight(.semibold))
                                .frame(width: 48, alignment: .leading)
                            Text(entry.comment ?? "—")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Spacer()
                            Button {
                                editingId = entry.id
                                durationText = Format.hours(entry.seconds)
                                comment = entry.comment ?? ""
                            } label: {
                                Image(systemName: "pencil")
                            }
                            .buttonStyle(.borderless)
                            .help("Edit entry")
                            Button {
                                busy = true
                                Task {
                                    _ = await state.deleteWorklog(issueKey: issueKey, worklogId: entry.id)
                                    if editingId == entry.id { editingId = nil }
                                    busy = false
                                }
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.red)
                            .help("Delete entry")
                        }
                        .padding(.vertical, 2)
                        .padding(.horizontal, 6)
                        .background(
                            editingId == entry.id ? Color.accentColor.opacity(0.1) : .clear,
                            in: RoundedRectangle(cornerRadius: 4)
                        )
                    }
                }
                Divider()
            }

            TextField("What did you work on? (optional)", text: $comment)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 4) {
                ForEach(["30m", "1h", "2h", "4h", "8h"], id: \.self) { preset in
                    Button(preset) { durationText = preset }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }

            HStack(spacing: 8) {
                TextField("1h 30m", text: $durationText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
                Spacer()
                if busy { ProgressView().controlSize(.small) }
                if editingId != nil {
                    Button("Cancel") {
                        editingId = nil
                        durationText = ""
                        comment = ""
                    }
                }
                Button(editingId == nil ? "Log time" : "Update") {
                    guard let secs = Format.parseDuration(durationText) else { return }
                    busy = true
                    Task {
                        let ok: Bool
                        if let id = editingId {
                            ok = await state.updateWorklog(issueKey: issueKey, worklogId: id, seconds: secs, comment: comment)
                        } else {
                            ok = await state.logWork(issueKey: issueKey, date: date, seconds: secs, comment: comment)
                        }
                        if ok { onDone() }
                        busy = false
                    }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(busy || Format.parseDuration(durationText) == nil)
            }
        }
        .padding(12)
        .frame(width: 300)
    }
}

// MARK: - Settings

struct SettingsView: View {
    @EnvironmentObject var state: AppState
    @State private var tokenField = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Jira connection")
                .font(.subheadline.weight(.semibold))

            VStack(alignment: .leading, spacing: 8) {
                LabeledField(label: "Site URL") {
                    TextField("https://yourcompany.atlassian.net", text: $state.baseURLString)
                }
                LabeledField(label: "Email") {
                    TextField("Only needed for Jira Cloud", text: $state.email)
                }
                LabeledField(label: "Token") {
                    SecureField("API token (Cloud) or PAT (Data Center)", text: $tokenField)
                }
            }

            Text("Cloud (*.atlassian.net) uses email + API token from id.atlassian.com. Self-hosted Data Center uses only a Personal Access Token. Stored in your Keychain.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                if let me = state.myself {
                    Label("Connected as \(me.displayName)", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
                Spacer()
                Button("Save & Connect") {
                    if !tokenField.isEmpty { state.saveToken(tokenField) }
                    Task { await state.refresh() }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }

            Divider()

            Text("General")
                .font(.subheadline.weight(.semibold))
            Toggle("Launch WorklogBar at login", isOn: $state.launchAtLogin)
                .toggleStyle(.switch)
                .controlSize(.small)

            HStack(spacing: 8) {
                Text("Daily target")
                    .font(.caption)
                TextField("8", value: $state.dailyTargetHours, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 44)
                Text("hours — under-logged weekdays are flagged in the Week grid")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Toggle("Remind me to log time", isOn: $state.reminderEnabled)
                .toggleStyle(.switch)
                .controlSize(.small)
            if state.reminderEnabled {
                HStack(spacing: 8) {
                    Text("Remind at")
                        .font(.caption)
                    DatePicker(
                        "",
                        selection: Binding(
                            get: { state.reminderDate },
                            set: { state.setReminderTime($0) }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                    Text("weekdays, only if you're below the daily target")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            Text("About")
                .font(.subheadline.weight(.semibold))
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    JiraGlyph(size: 14)
                    Text("WorklogBar 0.1.0")
                        .font(.caption.weight(.semibold))
                }
                Text("Made by Bruno Fevereiro")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("MIT License — free to use, modify and share.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    Link("GitHub",
                         destination: URL(string: "https://github.com/BRUNO-FEVE/jira-worklog")!)
                    Link("LinkedIn",
                         destination: URL(string: "https://www.linkedin.com/in/bruno-fevereiro/")!)
                }
                .font(.caption)
            }
        }
        .padding(12)
        .onAppear { tokenField = state.token }
    }
}

struct LabeledField<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .trailing)
            content
                .textFieldStyle(.roundedBorder)
        }
    }
}

// MARK: - Shared

struct EmptyStateView: View {
    let icon: String
    let text: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 40)
    }
}
