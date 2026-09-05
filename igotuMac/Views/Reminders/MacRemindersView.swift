import SwiftUI
import IgotuCore

struct MacRemindersView: View {
    @EnvironmentObject private var configuration: MacConfigurationStore
    @Environment(\.macAccent) private var accent
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
            }
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(34)
        }
        .background(MacAmbientBackground(accent: accent))
        .tint(accent)
    }

    private func reminderRow(_ behavior: Behavior) -> some View {
        let rule = configuration.reminderRule(for: behavior, in: context)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Image(systemName: behavior.icon)
                    .foregroundStyle(accent)
                    .frame(width: 30, height: 30)
                    .background(accent.opacity(0.12), in: Circle())
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
                VStack(alignment: .leading, spacing: 8) {
                    Picker("Every", selection: intervalBinding(for: behavior)) {
                        ForEach(intervalOptions(for: behavior), id: \.self) { interval in
                            Text(intervalTitle(for: interval)).tag(interval)
                        }
                    }
                    Picker("Offset", selection: offsetBinding(for: behavior)) {
                        ForEach(offsetOptions(for: behavior)) { option in
                            Text(option.title).tag(option)
                        }
                    }
                }
                .padding(.leading, 44)
            }
        }
        .padding(.vertical, 16)
        .onAppear {
            normalizeOffsetIfNeeded(for: behavior)
        }
    }

    private func intervalOptions(for behavior: Behavior) -> [TimeInterval] {
        ReminderFrequency.intervalOptions(
            including: configuration.reminderRule(for: behavior, in: context).frequency.interval
        )
    }

    private func offsetOptions(for behavior: Behavior) -> [MacOffsetOption] {
        let frequency = configuration.reminderRule(for: behavior, in: context).frequency
        return ReminderFrequency.offsetTierMinutes(for: frequency.interval).map {
            MacOffsetOption(lowerBound: -Double($0), upperBound: Double($0))
        }
    }

    private func intervalBinding(for behavior: Behavior) -> Binding<TimeInterval> {
        Binding(
            get: { configuration.reminderRule(for: behavior, in: context).frequency.interval },
            set: { interval in
                let frequency = configuration.reminderRule(for: behavior, in: context).frequency
                let currentOffsetMinutes = max(
                    abs(frequency.offsetRange.lowerBound / 60),
                    abs(frequency.offsetRange.upperBound / 60)
                )
                let offsetMinutes = ReminderFrequency.nearestOffsetMinutes(
                    to: min(
                        currentOffsetMinutes,
                        Double(ReminderFrequency.maximumOffsetMinutes(for: interval))
                    ),
                    for: interval
                )
                configuration.setReminderFrequency(
                    ReminderFrequency(
                        interval: interval,
                        offsetRange: -offsetMinutes * 60 ... offsetMinutes * 60
                    ),
                    for: behavior,
                    in: context
                )
            }
        )
    }

    private func offsetBinding(for behavior: Behavior) -> Binding<MacOffsetOption> {
        Binding(
            get: {
                let frequency = configuration.reminderRule(for: behavior, in: context).frequency
                return MacOffsetOption(
                    lowerBound: frequency.offsetRange.lowerBound / 60,
                    upperBound: frequency.offsetRange.upperBound / 60
                )
            },
            set: { option in
                let frequency = configuration.reminderRule(for: behavior, in: context).frequency
                configuration.setReminderFrequency(
                    ReminderFrequency(interval: frequency.interval, offsetRange: option.range),
                    for: behavior,
                    in: context
                )
            }
        )
    }

    private func intervalTitle(for interval: TimeInterval) -> String {
        let minutes = interval / 60
        if minutes >= 60 {
            let hours = minutes / 60
            if hours.rounded() == hours {
                let wholeHours = Int(hours)
                return wholeHours == 1 ? "1 hour" : "\(wholeHours) hours"
            }
            return "\(String(format: "%.1f", hours)) hours"
        }
        return "\(Int(minutes.rounded())) min"
    }

    private func normalizeOffsetIfNeeded(for behavior: Behavior) {
        let frequency = configuration.reminderRule(for: behavior, in: context).frequency
        let currentMinutes = max(
            abs(frequency.offsetRange.lowerBound / 60),
            abs(frequency.offsetRange.upperBound / 60)
        )
        let normalizedMinutes = ReminderFrequency.nearestOffsetMinutes(
            to: currentMinutes,
            for: frequency.interval
        )

        guard currentMinutes != normalizedMinutes
            || frequency.offsetRange.lowerBound != -normalizedMinutes * 60
            || frequency.offsetRange.upperBound != normalizedMinutes * 60
        else { return }

        configuration.setReminderFrequency(
            ReminderFrequency(
                interval: frequency.interval,
                offsetRange: -normalizedMinutes * 60 ... normalizedMinutes * 60
            ),
            for: behavior,
            in: context
        )
    }
}

private struct MacOffsetOption: Hashable, Identifiable {
    let lowerBound: Double
    let upperBound: Double

    var id: String { "\(lowerBound)-\(upperBound)" }
    var range: ClosedRange<TimeInterval> { lowerBound * 60 ... upperBound * 60 }

    var title: String {
        if lowerBound == 0, upperBound == 0 { return "None" }
        if lowerBound == -upperBound { return "\(Int(upperBound.rounded())) min" }
        return "\(Int(lowerBound.rounded())) min to +\(Int(upperBound.rounded())) min"
    }
}

#Preview("Reminders") {
    MacRemindersView()
        .environmentObject(MacConfigurationStore.preview())
        .frame(width: 1_120, height: 740)
}
