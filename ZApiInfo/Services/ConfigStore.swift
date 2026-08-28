import Foundation

enum ConfigStore {
    private static let configKey = "zapiinfo.appConfig"
    private static let snapshotsKey = "zapiinfo.dailySnapshots"
    private static let cacheKey = "zapiinfo.lastValues"

    static func loadConfig() -> AppConfig {
        guard let data = UserDefaults.standard.data(forKey: configKey) else { return .empty }
        do {
            return try JSONDecoder().decode(AppConfig.self, from: data)
        } catch {
            return .empty
        }
    }

    static func saveConfig(_ config: AppConfig) {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: configKey)
        }
    }

    static func loadSnapshots() -> [DailySnapshot] {
        guard let data = UserDefaults.standard.data(forKey: snapshotsKey) else { return [] }
        return (try? JSONDecoder().decode([DailySnapshot].self, from: data)) ?? []
    }

    static func saveSnapshots(_ snapshots: [DailySnapshot]) {
        if let data = try? JSONEncoder().encode(snapshots) {
            UserDefaults.standard.set(data, forKey: snapshotsKey)
        }
    }

    static func loadCache() -> ValueCache? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return nil }
        return try? JSONDecoder().decode(ValueCache.self, from: data)
    }

    static func saveCache(_ cache: ValueCache) {
        if let data = try? JSONEncoder().encode(cache) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }

    static func clearAll(includingKey: Bool) {
        UserDefaults.standard.removeObject(forKey: configKey)
        UserDefaults.standard.removeObject(forKey: snapshotsKey)
        UserDefaults.standard.removeObject(forKey: cacheKey)
        if includingKey {
            KeychainStore.delete()
        }
    }
}

struct CachedLeaf: Codable, Sendable {
    var kind: String
    var number: Double?
    var bool: Bool?
    var string: String?

    init(_ value: JSONLeafValue) {
        switch value {
        case .number(let number):
            kind = "number"
            self.number = number
            bool = nil
            string = nil
        case .bool(let flag):
            kind = "bool"
            number = nil
            bool = flag
            string = nil
        case .string(let text):
            kind = "string"
            number = nil
            bool = nil
            string = text
        }
    }

    var value: JSONLeafValue? {
        switch kind {
        case "number": if let number { return .number(number) }
        case "bool": if let bool { return .bool(bool) }
        case "string": if let string { return .string(string) }
        default: break
        }
        return nil
    }
}

struct ValueCache: Codable, Sendable {
    var lastSuccessAt: Date?
    var lastURL: String
    var values: [String: CachedLeaf]
}
