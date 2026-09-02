import XCTest

final class igotuUITests: XCTestCase {
    func testSettingsTabLoadsWithoutHanging() {
        let app = XCUIApplication()
        app.launch()

        let continueButton = app.buttons["Continue"]
        if continueButton.waitForExistence(timeout: 5) {
            continueButton.tap()
        }

        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5))
        settingsTab.tap()

        XCTAssertTrue(app.navigationBars["Schedule"].waitForExistence(timeout: 5))
    }

    func testReminderTestsPageLoads() {
        let app = XCUIApplication()
        app.launch()

        let continueButton = app.buttons["Continue"]
        if continueButton.waitForExistence(timeout: 5) {
            continueButton.tap()
        }

        app.tabBars.buttons["Settings"].tap()
        app.swipeUp()

        let reminderTests = app.buttons["Reminder tests"]
        XCTAssertTrue(reminderTests.waitForExistence(timeout: 5))
        reminderTests.tap()

        XCTAssertTrue(app.navigationBars["Testing"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Drink Water in 1 minute"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Stand Up in 1 minute"].exists)
        XCTAssertTrue(app.buttons["Move Around in 1 minute"].exists)
        XCTAssertTrue(app.buttons["Wind Down in 1 minute"].exists)
    }
}
