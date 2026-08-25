import SwiftUI

struct DailyGoalsSettingsView: View {
    @EnvironmentObject private var configuration: AppConfigurationStore

    var body: some View {
        Form {
            Section {
                goalStepper(
                    title: "Drink Water",
                    subtitle: "Times per day",
                    value: Binding(
                        get: { configuration.dailyGoals.hydrationCount },
                        set: { updateGoals(hydrationCount: $0) }
                    ),
                    range: DailyGoals.hydrationRange
                )

                goalStepper(
                    title: "Stand Up",
                    subtitle: "Different hours per day",
                    value: Binding(
                        get: { configuration.dailyGoals.standingHours },
                        set: { updateGoals(standingHours: $0) }
                    ),
                    range: DailyGoals.standingHoursRange
                )
            } header: {
                Text("Daily Targets")
            } footer: {
                Text("A standing hour counts once, even if you complete multiple reminders during that hour.")
            }
        }
        .navigationTitle("Daily Goals")
    }

    private func goalStepper(
        title: String,
        subtitle: String,
        value: Binding<Int>,
        range: ClosedRange<Int>
    ) -> some View {
        Stepper(value: value, in: range) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                Text("\(value.wrappedValue) \(subtitle)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func updateGoals(
        hydrationCount: Int? = nil,
        standingHours: Int? = nil
    ) {
        var goals = configuration.dailyGoals
        if let hydrationCount {
            goals.hydrationCount = hydrationCount
        }
        if let standingHours {
            goals.standingHours = standingHours
        }
        configuration.save(dailyGoals: goals)
    }
}

#Preview {
    NavigationStack {
        DailyGoalsSettingsView()
            .environmentObject(AppConfigurationStore())
    }
}
