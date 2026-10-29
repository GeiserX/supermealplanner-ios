//  One dish: the whole recipe, this person's plate for the day, and the 👍/👎 the next draw reads.

import SwiftUI

struct RecipeView: View {
    @Environment(AppModel.self) private var model
    var id: String
    var person: String?
    var date: Date

    @State private var state: Loaded<RecipeFull> = .loading
    @State private var vote: Int?
    @State private var voting = false

    var body: some View {
        List {
            switch state {
            case .loading:
                Loading()
            case .failed(let error):
                Problem(error: error) { Task { await load() } }
            case .live(let full), .cached(let full, _):
                body(for: full)
            }
        }
        .navigationTitle(state.value?.recipe.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        state = await model.fetch(nil) { try await $0.recipe(id, d: date, person: person) }
        vote = state.value?.vote
    }

    @ViewBuilder
    private func body(for full: RecipeFull) -> some View {
        if let total = full.together {
            Section {
                ForEach(total.lines, id: \.self) { Text($0) }
            } header: {
                Text("Everyone together")
            } footer: {
                // Only what the server sent: a missing figure is not a zero.
                let figures = [total.kcal.map { "\($0) kcal" }, total.proteinG.map { "\(Int($0)) g protein" }]
                    .compactMap { $0 }
                if !figures.isEmpty { Text(figures.joined(separator: " · ")) }
            }
        }

        if let plate = full.plate {
            Section {
                ForEach(plate.lines, id: \.self) { Text($0) }
            } header: {
                Text(model.name(of: person).map { String(localized: "For \($0)") } ?? String(localized: "Your plate"))
            } footer: {
                Text("\(plate.kcal ?? 0) kcal · \(Int(plate.proteinG ?? 0)) g protein")
            }
        }

        Section("What goes in") {
            ForEach(full.recipe.ingredients, id: \.id) { item in
                LabeledContent(item.note ?? item.id) {
                    Text(item.qty.map { "\(Int($0))" } ?? "")
                        .foregroundStyle(.secondary)
                }
            }
        }

        if !full.recipe.steps.isEmpty {
            Section("How") {
                ForEach(Array(full.recipe.steps.enumerated()), id: \.offset) { i, step in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("\(i + 1)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        Text(step)
                    }
                }
            }
        }

        Section {
            if let minutes = full.recipe.minutes, minutes > 0 {
                LabeledContent("Time") { Text("\(minutes) min") }
            }
            if let kind = full.recipe.kind { LabeledContent("Kind") { Text(kind) } }
            if !full.recipe.tags.isEmpty {
                LabeledContent("Tags") { Text(full.recipe.tags.joined(separator: ", ")) }
            }
            if let video = full.recipe.video, let url = URL(string: video) {
                Link(destination: url) { Label("Watch someone cook it", systemImage: "play.rectangle") }
            }
        }

        Section {
            HStack {
                voteButton(1, "hand.thumbsup", .green)
                Divider()
                voteButton(-1, "hand.thumbsdown", .orange)
            }
            .disabled(voting || person == nil)
        } footer: {
            Text("The next menus follow these.")
        }
    }

    private func voteButton(_ value: Int, _ icon: String, _ colour: Color) -> some View {
        Button {
            send(vote == value ? 0 : value)
        } label: {
            HStack {
                Spacer()
                Image(systemName: vote == value ? icon + ".fill" : icon)
                    .foregroundStyle(vote == value ? colour : Color.secondary)
                    .imageScale(.large)
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }

    private func send(_ value: Int) {
        guard let client = model.client, let person else { return }
        voting = true
        let before = vote
        vote = value == 0 ? nil : value
        Task {
            defer { voting = false }
            do {
                try await client.rate(id, vote: value, person: person)
            } catch {
                vote = before                 // the server is the truth; put the thumb back
                model.lastError = error.localizedDescription
            }
        }
    }
}
