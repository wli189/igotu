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
        XCTAssertTrue(app.steppers["Test first alert delay"].exists)
        XCTAssertTrue(app.steppers["Test visible duration"].exists)
        XCTAssertTrue(app.steppers["Test repeat delay"].exists)
        XCTAssertTrue(app.buttons["Schedule Drink Water test"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Schedule Stand Up test"].exists)
        XCTAssertTrue(app.buttons["Schedule Move Around test"].exists)
        XCTAssertTrue(app.buttons["Schedule Wind Down test"].exists)
    }
}
