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
        let firstAlertMinus = app.buttons["Test first alert delay minus"]
        let firstAlertPlus = app.buttons["Test first alert delay plus"]
        let firstAlertValue = app.staticTexts["Test first alert delay value"]
        XCTAssertTrue(firstAlertMinus.waitForExistence(timeout: 5))
        XCTAssertTrue(firstAlertPlus.exists)
        XCTAssertTrue(firstAlertValue.exists)
        let initialFirstAlertValue = firstAlertValue.label
        firstAlertPlus.tap()
        XCTAssertNotEqual(firstAlertValue.label, initialFirstAlertValue)
        firstAlertMinus.tap()
        XCTAssertEqual(firstAlertValue.label, initialFirstAlertValue)

        XCTAssertTrue(app.buttons["Test visible duration minus"].exists)
        XCTAssertTrue(app.buttons["Test visible duration plus"].exists)
        XCTAssertTrue(app.buttons["Test repeat delay minus"].exists)
        XCTAssertTrue(app.buttons["Test repeat delay plus"].exists)
        XCTAssertTrue(app.buttons["Schedule Drink Water test"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Schedule Stand Up test"].exists)
        XCTAssertTrue(app.buttons["Schedule Move Around test"].exists)
        XCTAssertTrue(app.buttons["Schedule Wind Down test"].exists)
    }

    func testExpandingWorkEndKeepsEveningTime() {
        let app = XCUIApplication()
        app.launch()

        let continueButton = app.buttons["Continue"]
        if continueButton.waitForExistence(timeout: 5) {
            continueButton.tap()
        }

        app.tabBars.buttons["Settings"].tap()

        let addTimePeriod = app.buttons["Add time period"]
        XCTAssertTrue(addTimePeriod.waitForExistence(timeout: 5))
        addTimePeriod.tap()

        let workEnds = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Work ends'")
        ).firstMatch
        XCTAssertTrue(workEnds.waitForExistence(timeout: 5))
        XCTAssertTrue(workEnds.label.contains("6:00"))
        XCTAssertTrue(workEnds.label.contains("PM"))

        workEnds.tap()

        let pmWheel = app.pickerWheels["PM"]
        XCTAssertTrue(pmWheel.waitForExistence(timeout: 5))
        XCTAssertTrue(workEnds.label.contains("PM"))
    }
}
