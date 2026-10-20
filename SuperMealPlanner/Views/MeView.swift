//  Me: what to write down today, how the weight is going, and which phones are paired.
//
//  Only the fields someone touched are sent, so opening this screen and closing it writes nothing.
//  A number out of range is clamped by the server, exactly as the web form is — the rules live on
//  one side only.

import SwiftUI

struct MeView: View {
    @Environment(AppModel.self) private var model

    @State private var person: String?
    @State private var kg = ""
    @State private var waist = ""
    @State private var hunger: Int?
    @State private var craving: Int?
    @State private var nausea: Int?
    @State private var water: Int?
    @State private var binge = false
    @State private var stool = false
    @State private var pills = false
    @State private var touchedFlags: Set<String> = []
    @State private var note = ""
    @State private var saving = false
    @State private var said: String?
    @State private var progress: Loaded<Progress> = .loading

    var body: some View {
        NavigationStack {
            Form {
                PersonPicker(person: $person)

                Section("Today") {
                    LabeledContent("Weight") {
                        TextField("kg", text: $kg).keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Waist") {
                        TextField("cm", text: $waist).keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    scale("Hunger", $hunger, 10)
                    scale("Craving", $craving, 10)
                    scale("Nausea", $nausea, 10)
                    scale("Water", $water, 40)
                }

                Section {
                    flag("Overate", $binge, "binge")
                    flag("Went to the loo", $stool, "stool")
                    flag("Took the lunch pills", $pills, "pills_lunch")
                    TextField("Anything else", text: $note, axis: .vertical).lineLimit(1...4)
                }

                Section {
                    Button(action: save) {
                        HStack { Spacer(); if saving { ProgressView() } else { Text("Save") }; Spacer() }
                    }
                    .disabled(saving || !hasSomething)
                    if let said { Text(said).font(.footnote).foregroundStyle(.secondary) }
                }

                if let mine = progress.value?.people.first(where: { $0.person == (person ?? model.showing) }) {
                    Section("How it is going") {
                        if let trend = mine.trendKg {
                            LabeledContent("Trend") {
                                Text("\(trend, format: .number.precision(.fractionLength(1))) kg")
                            }
                        }
                        if let rate = mine.rateKgWeek {
                            LabeledContent("Per week") {
                                Text("\(rate, format: .number.precision(.fractionLength(2))) kg")
                            }
                        }
                        if let kcal = mine.kcal { LabeledContent("Calories now") { Text("\(kcal) kcal") } }
                        ForEach(mine.flags, id: \.self) { flag in
                            Label(flag, systemImage: "info.circle").font(.footnote)
                        }
                        if let changed = mine.changed {
                            Label(changed, systemImage: "arrow.triangle.turn.up.right.diamond")
                                .font(.footnote)
                        }
                    }
                }

                Section {
                    NavigationLink { DevicesView() } label: {
                        Label("Paired phones", systemImage: "iphone")
                    }
                    NavigationLink { ServerView() } label: {
                        Label("Server", systemImage: "server.rack")
                    }
                }
            }
            .navigationTitle(model.name(of: person ?? model.showing) ?? String(localized: "Me"))
            .task {
                if person == nil { person = model.showing }
                progress = await model.fetch(nil) { try await $0.progress() }
            }
        }
    }

    private var hasSomething: Bool {
        !kg.isEmpty || !waist.isEmpty || hunger != nil || craving != nil || nausea != nil
            || water != nil || !touchedFlags.isEmpty || !note.isEmpty
    }

    private func scale(_ title: LocalizedStringKey, _ value: Binding<Int?>, _ top: Int) -> some View {
        LabeledContent(title) {
            HStack {
                if let v = value.wrappedValue {
                    Text("\(v)").monospacedDigit()
                } else {
                    Text("—").foregroundStyle(.tertiary)
                }
                Stepper(title, value: Binding(get: { value.wrappedValue ?? 0 },
                                              set: { value.wrappedValue = max(0, min(top, $0)) }),
                        in: 0...top)
                    .labelsHidden()
            }
        }
    }

    private func flag(_ title: LocalizedStringKey, _ value: Binding<Bool>, _ key: String) -> some View {
        Toggle(title, isOn: Binding(get: { value.wrappedValue },
                                    set: { value.wrappedValue = $0; touchedFlags.insert(key) }))
    }

    private func save() {
        guard let client = model.client else { return }
        var fields: [String: Any] = [:]
        if let person { fields["person"] = person }
        if let v = Double(kg.replacingOccurrences(of: ",", with: ".")) { fields["kg"] = v }
        if let v = Double(waist.replacingOccurrences(of: ",", with: ".")) { fields["waist_cm"] = v }
        if let v = hunger { fields["hunger"] = v }
        if let v = craving { fields["craving"] = v }
        if let v = nausea { fields["nausea"] = v }
        if let v = water { fields["water"] = v }
        if touchedFlags.contains("binge") { fields["binge"] = binge }
        if touchedFlags.contains("stool") { fields["stool"] = stool }
        if touchedFlags.contains("pills_lunch") { fields["pills_lunch"] = pills }
        if !note.isEmpty { fields["note"] = note }
        saving = true
        said = nil
        Task {
            defer { saving = false }
            do {
                try await client.log(fields)
                said = String(localized: "Written down.")
                kg = ""; waist = ""; note = ""
                hunger = nil; craving = nil; nausea = nil; water = nil
                touchedFlags = []
                progress = await model.fetch(nil) { try await $0.progress() }
            } catch {
                said = error.localizedDescription
            }
        }
    }
}

struct DevicesView: View {
    @Environment(AppModel.self) private var model
    @State private var state: Loaded<Devices> = .loading
    @State private var problem: String?

