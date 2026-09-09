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

    @State private var periodsByMode: [DailyMode: [DailySchedulePeriod]] = [:]
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
                    periodsByMode: periodsByMode,
                    accent: accent,
                    onAdd: {
                        editorConfiguration = SchedulePeriodEditorConfiguration(
                            mode: DailyMode.defaultScheduleMode,
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
        .onChange(of: periodsByMode) { _, _ in
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
        DailySchedule(periodsByMode: periodsByMode)
    }

    private func loadSavedSchedule() {
        guard !hasLoadedSavedSchedule else { return }

        periodsByMode = configuration.schedule.periodsByMode
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
        var proposedPeriodsByMode = periodsByMode

        if mode != originalMode {
            proposedPeriodsByMode[originalMode, default: []]
                .removeAll { $0.id == period.id }
        }

        var proposedPeriods = proposedPeriodsByMode[mode] ?? []
        if let index = proposedPeriods.firstIndex(where: { $0.id == period.id }) {
            proposedPeriods[index] = period
        } else {
            proposedPeriods.append(period)
        }
        proposedPeriodsByMode[mode] = proposedPeriods

        let proposedSchedule = DailySchedule(periodsByMode: proposedPeriodsByMode)
        if let issue = scheduleValidator.issue(for: proposedSchedule) {
            return issue.message
        }

        periodsByMode = proposedPeriodsByMode
        return nil
    }

    private func delete(_ period: DailySchedulePeriod, from mode: DailyMode) {
        periodsByMode[mode, default: []].removeAll { $0.id == period.id }
        if periodsByMode[mode]?.isEmpty == true {
            periodsByMode.removeValue(forKey: mode)
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
