//  The shapes `/api/v1` answers with. One struct per route, named after it.
//
//  Two rules come from the server's contract (SuperMealPlanner docs/api.md): inside API version 1 a
//  field is added, never renamed or removed. So every field a screen can live without is optional
//  here, and decoding never fails because a server is older than the app. The app checks `api` from
//  `GET /ping` when it needs something newer, rather than crashing on a missing key.

import Foundation

struct Ping: Codable, Sendable {
    var app: String?
    var version: String?
    var api: Int?

    var isOurs: Bool { app == "supermealplanner" }
}

struct Paired: Codable, Sendable {
    var token: String
    var deviceID: Int
    var device: String?
    var person: String?
    var personName: String?
    var household: String?

    enum CodingKeys: String, CodingKey {
        case token, device, person, household
        case deviceID = "device_id"
        case personName = "person_name"
    }
}

struct Person: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var name: String
}

struct Store: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var name: String
}

struct Meta: Codable, Sendable {
    var household: String?
    var timezone: String?
    var locale: String?
    var version: String?
    var api: Int?
    var today: String?
    var people: [Person] = []
    var stores: [Store] = []
    var device: DeviceSelf?

    struct DeviceSelf: Codable, Sendable {
        var id: Int
        var name: String?
        var person: String?
    }
}

struct RecipeBrief: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var name: String
    var kind: String?
    var minutes: Int?
    var tags: [String] = []
    var protein: String?
    var video: String?
}

/// One person's share of a dish: the ingredient lines already scaled, and what it comes to.
struct Plate: Codable, Hashable, Sendable {
    var person: String?
    var name: String?
    var recipe: RecipeBrief?
    var factor: Double?
    var lines: [String] = []
    var kcal: Int?
    var proteinG: Double?

    enum CodingKeys: String, CodingKey {
        case person, name, recipe, factor, lines, kcal
        case proteinG = "protein_g"
    }
}

struct Day: Codable, Sendable {
    var day: String
    var today: String?
    var paused: Bool = false
    var planned: Bool = false
    var meals: [MealBlock] = []
    var people: [Totals] = []
    var defrostForTomorrow: [RecipeBrief] = []
    var votes: [String: Int] = [:]
    var person: String?

    enum CodingKeys: String, CodingKey {
        case day, today, paused, planned, meals, people, votes, person
        case defrostForTomorrow = "defrost_for_tomorrow"
    }

    struct MealBlock: Codable, Hashable, Identifiable, Sendable {
        var meal: String
        var dishes: [Dish] = []
        /// Whether this is the meal of the moment, by the household's clock: it starts unfolded.
        var open: Bool?
        var id: String { meal }

        /// Unfolded as it was left by hand, else as the server judged it. A server that does not
        /// send `open` leaves every meal unfolded, as before.
        func isUnfolded(_ folds: [String: Bool]) -> Bool { folds[meal] ?? open ?? true }
    }

    struct Dish: Codable, Hashable, Identifiable, Sendable {
        var recipe: RecipeBrief
        var plates: [Plate] = []
        var id: String { recipe.id }
    }

    struct Totals: Codable, Hashable, Identifiable, Sendable {
        var person: String
        var name: String?
        var kcalTarget: Int?
        var kcal: Int?
        var proteinTarget: Double?
        var proteinG: Double?
        var factor: Double?
        var toppers: [String] = []
        var daysSinceInjection: Int?
        var id: String { person }

        enum CodingKeys: String, CodingKey {
            case person, name, kcal, factor, toppers
            case kcalTarget = "kcal_target"
            case proteinTarget = "protein_target"
            case proteinG = "protein_g"
            case daysSinceInjection = "days_since_injection"
        }
    }
}

struct Week: Codable, Sendable {
    var monday: String
    var today: String?
    var days: [WeekDay] = []

    struct WeekDay: Codable, Hashable, Identifiable, Sendable {
        var day: String
        var paused: Bool = false
        var meals: [Entry] = []
        var id: String { day }

        struct Entry: Codable, Hashable, Sendable {
            var meal: String
            var recipe: RecipeBrief
        }
    }
}

struct Tasks: Codable, Sendable {
    var monday: String
    var today: String?
    var days: [TaskDay] = []

    struct TaskDay: Codable, Hashable, Identifiable, Sendable {
        var day: String
        var tasks: [Job] = []
        var id: String { day }

        struct Job: Codable, Hashable, Sendable {
            var at: String?
            var text: String
        }
    }
}

struct Cook: Codable, Sendable {
    var day: String
    var dishes: [Batch] = []

    struct Batch: Codable, Hashable, Identifiable, Sendable {
        var recipe: RecipeBrief
        var servings: Double?
        var morning: Bool = false
        var eatOn: [String] = []
        var forText: String?
        var splitText: String?
        var lines: [String] = []
        var containers: [Container] = []
        var id: String { recipe.id }

        enum CodingKeys: String, CodingKey {
            case recipe, servings, morning, lines, containers
            case eatOn = "eat_on"
            case forText = "for_text"
            case splitText = "split_text"
        }

        struct Container: Codable, Hashable, Sendable {
            var eat: String
            var storage: String?
            var defrostOn: String?
            var servings: [String: Double] = [:]

            enum CodingKeys: String, CodingKey {
                case eat, storage, servings
                case defrostOn = "defrost_on"
            }
        }
    }
}

/// The whole recipe as the server stores it, plus this person's plate for the day.
struct RecipeFull: Codable, Sendable {
    var recipe: Full
    var plate: Plate?
    var vote: Int?