    var body: some View {
        List {
            if let problem { Text(problem).foregroundStyle(.red) }
            switch state {
            case .loading:
                Loading()
            case .failed(let error):
                Problem(error: error) { Task { await load() } }
            case .live(let devices), .cached(let devices, _):
                ForEach(devices.devices) { d in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(d.name ?? "Phone")
                            if d.this { Text("this one").font(.caption).foregroundStyle(.tint) }
                        }
                        if let who = d.personName ?? d.person {
                            Text(who).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions {
                        Button("Unpair", role: .destructive) { revoke(d) }
                    }
                }
            }
        }
        .navigationTitle("Paired phones")
        .refreshable { await load() }
        .task { await load() }
    }

    private func load() async {
        state = await model.fetch(nil) { try await $0.devices() }
    }

    /// Taking this phone away is allowed: the next call gets a 401 and the app returns to pairing by
    /// itself, which is exactly what a lost phone needs from another one.
    private func revoke(_ device: Devices.Entry) {
        guard let client = model.client else { return }
        Task {
            do {
                try await client.revoke(device.id)
                if device.this { model.unpair() } else { await load() }
            } catch {
                problem = error.localizedDescription
            }
        }
    }
}

struct ServerView: View {
    @Environment(AppModel.self) private var model
    @State private var confirm = false

    var body: some View {
        List {
            Section("Paired to") {
                LabeledContent("Address") { Text(model.account?.server.host() ?? "—") }
                if let household = model.account?.household {
                    LabeledContent("Household") { Text(household) }
                }
                if let version = model.meta?.version {
                    LabeledContent("Server version") { Text(version) }
                }
                if let device = model.account?.device {
                    LabeledContent("This phone") { Text(device) }
                }
            }
            Section {
                Button("Unpair this phone", role: .destructive) { confirm = true }
            } footer: {
                Text("The token is deleted from this phone. Nothing on the server changes until someone removes the device there too.")
            }
        }
        .navigationTitle("Server")
        .confirmationDialog("Unpair this phone?", isPresented: $confirm, titleVisibility: .visible) {
            Button("Unpair", role: .destructive) { model.unpair() }
        }
    }
}
