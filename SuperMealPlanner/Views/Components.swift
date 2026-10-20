//  The small pieces every screen uses: how a cached answer is marked, how a failure reads, and the
//  names the app gives to things the server sends as ids.

import SwiftUI

/// Shown above a screen that is reading from the cache, with the time it was fetched. The app never
/// shows an old plan as if it were live.
struct StaleNote: View {
    var since: Date

    var body: some View {
        Label {
            Text("Saved copy from \(since.formatted(date: .omitted, time: .shortened))")
        } icon: {
            Image(systemName: "wifi.slash")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .listRowBackground(Color.clear)
    }
}

struct Problem: View {
    var error: Error
    var retry: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label("Nothing to show", systemImage: "exclamationmark.triangle")
        } description: {
            Text(error.localizedDescription)
        } actions: {
            if let retry { Button("Try again", action: retry) }
        }
    }
}

struct Loading: View {
    var body: some View {
        HStack { Spacer(); ProgressView(); Spacer() }
            .listRowBackground(Color.clear)
    }
}

/// Whose plate to show. Hidden when the household has one person.
struct PersonPicker: View {
    @Environment(AppModel.self) private var model
    @Binding var person: String?

    var body: some View {
        if let people = model.meta?.people, people.count > 1 {
            Picker("Person", selection: Binding(get: { person ?? people[0].id },
                                                set: { person = $0 })) {
                ForEach(people) { Text($0.name).tag($0.id) }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)
        }
    }
}

enum Names {
    /// The server sends meal ids; what they are called is the app's own language, not the server's.
    static func meal(_ id: String) -> String {
        switch id {
        case "breakfast": return String(localized: "Breakfast")
        case "lunch": return String(localized: "Lunch")
        case "dinner": return String(localized: "Dinner")
        case "snack": return String(localized: "Snack")
        default: return id.capitalized
        }
    }

    static func icon(_ meal: String) -> String {
        switch meal {
        case "breakfast": return "sun.horizon"
        case "lunch": return "sun.max"
        case "dinner": return "moon"
        case "snack": return "cup.and.saucer"
        default: return "fork.knife"
        }
    }

    /// `/list` sends the household's own section labels; fall back to the id when one is missing.
    static func section(_ id: String, _ labels: [String: String]) -> String {
        labels[id] ?? id.replacingOccurrences(of: "-", with: " ").capitalized
    }
}

extension View {
    /// Pull to refresh that does not swallow the error: whatever the task throws lands in the view's
    /// own state, as the first load does.
    func reload(_ work: @escaping @Sendable () async -> Void) -> some View {
        refreshable { await work() }
    }
}
