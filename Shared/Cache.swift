//  The last good answer for a screen, kept on disk so the app opens with something and the widget
//  has a plan to show without a token of its own.
//
//  The cache holds answers, never credentials: `Vault` is the only thing that touches the bearer. A
//  cached answer is always shown with the time it was fetched, so nobody reads a stale plan thinking
//  it is live.

import Foundation

struct Cached<T: Codable & Sendable>: Codable, Sendable {
    var fetched: Date
    var value: T
}

struct Cache: Sendable {
    /// The app group container when there is one, the caches folder otherwise, so a build without
    /// the entitlement still works (the widget is the part that then sees nothing).
    static var folder: URL {
        if let shared = AppGroup.container { return shared }
        return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    }

    var folder: URL = Cache.folder

    private func file(_ name: String) -> URL {
        folder.appendingPathComponent("cache-" + name + ".json")
    }

    func read<T: Codable & Sendable>(_ name: String, as: T.Type = T.self) -> Cached<T>? {
        guard let data = try? Data(contentsOf: file(name)) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(Cached<T>.self, from: data)
    }

    func write<T: Codable & Sendable>(_ name: String, _ value: T, at when: Date = Date()) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(Cached(fetched: when, value: value)) else { return }
        try? data.write(to: file(name), options: .atomic)
    }

    /// Unpairing wipes it: the next household to use this phone starts clean.
    func clear() {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder,
                                                                 includingPropertiesForKeys: nil)) ?? []
        for f in files where f.lastPathComponent.hasPrefix("cache-") {
            try? FileManager.default.removeItem(at: f)
        }
    }

    enum Key {
        static let day = "day"
        static let week = "week"
        static let list = "list"
        static let cook = "cook"
        static let tasks = "tasks"
        static let meta = "meta"
    }
}
