import Foundation
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

        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Label("Reminders", systemImage: "bell.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accent)

                VStack(spacing: 0) {
                    ForEach(rules.indices, id: \.self) { index in
                        reminderRow(for: rules[index].behavior)

                        if index < rules.count - 1 {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }
                }
                .ambientSurface(cornerRadius: 24)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
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
                FrequencyEditorView(behavior: behavior, context: context)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

private struct FrequencyEditorView: View {
    @EnvironmentObject private var configuration: AppConfigurationStore

    let behavior: Behavior
    let context: ReminderContext

    private enum PresentedPicker: String, Identifiable {
        case interval
        case offset

        var id: String { rawValue }
    }

    @State private var presentedPicker: PresentedPicker?

    private var frequency: ReminderFrequency {
        configuration.reminderRule(for: behavior, in: context).frequency
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            pickerRow(
                title: "Every",
                value: intervalTitle(for: frequency.interval),
                picker: .interval
            )

            pickerRow(
                title: "Offset",
                value: currentOffset.title,
                picker: .offset
            )
        }
        .padding(.top, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            normalizeOffsetIfNeeded()
        }
    }

    private var currentOffset: OffsetOption {
        OffsetOption(
            lowerBound: frequency.offsetRange.lowerBound / 60,
            upperBound: frequency.offsetRange.upperBound / 60
        )
    }

    private func pickerRow(
        title: String,
        value: String,
        picker: PresentedPicker
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    presentedPicker = presentedPicker == picker ? nil : picker
                }
            } label: {
                HStack {
                    Text(title)

                    Spacer()

                    HStack(spacing: 8) {
                        Text(value)
                            .foregroundStyle(.secondary)

                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemFill), in: Capsule())
                }
            }

            if presentedPicker == picker {
                pickerView(for: picker)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)
                    .clipped()
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityValue(value)
    }

    @ViewBuilder
    private func pickerView(for picker: PresentedPicker) -> some View {
        switch picker {
        case .interval:
            Picker("Interval", selection: intervalBinding) {
                ForEach(intervalOptions, id: \.self) { interval in
                    Text(intervalTitle(for: interval)).tag(interval)
                }
            }
            .pickerStyle(.wheel)

        case .offset:
            Picker("Offset", selection: offsetBinding) {
                ForEach(offsetOptions) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.wheel)
        }
    }

    private var intervalOptions: [TimeInterval] {
        let defaults: [TimeInterval] = [15, 30, 45, 60, 120, 180, 240, 300, 360].map { $0 * 60 }
        return Array(Set(defaults + [frequency.interval])).sorted()
    }

    private var offsetOptions: [OffsetOption] {
        offsetTierMinutes.map { minutes in
            OffsetOption(lowerBound: -Double(minutes), upperBound: Double(minutes))
        }
    }

    private var maxOffsetMinutes: Int {
        ReminderFrequency.maximumOffsetMinutes(for: frequency.interval)
    }

    private var offsetTierMinutes: [Int] {
        Array(Set([
            0,
            Int((Double(maxOffsetMinutes) / 3).rounded()),
            Int((Double(maxOffsetMinutes) * 2 / 3).rounded()),
            maxOffsetMinutes
        ])).sorted()
    }

    private var intervalBinding: Binding<TimeInterval> {
        Binding(
            get: { frequency.interval },
            set: { interval in
                let currentOffsetMinutes = max(
                    abs(frequency.offsetRange.lowerBound / 60),
                    abs(frequency.offsetRange.upperBound / 60)
                )
                let maximumOffsetMinutes = Double(
                    ReminderFrequency.maximumOffsetMinutes(for: interval)
                )
                let offsetMinutes = nearestOffsetMinutes(
                    to: min(currentOffsetMinutes, maximumOffsetMinutes),
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

    private var offsetBinding: Binding<OffsetOption> {
        Binding(
            get: {
                OffsetOption(
                    lowerBound: frequency.offsetRange.lowerBound / 60,
                    upperBound: frequency.offsetRange.upperBound / 60
                )
            },
            set: { option in
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

    private func nearestOffsetMinutes(
        to minutes: Double,
        for interval: TimeInterval
    ) -> Double {
        let maximum = ReminderFrequency.maximumOffsetMinutes(for: interval)
        let tiers = Set([
            0,
            Int((Double(maximum) / 3).rounded()),
            Int((Double(maximum) * 2 / 3).rounded()),
            maximum
        ])

        return Double(tiers.min {
            let leftDistance = abs(Double($0) - minutes)
            let rightDistance = abs(Double($1) - minutes)
            return leftDistance == rightDistance ? $0 < $1 : leftDistance < rightDistance
        } ?? 0)
    }

    private func normalizeOffsetIfNeeded() {
        let currentMinutes = max(
            abs(frequency.offsetRange.lowerBound / 60),
            abs(frequency.offsetRange.upperBound / 60)
        )
        let normalizedMinutes = nearestOffsetMinutes(
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

private struct OffsetOption: Hashable, Identifiable {
    let lowerBound: Double
    let upperBound: Double

    var id: String {
        "\(lowerBound)-\(upperBound)"
    }

    var range: ClosedRange<TimeInterval> {
        lowerBound * 60 ... upperBound * 60
    }

    var title: String {
        if lowerBound == 0, upperBound == 0 {
            return "None"
        }

        if lowerBound == -upperBound {
            return minuteTitle(upperBound)
        }

        return "\(minuteTitle(lowerBound)) to +\(minuteTitle(upperBound))"
    }

    private func minuteTitle(_ minutes: Double) -> String {
        "\(Int(minutes.rounded())) min"
    }
}

#Preview {
    NavigationStack {
        ReminderSettingsView(context: .work)
            .environmentObject(AppConfigurationStore())
    }
}
