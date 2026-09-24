import Foundation

enum FieldCategory: String, Codable, CaseIterable, Sendable {
    case quota
    case token
    case request
    case account
    case derived
    case other

    var title: String {
        L10n(language: AppLanguage.current).category(self)
    }
}

enum FieldFormat: String, Codable, CaseIterable, Identifiable, Sendable {
    case auto
    case integer
    case decimal
    case percent
    case currency
    case datetime

    var id: String { rawValue }

    var title: String {
        L10n(language: AppLanguage.current).format(self)
    }
}

enum AuthScheme: String, Codable, CaseIterable, Sendable {
    case bearer
    case none

    var title: String {
        L10n(language: AppLanguage.current).auth(self)
    }
}

struct FieldConfig: Codable, Identifiable, Hashable, Sendable {
    var path: String
    var displayName: String
    var showInStatusBar: Bool
    var showInMenu: Bool
    var generateDeltaToday: Bool
    var format: FieldFormat
    var decimalPlaces: Int
    var scale: Double
    var sortOrder: Int
    var category: FieldCategory

    var id: String { path }

    var lastComponent: String {
        path.split(separator: ".").last.map(String.init) ?? path
    }

    var isDerivedDelta: Bool {
        path.hasPrefix(DerivedField.deltaPrefix)
    }

    var deltaSourcePath: String? {
        guard isDerivedDelta else { return nil }
        return String(path.dropFirst(DerivedField.deltaPrefix.count))
    }

    var resolvedDisplayName: String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? path : trimmed
    }

    init(
        path: String,
        displayName: String,
        showInStatusBar: Bool = false,
        showInMenu: Bool = false,
        generateDeltaToday: Bool = false,
        format: FieldFormat = .auto,
        decimalPlaces: Int = 2,
        scale: Double = 1,
        sortOrder: Int = 0,
        category: FieldCategory = .other
    ) {
        self.path = path
        self.displayName = displayName
        self.showInStatusBar = showInStatusBar
        self.showInMenu = showInMenu
        self.generateDeltaToday = generateDeltaToday
        self.format = format
        self.decimalPlaces = decimalPlaces
        self.scale = scale
        self.sortOrder = sortOrder
        self.category = category
    }
}

enum DerivedField {
    static let deltaPrefix = "_derived.delta_today."
    static let todayPrefix = "_derived.today."
    static let remainRatio = "_derived.remain_ratio"

    static func deltaPath(for sourcePath: String) -> String {
        deltaPrefix + sourcePath
    }

    static func todayPath(for sourcePath: String) -> String {
        todayPrefix + sourcePath
    }

    static func isLocallyComputed(_ path: String) -> Bool {
        path.hasPrefix(deltaPrefix) || path == remainRatio
    }
}

struct AppConfig: Codable, Equatable, Sendable {
    var endpointURL: String
    var authScheme: AuthScheme
    var extraHeaderName: String
    var extraHeaderValue: String
    var refreshIntervalSec: Int
    var timeoutSec: Int
    var presetId: String
    var statusBarSeparator: String
    var compactLargeNumbers: Bool
    var currencySymbol: String
    var launchAtLogin: Bool
    var showProtocolFields: Bool
    var fields: [FieldConfig]
    var remainNumeratorPath: String
    var remainDenominatorPath: String
    var showRemainRatio: Bool
    var languageCode: String?

    static let defaultRefreshIntervals = [15, 30, 60, 300, 900]

    static var empty: AppConfig {
        AppConfig(
            endpointURL: "",
            authScheme: .bearer,
            extraHeaderName: "",
            extraHeaderValue: "",
            refreshIntervalSec: 60,
            timeoutSec: 10,
            presetId: PresetID.custom.rawValue,
            statusBarSeparator: " · ",
            compactLargeNumbers: true,
            currencySymbol: "$",
            launchAtLogin: false,
            showProtocolFields: false,
            fields: [],
            remainNumeratorPath: "",
            remainDenominatorPath: "",
            showRemainRatio: false,
            languageCode: nil
        )
    }

    var trimmedURL: String {
        endpointURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isConfigured: Bool {
        guard let components = URLComponents(string: trimmedURL) else { return false }
        let scheme = components.scheme?.lowercased()
        let host = components.host ?? ""
        return (scheme == "http" || scheme == "https") && !host.isEmpty
    }

    var usesHTTP: Bool {
        trimmedURL.lowercased().hasPrefix("http://")
    }

    var extraHeader: (String, String)? {
        let name = extraHeaderName.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = extraHeaderValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !value.isEmpty else { return nil }
        return (name, value)
    }

    var sortedFields: [FieldConfig] {
        fields.sorted { lhs, rhs in
            if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
            return lhs.path < rhs.path
        }
    }

    func field(path: String) -> FieldConfig? {
        fields.first { $0.path == path }
    }

    mutating func upsertField(_ field: FieldConfig) {
        if let index = fields.firstIndex(where: { $0.path == field.path }) {
            fields[index] = field
        } else {
            fields.append(field)
        }
    }

    mutating func removeField(path: String) {
        fields.removeAll { $0.path == path }
    }

    mutating func reindexSortOrder() {
        for (index, _) in fields.enumerated() {
            fields[index].sortOrder = index
        }
    }
}

struct SourceProfile: Codable, Identifiable, Equatable, Hashable, Sendable {
    var id: UUID
    var name: String
    var endpointURL: String
    var authScheme: AuthScheme
    var extraHeaderName: String
    var extraHeaderValue: String
    var refreshIntervalSec: Int
    var timeoutSec: Int
    var presetId: String
    var statusBarSeparator: String
    var compactLargeNumbers: Bool
    var currencySymbol: String
    var showProtocolFields: Bool
    var fields: [FieldConfig]
    var remainNumeratorPath: String
    var remainDenominatorPath: String
    var showRemainRatio: Bool

