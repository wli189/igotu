//
//  SetUpView.swift
//  igotu
//
//  Created by Brian Li on 8/19/26.
//

import SwiftUI

struct SetUpView: View {
    @EnvironmentObject private var configuration: AppConfigurationStore
    @Environment(\.dismiss) private var dismiss

    let isEditing: Bool
    private let themeColorService = ThemeColorService()
    private let scheduleValidator = DailyScheduleValidator()

    @State private var sleepStart = Self.time(hour: 23)
    @State private var sleepEnd = Self.time(hour: 7)
    @State private var workStart = Self.time(hour: 9)
    @State private var workEnd = Self.time(hour: 18)
    @State private var workdays = Weekday.defaultWorkdays
    @State private var errorMessage: String?
    @State private var hasLoadedSavedSchedule = false

    init(isEditing: Bool = false) {
        self.isEditing = isEditing
    }
    
    private func components(from date: Date) -> DateComponents {
        Calendar.current.dateComponents([.hour, .minute], from: date)
    }
    
    private static func time(hour: Int) -> Date {
        Calendar.current.date(from: DateComponents(hour: hour))!
    }

    private static func time(from components: DateComponents) -> Date {
        Calendar.current.date(
            from: DateComponents(
                year: 2000,
                month: 1,
                day: 1,
                hour: components.hour,
                minute: components.minute
            )
        ) ?? .now
    }

    private func loadSavedSchedule() {
        guard !hasLoadedSavedSchedule else { return }

        sleepStart = Self.time(from: configuration.schedule.sleepStart)
        sleepEnd = Self.time(from: configuration.schedule.sleepEnd)
        workStart = Self.time(from: configuration.schedule.workStart)
        workEnd = Self.time(from: configuration.schedule.workEnd)
        workdays = configuration.schedule.workdays
        hasLoadedSavedSchedule = true
    }
    
    private func save() -> Bool {
        let schedule = currentSchedule

        if let issue = scheduleValidator.issue(for: schedule) {
            errorMessage = issue.message
            return false
        }

        configuration.save(schedule: schedule)
        return true
    }

    private var currentSchedule: DailySchedule {
        DailySchedule(
            sleepStart: components(from: sleepStart),
            sleepEnd: components(from: sleepEnd),
            workStart: components(from: workStart),
            workEnd: components(from: workEnd),
            workdays: workdays
        )
    }

    private func saveEditedScheduleIfNeeded() {
        guard isEditing, hasLoadedSavedSchedule else { return }
        guard currentSchedule != configuration.schedule else { return }

        _ = save()
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
            .padding(.horizontal, 20)
            .padding(.top, isEditing ? 16 : 20)
            .padding(.bottom, isEditing ? 24 : 12)
        }
        .scrollIndicators(.hidden)
        .background {
            AmbientBackground(color: accent)
        }
        .tint(accent)
        .navigationTitle(isEditing ? "Schedule" : "")
        .navigationBarTitleDisplayMode(.large)
        .toolbar(isEditing ? .visible : .hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !isEditing {
                continueFooter(accent: accent)
            }
        }
        .onAppear {
            loadSavedSchedule()
        }
        .onChange(of: sleepStart) { _, _ in
            saveEditedScheduleIfNeeded()
        }
        .onChange(of: sleepEnd) { _, _ in
            saveEditedScheduleIfNeeded()
        }
        .onChange(of: workStart) { _, _ in
            saveEditedScheduleIfNeeded()
        }
        .onChange(of: workEnd) { _, _ in
            saveEditedScheduleIfNeeded()
        }
        .onChange(of: workdays) { _, _ in
            saveEditedScheduleIfNeeded()
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
                VStack(spacing: 0) {
                    scheduleGroup(
                        title: "Sleep",
                        systemImage: "moon.fill",
                        firstLabel: "Bedtime",
                        firstSelection: $sleepStart,
                        secondLabel: "Wake up",
                        secondSelection: $sleepEnd
                    )

                    Divider()
                        .padding(.leading, 44)

                    scheduleGroup(
                        title: "Work",
                        systemImage: "briefcase.fill",
                        firstLabel: "Work starts",
                        firstSelection: $workStart,
                        secondLabel: "Work ends",
                        secondSelection: $workEnd
                    )

                    Divider()
                        .padding(.leading, 44)

                    activeDaysContent(accent: accent)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
    }

    private func scheduleGroup(
        title: String,
        systemImage: String,
        firstLabel: String,
        firstSelection: Binding<Date>,
        secondLabel: String,
        secondSelection: Binding<Date>
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(.primary)
                .padding(.bottom, 2)

            DatePicker(
                firstLabel,
                selection: firstSelection,
                displayedComponents: .hourAndMinute
            )

            DatePicker(
                secondLabel,
                selection: secondSelection,
                displayedComponents: .hourAndMinute
            )
        }
        .padding(.vertical, 12)
    }

    private func activeDaysContent(accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Active days", systemImage: "calendar.badge.clock")
                .font(.headline)

            HStack(spacing: 4) {
                ForEach(Weekday.mondayFirst) { weekday in
                    dayButton(for: weekday, accent: accent)
                }
            }
        }
        .padding(.vertical, 12)
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
        HStack {
            Button {
                if save() {
                    dismiss()
                }
            } label: {
                Label("Continue", systemImage: "arrow.right")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .tint(accent)
            .controlSize(.large)
            .frame(maxWidth: 360)
            .shadow(color: .black.opacity(0.14), radius: 16, y: 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(alignment: .top) {
                    Divider()
                        .opacity(0.35)
                }
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private func dayButton(for weekday: Weekday, accent: Color) -> some View {
        let isActive = workdays.contains(weekday)

        return Button {
            if isActive {
                workdays.remove(weekday)
            } else {
                workdays.insert(weekday)
            }
        } label: {
            Text(String(weekday.shortTitle.prefix(1)))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isActive ? .white : accent)
                .frame(maxWidth: .infinity, minHeight: 36, maxHeight: 36)
                .background {
                    Circle()
                        .fill(isActive ? accent : accent.opacity(0.12))
                }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityLabel(weekday.title)
        .accessibilityValue(isActive ? "Active" : "Inactive")
        .accessibilityAddTraits(isActive ? .isSelected : [])
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
