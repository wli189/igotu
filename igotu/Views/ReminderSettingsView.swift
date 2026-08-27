import SwiftUI

struct ReminderSettingsView: View {
    @EnvironmentObject private var configuration: AppConfigurationStore

    let context: ReminderContext
    private let themeColorService = ThemeColorService()

    private var rules: [ReminderRule] {
        context == .work
            ? configuration.workReminders
            : configuration.idleReminders
    }

    var body: some View {
        let accent = themeColorService.currentColor(for: configuration.schedule)

        Form {
            Section("Reminders") {
                ForEach(rules) { rule in
                    reminderRow(for: rule.behavior)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background {
            AmbientBackground(color: accent)
        }
        .tint(accent)
        .navigationTitle(context.title)
    }

    private func reminderRow(for behavior: Behavior) -> some View {
        let rule = configuration.reminderRule(for: behavior, in: context)

        return VStack(alignment: .leading, spacing: 16) {
            Toggle(
                isOn: Binding(
                    get: { configuration.reminderRule(for: behavior, in: context).isEnabled },
                    set: { configuration.setReminderEnabled($0, for: behavior, in: context) }
                )
            ) {
                Label(behavior.title, systemImage: behavior.icon)
            }

            if rule.isEnabled {
                Picker(
                    "Frequency",
                    selection: Binding(
                        get: { configuration.reminderRule(for: behavior, in: context).frequency },
                        set: { configuration.setReminderFrequency($0, for: behavior, in: context) }
                    )
                ) {
                    ForEach(ReminderFrequency.allCases) { frequency in
                        Text(frequency.title).tag(frequency)
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ReminderSettingsView(context: .work)
            .environmentObject(AppConfigurationStore())
    }
}
