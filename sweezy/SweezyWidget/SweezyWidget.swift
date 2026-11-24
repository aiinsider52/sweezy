import SwiftUI
import WidgetKit

// MARK: - Shared snapshot

/// What the app last wrote for the widget. The app localises every string before writing, so the
/// widget never needs its own translations. Keep in sync with `WidgetSnapshot` in the app target.
struct WidgetSnapshot: Codable, Equatable {
    struct Deadline: Codable, Equatable {
        var title: String
        var date: Date
    }

    var nextStepLabel: String
    var nextStepTitle: String
    var progressDone: Int
    var progressTotal: Int
    var deadlineLabel: String
    var deadline: Deadline?
    var daysUnit: String
    var todayWord: String
    var emptyDeadline: String

    static let appGroup = "group.com.sweezy.mobile"
    static let key = "widget.snapshot"

    static func load() -> WidgetSnapshot {
        guard let data = UserDefaults(suiteName: appGroup)?.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else {
            return .placeholder
        }
        return snapshot
    }

    static let placeholder = WidgetSnapshot(
        nextStepLabel: "Наступний крок",
        nextStepTitle: "Реєстрація у громаді",
        progressDone: 2,
        progressTotal: 7,
        deadlineLabel: "Найближчий строк",
        deadline: Deadline(title: "Податкова декларація", date: Date().addingTimeInterval(86_400 * 12)),
        daysUnit: "дн.",
        todayWord: "Сьогодні",
        emptyDeadline: "Строків поки немає"
    )
}

// MARK: - Timeline

struct SweezyEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct SweezyProvider: TimelineProvider {
    func placeholder(in context: Context) -> SweezyEntry {
        SweezyEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (SweezyEntry) -> Void) {
        completion(SweezyEntry(date: Date(), snapshot: context.isPreview ? .placeholder : .load()))
    }

    /// One entry per midnight for the next week, so the countdown ticks without the app running.
    func getTimeline(in context: Context, completion: @escaping (Timeline<SweezyEntry>) -> Void) {
        let snapshot = WidgetSnapshot.load()
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        var entries = [SweezyEntry(date: Date(), snapshot: snapshot)]
        for day in 1...7 {
            if let date = calendar.date(byAdding: .day, value: day, to: start) {
                entries.append(SweezyEntry(date: date, snapshot: snapshot))
            }
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

// MARK: - Palette (mirrors the app's JourneyVisual tokens)

private enum Palette {
    static let lime = Color(red: 0.78, green: 1.0, blue: 0.02)
    static let ink = Color(red: 0.09, green: 0.10, blue: 0.09)
    static let paper = Color(red: 0.97, green: 0.95, blue: 0.92)
    static let muted = Color(red: 0.42, green: 0.44, blue: 0.40)
}

private func daysLeft(until date: Date, from now: Date) -> Int {
    let calendar = Calendar.current
    return calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day ?? 0
}

// MARK: - Views

struct SweezyWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SweezyEntry

    var body: some View {
        switch family {
        case .systemMedium: medium
        case .accessoryRectangular: rectangular
        case .accessoryCircular: circular
        default: small
        }
    }

    private var snapshot: WidgetSnapshot { entry.snapshot }

    private var countdownText: String? {
        guard let deadline = snapshot.deadline else { return nil }
        let days = daysLeft(until: deadline.date, from: entry.date)
        return days <= 0 ? snapshot.todayWord : "\(days) \(snapshot.daysUnit)"
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                progressRing(size: 26, lineWidth: 4)
                Text(snapshot.nextStepLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Palette.muted)
                    .lineLimit(1)
            }
            Text(snapshot.nextStepTitle)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Palette.ink)
                .lineLimit(3)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 0)
            if let countdown = countdownText, let deadline = snapshot.deadline {
                HStack(spacing: 6) {
                    Text(countdown)
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Palette.lime, in: Capsule())
                    Text(deadline.title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Palette.muted)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(Palette.paper, for: .widget)
    }

    private var medium: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    progressRing(size: 26, lineWidth: 4)
                    Text(snapshot.nextStepLabel)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.muted)
                }
                Text(snapshot.nextStepTitle)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 0)
                Link(destination: URL(string: "sweezy://deadlines")!) {
                    HStack(spacing: 8) {
                        if let countdown = countdownText {
                            Text(countdown)
                                .font(.system(size: 13, weight: .heavy))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(Palette.lime, in: Capsule())
                        }
                        VStack(alignment: .leading, spacing: 0) {
                            Text(snapshot.deadlineLabel)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Palette.muted)
                            Text(snapshot.deadline?.title ?? snapshot.emptyDeadline)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Palette.ink)
                                .lineLimit(1)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
            Image("WidgetMascot")
                .resizable()
                .scaledToFit()
                .frame(maxHeight: .infinity, alignment: .bottom)
                .accessibilityHidden(true)
        }
        .containerBackground(Palette.paper, for: .widget)
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(snapshot.nextStepLabel)
                .font(.system(size: 11, weight: .semibold))
                .widgetAccentable()
            Text(snapshot.nextStepTitle)
                .font(.system(size: 14, weight: .bold))
                .lineLimit(1)
            if let countdown = countdownText, let deadline = snapshot.deadline {
                Text("\(countdown) · \(deadline.title)")
                    .font(.system(size: 12))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(.clear, for: .widget)
    }

    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let deadline = snapshot.deadline {
                VStack(spacing: -2) {
                    Text("\(max(0, daysLeft(until: deadline.date, from: entry.date)))")
                        .font(.system(size: 20, weight: .heavy))
                    Text(snapshot.daysUnit)
                        .font(.system(size: 9, weight: .semibold))
                }
            } else {
                Text("\(snapshot.progressDone)/\(snapshot.progressTotal)")
                    .font(.system(size: 14, weight: .heavy))
            }
        }
        .containerBackground(.clear, for: .widget)
    }

    private func progressRing(size: CGFloat, lineWidth: CGFloat) -> some View {
        let fraction = snapshot.progressTotal == 0 ? 0 : min(1, Double(snapshot.progressDone) / Double(snapshot.progressTotal))
        return ZStack {
            Circle().stroke(Palette.ink.opacity(0.12), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.02, fraction))
                .stroke(Palette.lime, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
        .accessibilityLabel("\(snapshot.progressDone)/\(snapshot.progressTotal)")
    }
}

// MARK: - Widget

struct SweezyNextStepWidget: Widget {
    let kind = "SweezyNextStep"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SweezyProvider()) { entry in
            SweezyWidgetView(entry: entry)
        }
        .configurationDisplayName("Sweezy")
        .description("Next step and nearest deadline")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular])
    }
}

@main
struct SweezyWidgetBundle: WidgetBundle {
    var body: some Widget {
        SweezyNextStepWidget()
    }
}

#Preview(as: .systemMedium) {
    SweezyNextStepWidget()
} timeline: {
    SweezyEntry(date: .now, snapshot: .placeholder)
}
