//
//  TodayView.swift
//  igotu
//
//  Created by Brian Li on 8/19/26.
//

import SwiftUI
import IgotuCore

struct TodayView: View {
    @EnvironmentObject private var configuration: AppConfigurationStore
    @EnvironmentObject private var history: ReminderHistoryStore

    private let metricsCalculator = DailyMetricsCalculator()
    private let progressCalculator = DailyModeProgressCalculator()
    private let themeColorService = ThemeColorService()

    private var schedule: DailySchedule {
        configuration.schedule
    }

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 60)) { timeline in
                let now = timeline.date
                let mode = themeColorService.currentMode(for: schedule, at: now)
                let metrics = metricsCalculator.calculate(
                    events: history.completedEvents(on: now),
                    goals: configuration.dailyGoals
                )
                let theme = themeColorService.theme(for: mode)
                let accent = themeColorService.color(for: theme)
                let progress = progressCalculator.progress(
                    for: mode,
                    schedule: schedule,
                    at: now
                )

                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        TodayHeaderView(
                            date: now,
                            accent: accent
                        )

                        CurrentContextCard(
                            mode: mode,
                            progress: progress,
                            accent: accent
                        )

                        TodayProgressSection(
                            metrics: metrics,
                            accent: accent
                        )

                        TodayRhythmSection(
                            schedule: schedule,
                            accent: accent
                        )
                    }
                    .frame(maxWidth: 760, alignment: .leading)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 20)
                }
                .scrollIndicators(.hidden)
                .background {
                    AmbientBackground(color: accent)
                }
                .tint(accent)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

#Preview("Work") {
    TodayView()
        .environmentObject(
            PreviewSupport.configuration(
                named: "today-work",
                schedule: PreviewSupport.allDayWorkSchedule
            )
        )
        .environmentObject(PreviewSupport.history(named: "today-work"))
}

#Preview("Sleeping") {
    TodayView()
        .environmentObject(
            PreviewSupport.configuration(
                named: "today-sleeping",
                schedule: PreviewSupport.allDaySleepSchedule
            )
        )
        .environmentObject(PreviewSupport.history(named: "today-sleeping"))
}

#Preview("No Schedule") {
    TodayView()
        .environmentObject(
            PreviewSupport.configuration(
                named: "today-empty",
                schedule: PreviewSupport.emptySchedule
            )
        )
        .environmentObject(PreviewSupport.history(named: "today-empty"))
}
