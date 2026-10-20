//  Where a paired server lives on the phone.
//
//  The bearer token goes in the keychain and nowhere else: not in UserDefaults, not in the cache the
//  widget reads, and never in a log line. Everything else about the pairing — which server, whose
//  plate to open first, the household's name — is ordinary preference data, kept in the app group so
//  the widget can read it without a token of its own.
//
//  Unpairing deletes the keychain item first. A server URL left behind is harmless; a token is not.

import Foundation

enum AppGroup {
    static let id = "group.io.github.geiserx.supermealplanner"

    /// The shared defaults, or this process's own when the group is missing (a unit test, or a build
    /// whose entitlement was not generated). Returning something always keeps the app usable.
    static var defaults: UserDefaults { UserDefaults(suiteName: id) ?? .standard }

    static var container: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id)
    }
}

/// The token, in the keychain. A struct so a test can hand the app a different one.
struct Vault {
    var service = "io.github.geiserx.supermealplanner.token"
    var account = "device"

    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    func read() -> String? {
        var q = query
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess,
              let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    func write(_ token: String) -> Bool {
        delete()
        var q = query
        q[kSecValueData as String] = Data(token.utf8)
        // The phone has to be unlocked once after a restart, then the widget's host and a background
        // refresh can both read it. ThisDeviceOnly keeps it out of an iCloud or iTunes backup.
        q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(q as CFDictionary, nil) == errSecSuccess
    }

    @discardableResult
    func delete() -> Bool {
        SecItemDelete(query as CFDictionary) == errSecSuccess
    }
}

/// One paired server, as the app remembers it.
struct Account: Codable, Equatable, Sendable {
    var server: URL
    var household: String?
    var person: String?
    var personName: String?
    var device: String?
    var deviceID: Int?

    private static let key = "account"

    static func load(from defaults: UserDefaults = AppGroup.defaults) -> Account? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(Account.self, from: data)
    }

    func save(to defaults: UserDefaults = AppGroup.defaults) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Account.key)
    }

    static func forget(from defaults: UserDefaults = AppGroup.defaults) {
        defaults.removeObject(forKey: key)
    }
}

/// What the app types into a URL bar, turned into a server address.
///
/// `comidas.example.com`, `https://comidas.example.com/` and `comidas.example.com:8080/api/v1` all
/// mean the same server. https is assumed, because a household name on a home network has a
/// certificate too; someone who really wants plain http types it.
enum ServerAddress {
    static func parse(_ raw: String) -> URL? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if !text.lowercased().hasPrefix("http://") && !text.lowercased().hasPrefix("https://") {
            text = "https://" + text
        }
        guard var parts = URLComponents(string: text), let host = parts.host, !host.isEmpty else { return nil }
        // A pasted address often carries the API path already. The client adds it back.
        var path = parts.path
        while path.hasSuffix("/") { path.removeLast() }
        if path.lowercased().hasSuffix("/api/v1") { path.removeLast("/api/v1".count) }
        parts.path = path
        parts.query = nil
        parts.fragment = nil
        return parts.url
    }
}
