import WidgetKit
import SwiftUI

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snap: WidgetSnapshot
}

struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: Date(), snap: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(SnapshotEntry(date: Date(), snap: SnapshotStore.load() ?? .placeholder))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let entry = SnapshotEntry(date: Date(), snap: SnapshotStore.load() ?? .placeholder)
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(15 * 60))))
    }
}

// MARK: - Small: today's progress ring

struct TodayRingView: View {
    let entry: SnapshotEntry

    private var progress: Double {
        guard entry.snap.targetSeconds > 0 else { return 0 }
        return min(1, Double(entry.snap.todaySeconds) / Double(entry.snap.targetSeconds))
    }

    var body: some View {
        VStack(spacing: 6) {
            Gauge(value: progress) {
                EmptyView()
            } currentValueLabel: {
                VStack(spacing: 0) {
                    Text(Format.hours(entry.snap.todaySeconds))
                        .font(.system(.callout, design: .rounded, weight: .bold))
                        .minimumScaleFactor(0.6)
                    Text("of \(Format.hours(entry.snap.targetSeconds))")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(progress >= 1 ? .green : .accentColor)
            .scaleEffect(1.15)

            Text("Logged today")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TodayWidget", provider: SnapshotProvider()) { entry in
            TodayRingView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Today's hours")
        .description("Time logged today against your daily target.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Medium: week bars

struct WeekBarsView: View {
    let entry: SnapshotEntry

    private static let dayFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }()

    var body: some View {
        let days = entry.snap.days
        let target = max(entry.snap.targetSeconds, 1)
        HStack(alignment: .bottom, spacing: 10) {
            if days.isEmpty {
                Text("Open WorklogBar to load your week")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    let ratio = min(1, Double(day.seconds) / Double(target))
                    let isToday = Calendar.current.isDateInToday(day.date)
                    VStack(spacing: 3) {
                        Text(day.seconds > 0 ? Format.hours(day.seconds) : " ")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(barColor(ratio: ratio, isToday: isToday))
                            .frame(height: max(4, 44 * ratio))
                            .frame(maxHeight: 44, alignment: .bottom)
                        Text(Self.dayFmt.string(from: day.date))
                            .font(.system(size: 9, weight: isToday ? .bold : .regular))
                            .foregroundStyle(isToday ? Color.accentColor : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func barColor(ratio: Double, isToday: Bool) -> Color {
        if ratio >= 1 { return .green }
        if isToday { return .accentColor }
        return .accentColor.opacity(0.5)
    }
}

struct WeekWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WeekWidget", provider: SnapshotProvider()) { entry in
            WeekBarsView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Week overview")
        .description("Hours logged per day this week.")
        .supportedFamilies([.systemMedium])
    }
}

@main
struct WorklogWidgets: WidgetBundle {
    var body: some Widget {
        TodayWidget()
        WeekWidget()
    }
}
