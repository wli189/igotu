import Foundation
import Testing
@testable import igotu

struct WellnessThemeTests {
    @Test func dailyModesUseTheirDocumentedThemes() {
        #expect(DailyMode.work.wellnessTheme == .work)
        #expect(DailyMode.idle.wellnessTheme == .home)
        #expect(DailyMode.sleeping.wellnessTheme == .sleep)
    }

    @Test func themesRoundTripThroughCodableIdentity() throws {
        let themes = WellnessTheme.allCases
        let encoded = try JSONEncoder().encode(themes)
        let decoded = try JSONDecoder().decode([WellnessTheme].self, from: encoded)

        #expect(decoded == themes)
    }

    @Test func accentComponentsMatchTheDesignPalette() {
        let work = WellnessTheme.work.accentComponents
        #expect(work.red == 94.0 / 255.0)
        #expect(work.green == 133.0 / 255.0)
        #expect(work.blue == 112.0 / 255.0)

        let study = WellnessTheme.study.accentComponents
        #expect(study.red == 107.0 / 255.0)
        #expect(study.green == 124.0 / 255.0)
        #expect(study.blue == 181.0 / 255.0)

        let home = WellnessTheme.home.accentComponents
        #expect(home.red == 194.0 / 255.0)
        #expect(home.green == 155.0 / 255.0)
        #expect(home.blue == 98.0 / 255.0)

        let sleep = WellnessTheme.sleep.accentComponents
        #expect(sleep.red == 58.0 / 255.0)
        #expect(sleep.green == 64.0 / 255.0)
        #expect(sleep.blue == 90.0 / 255.0)
    }

}
