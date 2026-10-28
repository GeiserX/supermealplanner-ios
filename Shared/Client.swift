//  The one place that talks to a server.
//
//  Every call goes through `send`, so there is a single answer to "what does a 401 mean", "what does
//  the app do when the phone is on a train" and "where does the bearer go". The token is attached
//  here and never passed around the views.

import Foundation

enum ClientError: LocalizedError, Equatable {
    case badAddress
    case notOurs                 // a server that answered, but is not a SuperMealPlanner
    case unpaired                // 401: the token is gone, revoked, or never worked
    case tooManyTries(Int)        // 429 from pairing, with the seconds the server asked for
    case notFound
    case server(Int, String?)
    case offline(String)
    case malformed(String)

    var errorDescription: String? {
        switch self {
        case .badAddress:
            return String(localized: "That is not an address. Try comidas.example.com")
        case .notOurs:
            return String(localized: "Something answered there, but it is not a SuperMealPlanner server.")
        case .unpaired:
            return String(localized: "This phone is not paired any more. Ask the bot for a new code.")
        case .tooManyTries(let seconds):
            let minutes = max(1, seconds / 60)
            return String(localized: "Too many wrong codes. Try again in \(minutes) min.")
        case .notFound:
            return String(localized: "That is not there any more.")
        case .server(let code, let detail):
            return detail ?? String(localized: "The server answered \(code).")
        case .offline:
            return String(localized: "Cannot reach the server. Are you on the house network or the VPN?")
        case .malformed:
            return String(localized: "The server answered something this version does not understand.")
        }
    }
}

struct Client: Sendable {
    var server: URL
    var token: String?
    var session: URLSession = .shared
    var deviceName: String = "Phone"

    private static let decoder: JSONDecoder = JSONDecoder()
    private static let encoder: JSONEncoder = JSONEncoder()

    private func url(_ path: String, _ query: [String: String?] = [:]) -> URL? {
        guard var parts = URLComponents(url: server, resolvingAgainstBaseURL: false) else { return nil }
        parts.path = parts.path + "/api/v1" + path
        let items = query.compactMap { key, value in
            value.map { URLQueryItem(name: key, value: $0) }
        }
        parts.queryItems = items.isEmpty ? nil : items.sorted { $0.name < $1.name }
        return parts.url
    }

    private func send<T: Decodable>(
        _ method: String, _ path: String, query: [String: String?] = [:], body: [String: Any]? = nil
    ) async throws -> T {
        guard let endpoint = url(path, query) else { throw ClientError.badAddress }
        var request = URLRequest(url: endpoint)
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token { request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization") }
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let data: Data, response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ClientError.offline(error.localizedDescription)
        }
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        let retryAfter = (response as? HTTPURLResponse)?
            .value(forHTTPHeaderField: "Retry-After").flatMap(Int.init) ?? 900
        switch code {
        case 200..<300:
            do {
                return try Client.decoder.decode(T.self, from: data)
            } catch {
                throw ClientError.malformed(String(describing: error))
            }
        case 401:
            throw ClientError.unpaired
        case 404:
            throw ClientError.notFound
        case 429:
            throw ClientError.tooManyTries(retryAfter)
        default:
            let detail = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            throw ClientError.server(code, detail?["detail"] as? String)
        }
    }

    // ---------------------------------------------------------------- pairing
    /// Is there a SuperMealPlanner at this address? Called before anyone types a code.
    func ping() async throws -> Ping {
        let got: Ping = try await send("GET", "/ping")
        guard got.isOurs else { throw ClientError.notOurs }
        return got
    }

    /// Swap the bot's six digits for this phone's token.
    func pair(code: String, device: String) async throws -> Paired {
        try await send("POST", "/pair", body: ["code": code, "device": device])
    }

    // ---------------------------------------------------------------- reading
    func meta() async throws -> Meta { try await send("GET", "/meta") }

    func day(_ d: Date? = nil, person: String? = nil) async throws -> Day {
        try await send("GET", "/day", query: ["d": d.map(Dates.key), "person": person])
    }

    func week(_ d: Date? = nil) async throws -> Week {
        try await send("GET", "/week", query: ["d": d.map(Dates.key)])
    }

    func tasks(_ d: Date? = nil) async throws -> Tasks {
        try await send("GET", "/tasks", query: ["d": d.map(Dates.key)])
    }

    func cook(_ d: Date? = nil) async throws -> Cook {
        try await send("GET", "/cook", query: ["d": d.map(Dates.key)])
    }

    func recipe(_ id: String, d: Date? = nil, person: String? = nil) async throws -> RecipeFull {
        try await send("GET", "/recipe/" + id, query: ["d": d.map(Dates.key), "person": person])
    }

    func shopping(_ d: Date? = nil, store: String? = nil) async throws -> Shopping {
        try await send("GET", "/list", query: ["d": d.map(Dates.key), "store": store])
    }

    /// Only the week's ticks: small enough to ask every few seconds while the list is open.
    func ticks(_ d: Date? = nil) async throws -> Ticked {
        try await send("GET", "/list/ticks", query: ["d": d.map(Dates.key)])
    }

    func pantry() async throws -> Pantry { try await send("GET", "/pantry") }

    func progress() async throws -> Progress { try await send("GET", "/progress") }

    func devices() async throws -> Devices { try await send("GET", "/devices") }

    // ---------------------------------------------------------------- writing
    @discardableResult
    func tick(_ ingredient: String, on: Bool, d: Date? = nil) async throws -> Ticked {
        var body: [String: Any] = ["ingredient": ingredient, "on": on]
        if let d { body["d"] = Dates.key(d) }
        return try await send("POST", "/list/tick", body: body)
    }

    @discardableResult
    func have(_ ingredient: String, on: Bool) async throws -> Have {
        try await send("POST", "/list/have", body: ["ingredient": ingredient, "on": on])
    }

    @discardableResult
    func rate(_ recipe: String, vote: Int, person: String? = nil) async throws -> Ack {
        var body: [String: Any] = ["recipe": recipe, "vote": vote]
        if let person { body["person"] = person }
        return try await send("POST", "/rate", body: body)
    }

    @discardableResult
    func log(_ fields: [String: Any]) async throws -> Ack {
        try await send("POST", "/log", body: fields)
    }

    @discardableResult
    func revoke(_ deviceID: Int) async throws -> Ack {
        try await send("DELETE", "/devices/\(deviceID)")
    }

    struct Ack: Codable, Sendable {
        var ok: Bool?
        var person: String?
        var day: String?
        var revoked: Int?
        var recipe: String?
        var vote: Int?
    }
}

/// Dates as the server writes them: a plain `YYYY-MM-DD`, read and written in the phone's own
/// calendar. The server decides what "today" is in the household's timezone; the app only ever says
/// which day it is asking about.
enum Dates {
    static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func key(_ date: Date) -> String { formatter.string(from: date) }

    static func date(_ key: String) -> Date? { formatter.date(from: key) }

    /// "Monday", "Tomorrow", "17 Oct" — whatever the phone's language calls that day.
    static func short(_ key: String, relativeTo today: Date = Date()) -> String {
        guard let date = date(key) else { return key }
        let cal = Calendar.current
        if cal.isDate(date, inSameDayAs: today) { return String(localized: "Today") }
        if let tomorrow = cal.date(byAdding: .day, value: 1, to: today),
           cal.isDate(date, inSameDayAs: tomorrow) { return String(localized: "Tomorrow") }
        return date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated))
    }
}
