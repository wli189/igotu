import SwiftUI
import IgotuCore

struct ReminderPreferencesSection: View {
    let accent: Color
    @Binding var sleepReminderLeadMinutes: Int
    @State private var isWindDownPickerExpanded = false

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
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    isWindDownPickerExpanded.toggle()
                }
            } label: {
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
                        .foregroundStyle(.primary)

                    Spacer(minLength: 8)

                    HStack(spacing: 8) {
                        Text("\(sleepReminderLeadMinutes) min")
                            .foregroundStyle(.secondary)

                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemFill), in: Capsule())
                }
                .frame(minHeight: 44)
            }

            if isWindDownPickerExpanded {
                Picker("Wind down lead time", selection: $sleepReminderLeadMinutes) {
                    ForEach(sleepReminderLeadMinuteOptions, id: \.self) { minutes in
                        Text("\(minutes) min")
                            .tag(minutes)
                    }
                }
                .pickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .clipped()
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
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
