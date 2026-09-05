import SwiftUI
import IgotuCore

struct MacTodayView: View {
    @EnvironmentObject private var configuration: MacConfigurationStore
    @EnvironmentObject private var history: MacReminderHistoryStore
    private let modeManager = DailyModeManager()
    private let metricsCalculator = DailyMetricsCalculator()
    private let progressCalculator = DailyModeProgressCalculator()

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            dashboard(at: timeline.date)
        }
    }

    @ViewBuilder
    private func dashboard(at now: Date) -> some View {
        let mode = modeManager.currentMode(for: configuration.schedule, at: now)
        let accent = color(for: mode)
        let metrics = metricsCalculator.calculate(events: history.completedEvents(on: now), goals: configuration.dailyGoals)
        let progress = progressCalculator.progress(for: mode, schedule: configuration.schedule, at: now)

        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                MacPageHeader(date: now, mode: mode, accent: accent)

                HStack(alignment: .top, spacing: 20) {
                    MacContextPanel(mode: mode, progress: progress, accent: accent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: 160, alignment: .leading)
                    MacNextStepPanel(mode: mode, accent: accent)
                        .frame(width: 230, height: 160, alignment: .leading)
                }

                MacSectionTitle(title: "TODAY'S PROGRESS")
                HStack(spacing: 14) {
                    MacMetricPanel(title: "Water", value: metrics.hydrationCount, goal: metrics.goals.hydrationCount, icon: "drop.fill", accent: accent)
                    MacMetricPanel(title: "Standing", value: metrics.standingHours, goal: metrics.goals.standingHours, icon: "figure.stand", accent: accent)
                }

                MacSectionTitle(title: "YOUR RHYTHM")
                MacRhythmPanel(schedule: configuration.schedule, accent: accent)
            }
            .frame(maxWidth: 1_000, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.horizontal, 34)
            .padding(.vertical, 30)
        }
        .background(MacAmbientBackground(accent: accent))
    }

    private func color(for mode: DailyMode) -> Color {
        MacTheme.color(for: mode)
    }

    private func modeSubtitle(_ mode: DailyMode) -> String {
        switch mode {
        case .sleeping: return "Resting"
        case .work: return "Focused time"
        case .idle: return "Open time"
        }
    }
}

private struct MacPageHeader: View {
    let date: Date
    let mode: DailyMode
    let accent: Color

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 7) {
                Text(date, format: .dateTime.weekday(.wide).month(.wide).day())
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Text("Good \(dayPeriod)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
            }
            Spacer()
            Label(mode.title, systemImage: mode.icon)
                .font(.callout.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(accent.opacity(0.14), in: Capsule())
                .foregroundStyle(accent)
        }
    }

    private var dayPeriod: String {
        switch Calendar.current.component(.hour, from: date) {
        case 5..<12: return "morning"
        case 12..<18: return "afternoon"
        default: return "evening"
        }
    }
}

private struct MacContextPanel: View {
    let mode: DailyMode
    let progress: Double
    let accent: Color

    var body: some View {
        MacSurface {
            HStack(spacing: 22) {
                MacFocusDial(progress: progress, icon: mode.icon, tint: accent)
                VStack(alignment: .leading, spacing: 8) {
                    Text("CURRENT CONTEXT")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(accent)
                        .lineLimit(1)
                    Text(nudge)
                        .font(.title3.weight(.semibold))
                        .lineLimit(2)
                    Text("Your reminders follow the rhythm of your schedule.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 12)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

    private var nudge: String {
        switch mode {
        case .sleeping: return "Rest easy"
        case .work: return "A small pause goes a long way"
        case .idle: return "Move at your own pace"
        }
    }
}

private struct MacNextStepPanel: View {
    let mode: DailyMode
    let accent: Color

    var body: some View {
        MacSurface {
            VStack(alignment: .leading, spacing: 14) {
                Label("NEXT STEP", systemImage: "sparkles")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accent)
                Text(nextStep)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 2)
                Text("Whenever it feels right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var nextStep: String {
        switch mode {
        case .sleeping: return "Let the day settle."
        case .work: return "Take a screen break."
        case .idle: return "Drink some water."
        }
    }
}

private struct MacMetricPanel: View {
    let title: String
    var value: Int = 0
    var goal: Int = 0
    var valueText: String?
    var subtitle: String?
    let icon: String
    let accent: Color

    init(title: String, value: Int = 0, goal: Int = 0, icon: String, accent: Color) {
        self.title = title
        self.value = value
        self.goal = goal
        self.icon = icon
        self.accent = accent
    }

    init(title: String, valueText: String, subtitle: String, icon: String, accent: Color) {
        self.title = title
        self.valueText = valueText
        self.subtitle = subtitle
        self.icon = icon
        self.accent = accent
    }

    var body: some View {
        MacSurface {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon)
                        .foregroundStyle(accent)
                        .frame(width: 28, height: 28)
                        .background(accent.opacity(0.12), in: Circle())
                    Spacer()
                    if valueText == nil {
                        Text("\(min(value, goal))/\(goal)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                Text(valueText ?? title)
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                Text(subtitle ?? title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if valueText == nil {
                    ProgressView(value: goal > 0 ? min(Double(value) / Double(goal), 1) : 0)
                        .tint(accent)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
            .padding(18)
        }
    }
}

struct MacSectionTitle: View {
    let title: String
    let detail: String?

    init(title: String, detail: String? = nil) {
        self.title = title
        self.detail = detail
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

private struct MacRhythmPanel: View {
    let schedule: DailySchedule
    let accent: Color

    var body: some View {
        MacSurface {
            HStack(spacing: 0) {
                rhythmColumn(title: "Sleep", icon: "moon.fill", periods: schedule.periods(for: .sleeping, on: .now))
                Divider().frame(height: 62)
                rhythmColumn(title: "Work", icon: "briefcase.fill", periods: schedule.periods(for: .work, on: .now))
                Divider().frame(height: 62)
                rhythmColumn(title: "Idle", icon: "house.fill", periods: [])
            }
            .padding(.vertical, 20)
        }
    }

    private func rhythmColumn(title: String, icon: String, periods: [DailySchedulePeriod]) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(title, systemImage: icon)
                .font(.callout.weight(.semibold))
                .foregroundStyle(accent)
            if periods.isEmpty {
                Text(title == "Idle" ? "All other time" : "Not scheduled today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(periods.map { timeText($0.start) + " – " + timeText($0.end) }.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 22)
    }

    private func timeText(_ components: DateComponents) -> String {
        let date = Calendar.current.date(from: DateComponents(year: 2000, month: 1, day: 1, hour: components.hour ?? 0, minute: components.minute ?? 0)) ?? .now
        return date.formatted(date: .omitted, time: .shortened)
    }
}

private struct MacFocusDial: View {
    let progress: Double
    let icon: String
    let tint: Color

    var body: some View {
        ZStack {
            Circle().stroke(tint.opacity(0.14), lineWidth: 8)
            Circle().trim(from: 0, to: max(0, min(progress, 1)))
                .stroke(tint, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Circle().fill(tint.opacity(0.11)).padding(14)
            Circle().fill(.thinMaterial).padding(17)
            Image(systemName: icon)
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(tint)
        }
        .frame(width: 100, height: 100)
    }
}

#Preview("Today") {
    MacTodayView()
        .environmentObject(MacConfigurationStore.preview())
        .environmentObject(MacReminderHistoryStore.preview())
        .frame(width: 1_120, height: 740)
}
