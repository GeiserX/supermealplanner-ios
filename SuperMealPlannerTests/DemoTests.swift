//  "Try the demo": every call the app makes is answered by the invented household, through an ordinary
//  `Client`, and the writes take effect for the rest of the session.

import XCTest

final class DemoTests: XCTestCase {
    private let client = Client(server: DemoServer.address, token: nil, session: DemoServer.session)

    override func setUp() {
        DemoServer.shared.reset()
    }

    func testEveryReadTheAppMakesIsAnsweredAndDecodes() async throws {
        let ping = try await client.ping()
        XCTAssertTrue(ping.isOurs)

        let meta = try await client.meta()
        XCTAssertEqual(meta.household, "Demo household")
        XCTAssertEqual(meta.people.map(\.id), ["alex", "sam"])
        XCTAssertEqual(meta.device?.id, 1)

        let day = try await client.day()
        XCTAssertTrue(day.planned)
        XCTAssertEqual(day.meals.map(\.meal), ["breakfast", "lunch", "snack", "dinner"])
        XCTAssertTrue(day.meals.allSatisfy { $0.dishes.first?.plates.count == 2 })
        XCTAssertEqual(day.people.count, 2)
        let samsDay = try await client.day(Date(), person: "sam")
        XCTAssertEqual(samsDay.person, "sam")

        let week = try await client.week()
        XCTAssertEqual(week.days.count, 7)
        XCTAssertTrue(week.days.allSatisfy { $0.meals.count == 4 })
        _ = try await client.week(Calendar.current.date(byAdding: .day, value: 7, to: Date()))

        let tasks = try await client.tasks()
        XCTAssertEqual(tasks.days.count, 7)
        XCTAssertFalse(tasks.days.flatMap(\.tasks).isEmpty)

        let cook = try await client.cook()
        XCTAssertFalse(cook.dishes.isEmpty)
        XCTAssertTrue(cook.dishes.allSatisfy { !$0.lines.isEmpty && !$0.containers.isEmpty })

        // Every dish of the week opens as a recipe.
        for id in Set(week.days.flatMap { $0.meals.map(\.recipe.id) }) {
            let recipe = try await client.recipe(id, d: Date(), person: "alex")
            XCTAssertEqual(recipe.recipe.id, id)
            XCTAssertFalse(recipe.recipe.ingredients.isEmpty)
            XCTAssertFalse(recipe.recipe.steps.isEmpty)
            XCTAssertNotNil(recipe.plate)
        }

        let list = try await client.shopping()
        XCTAssertEqual(list.stores.count, 2)
        XCTAssertFalse(list.ticked.isEmpty, "the demo starts with something in the basket")
        for view in list.views {
            let one = try await client.shopping(nil, store: view.id)
            XCTAssertFalse(one.stores.isEmpty, "store view \(view.id) is empty")
        }

        let ticks = try await client.ticks()
        XCTAssertEqual(ticks.tickedOrder, list.tickedOrder)

        let progress = try await client.progress()
        XCTAssertEqual(progress.people.count, 2)
        XCTAssertFalse(progress.people[0].weights.isEmpty)

        let devices = try await client.devices()
        XCTAssertEqual(devices.devices.filter(\.this).map(\.id), [1])
    }

    func testTheDatesFollowToday() async throws {
        let today = Dates.key(Date())
        let week = try await client.week()
        XCTAssertEqual(week.today, today)
        XCTAssertTrue(week.days.contains { $0.day == today })
        let day = try await client.day()
        XCTAssertEqual(day.day, today)
        let meta = try await client.meta()
        XCTAssertEqual(meta.today, today)
        let lastWeek = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -7, to: Date()))
        let before = try await client.week(lastWeek)
        XCTAssertNotEqual(before.monday, week.monday)
    }

    func testATickStaysForTheSessionAndComesOffAgain() async throws {
        let list = try await client.shopping()
        let line = try XCTUnwrap(list.stores.flatMap { $0.sections.flatMap(\.lines) }
            .first { !list.ticked.contains($0.ingredient) })

        let on = try await client.tick(line.ingredient, on: true)
        XCTAssertTrue(on.ticked.contains(line.ingredient))
        XCTAssertEqual(on.tickedOrder.last, line.ingredient, "the newest tick goes last")
        let ticks = try await client.ticks()
        XCTAssertTrue(ticks.ticked.contains(line.ingredient))
        let again = try await client.shopping()
        XCTAssertTrue(again.ticked.contains(line.ingredient))

        let off = try await client.tick(line.ingredient, on: false)
        XCTAssertFalse(off.ticked.contains(line.ingredient))
        let after = try await client.ticks()
        XCTAssertFalse(after.ticked.contains(line.ingredient))
    }

    func testHaveItAtHomeTakesTheLineOffTheList() async throws {
        func ids() async throws -> Set<String> {
            let list = try await client.shopping()
            return Set(list.stores.flatMap { $0.sections.flatMap { $0.lines.map(\.ingredient) } })
        }
        let before = try await ids()
        XCTAssertTrue(before.contains("rice"))
        let have = try await client.have("rice", on: true)
        XCTAssertEqual(have.have, ["rice"])
        let during = try await ids()
        XCTAssertFalse(during.contains("rice"))
        _ = try await client.have("rice", on: false)
        let after = try await ids()
        XCTAssertTrue(after.contains("rice"))
    }

    func testAVoteShowsOnTheDayAndTheRecipe() async throws {
        let today = try await client.day()
        let dish = try XCTUnwrap(today.meals.first?.dishes.first?.recipe.id)
        try await client.rate(dish, vote: -1, person: "alex")
        let voted = try await client.day()
        XCTAssertEqual(voted.votes[dish], -1)
        let recipe = try await client.recipe(dish, person: "alex")
        XCTAssertEqual(recipe.vote, -1)
        try await client.rate(dish, vote: 0, person: "alex")
        let cleared = try await client.day()
        XCTAssertNil(cleared.votes[dish])
    }

    func testALogEntryAndAnUnpairedPhoneTakeEffect() async throws {
        try await client.log(["kg": 80.5, "person": "sam"])
        let progress = try await client.progress()
        let sam = try XCTUnwrap(progress.people.first { $0.person == "sam" })
        XCTAssertEqual(sam.weights.last?.kg, 80.5)
        XCTAssertEqual(sam.weights.last?.day, Dates.key(Date()))

        try await client.revoke(3)
        let devices = try await client.devices()
        XCTAssertEqual(devices.devices.map(\.id), [1, 2])
    }

    func testTheDemoRefusesWhatARealServerRefuses() async {
        await assertRefused(.notFound) { _ = try await self.client.recipe("no-such-dish") }
        await assertRefused(nil) { _ = try await self.client.pair(code: "123456", device: "Phone") }
        await assertRefused(nil) { try await self.client.log(["kg": 4]) }
        await assertRefused(nil) { _ = try await self.client.day(nil, person: "stranger") }
    }

    func testTheDemoIsNeverSentAToken() async {
        let tokened = Client(server: DemoServer.address, token: "t0ken", session: DemoServer.session)
        await assertRefused(nil) { _ = try await tokened.meta() }
    }

    private func assertRefused(_ expected: ClientError?, _ call: () async throws -> Void,
                               line: UInt = #line) async {
        do {
            try await call()
            XCTFail("the demo accepted it", line: line)
        } catch let error as ClientError {
            if let expected {
                XCTAssertEqual(error, expected, line: line)
            } else if case .server(400, _) = error {
            } else {
                XCTFail("expected a 400, got \(error)", line: line)
            }
        } catch {
            XCTFail("unexpected \(error)", line: line)
        }
    }
}
