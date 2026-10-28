//  "Try the demo": an invented household that answers in place of a server.
//
//  The rest of the app runs unchanged. `AppModel` hands the views an ordinary `Client` pointed at
//  `DemoServer.address`, on a URLSession whose only protocol is `DemoURLProtocol`, so every screen
//  goes through `Client.send` exactly as it does against a real server. The answers are built here
//  for the current week, so the demo never shows a stale plan, and a tick, a vote, «I have it at
//  home», a log entry or an unpaired phone take effect in memory until the demo is left.
//
//  Everything in it is invented: the household, the two people, the recipes, the stores.

import Foundation

final class DemoServer: @unchecked Sendable {
    /// `.invalid` never resolves (RFC 2606): a request that got past the protocol would fail, not leave.
    static let address = URL(string: "https://demo.supermealplanner.invalid")!
    static let shared = DemoServer()

    /// The session every demo `Client` uses. Ephemeral, so nothing is written to a URL cache on disk.
    static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [DemoURLProtocol.self]
        return URLSession(configuration: config)
    }()

    static let household = "Demo household"
    static let account = Account(server: address, household: household, person: "alex",
                                 personName: "Alex", device: "This phone", deviceID: 1)

    struct Response: Sendable {
        var status: Int
        var body: Data
    }

    // ---------------------------------------------------------------- the household

    private struct Person {
        var id, name: String
        var factor: Double
        var kcalTarget: Int
        var proteinTarget: Double
    }

    private static let people = [
        Person(id: "alex", name: "Alex", factor: 1.0, kcalTarget: 2200, proteinTarget: 120),
        Person(id: "sam", name: "Sam", factor: 0.8, kcalTarget: 1800, proteinTarget: 95),
    ]

    private static let stores: [(id: String, name: String)] = [("corner", "Corner Market"), ("big", "Big Grocer")]

    private static let sections: [(id: String, label: String)] = [
        ("produce", "Fruit and veg"), ("bakery", "Bakery"), ("dairy", "Dairy and eggs"),
        ("meat-fish", "Meat and fish"), ("frozen", "Frozen"), ("pantry", "Pantry"),
    ]

    private struct Ingredient {
        var name: String          // as a list line shows it
        var one: String? = nil    // one piece, for a plate line: "1 apple", not "1 apples"
        var unit: String          // g, ml or pcs
        var section: String
        var store: String
        var pricePerUnit: Double  // per g, ml or piece
    }

    private static let ingredients: [String: Ingredient] = [
        "oats": .init(name: "Rolled oats", unit: "g", section: "pantry", store: "big", pricePerUnit: 0.002),
        "milk": .init(name: "Milk", unit: "ml", section: "dairy", store: "corner", pricePerUnit: 0.001),
        "yogurt": .init(name: "Greek yogurt", unit: "g", section: "dairy", store: "corner", pricePerUnit: 0.004),
        "berries": .init(name: "Frozen berries", unit: "g", section: "frozen", store: "big", pricePerUnit: 0.008),
        "banana": .init(name: "Bananas", one: "Banana", unit: "pcs", section: "produce", store: "corner", pricePerUnit: 0.25),
        "apple": .init(name: "Apples", one: "Apple", unit: "pcs", section: "produce", store: "corner", pricePerUnit: 0.4),
        "peanut-butter": .init(name: "Peanut butter", unit: "g", section: "pantry", store: "big", pricePerUnit: 0.009),
        "eggs": .init(name: "Eggs", one: "Egg", unit: "pcs", section: "dairy", store: "corner", pricePerUnit: 0.3),
        "bread": .init(name: "Wholegrain bread", unit: "g", section: "bakery", store: "corner", pricePerUnit: 0.005),
        "tortillas": .init(name: "Tortillas", one: "Tortilla", unit: "pcs", section: "bakery", store: "big", pricePerUnit: 0.3),
        "chickpeas": .init(name: "Chickpeas", unit: "g", section: "pantry", store: "big", pricePerUnit: 0.003),
        "coconut-milk": .init(name: "Coconut milk", unit: "ml", section: "pantry", store: "big", pricePerUnit: 0.005),
        "rice": .init(name: "Basmati rice", unit: "g", section: "pantry", store: "big", pricePerUnit: 0.003),
        "risotto-rice": .init(name: "Risotto rice", unit: "g", section: "pantry", store: "big", pricePerUnit: 0.004),
        "pasta": .init(name: "Pasta", unit: "g", section: "pantry", store: "big", pricePerUnit: 0.002),
        "noodles": .init(name: "Egg noodles", unit: "g", section: "pantry", store: "big", pricePerUnit: 0.004),
        "pesto": .init(name: "Pesto", unit: "g", section: "pantry", store: "big", pricePerUnit: 0.012),
        "passata": .init(name: "Tomato passata", unit: "g", section: "pantry", store: "big", pricePerUnit: 0.002),
        "lentils": .init(name: "Green lentils", unit: "g", section: "pantry", store: "big", pricePerUnit: 0.003),
        "spinach": .init(name: "Spinach", unit: "g", section: "produce", store: "corner", pricePerUnit: 0.01),
        "tomatoes": .init(name: "Tomatoes", unit: "g", section: "produce", store: "corner", pricePerUnit: 0.003),
        "onion": .init(name: "Onions", unit: "g", section: "produce", store: "corner", pricePerUnit: 0.0015),
        "cucumber": .init(name: "Cucumber", unit: "g", section: "produce", store: "corner", pricePerUnit: 0.003),
        "peppers": .init(name: "Peppers", unit: "g", section: "produce", store: "corner", pricePerUnit: 0.004),
        "broccoli": .init(name: "Broccoli", unit: "g", section: "produce", store: "corner", pricePerUnit: 0.003),
        "potatoes": .init(name: "Potatoes", unit: "g", section: "produce", store: "corner", pricePerUnit: 0.0015),
        "mushrooms": .init(name: "Mushrooms", unit: "g", section: "produce", store: "corner", pricePerUnit: 0.006),
        "feta": .init(name: "Feta", unit: "g", section: "dairy", store: "corner", pricePerUnit: 0.012),
        "parmesan": .init(name: "Parmesan", unit: "g", section: "dairy", store: "corner", pricePerUnit: 0.025),
        "tofu": .init(name: "Firm tofu", unit: "g", section: "dairy", store: "big", pricePerUnit: 0.007),
        "salmon": .init(name: "Salmon fillets", unit: "g", section: "meat-fish", store: "big", pricePerUnit: 0.02),
        "chicken": .init(name: "Chicken breast", unit: "g", section: "meat-fish", store: "big", pricePerUnit: 0.009),
    ]

    private struct Recipe {
        var id, name, kind: String
        var meals: [String]
        var minutes: Int
        var protein: String?
        var tags: [String]
        var freezes: Bool
        var fridgeDays: Int
        var kcal: Double
        var proteinG: Double
        var items: [(id: String, qty: Double)]
        var steps: [String]
    }

    private static let recipes: [Recipe] = [
        Recipe(id: "overnight-oats", name: "Overnight oats with berries", kind: "breakfast", meals: ["breakfast"],
               minutes: 5, protein: nil, tags: ["vegetarian", "make-ahead"], freezes: false, fridgeDays: 2,
               kcal: 420, proteinG: 18, items: [("oats", 60), ("milk", 150), ("berries", 80)],
               steps: ["Stir the oats into the milk in a jar.", "Top with the berries.", "Leave in the fridge overnight."]),
        Recipe(id: "yogurt-bowl", name: "Yogurt with banana and oats", kind: "breakfast", meals: ["breakfast"],
               minutes: 3, protein: nil, tags: ["vegetarian", "quick"], freezes: false, fridgeDays: 1,
               kcal: 380, proteinG: 24, items: [("yogurt", 200), ("banana", 1), ("oats", 30)],
               steps: ["Spoon the yogurt into a bowl.", "Slice the banana on top and scatter the oats."]),
        Recipe(id: "eggs-on-toast", name: "Scrambled eggs on toast", kind: "breakfast", meals: ["breakfast"],
               minutes: 10, protein: "eggs", tags: ["vegetarian", "quick"], freezes: false, fridgeDays: 0,
               kcal: 450, proteinG: 22, items: [("eggs", 2), ("bread", 60), ("tomatoes", 80)],
               steps: ["Whisk the eggs with a pinch of salt.", "Cook gently, stirring, until just set.",
                       "Serve on toast with sliced tomatoes."]),
        Recipe(id: "chickpea-curry", name: "Chickpea and spinach curry", kind: "batch", meals: ["lunch"],
               minutes: 35, protein: "legumes", tags: ["vegan", "batch"], freezes: true, fridgeDays: 4,
               kcal: 640, proteinG: 22,
               items: [("chickpeas", 200), ("coconut-milk", 100), ("spinach", 60), ("onion", 80), ("rice", 70)],
               steps: ["Soften the onion in a little oil.", "Add the chickpeas and coconut milk; simmer 15 minutes.",
                       "Stir in the spinach until it wilts.", "Serve with the rice."]),
        Recipe(id: "lentil-salad", name: "Lentil salad with feta", kind: "batch", meals: ["lunch"],
               minutes: 25, protein: "legumes", tags: ["vegetarian", "batch"], freezes: false, fridgeDays: 3,
               kcal: 520, proteinG: 28,
               items: [("lentils", 80), ("feta", 40), ("cucumber", 100), ("tomatoes", 100)],
               steps: ["Cook the lentils until tender and let them cool.", "Dice the cucumber and tomatoes.",
                       "Toss everything together and crumble the feta on top."]),
        Recipe(id: "tomato-soup", name: "Tomato soup with toast", kind: "batch", meals: ["lunch"],
               minutes: 30, protein: nil, tags: ["vegetarian", "batch"], freezes: true, fridgeDays: 4,
               kcal: 430, proteinG: 14, items: [("passata", 250), ("onion", 80), ("bread", 60)],
               steps: ["Soften the onion.", "Add the passata and a cup of water; simmer 20 minutes.",
                       "Blend until smooth and serve with toast."]),
        Recipe(id: "apple-peanut", name: "Apple with peanut butter", kind: "snack", meals: ["snack"],
               minutes: 2, protein: nil, tags: ["vegan", "quick"], freezes: false, fridgeDays: 0,
               kcal: 250, proteinG: 7, items: [("apple", 1), ("peanut-butter", 25)],
               steps: ["Slice the apple and serve with the peanut butter."]),
        Recipe(id: "salmon-potatoes", name: "Baked salmon with potatoes", kind: "dinner", meals: ["dinner"],
               minutes: 40, protein: "fish", tags: ["oven"], freezes: false, fridgeDays: 1,
               kcal: 610, proteinG: 38, items: [("salmon", 150), ("potatoes", 200), ("broccoli", 120)],
               steps: ["Roast the potatoes for 20 minutes at 200 °C.", "Add the salmon and broccoli to the tray.",
                       "Roast 15 minutes more."]),
        Recipe(id: "tofu-stir-fry", name: "Tofu and vegetable stir-fry", kind: "dinner", meals: ["dinner"],
               minutes: 20, protein: "tofu", tags: ["vegan", "quick"], freezes: false, fridgeDays: 2,
               kcal: 540, proteinG: 26, items: [("tofu", 150), ("noodles", 80), ("peppers", 120), ("broccoli", 80)],
               steps: ["Cook the noodles.", "Fry the tofu until golden.", "Add the vegetables, then the noodles; toss."]),
        Recipe(id: "pasta-pesto", name: "Pasta with pesto and spinach", kind: "dinner", meals: ["dinner"],
               minutes: 15, protein: nil, tags: ["vegetarian", "quick"], freezes: false, fridgeDays: 2,
               kcal: 620, proteinG: 21, items: [("pasta", 90), ("pesto", 30), ("spinach", 40), ("parmesan", 15)],
               steps: ["Boil the pasta.", "Stir in the pesto and spinach.", "Finish with grated parmesan."]),
        Recipe(id: "shakshuka", name: "Shakshuka", kind: "dinner", meals: ["dinner"],
               minutes: 25, protein: "eggs", tags: ["vegetarian"], freezes: false, fridgeDays: 1,
               kcal: 480, proteinG: 24, items: [("eggs", 2), ("passata", 200), ("peppers", 100), ("bread", 50)],
               steps: ["Simmer the peppers in the passata for 10 minutes.", "Make two hollows and crack in the eggs.",
                       "Cover until the whites set. Serve with bread."]),
        Recipe(id: "chicken-fajitas", name: "Chicken fajitas", kind: "dinner", meals: ["dinner"],
               minutes: 25, protein: "chicken", tags: ["quick"], freezes: false, fridgeDays: 2,
               kcal: 590, proteinG: 42, items: [("chicken", 150), ("peppers", 120), ("onion", 60), ("tortillas", 2)],
               steps: ["Slice the chicken, peppers and onion.", "Fry hot until the chicken is cooked through.",
                       "Wrap in warm tortillas."]),
        Recipe(id: "mushroom-risotto", name: "Mushroom risotto", kind: "dinner", meals: ["dinner"],
               minutes: 35, protein: nil, tags: ["vegetarian"], freezes: false, fridgeDays: 2,
               kcal: 560, proteinG: 17, items: [("risotto-rice", 80), ("mushrooms", 150), ("onion", 50), ("parmesan", 20)],
               steps: ["Soften the onion and mushrooms.", "Add the rice and stock a ladle at a time, stirring.",
                       "Finish with parmesan."]),
    ]

    /// The plan by weekday, Monday first. Lunches are cooked in batches, so they repeat.
    private static let rotation: [String: [String]] = [
        "breakfast": ["overnight-oats", "yogurt-bowl", "overnight-oats", "eggs-on-toast", "yogurt-bowl",
                      "eggs-on-toast", "overnight-oats"],
        "lunch": ["chickpea-curry", "chickpea-curry", "lentil-salad", "lentil-salad", "tomato-soup",
                  "tomato-soup", "chickpea-curry"],
        "snack": Array(repeating: "apple-peanut", count: 7),
        "dinner": ["salmon-potatoes", "tofu-stir-fry", "pasta-pesto", "shakshuka", "chicken-fajitas",
                   "mushroom-risotto", "salmon-potatoes"],
    ]

    private static let mealOrder = ["breakfast", "lunch", "snack", "dinner"]

    // ---------------------------------------------------------------- the session's writes

    private let lock = NSLock()
    private var ticks: [String: [(id: String, at: Date)]] = [:]   // per Monday, in the order ticked
    private var have: [String] = []
    private var votes: [String: [String: Int]] = [:]             // person → recipe → vote
    private var weights: [String: [(day: String, kg: Double)]] = [:]
    private var devices: [[String: Any]] = []

    init() { reset() }

    /// Back to the household as it starts: a few things already in the basket, two votes, three phones.
    func reset() {
        lock.lock(); defer { lock.unlock() }
        let now = Date()
        let monday = Self.key(Self.monday(of: now))
        ticks = [monday: [("milk", now.addingTimeInterval(-3600)), ("bread", now.addingTimeInterval(-3000)),
                          ("tomatoes", now.addingTimeInterval(-2400))]]
        have = []
        votes = ["alex": ["shakshuka": 1, "tomato-soup": 1], "sam": ["salmon-potatoes": 1]]
        weights = [:]
        let start: [String: Double] = ["alex": 78.4, "sam": 64.1]
        let drift: [String: Double] = ["alex": -0.12, "sam": -0.05]
        for person in Self.people {
            weights[person.id] = stride(from: 27, through: 0, by: -3).map { back in
                let wobble = [0.2, -0.1, 0.15, -0.2, 0.05, 0.1, -0.15, 0.0, 0.1, -0.05][back / 3 % 10]
                let kg = start[person.id]! + drift[person.id]! * Double(27 - back) / 3 + wobble
                return (Self.key(Self.add(-back, to: now)), (kg * 10).rounded() / 10)
            }
        }
        devices = [
            ["id": 1, "name": "This phone", "person": "alex", "person_name": "Alex",
             "created": Self.key(Self.add(-40, to: now)), "last_seen": Self.key(now)],
            ["id": 2, "name": "Sam's phone", "person": "sam", "person_name": "Sam",
             "created": Self.key(Self.add(-38, to: now)), "last_seen": Self.key(now)],
            ["id": 3, "name": "Kitchen tablet", "person": "alex", "person_name": "Alex",
             "created": Self.key(Self.add(-20, to: now)), "last_seen": Self.key(Self.add(-1, to: now))],
        ]
    }

    // ---------------------------------------------------------------- routing

    func respond(to request: URLRequest) -> Response {
        guard let url = request.url, let parts = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return error(404, "Not Found") }
        // The demo has no token to check, so a request that carries one is a bug in the app.
        if request.value(forHTTPHeaderField: "Authorization") != nil {
            return error(400, "The demo takes no token.")
        }
        var query: [String: String] = [:]
        for item in parts.queryItems ?? [] { query[item.name] = item.value ?? "" }
        let body = request.httpBody.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]
        let method = request.httpMethod ?? "GET"
        var path = parts.path
        guard path.hasPrefix("/api/v1/") else { return error(404, "Not Found") }
        path.removeFirst("/api/v1".count)

        lock.lock(); defer { lock.unlock() }
        let today = Date()
        let d: Date
        if let raw = query["d"] ?? (body["d"] as? String) {
            guard let parsed = Dates.date(raw) else { return error(400, "d must be a date as YYYY-MM-DD") }
            d = Self.calendar.startOfDay(for: parsed)
        } else {
            d = Self.calendar.startOfDay(for: today)
        }
        let person = query["person"] ?? (body["person"] as? String) ?? "alex"
        guard Self.people.contains(where: { $0.id == person }) else {
            return error(400, "person must be someone in the household")
        }

        switch (method, path) {
        case ("GET", "/ping"): return json(["app": "supermealplanner", "version": "demo", "api": 1])
        case ("POST", "/pair"): return error(400, "The demo needs no pairing.")
        case ("GET", "/meta"): return json(meta(today))
        case ("GET", "/day"): return json(day(d, person: person, today: today))
        case ("GET", "/week"): return json(week(d, today: today))
        case ("GET", "/tasks"): return json(tasks(d, today: today))
        case ("GET", "/cook"): return json(cook(d))
        case ("GET", "/list"): return json(shopping(d, store: query["store"]))
        case ("GET", "/list/ticks"): return json(ticked(d))
        case ("POST", "/list/tick"): return tick(body, d: d)
        case ("POST", "/list/have"): return markHave(body)
        case ("GET", "/pantry"): return json(pantry(today))
        case ("POST", "/rate"): return rate(body, person: person)
        case ("POST", "/log"): return log(body, person: person, today: today)
        case ("GET", "/progress"): return json(progress(today))
        case ("GET", "/devices"): return json(["devices": devices.map { $0.merging(["this": ($0["id"] as? Int) == 1]) { a, _ in a } }])
        default: break
        }
        if method == "GET", path.hasPrefix("/recipe/") {
            let id = String(path.dropFirst("/recipe/".count))
            guard let recipe = Self.recipe(id) else { return error(404, "Not Found") }
            return json(full(recipe, d: d, person: person))
        }
        if method == "DELETE", path.hasPrefix("/devices/"), let id = Int(path.dropFirst("/devices/".count)) {
            guard devices.contains(where: { $0["id"] as? Int == id }) else { return error(404, "Not Found") }
            devices.removeAll { $0["id"] as? Int == id }
            return json(["ok": true, "revoked": id])
        }
        return error(404, "Not Found")
    }

    // ---------------------------------------------------------------- reading

    private func meta(_ today: Date) -> [String: Any] {
        ["household": Self.household, "timezone": TimeZone.current.identifier, "locale": "en",
         "version": "demo", "api": 1, "today": Self.key(today),
         "people": Self.people.map { ["id": $0.id, "name": $0.name] },
         "stores": Self.stores.map { ["id": $0.id, "name": $0.name] },
         "device": ["id": 1, "name": "This phone", "person": "alex"]]
    }

    private func day(_ d: Date, person: String, today: Date) -> [String: Any] {
        var totals: [String: (kcal: Double, protein: Double)] = [:]
        let meals = Self.mealOrder.map { meal -> [String: Any] in
            let recipe = Self.planned(meal, on: d)
            let plates = Self.people.map { p -> [String: Any] in
                totals[p.id, default: (0, 0)].kcal += recipe.kcal * p.factor
                totals[p.id, default: (0, 0)].protein += recipe.proteinG * p.factor
                return plate(recipe, for: p)
            }
            return ["meal": meal, "dishes": [["recipe": Self.brief(recipe), "plates": plates]]]
        }
        let tomorrow = Self.planned("lunch", on: Self.add(1, to: d))
        return [
            "day": Self.key(d), "today": Self.key(today), "paused": false, "planned": true,
            "meals": meals, "person": person,
            "people": Self.people.map { p -> [String: Any] in
                ["person": p.id, "name": p.name, "kcal_target": p.kcalTarget, "protein_target": p.proteinTarget,
                 "kcal": Int(totals[p.id]?.kcal ?? 0), "protein_g": (totals[p.id]?.protein ?? 0).rounded(),
                 "factor": p.factor, "toppers": p.id == "alex" ? ["a handful of nuts"] : []]
            },
            "defrost_for_tomorrow": tomorrow.freezes ? [Self.brief(tomorrow)] : [],
            "votes": votes[person] ?? [:],
        ]
    }

    private func week(_ d: Date, today: Date) -> [String: Any] {
        let monday = Self.monday(of: d)
        return ["monday": Self.key(monday), "today": Self.key(today),
                "days": (0..<7).map { i -> [String: Any] in
                    let day = Self.add(i, to: monday)
                    return ["day": Self.key(day), "paused": false,
                            "meals": Self.mealOrder.map { ["meal": $0, "recipe": Self.brief(Self.planned($0, on: day))] }]
                }]
    }

    private func tasks(_ d: Date, today: Date) -> [String: Any] {
        let monday = Self.monday(of: d)
        return ["monday": Self.key(monday), "today": Self.key(today),
                "days": (0..<7).map { i -> [String: Any] in
                    let day = Self.add(i, to: monday)
                    var jobs: [[String: Any]] = []
                    if i == 5 { jobs.append(["at": "10:00", "text": "Shopping at Corner Market and Big Grocer"]) }
                    let batch = batchRecipes(day)
                    if !batch.isEmpty, i == 2 || i == 6 {
                        jobs.append(["at": "17:00", "text": "Batch cook: " + batch.map(\.recipe.name).joined(separator: ", ")])
                    }
                    let next = Self.planned("lunch", on: Self.add(1, to: day))
                    if next.freezes, Self.planned("lunch", on: day).id != next.id {
                        jobs.append(["at": "21:00", "text": "Take the \(next.name.lowercased()) out of the freezer"])
                    }
                    return ["day": Self.key(day), "tasks": jobs]
                }]
    }

    /// The lunches of the next three days, cooked together on `d`.
    private func batchRecipes(_ d: Date) -> [(recipe: Recipe, days: [Date])] {
        var out: [(recipe: Recipe, days: [Date])] = []
        for offset in 1...3 {
            let eat = Self.add(offset, to: d)
            let recipe = Self.planned("lunch", on: eat)
            if let i = out.firstIndex(where: { $0.recipe.id == recipe.id }) {
                out[i].days.append(eat)
            } else {
                out.append((recipe, [eat]))
            }
        }
        return out
    }

    private func cook(_ d: Date) -> [String: Any] {
        let portions = Self.people.reduce(0) { $0 + $1.factor }
        return ["day": Self.key(d),
                "dishes": batchRecipes(d).map { batch -> [String: Any] in
                    let servings = portions * Double(batch.days.count)
                    let names = batch.days.map { Self.weekday($0) }
                    return [
                        "recipe": Self.brief(batch.recipe),
                        "servings": servings,
                        "morning": false,
                        "eat_on": batch.days.map(Self.key),
                        "for_text": "For " + Self.joined(names) + " lunch",
                        "split_text": Self.people.map { "\($0.name) \(Self.number($0.factor))" }.joined(separator: " · "),
                        "lines": batch.recipe.items.map { Self.line($0.id, $0.qty * servings) },
                        "containers": batch.days.map { eat -> [String: Any] in
                            let ahead = Self.calendar.dateComponents([.day], from: d, to: eat).day ?? 0
                            let freeze = batch.recipe.freezes && ahead > 2
                            var box: [String: Any] = [
                                "eat": Self.key(eat), "storage": freeze ? "freezer" : "fridge",
                                "servings": Dictionary(uniqueKeysWithValues: Self.people.map { ($0.id, $0.factor) }),
                            ]
                            if freeze { box["defrost_on"] = Self.key(Self.add(-1, to: eat)) }
                            return box
                        },
                    ]
                }]
    }

    private func full(_ recipe: Recipe, d: Date, person: String) -> [String: Any] {
        let p = Self.people.first { $0.id == person }!
        var out: [String: Any] = [
            "recipe": [
                "id": recipe.id, "name": recipe.name, "meals": recipe.meals, "kind": recipe.kind,
                "minutes": recipe.minutes, "fridge_days": recipe.fridgeDays, "freezes": recipe.freezes,
                "protein": Self.orNull(recipe.protein), "tags": recipe.tags, "serves_note": "One adult portion",
                "ingredients": recipe.items.map { ["id": $0.id, "qty": $0.qty,
                                                   "note": Self.ingredients[$0.id]?.name ?? $0.id] },
                "steps": recipe.steps,
                "nutrition": ["kcal": recipe.kcal, "protein_g": recipe.proteinG],
            ] as [String: Any],
            "plate": plate(recipe, for: p),
        ]
        if let vote = votes[person]?[recipe.id] { out["vote"] = vote }
        return out
    }

    private func shopping(_ d: Date, store: String?, hidingHave: Bool = true) -> [String: Any] {
        let monday = Self.monday(of: d)
        var need: [String: Double] = [:]
        let portions = Self.people.reduce(0) { $0 + $1.factor }
        for i in 0..<7 {
            for meal in Self.mealOrder {
                for item in Self.planned(meal, on: Self.add(i, to: monday)).items {
                    need[item.id, default: 0] += item.qty * portions
                }
            }
        }
        if hidingHave { for id in have { need[id] = nil } }
        let week = ticks[Self.key(monday)] ?? []
        let tickedAt = Dictionary(week.map { ($0.id, Self.stamp($0.at)) }, uniquingKeysWith: { a, _ in a })
        let shown = Self.stores.filter { store == nil || store == "all" || store == $0.id }
        let lists = shown.map { shop -> [String: Any] in
            var total = 0.0
            let sections = Self.sections.compactMap { section -> [String: Any]? in
                let ids = need.keys.filter {
                    Self.ingredients[$0]?.store == shop.id && Self.ingredients[$0]?.section == section.id
                }.sorted { Self.ingredients[$0]!.name < Self.ingredients[$1]!.name }
                guard !ids.isEmpty else { return nil }
                let lines = ids.enumerated().map { position, id -> [String: Any] in
                    let ingredient = Self.ingredients[id]!
                    let qty = Self.rounded(need[id]!, unit: ingredient.unit)
                    let price = (qty * ingredient.pricePerUnit * 100).rounded() / 100
                    total += price
                    return ["ingredient": id, "name": ingredient.name, "section": section.id,
                            "amount": Self.amount(qty, unit: ingredient.unit), "qty": qty, "unit": ingredient.unit,
                            "price": price, "position": position,
                            "ticked": tickedAt[id] != nil, "ticked_at": Self.orNull(tickedAt[id])]
                }
                return ["section": section.id, "lines": lines]
            }
            return ["id": shop.id, "name": shop.name, "total": (total * 100).rounded() / 100, "unpriced": 0,
                    "sections": sections]
        }
        var out: [String: Any] = [
            "monday": Self.key(monday), "view": store ?? "all",
            "views": [["id": "all", "label": "All stores"]] + Self.stores.map { ["id": $0.id, "label": $0.name] },
            "labels": Dictionary(uniqueKeysWithValues: Self.sections.map { ($0.id, $0.label) }),
            "stores": lists, "have": have,
        ]
        out.merge(ticked(d)) { _, new in new }
        return out
    }

    private func ticked(_ d: Date) -> [String: Any] {
        let monday = Self.key(Self.monday(of: d))
        let week = ticks[monday] ?? []
        return ["ok": true, "monday": monday, "ticked": week.map(\.id).sorted(), "ticked_order": week.map(\.id),
                "ticked_at": Dictionary(week.map { ($0.id, Self.stamp($0.at)) }, uniquingKeysWith: { a, _ in a })]
    }

    /// This week's ticks are what is at home, at the amount their line buys; fresh food keeps five
    /// days. The demo does not take the cooking out, the server does.
    private func pantry(_ today: Date) -> [String: Any] {
        let monday = Self.monday(of: today)
        let lines = (shopping(today, store: nil, hidingHave: false)["stores"] as? [[String: Any]] ?? [])
            .flatMap { $0["sections"] as? [[String: Any]] ?? [] }
            .flatMap { $0["lines"] as? [[String: Any]] ?? [] }
        let byID = Dictionary(lines.map { ($0["ingredient"] as? String ?? "", $0) }, uniquingKeysWith: { a, _ in a })
        let fresh: Set<String> = ["produce", "bakery", "dairy", "meat-fish"]
        let items = (ticks[Self.key(monday)] ?? []).compactMap { tick -> [String: Any]? in
            guard let line = byID[tick.id], let ingredient = Self.ingredients[tick.id] else { return nil }
            let since = Self.calendar.startOfDay(for: tick.at)
            return ["ingredient": tick.id, "name": ingredient.name, "qty": line["qty"] ?? 0,
                    "unit": ingredient.unit, "amount": line["amount"] ?? "", "since": Self.key(since),
                    "expires": fresh.contains(ingredient.section) ? Self.key(Self.add(5, to: since)) : NSNull()]
        }.sorted { ($0["name"] as? String ?? "") < ($1["name"] as? String ?? "") }
        return ["day": Self.key(today), "items": items,
                "have": have.compactMap { id in Self.ingredients[id].map { ["ingredient": id, "name": $0.name] } }]
    }

    private func progress(_ today: Date) -> [String: Any] {
        ["today": Self.key(today),
         "people": Self.people.map { p -> [String: Any] in
             let points = weights[p.id] ?? []
             // A plain moving average stands in for the server's smoothing.
             let trend = points.indices.map { i -> [String: Any] in
                 let window = points[max(0, i - 2)...i].map(\.kg)
                 return ["day": points[i].day, "kg": (window.reduce(0, +) / Double(window.count) * 10).rounded() / 10]
             }
             let first = (trend.first?["kg"] as? Double) ?? 0
             let last = (trend.last?["kg"] as? Double) ?? 0
             let weeks = max(1, Double(points.count - 1) * 3 / 7)
             return ["person": p.id, "name": p.name,
                     "weights": points.map { ["day": $0.day, "kg": $0.kg] }, "trend": trend,
                     "trend_kg": last, "rate_kg_week": ((last - first) / weeks * 100).rounded() / 100,
                     "mode": "steady", "kcal": p.kcalTarget, "protein_g": p.proteinTarget,
                     "flags": ["Protein reached the target on 6 of the last 7 days."]]
         }]
    }

    // ---------------------------------------------------------------- writing

    private func tick(_ body: [String: Any], d: Date) -> Response {
        guard let id = body["ingredient"] as? String, let on = body["on"] as? Bool else {
            return error(400, "ingredient and on are required")
        }
        guard Self.ingredients[id] != nil else { return error(404, "Not Found") }
        let monday = Self.key(Self.monday(of: d))
        var week = ticks[monday] ?? []
        week.removeAll { $0.id == id }
        if on { week.append((id, Date())) }
        ticks[monday] = week
        return json(ticked(d))
    }

    private func markHave(_ body: [String: Any]) -> Response {
        guard let id = body["ingredient"] as? String, let on = body["on"] as? Bool else {
            return error(400, "ingredient and on are required")
        }
        guard Self.ingredients[id] != nil else { return error(404, "Not Found") }
        have.removeAll { $0 == id }
        if on { have.append(id) }
        return json(["have": have])
    }

    private func rate(_ body: [String: Any], person: String) -> Response {
        guard let id = body["recipe"] as? String, let vote = body["vote"] as? Int, [-1, 0, 1].contains(vote) else {
            return error(400, "vote must be 1, -1 or 0")
        }
        guard Self.recipe(id) != nil else { return error(404, "Not Found") }
        votes[person, default: [:]][id] = vote == 0 ? nil : vote
        return json(["ok": true, "recipe": id, "vote": vote, "person": person])
    }

    private func log(_ body: [String: Any], person: String, today: Date) -> Response {
        let day = Self.key(today)
        if let kg = (body["kg"] as? NSNumber)?.doubleValue {
            guard (25...300).contains(kg) else { return error(400, "That weight does not look right.") }
            weights[person, default: []].removeAll { $0.day == day }
            weights[person, default: []].append((day, kg))
        }
        return json(["ok": true, "person": person, "day": day])
    }

    // ---------------------------------------------------------------- shapes and helpers

    private func plate(_ recipe: Recipe, for p: Person) -> [String: Any] {
        ["person": p.id, "name": p.name, "recipe": Self.brief(recipe), "factor": p.factor,
         "lines": recipe.items.map { Self.line($0.id, $0.qty * p.factor) },
         "kcal": Int(recipe.kcal * p.factor), "protein_g": (recipe.proteinG * p.factor).rounded()]
    }

    private static func brief(_ r: Recipe) -> [String: Any] {
        ["id": r.id, "name": r.name, "kind": r.kind, "minutes": r.minutes, "tags": r.tags,
         "protein": orNull(r.protein)]
    }

    private static func recipe(_ id: String) -> Recipe? { recipes.first { $0.id == id } }

    private static func planned(_ meal: String, on day: Date) -> Recipe {
        let start = calendar.startOfDay(for: day)
        let index = (calendar.dateComponents([.day], from: monday(of: start), to: start).day ?? 0) % 7
        return recipe(rotation[meal]![index])!
    }

    private static func line(_ id: String, _ qty: Double) -> String {
        let ingredient = ingredients[id]!
        let qty = rounded(qty, unit: ingredient.unit)
        let name = qty == 1 ? ingredient.one ?? ingredient.name : ingredient.name
        return amount(qty, unit: ingredient.unit) + " " + name.lowercased()
    }

    private static func rounded(_ qty: Double, unit: String) -> Double {
        unit == "pcs" ? max(1, qty.rounded()) : max(5, (qty / 5).rounded() * 5)
    }

    private static func amount(_ qty: Double, unit: String) -> String {
        unit == "pcs" ? number(qty) : number(qty) + " " + unit
    }

    private static func number(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
    }

    private static var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        cal.firstWeekday = 2
        return cal
    }

    static func monday(of day: Date) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: day)?.start ?? calendar.startOfDay(for: day)
    }

    private static func add(_ days: Int, to day: Date) -> Date {
        calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: day)) ?? day
    }

    private static func key(_ day: Date) -> String { Dates.key(day) }

    private static func weekday(_ day: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "EEEE"
        return f.string(from: day)
    }

    private static func orNull(_ text: String?) -> Any { text.map { $0 as Any } ?? NSNull() }

    /// "Tuesday", "Tuesday and Wednesday", "Monday, Tuesday and Wednesday".
    private static func joined(_ names: [String]) -> String {
        guard names.count > 1 else { return names.first ?? "" }
        return names.dropLast().joined(separator: ", ") + " and " + names.last!
    }

    private static func stamp(_ when: Date) -> String {
        ISO8601DateFormatter().string(from: when)
    }

    private func json(_ value: Any, status: Int = 200) -> Response {
        Response(status: status, body: (try? JSONSerialization.data(withJSONObject: value)) ?? Data("{}".utf8))
    }

    private func error(_ status: Int, _ detail: String) -> Response {
        json(["detail": detail], status: status)
    }
}

/// Answers every request to the demo address from `DemoServer.shared`.
final class DemoURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host() == DemoServer.address.host()
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        var request = self.request
        // URLSession hands a protocol the body as a stream; read it back so the writes can see it.
        if request.httpBody == nil, let stream = request.httpBodyStream {
            stream.open()
            var data = Data()
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let read = stream.read(&buffer, maxLength: buffer.count)
                if read <= 0 { break }
                data.append(buffer, count: read)
            }
            stream.close()
            request.httpBody = data
        }
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let answer = DemoServer.shared.respond(to: request)
        let response = HTTPURLResponse(url: url, statusCode: answer.status, httpVersion: "HTTP/1.1",
                                       headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: answer.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
