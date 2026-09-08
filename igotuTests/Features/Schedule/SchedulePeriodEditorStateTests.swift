import Foundation
import Testing
import IgotuCore
@testable import igotu

struct SchedulePeriodEditorStateTests {
    @Test func sleepingPeriodUsesSleepingDefaults() {
        let state = SchedulePeriodEditorState(mode: .sleeping, period: nil)

        #expect(state.selectedMode == .sleeping)
        #expect(timeComponents(from: state.start) == DateComponents(hour: 23, minute: 0))
        #expect(timeComponents(from: state.end) == DateComponents(hour: 7, minute: 0))
        #expect(state.days == Set(Weekday.allCases))
        #expect(state.expandedTimePicker == nil)
    }

    @Test func workPeriodUsesWorkDefaults() {
        let state = SchedulePeriodEditorState(mode: .work, period: nil)

        #expect(state.selectedMode == .work)
        #expect(timeComponents(from: state.start) == DateComponents(hour: 9, minute: 0))
        #expect(timeComponents(from: state.end) == DateComponents(hour: 18, minute: 0))
        #expect(state.days == Weekday.defaultWorkdays)
    }

    @Test func existingPeriodRestoresItsValues() {
        let period = DailySchedulePeriod(
            start: DateComponents(hour: 8, minute: 15),
            end: DateComponents(hour: 16, minute: 45),
            days: [.monday, .wednesday]
        )

        let state = SchedulePeriodEditorState(mode: .work, period: period)

        #expect(timeComponents(from: state.start) == period.start)
        #expect(timeComponents(from: state.end) == period.end)
        #expect(state.days == period.days)
    }

    @Test func applyingDefaultsUpdatesTimeAndDaysForTheMode() {
        var state = SchedulePeriodEditorState(mode: .work, period: nil)
        state.selectedMode = .sleeping

        state.applyDefaults(for: .sleeping)

        #expect(timeComponents(from: state.start) == DateComponents(hour: 23, minute: 0))
        #expect(timeComponents(from: state.end) == DateComponents(hour: 7, minute: 0))
        #expect(state.days == Set(Weekday.allCases))
    }

    private func timeComponents(from date: Date) -> DateComponents {
        Calendar.current.dateComponents([.hour, .minute], from: date)
    }
}
