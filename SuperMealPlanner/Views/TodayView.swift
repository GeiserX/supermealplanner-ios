//  Today: every meal in the order it is eaten, with this person's plate under each dish.
//
//  The lines are the server's: it scales a recipe by the person's factor and applies their swaps, so
//  the app shows exactly what the web page shows. Nothing is recomputed here.

import SwiftUI

struct TodayView: View {
    @Environment(AppModel.self) private var model

    @State private var date = Date()
    @State private var state: Loaded<Day> = .loading
    @State private var person: String?
    /// The meals folded or unfolded by hand while this page is on screen.
    @State private var folds: [String: Bool] = [:]

    var body: some View {
        NavigationStack {
            List {
                if let since = state.staleSince { StaleNote(since: since) }
                PersonPicker(person: $person)

                switch state {
                case .loading:
                    Loading()
                case .failed(let error):
                    Problem(error: error) { Task { await load() } }
                        .listRowBackground(Color.clear)
                case .live(let day), .cached(let day, _):
                    body(for: day)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(Dates.short(Dates.key(date)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { shift(-1) } label: { Image(systemName: "chevron.left") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { shift(1) } label: { Image(systemName: "chevron.right") }
                }
            }
            .refreshable { await load() }
            .task(id: reloadKey) { await load() }
        }
    }

    private var reloadKey: String { Dates.key(date) + "|" + (person ?? "") }

    private func shift(_ days: Int) {
        date = Calendar.current.date(byAdding: .day, value: days, to: date) ?? date
        folds = [:]
    }

    private func load() async {
        if person == nil { person = model.showing }
        let today = Calendar.current.isDateInToday(date)
        let who = person
        state = await model.fetch(today && who == model.account?.person ? Cache.Key.day : nil) {
            try await $0.day(date, person: who)
        }
    }

    @ViewBuilder
    private func body(for day: Day) -> some View {
        if day.paused {
            Section { Label("No plan today", systemImage: "pause.circle") }
        } else if !day.planned {
            Section {
                Label("Nothing planned for this day", systemImage: "questionmark.circle")
                    .foregroundStyle(.secondary)
            }
        }

        ForEach(day.meals) { block in
            let unfolded = block.isUnfolded(folds)
            Section {
                if unfolded {
                    ForEach(block.dishes) { dish in
                        DishRow(dish: dish, person: person ?? day.person,
                                vote: day.votes[dish.recipe.id], date: date)
                    }
                }
            } header: {
                Button {
                    folds[block.meal] = !unfolded
                } label: {
                    HStack {
                        Label(Names.meal(block.meal), systemImage: Names.icon(block.meal))
                        Spacer()
                        Image(systemName: unfolded ? "chevron.down" : "chevron.right")
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }

        if let mine = day.people.first(where: { $0.person == (person ?? day.person) }) {
            Section("The day") {
                LabeledContent("Calories") {
                    Text("\(mine.kcal ?? 0) / \(mine.kcalTarget ?? 0) kcal")
                }
                LabeledContent("Protein") {
                    Text("\(Int(mine.proteinG ?? 0)) / \(Int(mine.proteinTarget ?? 0)) g")
                }
                if !mine.toppers.isEmpty {
                    LabeledContent("Add on top") { Text(mine.toppers.joined(separator: ", ")) }
                }
            }
        }

        if !day.defrostForTomorrow.isEmpty {
            Section {
                ForEach(day.defrostForTomorrow) { r in
                    Label(r.name, systemImage: "snowflake")
                }
            } header: {
                Text("Take out for tomorrow")
            }
        }
    }
}

struct DishRow: View {
    @Environment(AppModel.self) private var model
    var dish: Day.Dish
    var person: String?
    var vote: Int?
    var date: Date

    var body: some View {
        NavigationLink {
            RecipeView(id: dish.recipe.id, person: person, date: date)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(dish.recipe.name).font(.headline)
                    if vote == 1 { Image(systemName: "hand.thumbsup.fill").foregroundStyle(.green) }
                    if vote == -1 { Image(systemName: "hand.thumbsdown.fill").foregroundStyle(.orange) }
                }
                if let total = dish.together {
                    Text("Everyone together").font(.caption.weight(.semibold))
                    ForEach(total.lines, id: \.self) { line in
                        Text(line).font(.subheadline)
                    }
                    Divider()
                }
                if let plate = dish.plates.first(where: { $0.person == person }) ?? dish.plates.first {
                    ForEach(plate.lines, id: \.self) { line in
                        Text(line).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Text("\(plate.kcal ?? 0) kcal · \(Int(plate.proteinG ?? 0)) g protein")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}
