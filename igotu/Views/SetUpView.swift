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
    @State private var sleepStart = Self.time(hour: 23)
    @State private var sleepEnd = Self.time(hour: 7)
    @State private var workStart = Self.time(hour: 9)
    @State private var workEnd = Self.time(hour: 18)
    @State private var errorMessage: String?
    
    private func components(from date: Date) -> DateComponents {
            Calendar.current.dateComponents([.hour, .minute], from: date)
        }
    
    private static func time(hour: Int) -> Date {
        Calendar.current.date(from: DateComponents(hour: hour))!
    }
    
    private func minutes(from components: DateComponents) -> Int {
        (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    private func ranges(start: Int, end: Int) -> [Range<Int>] {
        if start < end {
            return [start..<end]
        }

        return [start..<1_440, 0..<end]
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
            workEnd: components(from: workEnd)
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
                    Button("Continue") {
                        if save() {
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Stay well")
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
}


#Preview {
    SetUpView()
        .environmentObject(AppConfigurationStore())
}
