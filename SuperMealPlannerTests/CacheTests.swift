//  The kept answer: it comes back, it carries when it was fetched, and unpairing wipes it.

import XCTest

final class CacheTests: XCTestCase {
    private var folder: URL!
    private var cache: Cache!

    override func setUpWithError() throws {
        folder = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("cache-test-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        cache = Cache(folder: folder)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    func testAnAnswerComesBackWithTheTimeItWasFetched() throws {
        let when = Date(timeIntervalSince1970: 1_760_000_000)
        cache.write(Cache.Key.day, Day(day: "2026-10-20", planned: true), at: when)
        let kept: Cached<Day> = try XCTUnwrap(cache.read(Cache.Key.day))
        XCTAssertEqual(kept.value.day, "2026-10-20")
        XCTAssertTrue(kept.value.planned)
        XCTAssertEqual(kept.fetched.timeIntervalSince1970, when.timeIntervalSince1970, accuracy: 1)
    }

    func testNothingKeptReadsAsNothing() {
        let kept: Cached<Day>? = cache.read("never-written")
        XCTAssertNil(kept)
    }

    func testUnpairingLeavesNoAnswerBehind() throws {
        cache.write(Cache.Key.day, Day(day: "2026-10-20"))
        cache.write(Cache.Key.list, Shopping(monday: "2026-10-19"))
        cache.clear()
        XCTAssertNil(cache.read(Cache.Key.day, as: Day.self))
        XCTAssertNil(cache.read(Cache.Key.list, as: Shopping.self))
    }

    func testTheCacheNeverHoldsAToken() throws {
        // The one thing that must not be written where the widget, a backup or a file dump can read
        // it. Belt and braces: the keychain is the only home for it, so no cached shape has a field
        // for one in the first place.
        cache.write(Cache.Key.day, Day(day: "2026-10-20"))
        let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            XCTAssertFalse(text.lowercased().contains("token"), "\(file.lastPathComponent) holds a token")
        }
    }
}
