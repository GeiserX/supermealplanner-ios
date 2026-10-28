//  The shopping list, which is the screen that gets used standing in a shop.
//
//  So a tick moves at once and the server catches up: the row flips locally, the POST goes out, and
//  if it fails the row flips back and says why. The ticks are the household's, not this phone's —
//  the same list on the laptop shows them, because both read one database.
//
//  Each section shows what is still to buy first and what is in the basket below, the first ticked
//  first, as the web page does. While the list is open it asks for the week's ticks every few
//  seconds, so a tick made on another phone or on the web page moves the row here too.
//
//  Below the list is the pantry, as the server works it out: a tick brings in what the line buys,
//  the cooking takes it out, fresh food goes off. The app only shows it.

import SwiftUI

struct ShoppingView: View {
    @Environment(AppModel.self) private var model

    @State private var monday = Date()
    @State private var store: String?
    @State private var state: Loaded<Shopping> = .loading
    @State private var ticked: Set<String> = []
    @State private var tickOrder: [String] = []
    @State private var have: Set<String> = []
    @State private var pantry: Pantry?
    @State private var inFlight: Set<String> = []
    @State private var problem: String?
    @State private var hideTicked = false

    var body: some View {
        NavigationStack {
            List {
                if let since = state.staleSince { StaleNote(since: since) }
                if let problem {
                    Text(problem).font(.footnote).foregroundStyle(.red)
                }

                switch state {
                case .loading:
                    Loading()
                case .failed(let error):
                    Problem(error: error) { Task { await load() } }
                        .listRowBackground(Color.clear)
                case .live(let list), .cached(let list, _):
                    if list.views.count > 1 {
                        Picker("Store", selection: Binding(get: { store ?? list.views[0].id },
                                                           set: { store = $0 })) {
                            ForEach(list.views) { Text($0.label).tag($0.id) }
                        }
                        .pickerStyle(.menu)
                        .listRowBackground(Color.clear)
                    }
                    body(for: list)
                }
            }
            .listStyle(.insetGrouped)
            .animation(.default, value: tickOrder)
            .navigationTitle("Shopping")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Toggle("Hide what is in the basket", isOn: $hideTicked)
                        Button("Previous week") { shift(-7) }
                        Button("Next week") { shift(7) }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .refreshable { await load() }
            .task(id: Dates.key(monday) + "|" + (store ?? "")) { await load() }
            .task(id: Dates.key(monday)) { await follow() }
        }
    }

    private func shift(_ days: Int) {
        monday = Calendar.current.date(byAdding: .day, value: days, to: monday) ?? monday
    }

    private func load() async {
        let thisWeek = Calendar.current.isDate(monday, equalTo: Date(), toGranularity: .weekOfYear)
        state = await model.fetch(thisWeek && store == nil ? Cache.Key.list : nil) {
            try await $0.shopping(monday, store: store)
        }
        if let list = state.value {
            apply(list.ticked, order: list.tickedOrder)
            have = Set(list.have)
        }
        await loadPantry()
    }

    /// The pantry is what is at home now, so it shows under this week's list only. A server older
    /// than the pantry answers 404: then there is no pantry to show. A 401 unpairs, as everywhere.
    private func loadPantry() async {
        let thisWeek = Calendar.current.isDate(monday, equalTo: Date(), toGranularity: .weekOfYear)
        pantry = thisWeek ? await model.fetch(nil) { try await $0.pantry() }.value : nil
    }

