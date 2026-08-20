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
    
    private func components(from date: Date) -> DateComponents {
            Calendar.current.dateComponents([.hour, .minute], from: date)
        }
    
    private static func time(hour: Int) -> Date {
        Calendar.current.date(from: DateComponents(hour: hour))!
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
                        let schedule = DailySchedule(
                            sleepStart: components(from: sleepStart),
                            sleepEnd: components(from: sleepEnd),
                            workStart: components(from: workStart),
                            workEnd: components(from: workEnd)
                        )

                        configuration.save(schedule: schedule)
                        dismiss()
                    }
                }
            }
            .navigationTitle("Stay well")
        }
    }
}


#Preview {
    SetUpView()
        .environmentObject(AppConfigurationStore())
}
