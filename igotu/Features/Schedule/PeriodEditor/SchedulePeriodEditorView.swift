import SwiftUI
import IgotuCore

struct SchedulePeriodEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let initialPeriod: DailySchedulePeriod?
    let isRegularWidth: Bool
    private let iPadPreferredHeight: CGFloat
    let onSave: (DailyMode, DailySchedulePeriod) -> String?
    let onDelete: (() -> Void)?

    @State private var editorState: SchedulePeriodEditorState
    @State private var selectedDetent: PresentationDetent = .large
    @State private var iPadSelectedDetent: PresentationDetent
    @State private var errorMessage: String?

    private var accent: Color {
        ThemeColorService().color(for: editorState.selectedMode.wellnessTheme)
    }

    init(
        mode: DailyMode,
        period: DailySchedulePeriod?,
        isRegularWidth: Bool = false,
        onSave: @escaping (DailyMode, DailySchedulePeriod) -> String?,
        onDelete: (() -> Void)? = nil
    ) {
        initialPeriod = period
        self.isRegularWidth = isRegularWidth
        self.onSave = onSave
        self.onDelete = onDelete

        let iPadHeight: CGFloat = 560
        iPadPreferredHeight = iPadHeight
        _iPadSelectedDetent = State(initialValue: .height(iPadHeight))
        _editorState = State(
            initialValue: SchedulePeriodEditorState(mode: mode, period: period)
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                SchedulePeriodEditorFields(
                    state: $editorState,
                    accent: accent,
                    onTimePickerExpanded: expandPresentation
                )
                .padding(20)
                .ambientSurface(cornerRadius: 24)
                .padding(20)
            }
            .scrollIndicators(.hidden)
            .background {
                AmbientBackground(color: accent)
            }
            .navigationTitle(editorState.selectedMode.title)
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
                            onDelete?()
                            dismiss()
                        }
                    }
                }
            }
            .onChange(of: editorState.selectedMode) { _, mode in
                guard initialPeriod == nil else { return }
                editorState.applyDefaults(for: mode)
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
        }
        .tint(accent)
        .modifier(ScheduleEditorPresentationModifier(
            isRegularWidth: isRegularWidth,
            selectedDetent: $selectedDetent,
            iPadSelectedDetent: $iPadSelectedDetent,
            iPadPreferredHeight: iPadPreferredHeight
        ))
    }

    private func expandPresentation() {
        if isRegularWidth {
            iPadSelectedDetent = .large
        } else {
            selectedDetent = .large
        }
    }

    private func save() {
        guard !editorState.days.isEmpty else {
            errorMessage = "Select at least one active day."
            return
        }

        let startComponents = components(from: editorState.start)
        let endComponents = components(from: editorState.end)
        guard startComponents != endComponents else {
            errorMessage = "Your (editorState.selectedMode.startTitle.lowercased()) "
                + "and (editorState.selectedMode.endTitle.lowercased()) cannot be the same."
            return
        }

        let period = DailySchedulePeriod(
            id: initialPeriod?.id ?? UUID(),
            start: startComponents,
            end: endComponents,
            days: editorState.days
        )

        if let message = onSave(editorState.selectedMode, period) {
            errorMessage = message
        } else {
            dismiss()
        }
    }

    private func components(from date: Date) -> DateComponents {
        Calendar.current.dateComponents([.hour, .minute], from: date)
    }
}

private struct ScheduleEditorPresentationModifier: ViewModifier {
    let isRegularWidth: Bool
    @Binding var selectedDetent: PresentationDetent
    @Binding var iPadSelectedDetent: PresentationDetent
    let iPadPreferredHeight: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        if isRegularWidth {
            content
                .presentationDetents(
                    [.height(iPadPreferredHeight), .large],
                    selection: $iPadSelectedDetent
                )
                .presentationSizing(.form)
                .presentationDragIndicator(.visible)
        } else {
            content
                .presentationDetents([.medium, .large], selection: $selectedDetent)
                .presentationDragIndicator(.visible)
        }
    }
}

#Preview("New Work Period") {
    SchedulePeriodEditorView(
        mode: .work,
        period: nil,
        onSave: { _, _ in nil }
    )
    .environmentObject(PreviewSupport.configuration(named: "period-editor-work"))
}

#Preview("New Sleep Period") {
    SchedulePeriodEditorView(
        mode: .sleeping,
        period: nil,
        onSave: { _, _ in nil }
    )
    .environmentObject(PreviewSupport.configuration(named: "period-editor-sleep"))
}

#Preview("Edit Existing Period") {
    SchedulePeriodEditorView(
        mode: .work,
        period: DailySchedulePeriod(
            start: DateComponents(hour: 8, minute: 30),
            end: DateComponents(hour: 17),
            days: Weekday.defaultWorkdays
        ),
        isRegularWidth: true,
        onSave: { _, _ in nil },
        onDelete: {}
    )
    .environmentObject(PreviewSupport.configuration(named: "period-editor-existing"))
}
