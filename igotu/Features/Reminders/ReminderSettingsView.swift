
import Foundation
import SwiftUI
import IgotuCore

struct ReminderSettingsView: View {
    let context: ReminderContext
    private let themeColorService = ThemeColorService()

    @EnvironmentObject private var configuration: AppConfigurationStore

    var body: some View {
        let accent = themeColorService.currentColor(for: configuration.schedule)

        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Label("Reminders", systemImage: "bell.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accent)

                ReminderRulesEditorView(context: context)
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

}

struct ReminderRulesEditorView: View {
    @EnvironmentObject private var configuration: AppConfigurationStore

    let context: ReminderContext
    var title: String?

    private var rules: [ReminderRule] {
        context == .work
            ? configuration.workReminders
            : configuration.idleReminders
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                if let title {
                    Text(title)
                        .font(.headline)
                }

                Spacer()
                addReminderMenu
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            ForEach(Array(rules.enumerated()), id: \.element.behavior) { index, rule in
                if index > 0 {
                    Divider()
                        .padding(.horizontal, 16)
                }

                reminderRow(for: rule.behavior)
            }

            if rules.isEmpty {
                Text("No reminders added")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
        }
    }

    private var addReminderMenu: some View {
        Menu {
            ForEach(configuration.availableReminderBehaviors(in: context)) { behavior in
                Button {
                    configuration.addReminder(for: behavior, in: context)
                } label: {
                    Label(behavior.title, systemImage: behavior.icon)
                }
            }
        } label: {
            Image(systemName: "plus")
        }
        .disabled(configuration.availableReminderBehaviors(in: context).isEmpty)
        .buttonStyle(.bordered)
    }

    private func reminderRow(for behavior: Behavior) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: behavior.icon)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.tint)
                    .frame(width: 34, height: 34)
                    .background(Color.accentColor.opacity(0.12), in: Circle())

                Text(behavior.title)
                    .font(.body.weight(.semibold))

                Spacer(minLength: 8)

                Button(role: .destructive) {
                    configuration.removeReminder(for: behavior, in: context)
                } label: {
                    Image(systemName: "trash")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove reminder")
            }

            FrequencyEditorView(behavior: behavior, context: context)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
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
                title: "Random timing",
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
            Picker("Random timing", selection: offsetBinding) {
                ForEach(offsetOptions) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.wheel)
        }
    }

    private var intervalOptions: [TimeInterval] {
        ReminderFrequency.intervalOptions(including: frequency.interval)
    }

    private var offsetOptions: [OffsetOption] {
        offsetTierMinutes.map { minutes in
            OffsetOption(lowerBound: -Double(minutes), upperBound: Double(minutes))
        }
    }

    private var offsetTierMinutes: [Int] {
        ReminderFrequency.offsetTierMinutes(for: frequency.interval)
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
        ReminderFrequency.nearestOffsetMinutes(to: minutes, for: interval)
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
            return "±\(minuteTitle(upperBound))"
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
