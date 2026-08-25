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
        NavigationStack{
            Form {
                Section(header: Text("Sleep Time")) {
                    DatePicker(
                        "Bedtimes",
                        selection: $sleepStart,
                        displayedComponents: .hourAndMinute
                    )
                    
                    DatePicker(
                        "Wake up",
                        selection: $sleepEnd,
                        displayedComponents: .hourAndMinute
                    )
                }
                
                Section(header: Text("Work Time")) {
                    DatePicker(
                        "Work starts",
                        selection: $workStart,
                        displayedComponents: .hourAndMinute
                    )
                    
                    DatePicker(
                        "Work ends",
                        selection: $workEnd,
                        displayedComponents: .hourAndMinute
                    )
                }

                Section {
                    daysActiveSelector
                }

                Section("Reminder Preferences") {
                    NavigationLink("Work Reminders") {
                        ReminderSettingsView(context: .work)
                    }

                    NavigationLink("Idle Reminders") {
                        ReminderSettingsView(context: .idle)
                    }
                }
                
                if !isEditing {
                    Section {
                        Button("Continue") {
                            if save() {
                                dismiss()
                            }
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Schedule" : "Stay well")
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

    private var daysActiveSelector: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Days Active")
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                ForEach(Weekday.mondayFirst) { weekday in
                    dayButton(for: weekday)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
        .listRowBackground(Color.clear)
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
                .font(.title3.weight(.semibold))
                .foregroundStyle(isActive ? .white : .primary)
                .frame(width: 40, height: 40)
                .background(isActive ? Color.accentColor : Color.secondary.opacity(0.16))
                .clipShape(Circle())
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
