import SwiftUI
import IgotuCore

struct DailyGoalsSettingsView: View {
    @EnvironmentObject private var configuration: AppConfigurationStore
    private let themeColorService = ThemeColorService()

    var body: some View {
        let accent = themeColorService.currentColor(for: configuration.schedule)

        Form {
            Section {
                goalStepper(
                    title: "Water",
                    unit: "day",
                    value: Binding(
                        get: { configuration.dailyGoals.hydrationCount },
                        set: { updateGoals(hydrationCount: $0) }
                    ),
                    range: DailyGoals.hydrationRange
                )

                goalStepper(
                    title: "Standing hours",
                    unit: "day",
                    value: Binding(
                        get: { configuration.dailyGoals.standingHours },
                        set: { updateGoals(standingHours: $0) }
                    ),
                    range: DailyGoals.standingHoursRange
                )
            } header: {
                Text("Daily targets")
            }
        }
        .scrollContentBackground(.hidden)
        .background {
            AmbientBackground(color: accent)
        }
        .tint(accent)
        .navigationTitle("Daily Goals")
    }

    private func goalStepper(
        title: String,
        unit: String,
        value: Binding<Int>,
        range: ClosedRange<Int>
    ) -> some View {
        Stepper(value: value, in: range) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                Text("\(value.wrappedValue)/\(unit)")
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
