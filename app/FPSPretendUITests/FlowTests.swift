import XCTest

final class FlowTests: XCTestCase {
    @MainActor func testFullMinuteAndReplay() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["startButton"].waitForExistence(timeout: 15))
        capture("Title", app: app)
        app.buttons["startButton"].tap()
        XCTAssertTrue(app.buttons["fireButton"].waitForExistence(timeout: 15))
        capture("Game", app: app)
        app.buttons["fireButton"].tap()
        XCTAssertTrue(app.staticTexts["ammoLabel"].label.contains("17"))
        XCTAssertTrue(app.staticTexts["scoreLabel"].label.contains("100"), "Initial center ray must hit the first dummy")
        app.buttons["reloadButton"].tap()
        XCTAssertTrue(app.staticTexts["ammoLabel"].label.contains("18"))
        let aim = app.otherElements["aimArea"]
        let center = aim.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        center.press(forDuration: 0.1, thenDragTo: aim.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.5)))
        XCTAssertTrue(app.buttons["replayButton"].waitForExistence(timeout: 65))
        capture("Result", app: app)
        XCTAssertTrue(app.staticTexts["resultScore"].label.contains("100"))
        XCTAssertTrue(app.staticTexts["resultAccuracy"].label.contains("100"))
        XCTAssertTrue(app.staticTexts["resultCombo"].label.contains("1"))
        app.buttons["replayButton"].tap()
        XCTAssertTrue(app.buttons["fireButton"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["ammoLabel"].label.contains("18"))
        XCTAssertEqual(app.staticTexts["scoreLabel"].label, "000000")
        app.terminate()
    }

    @MainActor private func capture(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
