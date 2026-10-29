//  "Try the demo", driven through the real screens: no server, so it runs everywhere, CI included.
//
//  It also takes the App Store screenshots. When /tmp/smp-shots exists (a simulator shares the host's
//  /tmp), each screen is written there as a PNG as well as kept as an attachment.

import XCTest

final class DemoUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // English and a US region whatever the simulator is set to, so the screenshots read the same.
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
    }

    func testTheDemoOpensEveryScreenAndLeavesCleanly() throws {
        app.launch()
        // A run before this one may have left the demo open; start from the pairing screen.
        if app.buttons["Leave demo"].waitForExistence(timeout: 3) { app.buttons["Leave demo"].tap() }

        let demo = app.buttons["Try the demo"]
        XCTAssertTrue(demo.waitForExistence(timeout: 10), "the pairing screen has no demo")
        demo.tap()

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10), "the demo did not open")
        XCTAssertTrue(app.buttons["Leave demo"].exists, "the demo banner is missing")
        // The first dish's «Everyone together» block is on the first screen whatever the day. A dish
        // further down, such as the snack, has no row until the list scrolls to it.
        XCTAssertTrue(labelled("Everyone together").waitForExistence(timeout: 10),
                      "today's plan did not load")
        shot("1-today")

        app.tabBars.buttons["Week"].tap()
        XCTAssertTrue(labelled("Chickpea and spinach curry").waitForExistence(timeout: 10))
        shot("2-week")

        app.tabBars.buttons["Shopping"].tap()
        XCTAssertTrue(labelled("Fruit and veg").waitForExistence(timeout: 10), "the list did not load")
        // A tick through the real row, then down to where the basket starts.
        let bananas = labelled("Bananas")
        XCTAssertTrue(bananas.waitForExistence(timeout: 5))
        bananas.tap()
        app.swipeUp()
        XCTAssertTrue(labelled("Tomatoes").waitForExistence(timeout: 5))
        shot("3-shopping")

        app.tabBars.buttons["Kitchen"].tap()
        app.buttons["Cooking"].tap()
        XCTAssertTrue(labelled(" lunch").waitForExistence(timeout: 10), "the batch sheet did not load")
        shot("4-kitchen")

        app.tabBars.buttons["Me"].tap()
        XCTAssertTrue(app.navigationBars["Alex"].waitForExistence(timeout: 10))
        shot("5-me")

        app.buttons["Leave demo"].tap()
        XCTAssertTrue(app.buttons["Try the demo"].waitForExistence(timeout: 10), "leaving the demo did not unpair")
    }

    /// Anything on screen whose label contains the text: a row that is a button folds its texts
    /// into one label, so a plain `staticTexts[...]` lookup misses it.
    private func labelled(_ text: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    private func shot(_ name: String) {
        let screen = app.screenshot()
        let attachment = XCTAttachment(screenshot: screen)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        var folder: ObjCBool = false
        if FileManager.default.fileExists(atPath: "/tmp/smp-shots", isDirectory: &folder), folder.boolValue {
            try? screen.pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/smp-shots/\(name).png"))
        }
    }
}
