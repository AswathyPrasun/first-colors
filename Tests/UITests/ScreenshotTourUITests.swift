import XCTest

/// Opt-in visual tour: saves a PNG of each main screen for design review.
/// Run with `TEST_RUNNER_SCREENSHOT_DIR=/some/folder` (skipped otherwise).
final class ScreenshotTourUITests: XCTestCase {
    @MainActor
    func testScreenshotTour() throws {
        guard let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] else {
            throw XCTSkip("Set TEST_RUNNER_SCREENSHOT_DIR to save screenshots")
        }
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()

        func shot(_ name: String) {
            let data = XCUIScreen.main.screenshot().pngRepresentation
            try? data.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
        }

        XCTAssertTrue(app.buttons["avatar.bear"].waitForExistence(timeout: 5))
        shot("1-profile-picker")
        app.buttons["avatar.bear"].tap()
        XCTAssertTrue(app.buttons["category.fruits"].waitForExistence(timeout: 5))
        sleep(1)
        shot("2-home")

        app.buttons["category.fruits"].tap()
        XCTAssertTrue(app.buttons["item.apple"].waitForExistence(timeout: 5))
        sleep(1)
        shot("3-picker")

        app.buttons["item.apple"].tap()
        XCTAssertTrue(app.buttons["tool.magic"].waitForExistence(timeout: 5))
        app.buttons["tool.crayon"].tap()
        app.buttons["color.yellow"].tap()
        let canvas = app.otherElements["drawingCanvas"]
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.62))
            .press(forDuration: 0.05, thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.8)))
        app.buttons["tool.magic"].tap()
        sleep(1)
        shot("4-coloring")

        app.buttons["done"].tap()
        XCTAssertTrue(app.staticTexts["celebrationTitle"].waitForExistence(timeout: 5))
        sleep(1)
        shot("5-celebration")

        app.buttons["celebrationMyArt"].tap()
        XCTAssertTrue(app.buttons["art.apple"].waitForExistence(timeout: 5))
        sleep(1)
        shot("6-my-art")

        app.buttons["back"].tap()
        XCTAssertTrue(app.buttons["category.fruits"].waitForExistence(timeout: 5))
        sleep(1)
        shot("7-home-with-art")

        app.buttons["parentLock"].tap()
        let gate = app.otherElements["gateButton"]
        XCTAssertTrue(gate.waitForExistence(timeout: 5))
        shot("8-parental-gate")
        gate.press(forDuration: 3.5)
        XCTAssertTrue(app.buttons["parentDone"].waitForExistence(timeout: 5))
        sleep(1)
        shot("9-parent-area")
        app.buttons["parentExport"].tap()
        sleep(2)
        shot("10-save-to-photos")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["parentProfiles"].waitForExistence(timeout: 5))
        app.buttons["parentProfiles"].tap()
        sleep(2)
        shot("11-profiles")
    }

    /// The parent area at the largest accessibility text size.
    @MainActor
    func testParentAreaAtLargestTextSize() throws {
        guard let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] else {
            throw XCTSkip("Set TEST_RUNNER_SCREENSHOT_DIR to save screenshots")
        }
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.buttons["avatar.bear"].waitForExistence(timeout: 5))
        app.buttons["avatar.bear"].tap()
        XCTAssertTrue(app.buttons["parentLock"].waitForExistence(timeout: 5))
        app.buttons["parentLock"].tap()
        let gate = app.otherElements["gateButton"]
        XCTAssertTrue(gate.waitForExistence(timeout: 5))
        let data = XCUIScreen.main.screenshot().pngRepresentation
        try? data.write(to: URL(fileURLWithPath: dir).appendingPathComponent("xxxl-gate.png"))
        gate.press(forDuration: 3.5)
        XCTAssertTrue(app.buttons["parentDone"].waitForExistence(timeout: 5))
        sleep(1)
        app.swipeUp()
        sleep(1)
        let parent = XCUIScreen.main.screenshot().pngRepresentation
        try? parent.write(to: URL(fileURLWithPath: dir).appendingPathComponent("xxxl-parent.png"))
    }

    /// iPad only: Home, picker and coloring in portrait and landscape.
    @MainActor
    func testIPadLayouts() throws {
        guard let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] else {
            throw XCTSkip("Set TEST_RUNNER_SCREENSHOT_DIR to save screenshots")
        }
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        guard app.windows.firstMatch.frame.width >= 700 || app.windows.firstMatch.frame.height >= 1000 else {
            throw XCTSkip("iPad only")
        }
        func shot(_ name: String) {
            sleep(1)
            let data = XCUIScreen.main.screenshot().pngRepresentation
            try? data.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
        }
        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(app.buttons["avatar.bear"].waitForExistence(timeout: 5))
        app.buttons["avatar.bear"].tap()
        XCTAssertTrue(app.buttons["category.fruits"].waitForExistence(timeout: 5))
        shot("ipad-portrait-home")
        app.buttons["category.fruits"].tap()
        XCTAssertTrue(app.buttons["item.apple"].waitForExistence(timeout: 5))
        shot("ipad-portrait-picker")
        app.buttons["item.apple"].tap()
        XCTAssertTrue(app.buttons["tool.magic"].waitForExistence(timeout: 5))
        app.buttons["tool.magic"].tap()
        shot("ipad-portrait-coloring")
        XCUIDevice.shared.orientation = .landscapeLeft
        shot("ipad-landscape-coloring")
        app.buttons["back"].tap()
        XCTAssertTrue(app.buttons["item.apple"].waitForExistence(timeout: 5))
        shot("ipad-landscape-picker")
        XCUIDevice.shared.orientation = .portrait
    }
}
