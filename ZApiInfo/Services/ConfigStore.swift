import Foundation

enum ConfigStore {
    private static let legacyConfigKey = "zapiinfo.appConfig"
    private static let legacySnapshotsKey = "zapiinfo.dailySnapshots"
    private static let legacyCacheKey = "zapiinfo.lastValues"
    private static let stateKey = "zapiinfo.appState"
    private static let snapshotsBySourceKey = "zapiinfo.snapshotsBySource"
    private static let cacheBySourceKey = "zapiinfo.cacheBySource"

    static func loadState() -> AppState {
        if let data = UserDefaults.standard.data(forKey: stateKey),
           let state = try? JSONDecoder().decode(AppState.self, from: data),
           !state.sources.isEmpty {
            return normalized(state)
        }
        return migrateLegacyConfig()
    }

    static func saveState(_ state: AppState) {
        if let data = try? JSONEncoder().encode(normalized(state)) {
            UserDefaults.standard.set(data, forKey: stateKey)
        }
    }

    static func loadSnapshots(sourceID: UUID) -> [DailySnapshot] {
        snapshotsMap()[sourceID.uuidString] ?? []
    }

    static func saveSnapshots(_ snapshots: [DailySnapshot], sourceID: UUID) {
        var map = snapshotsMap()
        map[sourceID.uuidString] = snapshots
        if let data = try? JSONEncoder().encode(map) {
            UserDefaults.standard.set(data, forKey: snapshotsBySourceKey)
        }
    }

    static func deleteSnapshots(sourceID: UUID) {
        var map = snapshotsMap()
        map.removeValue(forKey: sourceID.uuidString)
        if let data = try? JSONEncoder().encode(map) {
            UserDefaults.standard.set(data, forKey: snapshotsBySourceKey)
        }
    }

    static func loadCache(sourceID: UUID) -> ValueCache? {
        cacheMap()[sourceID.uuidString]
    }

    static func saveCache(_ cache: ValueCache, sourceID: UUID) {
        var map = cacheMap()
        map[sourceID.uuidString] = cache
        if let data = try? JSONEncoder().encode(map) {
            UserDefaults.standard.set(data, forKey: cacheBySourceKey)
        }
    }

    static func deleteCache(sourceID: UUID) {
        var map = cacheMap()
        map.removeValue(forKey: sourceID.uuidString)
        if let data = try? JSONEncoder().encode(map) {
            UserDefaults.standard.set(data, forKey: cacheBySourceKey)
        }
    }

    static func clearAll() {
        UserDefaults.standard.removeObject(forKey: stateKey)
        UserDefaults.standard.removeObject(forKey: snapshotsBySourceKey)
        UserDefaults.standard.removeObject(forKey: cacheBySourceKey)
        UserDefaults.standard.removeObject(forKey: legacyConfigKey)
        UserDefaults.standard.removeObject(forKey: legacySnapshotsKey)
        UserDefaults.standard.removeObject(forKey: legacyCacheKey)
    }

    private static func migrateLegacyConfig() -> AppState {
        guard let data = UserDefaults.standard.data(forKey: legacyConfigKey),
              let config = try? JSONDecoder().decode(AppConfig.self, from: data) else {
            return .empty
        }
        let name = URLComponents(string: config.trimmedURL)?.host ?? ""
        let source = SourceProfile.from(config, name: name)
        let state = AppState(
            languageCode: config.languageCode,
            launchAtLogin: config.launchAtLogin,
            activeSourceID: source.id,
            sources: [source]
        )
        if let snapshots = loadLegacySnapshots() {
            saveSnapshots(snapshots, sourceID: source.id)
        }
        if let cache = loadLegacyCache() {
            saveCache(cache, sourceID: source.id)
        }
        KeychainStore.migrateLegacyKey(to: source.id)
        saveState(state)
        UserDefaults.standard.removeObject(forKey: legacyConfigKey)
        UserDefaults.standard.removeObject(forKey: legacySnapshotsKey)
        UserDefaults.standard.removeObject(forKey: legacyCacheKey)
        return state
    }

    private static func loadLegacySnapshots() -> [DailySnapshot]? {
        guard let data = UserDefaults.standard.data(forKey: legacySnapshotsKey) else { return nil }
        return try? JSONDecoder().decode([DailySnapshot].self, from: data)
    }

    private static func loadLegacyCache() -> ValueCache? {
        guard let data = UserDefaults.standard.data(forKey: legacyCacheKey) else { return nil }
        return try? JSONDecoder().decode(ValueCache.self, from: data)
    }

    private static func snapshotsMap() -> [String: [DailySnapshot]] {
        guard let data = UserDefaults.standard.data(forKey: snapshotsBySourceKey) else { return [:] }
        return (try? JSONDecoder().decode([String: [DailySnapshot]].self, from: data)) ?? [:]
    }

    private static func cacheMap() -> [String: ValueCache] {
        guard let data = UserDefaults.standard.data(forKey: cacheBySourceKey) else { return [:] }
        return (try? JSONDecoder().decode([String: ValueCache].self, from: data)) ?? [:]
    }

    private static func normalized(_ state: AppState) -> AppState {
        var next = state
        if next.sources.isEmpty {
            next = .empty
            next.languageCode = state.languageCode
            next.launchAtLogin = state.launchAtLogin
        }
        if !next.sources.contains(where: { $0.id == next.activeSourceID }) {
            next.activeSourceID = next.sources[0].id
        }
        return next
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
