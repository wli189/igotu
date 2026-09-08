//
//  SetUpView.swift
//  igotu
//
//  Created by Brian Li on 8/19/26.
//

import SwiftUI
import IgotuCore

private struct SchedulePeriodEditorConfiguration: Identifiable {
    let id: UUID
    let mode: DailyMode
    let period: DailySchedulePeriod?

    init(mode: DailyMode, period: DailySchedulePeriod?) {
        id = period?.id ?? UUID()
        self.mode = mode
        self.period = period
    }
}

struct SetUpView: View {
    @EnvironmentObject private var configuration: AppConfigurationStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let isEditing: Bool
    private let themeColorService = ThemeColorService()
    private let scheduleValidator = DailyScheduleValidator()

    @State private var sleepPeriods: [DailySchedulePeriod] = []
    @State private var workPeriods: [DailySchedulePeriod] = []
    @State private var sleepReminderLeadMinutes = 30
    @State private var editorConfiguration: SchedulePeriodEditorConfiguration?
    @State private var errorMessage: String?
    @State private var hasLoadedSavedSchedule = false

    init(isEditing: Bool = false) {
        self.isEditing = isEditing
    }

    var body: some View {
        let accent = themeColorService.currentColor(for: configuration.schedule)

        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if !isEditing {
                    onboardingHeader(accent: accent)
                }

                ScheduleOverviewSection(
                    sleepPeriods: sleepPeriods,
                    workPeriods: workPeriods,
                    accent: accent,
                    onAdd: {
                        editorConfiguration = SchedulePeriodEditorConfiguration(
                            mode: .work,
                            period: nil
                        )
                    },
                    onEdit: { mode, period in
                        editorConfiguration = SchedulePeriodEditorConfiguration(
                            mode: mode,
                            period: period
                        )
                    }
                )

                ReminderPreferencesSection(
                    accent: accent,
                    sleepReminderLeadMinutes: $sleepReminderLeadMinutes
                )

                DailyGoalsOverviewSection(accent: accent)
            }
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.top, isEditing ? 16 : 20)
            .padding(.bottom, isEditing ? 24 : 96)
        }
        .scrollIndicators(.hidden)
        .background {
            AmbientBackground(color: accent)
        }
        .tint(accent)
        .navigationTitle(isEditing ? "Schedule" : "")
        .navigationBarTitleDisplayMode(.large)
        .toolbar(isEditing ? .visible : .hidden, for: .navigationBar)
        .overlay(alignment: .bottom) {
            if !isEditing {
                continueFooter(accent: accent)
            }
        }
        .onAppear {
            loadSavedSchedule()
        }
        .onChange(of: sleepPeriods) { _, _ in
            saveEditedScheduleIfNeeded()
        }
        .onChange(of: workPeriods) { _, _ in
            saveEditedScheduleIfNeeded()
        }
        .onChange(of: sleepReminderLeadMinutes) { _, _ in
            saveEditedSleepReminderLeadTimeIfNeeded()
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
        .sheet(item: $editorConfiguration) { editor in
            SchedulePeriodEditorView(
                mode: editor.mode,
                period: editor.period,
                isRegularWidth: horizontalSizeClass == .regular,
                onSave: { mode, period in
                    save(period, for: mode, replacing: editor.mode)
                },
                onDelete: editor.period.map { period in
                    { delete(period, from: editor.mode) }
                }
            )
        }
    }

    private var currentSchedule: DailySchedule {
        DailySchedule(
            sleepPeriods: sleepPeriods,
            workPeriods: workPeriods
        )
    }

    private func loadSavedSchedule() {
        guard !hasLoadedSavedSchedule else { return }

        sleepPeriods = configuration.schedule.sleepPeriods
        workPeriods = configuration.schedule.workPeriods
        sleepReminderLeadMinutes = Int(configuration.sleepReminderLeadTime / 60)
        hasLoadedSavedSchedule = true
    }

    private func save() -> Bool {
        let schedule = currentSchedule

        if let issue = scheduleValidator.issue(for: schedule) {
            errorMessage = issue.message
            return false
        }

        configuration.save(schedule: schedule)
        configuration.save(
            sleepReminderLeadTime: TimeInterval(sleepReminderLeadMinutes * 60)
        )
        return true
    }

    private func saveEditedScheduleIfNeeded() {
        guard isEditing, hasLoadedSavedSchedule else { return }
        guard currentSchedule != configuration.schedule else { return }

        _ = save()
    }

    private func saveEditedSleepReminderLeadTimeIfNeeded() {
        guard isEditing, hasLoadedSavedSchedule else { return }

        let leadTime = TimeInterval(sleepReminderLeadMinutes * 60)
        guard leadTime != configuration.sleepReminderLeadTime else { return }

        configuration.save(sleepReminderLeadTime: leadTime)
    }

    private func save(
        _ period: DailySchedulePeriod,
        for mode: DailyMode,
        replacing originalMode: DailyMode
    ) -> String? {
        var proposedSleepPeriods = sleepPeriods
        var proposedWorkPeriods = workPeriods

        if mode != originalMode {
            if originalMode == .sleeping {
                proposedSleepPeriods.removeAll { $0.id == period.id }
            } else {
                proposedWorkPeriods.removeAll { $0.id == period.id }
            }
        }

        if mode == .sleeping {
            if let index = proposedSleepPeriods.firstIndex(where: { $0.id == period.id }) {
                proposedSleepPeriods[index] = period
            } else {
                proposedSleepPeriods.append(period)
            }
        } else {
            if let index = proposedWorkPeriods.firstIndex(where: { $0.id == period.id }) {
                proposedWorkPeriods[index] = period
            } else {
                proposedWorkPeriods.append(period)
            }
        }

        let proposedSchedule = DailySchedule(
            sleepPeriods: proposedSleepPeriods,
            workPeriods: proposedWorkPeriods
        )
        if let issue = scheduleValidator.issue(for: proposedSchedule) {
            return issue.message
        }

        sleepPeriods = proposedSleepPeriods
        workPeriods = proposedWorkPeriods
        return nil
    }

    private func delete(_ period: DailySchedulePeriod, from mode: DailyMode) {
        if mode == .sleeping {
            sleepPeriods.removeAll { $0.id == period.id }
        } else {
            workPeriods.removeAll { $0.id == period.id }
        }
    }

    private func onboardingHeader(accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 48, height: 48)
                .background(accent.opacity(0.12), in: Circle())

            Text("Build your daily rhythm")
                .font(.system(size: 32, weight: .bold, design: .rounded))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func continueFooter(accent: Color) -> some View {
        Button {
            if save() {
                dismiss()
            }
        } label: {
            Label("Continue", systemImage: "arrow.right")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.capsule)
        .tint(accent)
        .controlSize(.large)
        .frame(maxWidth: 360)
        .shadow(color: .black.opacity(0.14), radius: 16, y: 8)
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }
}

#Preview {
    NavigationStack {
        SetUpView()
            .environmentObject(PreviewSupport.configuration(named: "setup-empty"))
    }
}

#Preview("Editing") {
    NavigationStack {
        SetUpView(isEditing: true)
            .environmentObject(PreviewSupport.configuration(named: "setup-editing"))
    }
}

#Preview("Editing Existing Schedule") {
    NavigationStack {
        SetUpView(isEditing: true)
            .environmentObject(
                PreviewSupport.configuration(
                    named: "setup-existing",
                    schedule: PreviewSupport.sampleSchedule
                )
            )
    }
}