    struct Full: Codable, Sendable {
        var id: String
        var name: String
        var meals: [String] = []
        var kind: String?
        var minutes: Int?
        var fridgeDays: Int?
        var freezes: Bool = false
        var protein: String?
        var tags: [String] = []
        var servesNote: String?
        var ingredients: [Item] = []
        var steps: [String] = []
        var nutrition: Nutrition?
        var video: String?

        enum CodingKeys: String, CodingKey {
            case id, name, meals, kind, minutes, freezes, protein, tags, ingredients, steps
            case nutrition, video
            case fridgeDays = "fridge_days"
            case servesNote = "serves_note"
        }

        struct Item: Codable, Hashable, Sendable {
            var id: String
            var qty: Double?
            var note: String?
        }

        struct Nutrition: Codable, Sendable {
            var kcal: Double?
            var proteinG: Double?

            enum CodingKeys: String, CodingKey {
                case kcal
                case proteinG = "protein_g"
            }
        }
    }
}

struct Shopping: Codable, Sendable {
    var monday: String
    var view: String?
    var views: [View] = []
    var labels: [String: String] = [:]
    var stores: [StoreList] = []
    var ticked: [String] = []
    var tickedOrder: [String] = []
    var have: [String] = []

    enum CodingKeys: String, CodingKey {
        case monday, view, views, labels, stores, ticked, have
        case tickedOrder = "ticked_order"
    }

    struct View: Codable, Hashable, Identifiable, Sendable {
        var id: String
        var label: String
    }

    struct StoreList: Codable, Hashable, Identifiable, Sendable {
        var id: String
        var name: String
        var total: Double?
        var unpriced: Int?
        var sections: [Section] = []

        struct Section: Codable, Hashable, Identifiable, Sendable {
            var section: String
            var lines: [Line] = []
            var id: String { section }
        }
    }

    struct Line: Codable, Hashable, Identifiable, Sendable {
        var ingredient: String
        var name: String
        var section: String?
        var amount: String?
        var qty: Double?
        var unit: String?
        var product: String?
        var packs: Double?
        var price: Double?
        var position: Int?
        var id: String { ingredient }
    }
}

extension Shopping.StoreList.Section {
    /// The section as the web page shows it: what is still to buy first, in the section's usual
    /// order (the server's `position`), then what is ticked, the first ticked first. `ticked` is the
    /// week's ticks in the order they were made, so a tick here or on another phone moves the row
    /// at once, without asking for the whole list again.
    func ordered(ticked: [String]) -> [Shopping.Line] {
        var rank: [String: Int] = [:]
        for (n, id) in ticked.enumerated() where rank[id] == nil { rank[id] = n }
        let usual = lines.enumerated().map { (line: $0.element, at: $0.element.position ?? $0.offset) }
        let toBuy = usual.filter { rank[$0.line.ingredient] == nil }.sorted { $0.at < $1.at }
        let done = usual.filter { rank[$0.line.ingredient] != nil }
            .sorted { rank[$0.line.ingredient, default: 0] < rank[$1.line.ingredient, default: 0] }
        return toBuy.map { $0.line } + done.map { $0.line }
    }
}

struct Ticked: Codable, Sendable {
    var monday: String?
    var ticked: [String] = []
    var tickedOrder: [String] = []

    enum CodingKeys: String, CodingKey {
        case monday, ticked
        case tickedOrder = "ticked_order"
    }
}

struct Have: Codable, Sendable {
    var have: [String] = []
}

struct Devices: Codable, Sendable {
    var devices: [Entry] = []

    struct Entry: Codable, Hashable, Identifiable, Sendable {
        var id: Int
        var name: String?
        var person: String?
        var personName: String?
        var created: String?
        var lastSeen: String?
        var this: Bool = false

        enum CodingKeys: String, CodingKey {
            case id, name, person, created, this
            case personName = "person_name"
            case lastSeen = "last_seen"
        }
    }
}

struct Progress: Codable, Sendable {
    var today: String?
    var people: [Entry] = []

    struct Entry: Codable, Hashable, Identifiable, Sendable {
        var person: String
        var name: String?
        var weights: [Point] = []
        var trend: [Point] = []
        var trendKg: Double?
        var rateKgWeek: Double?
        var mode: String?
        var kcal: Int?
        var proteinG: Double?
        var flags: [String] = []
        var changed: String?
        var id: String { person }

        enum CodingKeys: String, CodingKey {
            case person, name, weights, trend, mode, kcal, flags, changed
            case trendKg = "trend_kg"
            case rateKgWeek = "rate_kg_week"
            case proteinG = "protein_g"
        }

        struct Point: Codable, Hashable, Sendable {
            var day: String
            var kg: Double
        }
    }
}

//  ----------------------------------------------------------------------------------------------
//  Missing keys
//
//  Swift's generated decoder demands every non-optional key, default value or not. An api-1 server
//  sends all of the fields above, so a missing one means something went wrong on the other side —
//  and when it does, the right answer is a screen without that field, not a screen that cannot be
//  drawn at all. These three overloads give exactly that: absent reads as empty, while a field of
//  the WRONG type still throws, so a real contract break is not swallowed.
//
//  They apply to every type decoded in this module and nothing else.

extension KeyedDecodingContainer {
    func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
        try decodeIfPresent(Bool.self, forKey: key) ?? false
    }

    func decode<T: Decodable>(_ type: [T].Type, forKey key: Key) throws -> [T] {
        try decodeIfPresent([T].self, forKey: key) ?? []
    }

    func decode<K: Decodable & Hashable, V: Decodable>(
        _ type: [K: V].Type, forKey key: Key
    ) throws -> [K: V] {
        try decodeIfPresent([K: V].self, forKey: key) ?? [:]
    }
}