    static func empty(id: UUID = UUID(), name: String = "") -> SourceProfile {
        SourceProfile(
            id: id,
            name: name,
            endpointURL: "",
            authScheme: .bearer,
            extraHeaderName: "",
            extraHeaderValue: "",
            refreshIntervalSec: 60,
            timeoutSec: 10,
            presetId: PresetID.custom.rawValue,
            statusBarSeparator: " · ",
            compactLargeNumbers: true,
            currencySymbol: "$",
            showProtocolFields: false,
            fields: [],
            remainNumeratorPath: "",
            remainDenominatorPath: "",
            showRemainRatio: false
        )
    }

    static func from(_ config: AppConfig, id: UUID = UUID(), name: String) -> SourceProfile {
        SourceProfile(
            id: id,
            name: name,
            endpointURL: config.endpointURL,
            authScheme: config.authScheme,
            extraHeaderName: config.extraHeaderName,
            extraHeaderValue: config.extraHeaderValue,
            refreshIntervalSec: config.refreshIntervalSec,
            timeoutSec: config.timeoutSec,
            presetId: config.presetId,
            statusBarSeparator: config.statusBarSeparator,
            compactLargeNumbers: config.compactLargeNumbers,
            currencySymbol: config.currencySymbol,
            showProtocolFields: config.showProtocolFields,
            fields: config.fields,
            remainNumeratorPath: config.remainNumeratorPath,
            remainDenominatorPath: config.remainDenominatorPath,
            showRemainRatio: config.showRemainRatio
        )
    }

    func asConfig(languageCode: String?, launchAtLogin: Bool) -> AppConfig {
        AppConfig(
            endpointURL: endpointURL,
            authScheme: authScheme,
            extraHeaderName: extraHeaderName,
            extraHeaderValue: extraHeaderValue,
            refreshIntervalSec: refreshIntervalSec,
            timeoutSec: timeoutSec,
            presetId: presetId,
            statusBarSeparator: statusBarSeparator,
            compactLargeNumbers: compactLargeNumbers,
            currencySymbol: currencySymbol,
            launchAtLogin: launchAtLogin,
            showProtocolFields: showProtocolFields,
            fields: fields,
            remainNumeratorPath: remainNumeratorPath,
            remainDenominatorPath: remainDenominatorPath,
            showRemainRatio: showRemainRatio,
            languageCode: languageCode
        )
    }

    var trimmedURL: String {
        endpointURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func resolvedName(fallbackIndex: Int, language: AppLanguage) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        if let host = URLComponents(string: trimmedURL)?.host, !host.isEmpty { return host }
        return L10n(language: language).untitledSource(fallbackIndex)
    }
}

struct AppState: Codable, Equatable, Sendable {
    var languageCode: String?
    var launchAtLogin: Bool
    var activeSourceID: UUID
    var sources: [SourceProfile]

    static var empty: AppState {
        let source = SourceProfile.empty()
        return AppState(
            languageCode: nil,
            launchAtLogin: false,
            activeSourceID: source.id,
            sources: [source]
        )
    }

    var activeIndex: Int {
        sources.firstIndex(where: { $0.id == activeSourceID }) ?? 0
    }

    var active: SourceProfile {
        sources.indices.contains(activeIndex) ? sources[activeIndex] : sources[0]
    }
}

enum PresetID: String, CaseIterable, Identifiable, Sendable {
    case custom
    case newapiToken = "newapi_token"
    case newapiUser = "newapi_user"
    case openaiUsage = "openai_usage"
    case openaiSubscription = "openai_subscription"

    var id: String { rawValue }

    var title: String {
        L10n(language: AppLanguage.current).preset(self)
    }
}

enum AppError: Equatable, Sendable, Error {
    case notConfigured
    case invalidURL
    case unauthorized
    case forbidden
    case http(Int)
    case timeout
    case cannotFindHost
    case network
    case notJSON
    case tooLarge
    case cancelled

    var statusBarText: String {
        L10n(language: AppLanguage.current).errorStatus(self)
    }

    var detailText: String {
        L10n(language: AppLanguage.current).errorDetail(self)
    }

    static func from(urlError: URLError) -> AppError {
        switch urlError.code {
        case .timedOut: .timeout
        case .cannotFindHost, .dnsLookupFailed: .cannotFindHost
        case .cancelled: .cancelled
        default: .network
        }
    }

    static func from(statusCode: Int) -> AppError {
        switch statusCode {
        case 401: .unauthorized
        case 403: .forbidden
        default: .http(statusCode)
        }
    }
}

enum JSONLeafValue: Equatable, Sendable {
    case number(Double)
    case bool(Bool)
    case string(String)

    var number: Double? {
        switch self {
        case .number(let value):
            return value
        case .string(let text):
            return TotalTodaySplit.parseNumber(text)
        case .bool:
            return nil
        }
    }

    var textValue: String? {
        if case .string(let text) = self { return text }
        return nil
    }
}

struct FlattenedLeaf: Sendable, Equatable {
    var path: String
    var value: JSONLeafValue
}

struct DailySnapshot: Codable, Equatable, Sendable {
    var sourcePath: String
    var date: String
    var rawValue: Double
}

struct LastRequestInfo: Equatable, Sendable {
    var url: String
    var statusCode: Int?
    var durationMs: Int
    var errorText: String?
}

enum AppStatus: Equatable, Sendable {
    case unconfigured
    case refreshing
    case ok
    case stale
    case error
}
