import SwiftUI
import IgotuCore

struct MacScheduleView: View {
    @EnvironmentObject private var configuration: MacConfigurationStore
    @Environment(\.macAccent) private var accent
    @State private var editorMode: DailyMode = .work
    @State private var editorPeriod: DailySchedulePeriod?
    @State private var isShowingEditor = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                MacDetailHeader(title: "Schedule", subtitle: "Shape the rhythm that guides your reminders.")

                scheduleSection(title: "Sleep", icon: "moon.fill", mode: .sleeping, periods: configuration.schedule.sleepPeriods)
                scheduleSection(title: "Work", icon: "briefcase.fill", mode: .work, periods: configuration.schedule.workPeriods)

                MacSectionTitle(title: "WIND DOWN", detail: "Before your next sleep period")
                MacSurface {
                    HStack {
                        Label("Remind me", systemImage: "moon.zzz.fill")
                            .font(.body.weight(.medium))
                        Spacer()
                        Picker("Wind down lead time", selection: Binding(
                            get: { Int(configuration.sleepReminderLeadTime / 60) },
                            set: { configuration.save(sleepReminderLeadTime: TimeInterval($0 * 60)) }
                        )) {
                            ForEach(Array(stride(from: 15, through: 120, by: 15)), id: \.self) { minutes in
                                Text("\(minutes) min").tag(minutes)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 120)
                    }
                    .padding(18)
                }

                MacSectionTitle(title: "DAILY GOALS", detail: "Lightweight and user-confirmed")
                MacSurface {
                    VStack(spacing: 0) {
                        goalRow(title: "Water", detail: "Confirmed drinks per day", value: Binding(
                            get: { configuration.dailyGoals.hydrationCount },
                            set: { updateGoals(hydrationCount: $0) }
                        ), range: DailyGoals.hydrationRange)
                        Divider()
                        goalRow(title: "Standing hours", detail: "Distinct hours per day", value: Binding(
                            get: { configuration.dailyGoals.standingHours },
                            set: { updateGoals(standingHours: $0) }
                        ), range: DailyGoals.standingHoursRange)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .frame(maxWidth: 820, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(34)
        }
        .background(MacAmbientBackground(accent: accent))
        .sheet(isPresented: $isShowingEditor) {
            MacPeriodEditor(mode: editorMode, period: editorPeriod) { period in
                save(period: period, in: editorMode)
            } onDelete: { period in
                delete(period: period, from: editorMode)
                isShowingEditor = false
            }
        }
    }

    private func scheduleSection(title: String, icon: String, mode: DailyMode, periods: [DailySchedulePeriod]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            MacSectionTitle(title: title.uppercased(), detail: periods.isEmpty ? "Not set" : "\(periods.count) period\(periods.count == 1 ? "" : "s")")
            MacSurface {
                VStack(spacing: 0) {
                    if periods.isEmpty {
                        HStack(spacing: 14) {
                            Image(systemName: icon)
                                .foregroundStyle(accent)
                            Text("No \(title.lowercased()) schedule yet")
                                .foregroundStyle(.secondary)
                            Spacer()
                            addButton(for: mode)
                        }
                        .padding(20)
                    } else {
                        ForEach(Array(periods.enumerated()), id: \.element.id) { index, period in
                            periodRow(period, mode: mode, icon: icon)
                            if index < periods.count - 1 { Divider().padding(.leading, 58) }
                        }
                        Divider().padding(.leading, 58)
                        HStack {
                            Spacer()
                            addButton(for: mode)
                        }
                        .padding(12)
                    }
                }
            }
        }
    }

    private func periodRow(_ period: DailySchedulePeriod, mode: DailyMode, icon: String) -> some View {
        Button {
            editorMode = mode
            editorPeriod = period
            isShowingEditor = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .foregroundStyle(accent)
                    .frame(width: 30, height: 30)
                    .background(accent.opacity(0.12), in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(timeText(period.start) + " – " + timeText(period.end))
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(daysText(period.days))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func addButton(for mode: DailyMode) -> some View {
        Button {
            editorMode = mode
            editorPeriod = nil
            isShowingEditor = true
        } label: {
            Label("Add period", systemImage: "plus")
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private func goalRow(title: String, detail: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.body.weight(.medium))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Stepper("\(value.wrappedValue)", value: value, in: range)
                .labelsHidden()
            Text("\(value.wrappedValue)/day")
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 66, alignment: .trailing)
        }
        .padding(.vertical, 14)
    }

    private func updateGoals(hydrationCount: Int? = nil, standingHours: Int? = nil) {
        var goals = configuration.dailyGoals
        if let hydrationCount { goals.hydrationCount = hydrationCount }
        if let standingHours { goals.standingHours = standingHours }
        configuration.save(dailyGoals: goals)
    }

    private func save(period: DailySchedulePeriod, in mode: DailyMode) -> String? {
        var schedule = configuration.schedule
        if mode == .sleeping {
            replace(period, in: &schedule.sleepPeriods)
        } else {
            replace(period, in: &schedule.workPeriods)
        }
        if let issue = DailyScheduleValidator().issue(for: schedule) {
            return issue.message
        }
        configuration.save(schedule: schedule)
        return nil
    }

    private func delete(period: DailySchedulePeriod, from mode: DailyMode) {
        var schedule = configuration.schedule
        if mode == .sleeping {
            schedule.sleepPeriods.removeAll { $0.id == period.id }
        } else {
            schedule.workPeriods.removeAll { $0.id == period.id }
        }
        configuration.save(schedule: schedule)
    }

    private func replace(_ period: DailySchedulePeriod, in periods: inout [DailySchedulePeriod]) {
        if let index = periods.firstIndex(where: { $0.id == period.id }) {
            periods[index] = period
        } else {
            periods.append(period)
        }
    }

    private func daysText(_ days: Set<Weekday>) -> String {
        if days.count == Weekday.allCases.count { return "Every day" }
        return Weekday.mondayFirst.filter { days.contains($0) }.map(\.shortTitle).joined(separator: ", ")
    }

    private func timeText(_ components: DateComponents) -> String {
        let date = Calendar.current.date(from: DateComponents(year: 2000, month: 1, day: 1, hour: components.hour ?? 0, minute: components.minute ?? 0)) ?? .now
        return date.formatted(date: .omitted, time: .shortened)
    }
}

struct MacDetailHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.system(size: 30, weight: .bold, design: .rounded))
            Text(subtitle).font(.callout).foregroundStyle(.secondary)
        }
    }
}

