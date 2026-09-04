//
//  SetUpView.swift
//  igotu
//
//  Created by Brian Li on 8/19/26.
//

import SwiftUI

private struct SchedulePeriodEditorConfiguration: Identifiable {
    let id: UUID
    let mode: DailyMode
    let period: DailySchedulePeriod?

    init(mode: DailyMode, period: DailySchedulePeriod?) {
        id = period?.id ?? UUID()
        self.mode = mode
        self.period = period
    }
}

struct SetUpView: View {
    @EnvironmentObject private var configuration: AppConfigurationStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let isEditing: Bool
    private let themeColorService = ThemeColorService()
    private let scheduleValidator = DailyScheduleValidator()

    @State private var sleepPeriods: [DailySchedulePeriod] = []
    @State private var workPeriods: [DailySchedulePeriod] = []
    @State private var sleepReminderLeadMinutes = 30
    @State private var editorConfiguration: SchedulePeriodEditorConfiguration?
    @State private var errorMessage: String?
    @State private var hasLoadedSavedSchedule = false

    init(isEditing: Bool = false) {
        self.isEditing = isEditing
    }

    private func loadSavedSchedule() {
        guard !hasLoadedSavedSchedule else { return }

        sleepPeriods = configuration.schedule.sleepPeriods
        workPeriods = configuration.schedule.workPeriods
        sleepReminderLeadMinutes = Int(configuration.sleepReminderLeadTime / 60)
        hasLoadedSavedSchedule = true
    }
    
    private func save() -> Bool {
        let schedule = currentSchedule

        if let issue = scheduleValidator.issue(for: schedule) {
            errorMessage = issue.message
            return false
        }

        configuration.save(schedule: schedule)
        configuration.save(
            sleepReminderLeadTime: TimeInterval(sleepReminderLeadMinutes * 60)
        )
        return true
    }

    private var currentSchedule: DailySchedule {
        DailySchedule(
            sleepPeriods: sleepPeriods,
            workPeriods: workPeriods
        )
    }

    private func saveEditedScheduleIfNeeded() {
        guard isEditing, hasLoadedSavedSchedule else { return }
        guard currentSchedule != configuration.schedule else { return }

        _ = save()
    }

    private func saveEditedSleepReminderLeadTimeIfNeeded() {
        guard isEditing, hasLoadedSavedSchedule else { return }

        let leadTime = TimeInterval(sleepReminderLeadMinutes * 60)
        guard leadTime != configuration.sleepReminderLeadTime else { return }

        configuration.save(sleepReminderLeadTime: leadTime)
    }

    var body: some View {
        let accent = themeColorService.currentColor(for: configuration.schedule)

        setupContent(accent: accent)
    }

    private func setupContent(accent: Color) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if !isEditing {
                    onboardingHeader(accent: accent)
                }