    /// Ask for the week's ticks every few seconds while the list is on screen. A tick of ours still
    /// on its way wins: its own answer will carry the server's state.
    private func follow() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled, inFlight.isEmpty, state.value != nil,
                  let client = model.client else { continue }
            if let got = try? await client.ticks(monday), !Task.isCancelled, inFlight.isEmpty {
                apply(got.ticked, order: got.tickedOrder)
            }
        }
    }

    /// The server's ticks replace ours. A server that does not send the order yet still has them
    /// below what is left to buy.
    private func apply(_ ids: [String], order: [String]) {
        ticked = Set(ids)
        tickOrder = order.isEmpty ? ids : order
    }

    @ViewBuilder
    private func body(for list: Shopping) -> some View {
        if list.stores.isEmpty {
            Section { Text("No list for this week yet.").foregroundStyle(.secondary) }
        }
        ForEach(list.stores) { shop in
            ForEach(shop.sections) { section in
                let lines = section.ordered(ticked: tickOrder)
                    .filter { !hideTicked || !ticked.contains($0.ingredient) }
                if !lines.isEmpty {
                    Section {
                        ForEach(lines) { line in
                            LineRow(line: line,
                                    ticked: ticked.contains(line.ingredient),
                                    have: have.contains(line.ingredient),
                                    busy: inFlight.contains(line.ingredient),
                                    tick: { tick(line, on: !ticked.contains(line.ingredient)) },
                                    atHome: { atHome(line, on: !have.contains(line.ingredient)) })
                        }
                    } header: {
                        Text(Names.section(section.section, list.labels))
                    } footer: {
                        if section.id == shop.sections.last?.id, let total = shop.total, total > 0 {
                            Text("\(shop.name): about \(total, format: .number.precision(.fractionLength(2)))")
                        }
                    }
                }
            }
        }
        if let pantry {
            PantrySection(pantry: pantry, stocked: Set(list.stocked))
        }
    }

    /// Flip now, tell the server, flip back if it refuses. The server's answer replaces the set, so
    /// another phone's tick arriving in the same second is not lost.
    private func tick(_ line: Shopping.Line, on: Bool) {
        guard let client = model.client else { return }
        let id = line.ingredient
        let was = tickOrder.firstIndex(of: id)
        tickOrder.removeAll { $0 == id }
        if on {
            ticked.insert(id)
            tickOrder.append(id)
        } else {
            ticked.remove(id)
        }
        inFlight.insert(id)
        problem = nil
        Task {
            defer { inFlight.remove(id) }
            do {
                let got = try await client.tick(id, on: on, d: monday)
                apply(got.ticked, order: got.tickedOrder)
                await loadPantry()   // the tick brought the line in, or took it out again
            } catch {
                tickOrder.removeAll { $0 == id }
                if on {
                    ticked.remove(id)
                } else {
                    ticked.insert(id)
                    tickOrder.insert(id, at: min(was ?? tickOrder.count, tickOrder.count))
                }
                problem = error.localizedDescription
            }
        }
    }

    private func atHome(_ line: Shopping.Line, on: Bool) {
        guard let client = model.client else { return }
        let id = line.ingredient
        if on { have.insert(id) } else { have.remove(id) }
        inFlight.insert(id)
        Task {
            defer { inFlight.remove(id) }
            do {
                let got = try await client.have(id, on: on)
                have = Set(got.have)
                await load()      // off every list now, so the list itself changes
            } catch {
                if on { have.remove(id) } else { have.insert(id) }
                problem = error.localizedDescription
            }
        }
    }
}

struct PantrySection: View {
    var pantry: Pantry
    var stocked: Set<String>

    var body: some View {
        Section {
            if pantry.items.isEmpty && pantry.have.isEmpty {
                Text("Nothing yet: what you tick on the list comes in here.").foregroundStyle(.secondary)
            }
            ForEach(pantry.items) { item in
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                        if stocked.contains(item.ingredient) {
                            Text("Enough for this week: off the list").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        if let amount = item.amount { Text(amount).font(.callout) }
                        if let expires = item.expires {
                            Text("Goes off \(Dates.short(expires))").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            ForEach(pantry.have) { item in
                HStack {
                    Text(item.name)
                    Spacer()
                    Label("Have it", systemImage: "house").labelStyle(.iconOnly).foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("In the pantry")
        } footer: {
            Text("Worked out by the app: a tick adds what you bought, each cooking takes its ingredients out and fresh food goes off. Tell the assistant when something ran out or how much there is.")
        }
    }
}

struct LineRow: View {
    var line: Shopping.Line
    var ticked: Bool
    var have: Bool
    var busy: Bool
    var tick: () -> Void
    var atHome: () -> Void

    var body: some View {
        Button(action: tick) {
            HStack(alignment: .firstTextBaseline) {
                Image(systemName: ticked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(ticked ? Color.accentColor : Color.secondary)
                    .imageScale(.large)
                VStack(alignment: .leading, spacing: 2) {
                    Text(line.name)
                        .strikethrough(ticked)
                        .foregroundStyle(ticked ? .secondary : .primary)
                    if let product = line.product {
                        Text(product).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if busy {
                    ProgressView()
                } else {
                    VStack(alignment: .trailing, spacing: 2) {
                        if let amount = line.amount { Text(amount).font(.callout) }
                        if let price = line.price {
                            Text(price, format: .number.precision(.fractionLength(2)))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .leading) {
            Button(action: atHome) {
                Label(have ? "Need it" : "Have it", systemImage: have ? "cart.badge.plus" : "house")
            }
            .tint(have ? .orange : .indigo)
        }
    }
}
