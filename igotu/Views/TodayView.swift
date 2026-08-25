//
//  TodayView.swift
//  igotu
//
//  Created by Brian Li on 8/19/26.
//

import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var configuration: AppConfigurationStore
    @EnvironmentObject private var history: ReminderHistoryStore
    @State private var isShowingSettings = false
    
    private let modeManager = DailyModeManager()
    private let metricsCalculator = DailyMetricsCalculator()

    private var schedule: DailySchedule {
        configuration.schedule
    }

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 60)) { timeline in
                let mode = modeManager.currentMode(
                    for: schedule,
                    at: timeline.date
                )
                let metrics = metricsCalculator.calculate(
                    events: history.completedEvents(on: timeline.date),
                    goals: configuration.dailyGoals
                )

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        greeting

                        currentModeCard(mode)

                        scheduleSection

                        dailyProgress(metrics)
                    }
                    .padding()
                }
            }
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isShowingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $isShowingSettings) {
                SetUpView(isEditing: true)
                    .environmentObject(configuration)
            }
        }
    }

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Good \(dayPeriod)")
                .font(.title.bold())

            Text(Date.now, format: .dateTime.weekday(.wide).month().day())
                .foregroundStyle(.secondary)
        }
    }

    private func currentModeCard(_ mode: DailyMode) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Current Mode", systemImage: "clock")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                Image(systemName: mode.icon)
                    .font(.title2)
                    .foregroundStyle(mode.color)
                    .frame(width: 48, height: 48)
                    .background(mode.color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.title)
                        .font(.title2.bold())

                    Text(mode.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SCHEDULE")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            scheduleRow(
                title: "Sleep",
                icon: "moon.fill",
                start: schedule.sleepStart,
                end: schedule.sleepEnd
            )

            Divider()

            scheduleRow(
                title: "Work",
                icon: "briefcase.fill",
                start: schedule.workStart,
                end: schedule.workEnd
            )
        }
        .padding()
    }

    private func dailyProgress(_ metrics: DailyMetrics) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("TODAY'S PROGRESS")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            progressRow(
                title: "Drink Water",
                icon: "drop.fill",
                value: metrics.hydrationCount,
                goal: metrics.goals.hydrationCount
            )

            progressRow(
                title: "Stand Up",
                icon: "figure.stand",
                value: metrics.standingHours,
                goal: metrics.goals.standingHours
            )
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func progressRow(
        title: String,
        icon: String,
        value: Int,
        goal: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(title, systemImage: icon)
                Spacer()
                Text("\(min(value, goal)) / \(goal)")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            ProgressView(value: Double(min(value, goal)), total: Double(goal))
        }
    }

    private func scheduleRow(
        title: String,
        icon: String,
        start: DateComponents,
        end: DateComponents
    ) -> some View {
        HStack {
            Label(title, systemImage: icon)

            Spacer()

            Text("\(timeText(start)) – \(timeText(end))")
                .foregroundStyle(.secondary)
        }
    }

    private func timeText(_ components: DateComponents) -> String {
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0

        let date = Calendar.current.date(
            from: DateComponents(
                year: 2000,
                month: 1,
                day: 1,
                hour: hour,
                minute: minute
            )
        ) ?? .now

        return date.formatted(date: .omitted, time: .shortened)
    }

    private var dayPeriod: String {
        let hour = Calendar.current.component(.hour, from: .now)

        switch hour {
        case 5..<12: return "morning"
        case 12..<18: return "afternoon"
        default: return "evening"
        }
    }
}

#Preview {
    TodayView()
        .environmentObject(AppConfigurationStore())
        .environmentObject(ReminderHistoryStore())
}
