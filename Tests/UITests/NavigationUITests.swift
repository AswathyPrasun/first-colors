import XCTest

/// End-to-end flows. `-uiTesting` gives every launch a fresh, throwaway data folder,
/// so each test starts at the first-launch profile picker.
final class NavigationUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launchAsBear() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        let bear = app.buttons["avatar.bear"]
        XCTAssertTrue(bear.waitForExistence(timeout: 5), "first launch shows the profile picker")
        bear.tap()
        XCTAssertTrue(app.buttons["category.fruits"].waitForExistence(timeout: 5))
        return app
    }

    /// The build prompt's acceptance flow: Home → Fruits → Apple → fill body red → Done →
    /// Celebration → My Art shows the apple.
    @MainActor
    func testColorAnAppleAndFindItInMyArt() {
        let app = launchAsBear()

        app.buttons["category.fruits"].tap()
        XCTAssertTrue(app.buttons["item.apple"].waitForExistence(timeout: 5))
        app.buttons["item.apple"].tap()

        let canvas = app.otherElements["drawingCanvas"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))
        app.buttons["color.red"].tap()
        // Middle of the apple body (well below the face's eyes).
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.32, dy: 0.72)).tap()
        XCTAssertTrue(app.buttons["undo"].isEnabled, "the fill happened")

        app.buttons["done"].tap()
        XCTAssertTrue(app.staticTexts["celebrationTitle"].waitForExistence(timeout: 5))
        app.buttons["celebrationMyArt"].tap()

        XCTAssertTrue(app.buttons["art.apple"].waitForExistence(timeout: 5), "My Art shows the apple")
        app.buttons["back"].tap()
        XCTAssertTrue(app.buttons["category.fruits"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testColorMoreReturnsToPickerWithACheck() {
        let app = launchAsBear()

        app.buttons["category.vegetables"].tap()
        XCTAssertTrue(app.buttons["item.carrot"].waitForExistence(timeout: 5))
        app.buttons["item.carrot"].tap()
        XCTAssertTrue(app.buttons["tool.magic"].waitForExistence(timeout: 5))
        app.buttons["tool.magic"].tap()
        app.buttons["done"].tap()
        XCTAssertTrue(app.buttons["colorMore"].waitForExistence(timeout: 5))
        app.buttons["colorMore"].tap()
        let carrot = app.buttons["item.carrot"]
        XCTAssertTrue(carrot.waitForExistence(timeout: 5))
        let expectation = expectation(for: NSPredicate(format: "value == 'Done'"), evaluatedWith: carrot)
        wait(for: [expectation], timeout: 5)
    }

    @MainActor
    func testEmptyGalleryAndParentArea() {
        let app = launchAsBear()

        app.buttons["myArt"].tap()
        XCTAssertTrue(app.images["galleryEmpty"].waitForExistence(timeout: 5))
        app.buttons["back"].tap()

        // The parental gate: a quick tap does nothing, holding 3 seconds opens settings.
        app.buttons["parentLock"].tap()
        let gate = app.otherElements["gateButton"]
        XCTAssertTrue(gate.waitForExistence(timeout: 5))
        gate.tap()
        XCTAssertFalse(app.buttons["parentDone"].waitForExistence(timeout: 1))
        gate.press(forDuration: 3.5)
        XCTAssertTrue(app.buttons["parentDone"].waitForExistence(timeout: 5))
        let offline = app.staticTexts["Works fully offline. No data leaves this device."]
        if !offline.exists { app.swipeUp() }   // below the fold in the smaller iPad sheet
        XCTAssertTrue(offline.waitForExistence(timeout: 3))
        app.buttons["parentDone"].tap()
        XCTAssertTrue(app.buttons["category.fruits"].waitForExistence(timeout: 5))

        // Closing the gate without holding goes straight back.
        app.buttons["parentLock"].tap()
        XCTAssertTrue(app.buttons["gateClose"].waitForExistence(timeout: 5))
        app.buttons["gateClose"].tap()
        XCTAssertTrue(app.buttons["category.fruits"].waitForExistence(timeout: 5))
    }
}
