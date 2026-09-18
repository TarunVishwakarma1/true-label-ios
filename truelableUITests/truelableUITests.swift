import XCTest

final class truelableUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    @discardableResult
    private func launchOnboarded() -> XCUIApplication {
        let app = XCUIApplication()

        app.launchArguments = ["UITEST_RESET_STATE"]
        app.launch()
        app.buttons["Continue"].tap()
        app.buttons["Continue"].tap()
        app.buttons["Start scanning"].tap()
        return app
    }

    @MainActor
    func testOnboardingCompletionReachesHomeTab() throws {
        let app = launchOnboarded()

        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Products"].exists)
    }

    @MainActor
    func testAllFourTabsAreReachable() throws {
        let app = launchOnboarded()

        for tab in ["History", "Verify", "You", "Home"] {
            let button = app.tabBars.buttons[tab]
            XCTAssertTrue(button.waitForExistence(timeout: 5), "\(tab) tab should exist")
            button.tap()
            XCTAssertTrue(button.isSelected, "\(tab) tab should be selected after tapping it")
        }
    }

    @MainActor
    func testManualEntrySheetOpensAndCloses() throws {
        let app = launchOnboarded()

        app.buttons["Type a barcode"].tap()
        XCTAssertTrue(app.staticTexts["Type the barcode"].waitForExistence(timeout: 5))

        app.buttons["Close"].tap()
        XCTAssertFalse(app.staticTexts["Type the barcode"].waitForExistence(timeout: 2))
    }

    @MainActor
    private func clearAndType(_ field: XCUIElement, _ text: String) {
        if let current = field.value as? String, !current.isEmpty {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        field.typeText(text)
    }

    @MainActor
    func testManualEntryValidatesBarcodeChecksum() throws {
        let app = launchOnboarded()
        app.buttons["Type a barcode"].tap()

        let field = app.textFields["8901234567890"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        let lookItUp = app.buttons["Look it up"]

        field.tap()
        clearAndType(field, "123")
        XCTAssertFalse(lookItUp.isEnabled, "an incomplete code must not enable the button")

        clearAndType(field, "1234567890123")
        XCTAssertFalse(lookItUp.isEnabled, "a bad checksum must not enable the button")

        clearAndType(field, "8901234567890")
        XCTAssertTrue(lookItUp.waitForExistence(timeout: 2))
        XCTAssertTrue(lookItUp.isEnabled, "a valid checksum must enable the button")

        clearAndType(field, "abc12")
        XCTAssertEqual(field.value as? String, "12")
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
