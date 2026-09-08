import SwiftUI
import IgotuCore

struct ScheduleOverviewSection: View {
    let sleepPeriods: [DailySchedulePeriod]
    let workPeriods: [DailySchedulePeriod]
    let accent: Color
    let onAdd: () -> Void
    let onEdit: (DailyMode, DailySchedulePeriod) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                ScheduleSettingsSectionLabel(
                    title: "Schedule",
                    systemImage: "calendar",
                    accent: accent
                )

                Spacer()

                Button(action: onAdd) {
                    Label("Add time period", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderless)
                .accessibilityHint("Choose a mode in the editor")
            }

            ScheduleSettingsSurface {
                Group {
                    if sleepPeriods.isEmpty && workPeriods.isEmpty {
                        Text("No schedule periods")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        VStack(alignment: .leading, spacing: 0) {
                            if !sleepPeriods.isEmpty {
                                schedulePeriodsContent(
                                    title: "Sleep",
                                    systemImage: "moon.fill",
                                    mode: .sleeping,
                                    periods: sleepPeriods
                                )
                            }

                            if !sleepPeriods.isEmpty && !workPeriods.isEmpty {
                                Divider()
                                    .padding(.leading, 44)
                            }

                            if !workPeriods.isEmpty {
                                schedulePeriodsContent(
                                    title: "Work",
                                    systemImage: "briefcase.fill",
                                    mode: .work,
                                    periods: workPeriods
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
    }

    private func schedulePeriodsContent(
        title: String,
        systemImage: String,
        mode: DailyMode,
        periods: [DailySchedulePeriod]
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(.primary)
                .padding(.bottom, 2)

            ForEach(Array(periods.sorted(by: periodSort).enumerated()), id: \.element.id) { index, period in
                if index > 0 {
                    Divider()
                        .padding(.leading, 48)
                }

                periodRow(period, mode: mode)
            }
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func periodRow(
        _ period: DailySchedulePeriod,
        mode: DailyMode
    ) -> some View {
        Button {
            onEdit(mode, period)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: mode == .sleeping ? "moon.fill" : "clock.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(accent)
                    .frame(width: 36, height: 36)
                    .background(accent.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(timeText(period.start) + " – " + timeText(period.end))
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                        .monospacedDigit()

                    Text(daysText(period.days))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Edit " + mode.title + " time period")
    }

    private func periodSort(
        _ first: DailySchedulePeriod,
        _ second: DailySchedulePeriod
    ) -> Bool {
        let firstStart = first.start.hour ?? 0
        let secondStart = second.start.hour ?? 0
        if firstStart != secondStart {
            return firstStart < secondStart
        }

        let firstMinute = first.start.minute ?? 0
        let secondMinute = second.start.minute ?? 0
        if firstMinute != secondMinute {
            return firstMinute < secondMinute
        }

        return first.id.uuidString < second.id.uuidString
    }

    private func timeText(_ components: DateComponents) -> String {
        let date = Calendar.current.date(
            from: DateComponents(
                year: 2000,
                month: 1,
                day: 1,
                hour: components.hour,
                minute: components.minute
            )
        ) ?? .now

        return date.formatted(date: .omitted, time: .shortened)
    }

    private func daysText(_ days: Set<Weekday>) -> String {
        if days.count == Weekday.allCases.count {
            return "Every day"
        }

        if days == Weekday.defaultWorkdays {
            return "Weekday"
        }

        if days == [.saturday, .sunday] {
            return "Weekend"
        }

        return Weekday.mondayFirst
            .filter { days.contains($0) }
            .map { $0.shortTitle }
            .joined(separator: "  ")
    }
}
