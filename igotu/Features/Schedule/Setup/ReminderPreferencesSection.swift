import SwiftUI
import IgotuCore

struct ReminderPreferencesSection: View {
    let accent: Color
    @Binding var sleepReminderLeadMinutes: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScheduleSettingsSectionLabel(
                title: "Reminder preferences",
                systemImage: "bell.fill",
                accent: accent
            )

            ScheduleSettingsSurface {
                VStack(spacing: 0) {
                    windDownSettingsRow

                    Divider()
                        .padding(.leading, 62)

                    ScheduleSettingsNavigationRow(
                        title: "Work reminders",
                        systemImage: "briefcase.fill",
                        accent: accent
                    ) {
                        ReminderSettingsView(context: .work)
                    }

                    Divider()
                        .padding(.leading, 62)

                    ScheduleSettingsNavigationRow(
                        title: "Idle reminders",
                        systemImage: "figure.walk",
                        accent: accent
                    ) {
                        ReminderSettingsView(context: .idle)
                    }

                    Divider()
                        .padding(.leading, 62)

                    ScheduleSettingsNavigationRow(
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

    private var windDownSettingsRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "moon.zzz.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(accent)
                .frame(width: 38, height: 38)
                .background(
                    accent.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                )

            Text("Wind down")
                .font(.body.weight(.medium))

            Spacer(minLength: 8)

            Picker("Wind down lead time", selection: $sleepReminderLeadMinutes) {
                ForEach(sleepReminderLeadMinuteOptions, id: \.self) { minutes in
                    Text("\(minutes) min")
                        .tag(minutes)
                }
            }
            .labelsHidden()
            .frame(width: 110)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var sleepReminderLeadMinuteOptions: [Int] {
        Array(
            stride(
                from: Int(ReminderTiming.minimumSleepReminderLeadTime / 60),
                through: Int(ReminderTiming.maximumSleepReminderLeadTime / 60),
                by: Int(ReminderTiming.sleepReminderLeadTimeStep / 60)
            )
        )
    }
}
