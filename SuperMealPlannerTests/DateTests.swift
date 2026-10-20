//  Dates travel as plain `YYYY-MM-DD`, in the phone's own calendar.

import XCTest

final class DateTests: XCTestCase {
    func testAKeyRoundTrips() throws {
        let date = try XCTUnwrap(Dates.date("2026-10-20"))
        XCTAssertEqual(Dates.key(date), "2026-10-20")
    }

    func testTodayAndTomorrowAreNamedNotDated() throws {
        let today = try XCTUnwrap(Dates.date(Dates.key(Date())))
        XCTAssertEqual(Dates.short(Dates.key(today), relativeTo: today), "Today")
        let tomorrow = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 1, to: today))
        XCTAssertEqual(Dates.short(Dates.key(tomorrow), relativeTo: today), "Tomorrow")
    }

    func testSomethingThatIsNotADateIsShownAsItCame() {
        XCTAssertEqual(Dates.short("not-a-date"), "not-a-date")
    }

    func testAnAprilFirstIsNotReadAsJanuaryFourth() throws {
        // The formatter is pinned to en_US_POSIX so a phone set to a different calendar or a
        // day-first locale still sends what the server parses.
        let date = try XCTUnwrap(Dates.date("2026-04-01"))
        let parts = Calendar(identifier: .gregorian).dateComponents([.month, .day], from: date)
        XCTAssertEqual(parts.month, 4)
        XCTAssertEqual(parts.day, 1)
    }
}
