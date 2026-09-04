//
//  TodayProgressSection.swift
//  igotu
//

import SwiftUI

struct TodayProgressSection: View {
    let metrics: DailyMetrics
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("TODAY'S PROGRESS")

            HStack(spacing: 12) {
                MetricCard(
                    title: "Water",
                    value: min(metrics.hydrationCount, metrics.goals.hydrationCount),
                    goal: metrics.goals.hydrationCount,
                    icon: "drop.fill",
                    tint: accent
                )

                MetricCard(
                    title: "Standing",
                    value: min(metrics.standingHours, metrics.goals.standingHours),
                    goal: metrics.goals.standingHours,
                    icon: "figure.stand",
                    tint: accent
                )
            }
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(.secondary)
    }
}

private struct MetricCard: View {
    let title: String
    let value: Int
    let goal: Int
    let icon: String
    let tint: Color

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(Double(value) / Double(goal), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 30, height: 30)
                    .background(tint.opacity(0.12), in: Circle())

                Spacer(minLength: 8)

                Text("\(value)/\(goal)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)

            ProgressView(value: progress)
                .tint(tint)
                .scaleEffect(y: 0.8)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
        .ambientSurface(cornerRadius: 18)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(value) of \(goal)")
    }
}
