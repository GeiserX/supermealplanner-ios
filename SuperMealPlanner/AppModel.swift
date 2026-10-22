//  What the whole app shares: which server it is paired to, who it is showing, and one way to fetch.
//
//  Every screen asks through `fetch`, which does the same three things everywhere: call the server,
//  keep the answer for next time, and when the server cannot be reached show the kept one with the
//  time it was fetched. A 401 anywhere means the phone was unpaired on the other side, so the token
//  is dropped and the app returns to the pairing screen by itself.

import Foundation
import SwiftUI
import WidgetKit

/// An answer and where it came from. The views show the age of a cached one; nothing pretends.
enum Loaded<T> {
    case loading
    case live(T)
    case cached(T, Date)
    case failed(Error)

    var value: T? {
        switch self {
        case .live(let v): return v
        case .cached(let v, _): return v
        case .loading, .failed: return nil
        }
    }

    var staleSince: Date? {
        if case .cached(_, let when) = self { return when }
        return nil
    }

    var error: Error? {
        if case .failed(let e) = self { return e }
        return nil
    }
}

@MainActor
@Observable
final class AppModel {
    private(set) var account: Account?
    private(set) var token: String?
    var meta: Meta?
    /// Whose plate the app opens on. Starts as the person the device was paired to.
    var person: String?
    var lastError: String?

    private let vault: Vault
    private let cache: Cache
    private let session: URLSession

    init(vault: Vault = Vault(), cache: Cache = Cache(), session: URLSession = .shared) {
        self.vault = vault
        self.cache = cache
        self.session = session
        self.account = Account.load()
        self.token = vault.read()
        self.person = account?.person
        self.meta = cache.read(Cache.Key.meta, as: Meta.self)?.value
    }

    var paired: Bool { account != nil && (token != nil || isDemo) }

    /// Showing the invented household from `DemoServer` instead of a real server.
    var isDemo: Bool { account?.server == DemoServer.address }

    /// The client for the paired server. nil before pairing, which is the only state without one.
    /// In the demo it carries no token and its session answers from `DemoServer`.
    var client: Client? {
        if isDemo { return Client(server: DemoServer.address, token: nil, session: DemoServer.session) }
        guard let account, let token else { return nil }
        return Client(server: account.server, token: token, session: session, deviceName: Self.deviceName)
    }

    static var deviceName: String {
        #if canImport(UIKit)
        return UIDevice.current.name
        #else
        return "Phone"
        #endif
    }

    // ---------------------------------------------------------------- pairing
    /// Check an address before anyone types a code into it.
    func check(_ raw: String) async throws -> Ping {
        guard let server = ServerAddress.parse(raw) else { throw ClientError.badAddress }
        return try await Client(server: server, token: nil, session: session).ping()
    }

    func pair(server raw: String, code: String, device: String) async throws {
        guard let server = ServerAddress.parse(raw) else { throw ClientError.badAddress }
        let client = Client(server: server, token: nil, session: session)
        let got = try await client.pair(code: code, device: device)
        guard vault.write(got.token) else {
            throw ClientError.malformed("the keychain refused to keep the token")
        }
        let account = Account(server: server, household: got.household, person: got.person,
                              personName: got.personName, device: got.device, deviceID: got.deviceID)
        account.save()
        self.account = account
        self.token = got.token
        self.person = got.person
        self.meta = try? await self.client?.meta()
        if let meta { cache.write(Cache.Key.meta, meta) }
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Open the invented household. The account is remembered like a real one, so the demo survives
    /// a relaunch and the widget shows its plan; no token is written, and any old one is dropped.
    func startDemo() async {
        vault.delete()
        token = nil
        cache.clear()
        DemoServer.shared.reset()
        let account = DemoServer.account
        account.save()
        self.account = account
        self.person = account.person
        self.meta = try? await client?.meta()
        if let meta { cache.write(Cache.Key.meta, meta) }
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Forget this server. The token goes first: a leftover address is harmless, a leftover token is
    /// the one thing that still opens the household's data.
    func unpair() {
        vault.delete()
        token = nil
        Account.forget()
        account = nil
        person = nil
        meta = nil
        cache.clear()
        DemoServer.shared.reset()
        WidgetCenter.shared.reloadAllTimelines()
    }

    // ---------------------------------------------------------------- fetching
    /// Call the server, keep the answer, and fall back to the kept one when it cannot be reached.
    ///
    /// `key` is nil for anything not worth keeping (another week, someone else's day): those simply
    /// fail when offline rather than showing a neighbour's cached answer.
    func fetch<T: Codable & Sendable>(
        _ key: String?, _ call: (Client) async throws -> T
    ) async -> Loaded<T> {
        guard let client else { return .failed(ClientError.unpaired) }
        do {
            let value = try await call(client)
            if let key {
                cache.write(key, value)
                if key == Cache.Key.day || key == Cache.Key.list {
                    WidgetCenter.shared.reloadAllTimelines()
                }
            }
            return .live(value)
        } catch ClientError.unpaired {
            // The household revoked this phone, or the database was replaced. Nothing to retry.
            unpair()
            return .failed(ClientError.unpaired)
        } catch {
            if let key, let kept: Cached<T> = cache.read(key) {
                return .cached(kept.value, kept.fetched)
            }
            return .failed(error)
        }
    }

    /// The person a screen should show: the one chosen, else the device's own, else the first one.
    var showing: String? {
        person ?? account?.person ?? meta?.people.first?.id
    }

    func name(of personID: String?) -> String? {
        guard let personID else { return nil }
        return meta?.people.first { $0.id == personID }?.name ?? account?.personName
    }
}
