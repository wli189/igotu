import SwiftUI
import IgotuCore

struct SchedulePeriodEditorState {
    enum TimePicker: Equatable {
        case start
        case end
    }

    var selectedMode: DailyMode
    var start: Date
    var end: Date
    var days: Set<Weekday>
    var expandedTimePicker: TimePicker?

    init(mode: DailyMode, period: DailySchedulePeriod?) {
        selectedMode = mode

        let defaultStart = mode == .sleeping ? 23 : 9
        let defaultEnd = mode == .sleeping ? 7 : 18
        start = Self.time(
            from: period?.start ?? DateComponents(hour: defaultStart)
        )
        end = Self.time(
            from: period?.end ?? DateComponents(hour: defaultEnd)
        )
        days = period?.days ?? (
            mode == .sleeping ? Set(Weekday.allCases) : Weekday.defaultWorkdays
        )
        expandedTimePicker = nil
    }

    mutating func applyDefaults(for mode: DailyMode) {
        let defaultStart = mode == .sleeping ? 23 : 9
        let defaultEnd = mode == .sleeping ? 7 : 18
        start = Self.time(from: DateComponents(hour: defaultStart))
        end = Self.time(from: DateComponents(hour: defaultEnd))
        days = mode == .sleeping ? Set(Weekday.allCases) : Weekday.defaultWorkdays
    }

    private static func time(from components: DateComponents) -> Date {
        Calendar.current.date(
            from: DateComponents(
                year: 2000,
                month: 1,
                day: 1,
                hour: components.hour,
                minute: components.minute
            )
        ) ?? .now
    }
}

struct SchedulePeriodEditorFields: View {
    @Binding var state: SchedulePeriodEditorState
    let accent: Color
    let onTimePickerExpanded: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Picker(selection: $state.selectedMode) {
                ForEach(DailyMode.scheduleModes, id: \.key) { mode in
                    Label(mode.title, systemImage: mode.icon)
                        .tag(mode)
                }
            } label: {
                Label(state.selectedMode.title, systemImage: state.selectedMode.icon)
                    .font(.headline)
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .padding(.bottom, 8)

            timePickerRow(
                title: state.selectedMode == .sleeping ? "Bedtime" : "Work starts",
                selection: $state.start,
                picker: .start
            )

            timePickerRow(
                title: state.selectedMode == .sleeping ? "Wake up" : "Work ends",
                selection: $state.end,
                picker: .end
            )

            if state.selectedMode == .work {
                Divider()
                    .padding(.top, 16)

                ReminderRulesEditorView(
                    context: .work,
                    title: "Reminder frequency"
                )
            }

            Divider()
                .padding(.vertical, 16)

            Text("Active days")
                .font(.headline)
                .padding(.bottom, 12)

            HStack(spacing: 6) {
                ForEach(Weekday.mondayFirst) { weekday in
                    dayButton(for: weekday)
                }
            }
        }
    }

    private func timePickerRow(
        title: String,
        selection: Binding<Date>,
        picker: SchedulePeriodEditorState.TimePicker
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                togglePicker(picker)
            } label: {
                HStack {
                    Text(title)

                    Spacer()

                    HStack(spacing: 8) {
                        Text(selection.wrappedValue.formatted(date: .omitted, time: .shortened))
                            .foregroundStyle(.secondary)

                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(minHeight: 44)
            }

            if state.expandedTimePicker == picker {
                DatePicker(
                    title,
                    selection: selection,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .clipped()
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func togglePicker(_ picker: SchedulePeriodEditorState.TimePicker) {
        withAnimation(.easeInOut(duration: 0.22)) {
            if state.expandedTimePicker == picker {
                state.expandedTimePicker = nil
            } else {
                onTimePickerExpanded()
                state.expandedTimePicker = picker
            }
        }
    }

    private func dayButton(for weekday: Weekday) -> some View {
        let isSelected = state.days.contains(weekday)

        return Button {
            if isSelected {
                state.days.remove(weekday)
            } else {
                state.days.insert(weekday)
            }
        } label: {
            Text(String(weekday.shortTitle.prefix(1)))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? .white : accent)
                .frame(maxWidth: .infinity, minHeight: 38, maxHeight: 38)
                .background {
                    Circle()
                        .fill(isSelected ? accent : accent.opacity(0.12))
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(weekday.title)
        .accessibilityValue(isSelected ? "Active" : "Inactive")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
