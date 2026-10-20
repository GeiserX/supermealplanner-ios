//  The kitchen: what has to happen, and what to cook on a batch afternoon.
//
//  Two views of the same week. Jobs are the week's reminders with their times — defrost, cook, shop.
//  Cooking is one afternoon's sheet: every dish, how much of it, and which container goes where.

import SwiftUI

struct KitchenView: View {
    @State private var page = Page.jobs

    enum Page: String, CaseIterable, Identifiable {
        case jobs, cooking
        var id: String { rawValue }
        var label: String {
            switch self {
            case .jobs: return String(localized: "Jobs")
            case .cooking: return String(localized: "Cooking")
            }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                switch page {
                case .jobs: TasksList()
                case .cooking: CookList()
                }
            }
            .navigationTitle("Kitchen")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("", selection: $page) {
                        ForEach(Page.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
    }
}

struct TasksList: View {
    @Environment(AppModel.self) private var model
    @State private var monday = Date()
    @State private var state: Loaded<Tasks> = .loading

    var body: some View {
        List {
            if let since = state.staleSince { StaleNote(since: since) }
            switch state {
            case .loading:
                Loading()
            case .failed(let error):
                Problem(error: error) { Task { await load() } }
                    .listRowBackground(Color.clear)
            case .live(let week), .cached(let week, _):
                ForEach(week.days) { day in
                    if !day.tasks.isEmpty {
                        Section(Dates.short(day.day, relativeTo: Date())) {
                            ForEach(Array(day.tasks.enumerated()), id: \.offset) { _, job in
                                HStack(alignment: .firstTextBaseline) {
                                    if let at = job.at {
                                        Text(at).font(.caption.monospacedDigit())
                                            .foregroundStyle(.secondary).frame(width: 46, alignment: .leading)
                                    }
                                    Text(job.text)
                                }
                            }
                        }
                    }
                }
            }
        }
        .refreshable { await load() }
        .task { await load() }
    }

    private func load() async {
        state = await model.fetch(Cache.Key.tasks) { try await $0.tasks(monday) }
    }
}

struct CookList: View {
    @Environment(AppModel.self) private var model
    @State private var date = Date()
    @State private var state: Loaded<Cook> = .loading

    var body: some View {
        List {
            if let since = state.staleSince { StaleNote(since: since) }
            DatePicker("Day", selection: $date, displayedComponents: .date)
                .listRowBackground(Color.clear)

            switch state {
            case .loading:
                Loading()
            case .failed(let error):
                Problem(error: error) { Task { await load() } }
                    .listRowBackground(Color.clear)
            case .live(let sheet), .cached(let sheet, _):
                if sheet.dishes.isEmpty {
                    Section { Text("Nothing to batch this day.").foregroundStyle(.secondary) }
                }
                ForEach(sheet.dishes) { dish in
                    Section {
                        if let text = dish.forText {
                            Label(text, systemImage: "calendar").font(.subheadline)
                        }
                        if let split = dish.splitText, !split.isEmpty {
                            Label(split, systemImage: "person.2").font(.subheadline)
                        }
                        ForEach(dish.lines, id: \.self) { Text($0) }
                        ForEach(Array(dish.containers.enumerated()), id: \.offset) { _, box in
                            HStack {
                                Image(systemName: box.storage == "freezer" ? "snowflake" : "refrigerator")
                                    .foregroundStyle(.secondary)
                                Text(Dates.short(box.eat, relativeTo: Date()))
                                Spacer()
                                if let out = box.defrostOn {
                                    Text("out \(Dates.short(out, relativeTo: Date()))")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    } header: {
                        HStack {
                            Text(dish.recipe.name)
                            if dish.morning { Image(systemName: "sunrise") }
                        }
                    }
                }
            }
        }
        .refreshable { await load() }
        .task(id: Dates.key(date)) { await load() }
    }

    private func load() async {
        let today = Calendar.current.isDateInToday(date)
        state = await model.fetch(today ? Cache.Key.cook : nil) { try await $0.cook(date) }
    }
}
