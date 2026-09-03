import SwiftUI

struct SchedulePeriodEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let mode: DailyMode
    let initialPeriod: DailySchedulePeriod?
    let onSave: (DailySchedulePeriod) -> String?
    let onDelete: (() -> Void)?

    @State private var start: Date
    @State private var end: Date
    @State private var days: Set<Weekday>
    @State private var expandedTimePicker: TimePicker?
    @State private var errorMessage: String?
    @State private var showsDeleteConfirmation = false

    private enum TimePicker: Equatable {
        case start
        case end
    }

    private var accent: Color {
        ThemeColorService().color(for: mode.wellnessTheme)
    }

    init(
        mode: DailyMode,
        period: DailySchedulePeriod?,
        onSave: @escaping (DailySchedulePeriod) -> String?,
        onDelete: (() -> Void)? = nil
    ) {
        self.mode = mode
        initialPeriod = period
        self.onSave = onSave
        self.onDelete = onDelete

        let defaultStart = mode == .sleeping ? 23 : 9
        let defaultEnd = mode == .sleeping ? 7 : 18
        _start = State(initialValue: Self.time(
            from: period?.start ?? DateComponents(hour: defaultStart)
        ))
        _end = State(initialValue: Self.time(
            from: period?.end ?? DateComponents(hour: defaultEnd)
        ))
        _days = State(initialValue: period?.days ?? (
            mode == .sleeping ? Set(Weekday.allCases) : Weekday.defaultWorkdays
        ))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    editorSurface
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)
            .background {
                AmbientBackground(color: accent)
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .fontWeight(.semibold)
                }

                if onDelete != nil {
                    ToolbarItem(placement: .bottomBar) {
                        Button("Delete", role: .destructive) {
                            showsDeleteConfirmation = true
                        }
                    }
                }
            }
            .alert(
                "Cannot Save Schedule",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "")
            }
            .confirmationDialog(
                "Delete this schedule?",
                isPresented: $showsDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    onDelete?()
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            }
        }
        .tint(accent)
    }

    private var editorSurface: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label(mode == .sleeping ? "Sleep" : "Work", systemImage: mode.icon)
                .font(.headline)
                .padding(.bottom, 8)

            timePickerRow(
                title: mode == .sleeping ? "Bedtime" : "Work starts",
                selection: $start,
                picker: .start
            )

            timePickerRow(
                title: mode == .sleeping ? "Wake up" : "Work ends",
                selection: $end,
                picker: .end
            )

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
        .padding(20)
        .ambientSurface(cornerRadius: 24)
    }

    private func timePickerRow(
        title: String,
        selection: Binding<Date>,
        picker: TimePicker
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    expandedTimePicker = expandedTimePicker == picker ? nil : picker
                }
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

            if expandedTimePicker == picker {
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

    private func dayButton(for weekday: Weekday) -> some View {
        let isSelected = days.contains(weekday)

        return Button {
            if isSelected {
                days.remove(weekday)
            } else {
                days.insert(weekday)
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

    private func save() {
        guard !days.isEmpty else {
            errorMessage = "Select at least one active day."
            return
        }

        let startComponents = components(from: start)
        let endComponents = components(from: end)
        guard startComponents != endComponents else {
            errorMessage = mode == .sleeping
                ? "Your bedtime and wake-up time cannot be the same."
                : "Your work start time and end time cannot be the same."
            return
        }

        let period = DailySchedulePeriod(
            id: initialPeriod?.id ?? UUID(),
            start: startComponents,
            end: endComponents,
            days: days
        )

        if let message = onSave(period) {
            errorMessage = message
        } else {
            dismiss()
        }
    }

    private func components(from date: Date) -> DateComponents {
        Calendar.current.dateComponents([.hour, .minute], from: date)
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
