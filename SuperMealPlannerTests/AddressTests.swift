//  What someone may type as a server address, and what it has to become.

import XCTest

final class AddressTests: XCTestCase {
    func testPlainHostBecomesHTTPS() {
        XCTAssertEqual(ServerAddress.parse("comidas.example.com")?.absoluteString,
                       "https://comidas.example.com")
    }

    func testTrailingSlashAndAPIPathAreDropped() {
        // Someone pastes the address out of the docs, which ends in /api/v1. The client adds that
        // back itself, so keeping it would ask for /api/v1/api/v1/day.
        XCTAssertEqual(ServerAddress.parse("https://comidas.example.com/api/v1/")?.absoluteString,
                       "https://comidas.example.com")
        XCTAssertEqual(ServerAddress.parse("comidas.example.com/")?.absoluteString,
                       "https://comidas.example.com")
    }

    func testPortAndSubpathSurvive() {
        XCTAssertEqual(ServerAddress.parse("192.168.1.9:8080")?.absoluteString,
                       "https://192.168.1.9:8080")
        XCTAssertEqual(ServerAddress.parse("http://pi.local:8080/comidas")?.absoluteString,
                       "http://pi.local:8080/comidas")
    }

    func testPlainHTTPIsKeptWhenAskedFor() {
        XCTAssertEqual(ServerAddress.parse("http://comidas.example.com")?.scheme, "http")
    }

    func testNonsenseIsRefused() {
        XCTAssertNil(ServerAddress.parse(""))
        XCTAssertNil(ServerAddress.parse("   "))
        XCTAssertNil(ServerAddress.parse("https://"))
    }
}
