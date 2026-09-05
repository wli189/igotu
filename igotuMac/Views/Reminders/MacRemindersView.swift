import SwiftUI
import IgotuCore

struct MacRemindersView: View {
    @EnvironmentObject private var configuration: MacConfigurationStore
    @State private var context: ReminderContext = .work

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                MacDetailHeader(title: "Reminders", subtitle: "Choose what should gently interrupt your work and idle time.")

                Picker("Context", selection: $context) {
                    Text("Work").tag(ReminderContext.work)
                    Text("Idle").tag(ReminderContext.idle)
                }
                .pickerStyle(.segmented)
                .frame(width: 260)

                MacSurface {
                    VStack(spacing: 0) {
                        ForEach(Array(Behavior.allCases.enumerated()), id: \.element.id) { index, behavior in
                            reminderRow(behavior)
                            if index < Behavior.allCases.count - 1 { Divider().padding(.leading, 58) }
                        }
                    }
                    .padding(.horizontal, 20)
                }

                MacSurface {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(MacTheme.accent)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("A little variation keeps the rhythm natural.")
                                .font(.callout.weight(.medium))
                            Text("Each reminder can use a different interval. The actual notification timing is calculated from your schedule.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(18)
                }
            }
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(34)
        }
        .background(MacAmbientBackground(accent: MacTheme.accent))
    }

    private func reminderRow(_ behavior: Behavior) -> some View {
        let rule = configuration.reminderRule(for: behavior, in: context)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Image(systemName: behavior.icon)
                    .foregroundStyle(MacTheme.accent)
                    .frame(width: 30, height: 30)
                    .background(MacTheme.accent.opacity(0.12), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(behavior.title).font(.body.weight(.medium))
                    Text(rule.isEnabled ? "Active in \(context.title.lowercased()) time" : "Paused")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { configuration.reminderRule(for: behavior, in: context).isEnabled },
                    set: { configuration.setReminderEnabled($0, for: behavior, in: context) }
                ))
                .labelsHidden()
            }

            if rule.isEnabled {
                HStack {
                    Text("Every").font(.callout).foregroundStyle(.secondary)
                    Spacer()
                    Picker("Frequency", selection: Binding(
                        get: { configuration.reminderRule(for: behavior, in: context).frequency },
                        set: { configuration.setReminderFrequency($0, for: behavior, in: context) }
                    )) {
                        ForEach(ReminderFrequency.allCases) { frequency in
                            Text(frequency.title).tag(frequency)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 130)
                }
                .padding(.leading, 44)
            }
        }
        .padding(.vertical, 16)
    }
}

#Preview("Reminders") {
    MacRemindersView()
        .environmentObject(MacConfigurationStore.preview())
        .frame(width: 1_120, height: 740)
}
