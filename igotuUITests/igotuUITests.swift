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
}
