import XCTest

/// Opt-in: captures the App Store screenshots. Colors a few pictures first so the pickers,
/// gallery and Home show real art. Run on an iPhone 6.9" and an iPad 13" simulator with
/// `TEST_RUNNER_APPSTORE_SHOT_DIR=/some/folder` (skipped otherwise). See `scripts/appstore-screenshots.sh`.
///
/// Shots (1.1): 01 a vehicle being colored, 02 Vehicles picker, 03 Super Kids celebration,
/// 04 Home with all five categories, 05 Rescue Pups picker, 06 My Art.
final class AppStoreScreenshotsUITests: XCTestCase {
    private var app: XCUIApplication!
    private var dir: URL!

    @MainActor
    func testAppStoreScreenshots() throws {
        guard let path = ProcessInfo.processInfo.environment["APPSTORE_SHOT_DIR"] else {
            throw XCTSkip("Set TEST_RUNNER_APPSTORE_SHOT_DIR to save App Store screenshots")
        }
        dir = URL(fileURLWithPath: path)
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()

        XCTAssertTrue(app.buttons["avatar.bear"].waitForExistence(timeout: 5))
        app.buttons["avatar.bear"].tap()
        XCTAssertTrue(app.buttons["category.fruits"].waitForExistence(timeout: 5))

        // Vehicles: a few finished with Magic, so the picker shows colored art.
        openCategory("vehicles")
        for id in ["car", "bus", "police_car", "ambulance", "train"] {
            magicColor(id)
            app.buttons["colorMore"].tap()
            XCTAssertTrue(app.buttons["item.\(id)"].waitForExistence(timeout: 5))
        }

        // Hero: a fire truck half colored, with a crayon stripe on the ladder and the palette glowing.
        open("fire_truck")
        app.buttons["color.red"].tap()
        tapCanvas(0.30, 0.55)                          // body
        app.buttons["tool.crayon"].tap()
        app.buttons["color.yellow"].tap()
        scribble(from: (0.12, 0.345), to: (0.56, 0.345))   // ladder (clipped to it)
        app.buttons["color.light blue"].tap()
        sleep(1)
        shot("01-coloring")
        app.buttons["back"].tap()
        XCTAssertTrue(app.buttons["item.car"].waitForExistence(timeout: 5))
        scrollToTop()
        sleep(2)
        shot("02-vehicles")
        app.buttons["back"].tap()

        // Rescue Pups.
        openCategory("rescue_pups")
        for id in ["fire_pup", "doctor_pup", "builder_pup", "swim_pup", "farm_pup"] {
            magicColor(id)
            app.buttons["colorMore"].tap()
            XCTAssertTrue(app.buttons["item.\(id)"].waitForExistence(timeout: 5))
        }
        scrollToTop()
        sleep(2)
        shot("05-rescue-pups")
        app.buttons["back"].tap()

        // Super Kids: the celebration shot.
        openCategory("super_kids")
        for id in ["heart_boy", "sun_hero"] {
            magicColor(id)
            app.buttons["colorMore"].tap()
            XCTAssertTrue(app.buttons["item.\(id)"].waitForExistence(timeout: 5))
        }
        magicColor("little_star")
        sleep(1)
        shot("03-celebration")
        app.buttons["colorMore"].tap()
        XCTAssertTrue(app.buttons["item.little_star"].waitForExistence(timeout: 5))
        app.buttons["back"].tap()

        // Home and My Art.
        XCTAssertTrue(app.buttons["category.fruits"].waitForExistence(timeout: 5))
        scrollToTop()
        sleep(2)
        shot("04-home")
        let myArt = app.buttons["myArt"]
        for _ in 0..<3 where !myArt.isHittable { app.swipeUp() }
        myArt.tap()
        XCTAssertTrue(app.buttons["art.little_star"].waitForExistence(timeout: 5))
        sleep(2)
        shot("06-my-art")
    }

    // MARK: - Helpers

    @MainActor private func openCategory(_ id: String) {
        let tile = app.buttons["category.\(id)"]
        XCTAssertTrue(tile.waitForExistence(timeout: 5))
        for _ in 0..<3 where !tile.isHittable { app.swipeUp() }
        tile.tap()
        XCTAssertTrue(app.buttons["back"].waitForExistence(timeout: 5))
    }

    @MainActor private func open(_ id: String) {
        let tile = app.buttons["item.\(id)"]
        XCTAssertTrue(tile.waitForExistence(timeout: 5))
        for _ in 0..<4 where !tile.isHittable { app.swipeUp() }
        tile.tap()
        XCTAssertTrue(app.buttons["tool.magic"].waitForExistence(timeout: 5))
    }

    /// Opens an item, colors it with Magic and finishes on the celebration screen.
    @MainActor private func magicColor(_ id: String) {
        open(id)
        app.buttons["tool.magic"].tap()
        app.buttons["done"].tap()
        XCTAssertTrue(app.buttons["colorMore"].waitForExistence(timeout: 5))
    }

    @MainActor private func scrollToTop() {
        for _ in 0..<3 { app.swipeDown() }
    }

    @MainActor private func tapCanvas(_ x: CGFloat, _ y: CGFloat) {
        app.otherElements["drawingCanvas"].coordinate(withNormalizedOffset: CGVector(dx: x, dy: y)).tap()
    }

    @MainActor private func scribble(from a: (CGFloat, CGFloat), to b: (CGFloat, CGFloat)) {
        let canvas = app.otherElements["drawingCanvas"]
        canvas.coordinate(withNormalizedOffset: CGVector(dx: a.0, dy: a.1))
            .press(forDuration: 0.05, thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: b.0, dy: b.1)))
    }

    @MainActor private func shot(_ name: String) {
        let data = XCUIScreen.main.screenshot().pngRepresentation
        try? data.write(to: dir.appendingPathComponent("\(name).png"))
    }
}
