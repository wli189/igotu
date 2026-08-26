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
    
    private func minutes(from components: DateComponents) -> Int {
        (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    private func ranges(start: Int, end: Int) -> [Range<Int>] {
        if start < end {
            return [start..<end]
        }

        return [start..<1440, 0..<end]
    }
    
    private func overlaps(
        sleepStart: Int,
        sleepEnd: Int,
        workStart: Int,
        workEnd: Int
    ) -> Bool {
        for rangeSleep in ranges(start: sleepStart, end: sleepEnd) {
            for rangeWork in ranges(start: workStart, end: workEnd) {
                if rangeSleep.lowerBound < rangeWork.upperBound && rangeSleep.upperBound > rangeWork.lowerBound {
                    return true
                }
            }
        }
        return false
    }
    
    private func validationMessage(for schedule: DailySchedule) -> String? {
        let sleepStart = minutes(from: schedule.sleepStart)
        let sleepEnd = minutes(from: schedule.sleepEnd)
        let workStart = minutes(from: schedule.workStart)
        let workEnd = minutes(from: schedule.workEnd)
        
        if sleepStart == sleepEnd {
            return "Your bedtime and wake-up time cannot be the same."
        }
        
        if workStart == workEnd {
            return "Your work start time and end time cannot be the same."
        }
        
        if overlaps(sleepStart: sleepStart, sleepEnd: sleepEnd, workStart: workStart, workEnd: workEnd) {
            return "Your work hours and bedtime overlap."
        }
        
        return nil
    }
    
    private func save() -> Bool {
        let schedule = DailySchedule(
            sleepStart: components(from: sleepStart),
            sleepEnd: components(from: sleepEnd),
            workStart: components(from: workStart),
            workEnd: components(from: workEnd),
            workdays: workdays
        )
        
        if let message = validationMessage(for: schedule) {
            errorMessage = message
            return false
        }

        configuration.save(schedule: schedule)
        return true
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    if !isEditing {
                        onboardingHeader
                    }

                    scheduleSection
                    reminderSection
                    dailyGoalsSection
                }
                .padding(.horizontal, 20)
                .padding(.top, isEditing ? 16 : 20)
                .padding(.bottom, isEditing ? 24 : 12)
            }
            .scrollIndicators(.hidden)
            .background {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
            }
            .navigationTitle(isEditing ? "Schedule" : "Stay well")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if isEditing {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                        }
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            if save() {
                                dismiss()
                            }
                        } label: {
                            Image(systemName: "checkmark")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !isEditing {
                    continueFooter
                }
            }
            .onAppear {
                loadSavedSchedule()
            }
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

    private var onboardingHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Build your daily rhythm")
                .font(.title2.bold())

            Text("Set a schedule so reminders arrive at the right time.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeading("Schedule", systemImage: "calendar")

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

                    activeDaysContent
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

    private var activeDaysContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Active days", systemImage: "calendar.badge.clock")
                .font(.headline)

            Text("Choose when work reminders are active.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                ForEach(Weekday.mondayFirst) { weekday in
                    dayButton(for: weekday)
                }
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 12)
    }

    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeading("Reminder preferences", systemImage: "bell.fill")

            groupedSurface {
                VStack(spacing: 0) {
                    settingsLink(
                        title: "Work reminders",
                        subtitle: "During your work hours",
                        systemImage: "briefcase.fill"
                    ) {
                        ReminderSettingsView(context: .work)
                    }

                    Divider()
                        .padding(.leading, 62)

                    settingsLink(
                        title: "Idle reminders",
                        subtitle: "When you are away from work",
                        systemImage: "figure.walk"
                    ) {
                        ReminderSettingsView(context: .idle)
                    }
                }
            }
        }
    }

    private var dailyGoalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeading("Daily goals", systemImage: "target")

            groupedSurface {
                settingsLink(
                    title: "Water and standing",
                    subtitle: "Set your daily targets",
                    systemImage: "drop.fill"
                ) {
                    DailyGoalsSettingsView()
                }
            }
        }
    }

    private func sectionHeading(_ title: String, systemImage: String) -> some View {
        Label(title.uppercased(), systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private func groupedSurface<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            }
    }

    private func settingsLink<Destination: View>(
        title: String,
        subtitle: String,
        systemImage: String,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 38, height: 38)
                    .background(
                        Color.accentColor.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

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

    private var continueFooter: some View {
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
            .tint(Color.accentColor)
            .controlSize(.large)
            .frame(maxWidth: 360)
            .shadow(color: .black.opacity(0.14), radius: 16, y: 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 12)
    }

    private func dayButton(for weekday: Weekday) -> some View {
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
                .foregroundStyle(isActive ? .white : .primary)
                .frame(maxWidth: .infinity, minHeight: 36, maxHeight: 36)
                .background {
                    Circle()
                        .fill(isActive ? Color.accentColor : Color.secondary.opacity(0.16))
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
    SetUpView()
        .environmentObject(AppConfigurationStore())
}

#Preview("Editing") {
    SetUpView(isEditing: true)
        .environmentObject(AppConfigurationStore())
}
