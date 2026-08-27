//
//  TodayRhythmSection.swift
//  igotu
//

import SwiftUI

struct TodayRhythmSection: View {
    let schedule: DailySchedule
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("SCHEDULE")

            VStack(spacing: 0) {
                RhythmRow(
                    title: "Sleep",
                    icon: "moon.fill",
                    time: "\(timeText(schedule.sleepStart)) – \(timeText(schedule.sleepEnd))",
                    tint: accent
                )

                Divider()
                    .padding(.leading, 54)

                RhythmRow(
                    title: "Work",
                    icon: "briefcase.fill",
                    time: "\(timeText(schedule.workStart)) – \(timeText(schedule.workEnd))",
                    tint: accent
                )
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .ambientSurface(cornerRadius: 24)
        }
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

private struct RhythmRow: View {
    let title: String
    let icon: String
    let time: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 38, height: 38)
                .background(tint.opacity(0.12), in: Circle())

            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)

            Spacer(minLength: 8)

            Text(time)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .monospacedDigit()
        }
        .padding(.vertical, 11)
    }
}