                scheduleSection(accent: accent)
                reminderSection(accent: accent)
                dailyGoalsSection(accent: accent)
            }
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.top, isEditing ? 16 : 20)
            .padding(.bottom, isEditing ? 24 : 96)
        }
        .scrollIndicators(.hidden)
        .background {
            AmbientBackground(color: accent)
        }
        .tint(accent)
        .navigationTitle(isEditing ? "Schedule" : "")
        .navigationBarTitleDisplayMode(.large)
        .toolbar(isEditing ? .visible : .hidden, for: .navigationBar)
        .overlay(alignment: .bottom) {
            if !isEditing {
                continueFooter(accent: accent)
            }
        }
        .onAppear {
            loadSavedSchedule()
        }
        .onChange(of: sleepPeriods) { _, _ in
            saveEditedScheduleIfNeeded()
        }
        .onChange(of: workPeriods) { _, _ in
            saveEditedScheduleIfNeeded()
        }
        .onChange(of: sleepReminderLeadMinutes) { _, _ in
            saveEditedSleepReminderLeadTimeIfNeeded()
        }
        .alert(
            "Cannot Save Schedule",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "")
        }
        .sheet(item: $editorConfiguration) { editor in
            SchedulePeriodEditorView(
                mode: editor.mode,
                period: editor.period,
                isRegularWidth: horizontalSizeClass == .regular,
                onSave: { period in
                    save(period, for: editor.mode)
                },
                onDelete: editor.period.map { period in
                    { delete(period, from: editor.mode) }
                },
                sleepReminderLeadMinutes: editor.mode == .sleeping
                    ? $sleepReminderLeadMinutes
                    : nil
            )
        }
    }

    private func onboardingHeader(accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 48, height: 48)
                .background(accent.opacity(0.12), in: Circle())

            Text("Build your daily rhythm")
                .font(.system(size: 32, weight: .bold, design: .rounded))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func scheduleSection(accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeading("Schedule", systemImage: "calendar", accent: accent)

            groupedSurface {
                VStack(alignment: .leading, spacing: 0) {
                    schedulePeriodsContent(
                        title: "Sleep",
                        systemImage: "moon.fill",
                        mode: .sleeping,
                        periods: sleepPeriods,
                        accent: accent
                    )

                    Divider()
                        .padding(.leading, 44)

                    schedulePeriodsContent(
                        title: "Work",
                        systemImage: "briefcase.fill",
                        mode: .work,
                        periods: workPeriods,
                        accent: accent
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
    }

    private func schedulePeriodsContent(
        title: String,
        systemImage: String,
        mode: DailyMode,
        periods: [DailySchedulePeriod],
        accent: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(.primary)
                .padding(.bottom, 2)

            if periods.isEmpty {
                Text("No time periods")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 10)
            } else {
                ForEach(Array(periods.sorted(by: periodSort).enumerated()), id: \.element.id) { index, period in
                    if index > 0 {
                        Divider()
                            .padding(.leading, 48)
                    }

                    periodRow(
                        period,
                        mode: mode,
                        accent: accent
                    )
                }
            }

            if mode != .sleeping || periods.isEmpty {
                Button {
                    editorConfiguration = SchedulePeriodEditorConfiguration(
                        mode: mode,
                        period: nil
                    )
                } label: {
                    Label("Add time period", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderless)
                .padding(.top, 10)
            }
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func periodRow(
        _ period: DailySchedulePeriod,
        mode: DailyMode,
        accent: Color
    ) -> some View {
        Button {
            editorConfiguration = SchedulePeriodEditorConfiguration(
                mode: mode,
                period: period
            )
        } label: {
            HStack(spacing: 12) {
                Image(systemName: mode == .sleeping ? "moon.fill" : "clock.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(accent)
                    .frame(width: 36, height: 36)
                    .background(accent.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(timeText(period.start) + " – " + timeText(period.end))
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                        .monospacedDigit()

                    Text(daysText(period.days))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Edit " + mode.title + " time period")
    }

    private func save(_ period: DailySchedulePeriod, for mode: DailyMode) -> String? {
        var proposedSleepPeriods = sleepPeriods
        var proposedWorkPeriods = workPeriods

        if mode == .sleeping {
            if let index = proposedSleepPeriods.firstIndex(where: { $0.id == period.id }) {
                proposedSleepPeriods[index] = period
            } else {
                proposedSleepPeriods.append(period)
            }
        } else {
            if let index = proposedWorkPeriods.firstIndex(where: { $0.id == period.id }) {
                proposedWorkPeriods[index] = period
            } else {
                proposedWorkPeriods.append(period)
            }
        }

        let proposedSchedule = DailySchedule(
            sleepPeriods: proposedSleepPeriods,
            workPeriods: proposedWorkPeriods
        )
        if let issue = scheduleValidator.issue(for: proposedSchedule) {
            return issue.message
        }

        sleepPeriods = proposedSleepPeriods
        workPeriods = proposedWorkPeriods
        return nil
    }

    private func delete(_ period: DailySchedulePeriod, from mode: DailyMode) {
        if mode == .sleeping {
            sleepPeriods.removeAll { $0.id == period.id }
        } else {
            workPeriods.removeAll { $0.id == period.id }
        }
    }

    private func periodSort(
        _ first: DailySchedulePeriod,
        _ second: DailySchedulePeriod
    ) -> Bool {
        let firstStart = first.start.hour ?? 0
        let secondStart = second.start.hour ?? 0
        if firstStart != secondStart {
            return firstStart < secondStart
        }

        let firstMinute = first.start.minute ?? 0
        let secondMinute = second.start.minute ?? 0
        if firstMinute != secondMinute {
            return firstMinute < secondMinute
        }

        return first.id.uuidString < second.id.uuidString
    }

    private func timeText(_ components: DateComponents) -> String {
        let date = Calendar.current.date(
            from: DateComponents(
                year: 2000,
                month: 1,
                day: 1,
                hour: components.hour,
                minute: components.minute
            )
        ) ?? .now

        return date.formatted(date: .omitted, time: .shortened)
    }

    private func daysText(_ days: Set<Weekday>) -> String {
        if days.count == Weekday.allCases.count {
            return "Every day"
        }

        if days == Weekday.defaultWorkdays {
            return "Weekday"
        }

        if days == [.saturday, .sunday] {
            return "Weekend"
        }

        return Weekday.mondayFirst
            .filter { days.contains($0) }
            .map { $0.shortTitle }
            .joined(separator: "  ")
    }

    private func reminderSection(accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeading("Reminder preferences", systemImage: "bell.fill", accent: accent)

            groupedSurface {
                VStack(spacing: 0) {
                    settingsLink(
                        title: "Work reminders",
                        systemImage: "briefcase.fill",
                        accent: accent
                    ) {
                        ReminderSettingsView(context: .work)
                    }

                    Divider()
                        .padding(.leading, 62)

                    settingsLink(
                        title: "Idle reminders",
                        systemImage: "figure.walk",
                        accent: accent
                    ) {
                        ReminderSettingsView(context: .idle)
                    }

                    Divider()
                        .padding(.leading, 62)

                    settingsLink(
                        title: "Reminder tests",
                        systemImage: "bell.badge",
                        accent: accent
                    ) {
                        NotificationTestView()
                    }
                }
            }
        }
    }

    private func dailyGoalsSection(accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeading("Daily goals", systemImage: "target", accent: accent)

            groupedSurface {
                settingsLink(
                    title: "Water and standing",
                    systemImage: "target",
                    accent: accent
                ) {
                    DailyGoalsSettingsView()
                }
            }
        }
    }

    private func sectionHeading(
        _ title: String,
        systemImage: String,
        accent: Color
    ) -> some View {
        Label(title.uppercased(), systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(accent)
    }

    private func groupedSurface<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .ambientSurface(cornerRadius: 24)
    }

    private func settingsLink<Destination: View>(
        title: String,
        systemImage: String,
        accent: Color,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(accent)
                    .frame(width: 38, height: 38)
                    .background(
                        accent.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                    )

                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func continueFooter(accent: Color) -> some View {
        Button {
            if save() {
                dismiss()
            }
        } label: {
            Label("Continue", systemImage: "arrow.right")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.capsule)
        .tint(accent)
        .controlSize(.large)
        .frame(maxWidth: 360)
        .shadow(color: .black.opacity(0.14), radius: 16, y: 8)
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

}

#Preview {
    NavigationStack {
        SetUpView()
            .environmentObject(AppConfigurationStore())
    }
}

#Preview("Editing") {
    NavigationStack {
        SetUpView(isEditing: true)
            .environmentObject(AppConfigurationStore())
    }
}