private struct MacPeriodEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.macAccent) private var accent
    let mode: DailyMode
    let period: DailySchedulePeriod?
    let onSave: (DailySchedulePeriod) -> String?
    let onDelete: (DailySchedulePeriod) -> Void
    @State private var start: Date
    @State private var end: Date
    @State private var days: Set<Weekday>
    @State private var errorMessage: String?

    init(mode: DailyMode, period: DailySchedulePeriod?, onSave: @escaping (DailySchedulePeriod) -> String?, onDelete: @escaping (DailySchedulePeriod) -> Void) {
        self.mode = mode
        self.period = period
        self.onSave = onSave
        self.onDelete = onDelete
        _start = State(initialValue: Self.date(from: period?.start ?? DateComponents(hour: mode == .sleeping ? 23 : 9)))
        _end = State(initialValue: Self.date(from: period?.end ?? DateComponents(hour: mode == .sleeping ? 7 : 18)))
        _days = State(initialValue: period?.days ?? (mode == .sleeping ? Set(Weekday.allCases) : Weekday.defaultWorkdays))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Label(mode.title, systemImage: mode.icon).font(.title2.weight(.semibold))
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") { save() }.keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }

            Form {
                DatePicker(mode == .sleeping ? "Bedtime" : "Starts", selection: $start, displayedComponents: .hourAndMinute)
                DatePicker(mode == .sleeping ? "Wake up" : "Ends", selection: $end, displayedComponents: .hourAndMinute)
                Section("Active days") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                        ForEach(Weekday.mondayFirst) { weekday in
                            Button(weekday.shortTitle) {
                                if days.contains(weekday) { days.remove(weekday) } else { days.insert(weekday) }
                            }
                            .buttonStyle(.bordered)
                            .tint(days.contains(weekday) ? accent : .secondary)
                        }
                    }
                }
            }
            .formStyle(.grouped)

            if let period {
                Button("Delete this period", role: .destructive) { onDelete(period) }
            }
        }
        .padding(28)
        .frame(width: 520)
        .alert("Cannot Save Schedule", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func save() {
        guard !days.isEmpty else {
            errorMessage = "Select at least one active day."
            return
        }
        guard start != end else {
            errorMessage = mode == .sleeping ? "Your bedtime and wake-up time cannot be the same." : "Your work start time and end time cannot be the same."
            return
        }
        let newPeriod = DailySchedulePeriod(id: period?.id ?? UUID(), start: components(from: start), end: components(from: end), days: days)
        if let message = onSave(newPeriod) {
            errorMessage = message
        } else {
            dismiss()
        }
    }

    private func components(from date: Date) -> DateComponents {
        Calendar.current.dateComponents([.hour, .minute], from: date)
    }

    private static func date(from components: DateComponents) -> Date {
        Calendar.current.date(from: DateComponents(year: 2000, month: 1, day: 1, hour: components.hour ?? 0, minute: components.minute ?? 0)) ?? .now
    }
}

#Preview("Schedule") {
    MacScheduleView()
        .environmentObject(MacConfigurationStore.preview())
        .frame(width: 1_120, height: 740)
}

#Preview("Period Editor") {
    MacPeriodEditor(mode: .work, period: nil, onSave: { _ in nil }, onDelete: { _ in })
}
