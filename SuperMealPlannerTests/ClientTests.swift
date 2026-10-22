//  The client's side of the contract: where it sends, what it carries, and what each refusal means.

import XCTest

final class ClientTests: XCTestCase {
    private func client(token: String? = "t0ken") -> Client {
        Client(server: URL(string: "https://comidas.example.com")!, token: token,
               session: StubServer.session())
    }

    func testEveryCallGoesUnderAPIV1AndCarriesTheBearer() async throws {
        StubServer.answer = { _ in .init(body: Data(#"{"ok":true,"app":"supermealplanner","api":1}"#.utf8)) }
        _ = try await client().ping()
        let request = try XCTUnwrap(StubServer.seen.first)
        XCTAssertEqual(request.url?.path, "/api/v1/ping")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer t0ken")
    }

    func testAServerThatIsNotOursIsRefusedBeforeAnyoneTypesACode() async {
        StubServer.answer = { _ in .init(body: Data(#"{"ok":true,"app":"something-else"}"#.utf8)) }
        do {
            _ = try await client(token: nil).ping()
            XCTFail("a stranger's server was accepted")
        } catch {
            XCTAssertEqual(error as? ClientError, .notOurs)
        }
    }

    func testTheDayCallSendsTheDateAndThePerson() async throws {
        StubServer.answer = { _ in .init(body: Data(#"{"day":"2026-10-20"}"#.utf8)) }
        _ = try await client().day(Dates.date("2026-10-20")!, person: "ana")
        let url = try XCTUnwrap(StubServer.seen.first?.url)
        let query = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        XCTAssertEqual(query.first { $0.name == "d" }?.value, "2026-10-20")
        XCTAssertEqual(query.first { $0.name == "person" }?.value, "ana")
    }

    func testNilQueryValuesAreLeftOutRatherThanSentEmpty() async throws {
        StubServer.answer = { _ in .init(body: Data(#"{"day":"2026-10-20"}"#.utf8)) }
        _ = try await client().day(nil, person: nil)
        let url = try XCTUnwrap(StubServer.seen.first?.url)
        XCTAssertNil(url.query, "an empty d= would ask the server to parse an empty date")
    }

    func testATickSendsTheIngredientAndTheWeek() async throws {
        StubServer.answer = { _ in .init(body: Data(#"{"monday":"2026-10-19","ticked":["milk"]}"#.utf8)) }
        let got = try await client().tick("milk", on: true, d: Dates.date("2026-10-21")!)
        XCTAssertEqual(got.ticked, ["milk"])
        let request = try XCTUnwrap(StubServer.seen.first)
        XCTAssertEqual(request.httpMethod, "POST")
        let body = try XCTUnwrap(request.httpBody)
        let sent = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(sent["ingredient"] as? String, "milk")
        XCTAssertEqual(sent["on"] as? Bool, true)
        XCTAssertEqual(sent["d"] as? String, "2026-10-21")
    }

    func testTheTicksAloneAreAskedForTheWeek() async throws {
        StubServer.answer = { _ in
            .init(body: Data(#"{"ok":true,"monday":"2026-10-19","ticked":["eggs","milk"],"ticked_order":["milk","eggs"]}"#.utf8))
        }
        let got = try await client().ticks(Dates.date("2026-10-21")!)
        XCTAssertEqual(got.tickedOrder, ["milk", "eggs"])
        let request = try XCTUnwrap(StubServer.seen.first)
        XCTAssertEqual(request.httpMethod, "GET")
        let url = try XCTUnwrap(request.url)
        XCTAssertEqual(url.path, "/api/v1/list/ticks")
        let query = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        XCTAssertEqual(query.first { $0.name == "d" }?.value, "2026-10-21")
    }

    func testFourOhOneMeansThisPhoneIsNotPairedAnyMore() async {
        StubServer.answer = { _ in .init(status: 401, body: Data(#"{"detail":"pair this device first"}"#.utf8)) }
        do {
            _ = try await client().meta()
            XCTFail("a 401 was swallowed")
        } catch {
            XCTAssertEqual(error as? ClientError, .unpaired)
        }
    }

    func testFourTwoNineCarriesTheWaitTheServerAskedFor() async {
        StubServer.answer = { _ in .init(status: 429, headers: ["Retry-After": "600"]) }
        do {
            _ = try await client(token: nil).pair(code: "000000", device: "iPhone")
            XCTFail("the pairing guard was ignored")
        } catch {
            XCTAssertEqual(error as? ClientError, .tooManyTries(600))
        }
    }

    func testAnUnreadableAnswerIsMalformedNotACrash() async {
        StubServer.answer = { _ in .init(body: Data("not json".utf8)) }
        do {
            _ = try await client().meta()
            XCTFail("rubbish was decoded")
        } catch {
            guard case .malformed = (error as? ClientError) else {
                return XCTFail("expected malformed, got \(error)")
            }
        }
    }

    func testTheServersOwnMessageIsWhatThePersonReads() async {
        StubServer.answer = { _ in .init(status: 400, body: Data(#"{"detail":"d must be a date as YYYY-MM-DD"}"#.utf8)) }
        do {
            _ = try await client().day()
            XCTFail("a 400 was swallowed")
        } catch {
            XCTAssertEqual(error.localizedDescription, "d must be a date as YYYY-MM-DD")
        }
    }
}
