//  First launch: which server, and the code the bot gave you.
//
//  Two steps on purpose. The address is checked against `GET /ping` before anyone types six digits,
//  so a typo in the host does not look like a wrong code — and a server that is not a
//  SuperMealPlanner says so instead of answering 401.

import SwiftUI

struct PairView: View {
    @Environment(AppModel.self) private var model

    @State private var address = ""
    @State private var code = ""
    @State private var deviceName = AppModel.deviceName
    @State private var found: Ping?
    @State private var busy = false
    @State private var problem: String?
    @FocusState private var field: Field?

    private enum Field { case address, code }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("comidas.example.com", text: $address)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($field, equals: .address)
                        .onChange(of: address) { found = nil }
                } header: {
                    Text("Your server")
                } footer: {
                    if let found {
                        Label("SuperMealPlanner \(found.version ?? "")", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Text("The address of the household's SuperMealPlanner. Nobody else's data is on it.")
                    }
                }

                if found != nil {
                    Section {
                        TextField("000 000", text: $code)
                            .keyboardType(.numberPad)
                            .font(.system(.title2, design: .rounded).monospacedDigit())
                            .focused($field, equals: .code)
                        TextField("This phone", text: $deviceName)
                            .textInputAutocapitalization(.words)
                    } header: {
                        Text("Pairing code")
                    } footer: {
                        Text("Send /pair to the household's bot in a private chat. It answers with six digits, good for ten minutes.")
                    }
                }

                if let problem {
                    Section { Text(problem).foregroundStyle(.red) }
                }

                Section {
                    Button(action: go) {
                        HStack {
                            Spacer()
                            if busy { ProgressView() } else { Text(found == nil ? "Check" : "Pair") }
                            Spacer()
                        }
                    }
                    .disabled(busy || address.isEmpty || (found != nil && digits.count < 6))
                }
            }
            .navigationTitle("Comidas")
            .onAppear { field = .address }
        }
    }

    private var digits: String { code.filter(\.isNumber) }

    private func go() {
        busy = true
        problem = nil
        Task {
            defer { busy = false }
            do {
                if found == nil {
                    found = try await model.check(address)
                    field = .code
                } else {
                    try await model.pair(server: address, code: digits, device: deviceName)
                }
            } catch {
                problem = error.localizedDescription
            }
        }
    }
}
