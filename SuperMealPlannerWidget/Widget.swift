//  The home-screen widget: what is for lunch, without opening anything.
//
//  It reads the plan the app last fetched from the app group, and never calls the server itself. So
//  it needs no token of its own, which is the point: the only copy of the bearer stays in the app's
//  keychain item, and a widget extension that is not signed by us finds nothing useful in the group.
//
//  The timeline refreshes at each meal boundary and whenever the app saves a new day.

import SwiftUI
import WidgetKit

struct Plan: TimelineEntry {
    var date: Date
    var household: String?
    var person: String?
    var meals: [(meal: String, dish: String, lines: [String])]
    var fetched: Date?
    var paired: Bool

    static let placeholder = Plan(
        date: Date(), household: nil, person: nil,
        meals: [(meal: "lunch", dish: "Lentils with rice", lines: ["200 g lentils", "80 g rice"]),
                (meal: "dinner", dish: "Omelette and salad", lines: ["2 eggs", "150 g salad"])],
        fetched: Date(), paired: true)
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Plan { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (Plan) -> Void) {
        completion(context.isPreview ? .placeholder : read())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Plan>) -> Void) {
        // Next refresh at the top of the next hour: meals move on, and the app reloads the timeline
        // itself whenever it fetches a day, so this is only the floor.
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [read()], policy: .after(next)))
    }

    private func read() -> Plan {
        let account = Account.load()
        guard let kept: Cached<Day> = Cache().read(Cache.Key.day) else {
            return Plan(date: Date(), household: account?.household, person: account?.person,
                        meals: [], fetched: nil, paired: account != nil)
        }
        let who = account?.person
        let meals = kept.value.meals.flatMap { block in
            block.dishes.map { dish in
                (meal: block.meal, dish: dish.recipe.name,
                 lines: (dish.plates.first { $0.person == who } ?? dish.plates.first)?.lines ?? [])
            }
        }
        return Plan(date: Date(), household: account?.household, person: who,
                    meals: meals, fetched: kept.fetched, paired: account != nil)
    }
}

struct PlanView: View {
    @Environment(\.widgetFamily) private var family
    var entry: Plan

    private var upcoming: [(meal: String, dish: String, lines: [String])] {
        let order = ["breakfast", "lunch", "snack", "dinner"]
        let hour = Calendar.current.component(.hour, from: entry.date)
        let from = hour < 11 ? 0 : (hour < 16 ? 1 : (hour < 19 ? 2 : 3))
        let rest = entry.meals.filter { (order.firstIndex(of: $0.meal) ?? 0) >= from }
        return rest.isEmpty ? entry.meals : rest
    }

    var body: some View {
        Group {
            if !entry.paired {
                Label("Pair the app first", systemImage: "link.badge.plus")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if entry.meals.isEmpty {
                Label("Open the app to load the plan", systemImage: "arrow.clockwise")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: family == .systemSmall ? 2 : 6) {
                    ForEach(Array(upcoming.prefix(family == .systemSmall ? 1 : 3).enumerated()),
                            id: \.offset) { _, item in
                        VStack(alignment: .leading, spacing: 1) {
                            Text(WidgetNames.meal(item.meal))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(item.dish)
                                .font(family == .systemSmall ? .footnote.weight(.semibold) : .subheadline.weight(.semibold))
                                .lineLimit(2)
                            if family != .systemSmall, let first = item.lines.first {
                                Text(first).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

enum WidgetNames {
    static func meal(_ id: String) -> String {
        switch id {
        case "breakfast": return String(localized: "Breakfast")
        case "lunch": return String(localized: "Lunch")
        case "dinner": return String(localized: "Dinner")
        case "snack": return String(localized: "Snack")
        default: return id.capitalized
        }
    }
}

struct ComidasWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "io.github.geiserx.supermealplanner.plan", provider: Provider()) {
            PlanView(entry: $0)
        }
        .configurationDisplayName("What's cooking")
        .description("Today's plates from your household's plan.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct ComidasWidgetBundle: WidgetBundle {
    var body: some Widget { ComidasWidget() }
}
