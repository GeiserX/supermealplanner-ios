//  The week at a glance: seven days of dish names, today marked, a tap opens that day.

import SwiftUI

struct WeekView: View {
    @Environment(AppModel.self) private var model

    @State private var monday = Date()
    @State private var state: Loaded<Week> = .loading

    var body: some View {
        NavigationStack {
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
                        Section {
                            if day.paused {
                                Label("No plan", systemImage: "pause.circle").foregroundStyle(.secondary)
                            } else if day.meals.isEmpty {
                                Text("—").foregroundStyle(.secondary)
                            } else {
                                ForEach(day.meals, id: \.recipe.id) { entry in
                                    HStack {
                                        Image(systemName: Names.icon(entry.meal))
                                            .foregroundStyle(.secondary)
                                            .frame(width: 22)
                                        Text(entry.recipe.name)
                                    }
                                }
                            }
                        } header: {
                            HStack {
                                Text(Dates.short(day.day, relativeTo: Date()))
                                if day.day == week.today {
                                    Text("today").foregroundStyle(.tint)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Week")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { shift(-7) } label: { Image(systemName: "chevron.left") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { shift(7) } label: { Image(systemName: "chevron.right") }
                }
            }
            .refreshable { await load() }
            .task(id: Dates.key(monday)) { await load() }
        }
    }

    private func shift(_ days: Int) {
        monday = Calendar.current.date(byAdding: .day, value: days, to: monday) ?? monday
    }

    private func load() async {
        let thisWeek = Calendar.current.isDate(monday, equalTo: Date(), toGranularity: .weekOfYear)
        state = await model.fetch(thisWeek ? Cache.Key.week : nil) { try await $0.week(monday) }
    }
}
