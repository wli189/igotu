//
//  TodayRhythmSection.swift
//  igotu
//

import SwiftUI
import IgotuCore

struct TodayRhythmSection: View {
    let schedule: DailySchedule
    let accent: Color

    private var today: Date {
        .now
    }

    var body: some View {
        let configuredModes = DailyMode.scheduleModes

        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("SCHEDULE")

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(configuredModes.enumerated()), id: \.element) { index, mode in
                    if index > 0 {
                        Divider()
                            .padding(.leading, 54)
                    }

                    scheduleRows(
                        title: mode.title,
                        icon: mode.icon,
                        periods: schedule.periods(for: mode, on: today),
                        emptyTitle: "No (mode.title.lowercased()) periods",
                        tint: accent
                    )
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .ambientSurface(cornerRadius: 24)
        }
    }

    private func scheduleRows(
        title: String,
        icon: String,
        periods: [DailySchedulePeriod],
        emptyTitle: String,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 38, height: 38)
                    .background(tint.opacity(0.12), in: Circle())

                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .padding(.vertical, 11)

            if periods.isEmpty {
                Text(emptyTitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 50)
                    .padding(.bottom, 11)
            } else {
                ForEach(periods) { period in
                    Text(timeText(period.start) + " – " + timeText(period.end))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                        .padding(.leading, 50)
                        .padding(.bottom, 11)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(.secondary)
    }

    private func timeText(_ components: DateComponents) -> String {
        let date = Calendar.current.date(
            from: DateComponents(
                year: 2000,
                month: 1,
                day: 1,
                hour: components.hour ?? 0,
                minute: components.minute ?? 0
            )
        ) ?? .now

        return date.formatted(date: .omitted, time: .shortened)
    }
}
