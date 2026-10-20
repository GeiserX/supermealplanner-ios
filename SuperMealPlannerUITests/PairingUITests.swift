//  Pairing, driven through the real screens.
//
//  This one talks to a real server, so it only runs when someone hands it one:
//
//      echo '{"server":"comidas.example.com","code":"418203"}' > /tmp/smp-ui.json
//      xcodebuild test -only-testing SuperMealPlannerUITests ...
//
//  The file, not an environment variable: the runner is a process on the simulator, so neither a
//  plain `SMP_SERVER=` nor xcodebuild's `TEST_RUNNER_` prefix reaches it (checked, both arrive
//  empty). A simulator shares the host's /tmp, so a file written there does. Nothing goes in git.
//
//  Without those two it reports skipped. CI has no household server, so CI skips it; it exists for
//  the check before a release, and for the App Store screenshots, which it writes as attachments.

import XCTest

final class PairingUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    func testPairingTheAppOpensTheHousehold() throws {
        guard let data = FileManager.default.contents(atPath: "/tmp/smp-ui.json"),
              let hand = try? JSONDecoder().decode(Hand.self, from: data) else {
            throw XCTSkip("write /tmp/smp-ui.json with {\"server\", \"code\"} to run this against a real server")
        }
        let (server, code) = (hand.server, hand.code)
        app.launch()

        let address = app.textFields.firstMatch
        XCTAssertTrue(address.waitForExistence(timeout: 10), "the pairing screen did not appear")
        address.tap()
        address.typeText(server)

        app.buttons["Check"].tap()
        // The address is checked against GET /ping before anyone types six digits.
        let codeField = app.textFields.element(boundBy: 1)
        XCTAssertTrue(codeField.waitForExistence(timeout: 20), "the server was not recognised")
        codeField.tap()
        codeField.typeText(code)

        app.buttons["Pair"].tap()

        // Paired: the tab bar replaces the pairing form.
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 30), "pairing did not finish")
        shot("today")

        for tab in ["Week", "Shopping", "Kitchen", "Me"] {
            app.tabBars.buttons[tab].tap()
            XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 20), "\(tab) did not open")
            shot(tab.lowercased())
        }
    }

    /// The server and the one-use code, handed over out of band so neither reaches the repository.
    private struct Hand: Decodable {
        var server: String
        var code: String
    }

    private func shot(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
