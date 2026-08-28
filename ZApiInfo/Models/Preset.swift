import Foundation

struct PresetDefinition: Sendable {
    var id: PresetID
    var path: String
    var extraHeaderName: String
    var remainNumeratorPath: String
    var remainDenominatorPath: String
    var showRemainRatio: Bool
    var seeds: [FieldConfig]
}

enum Presets {
    static let quotaPerDollar = 1.0 / 500_000.0

    static let all: [PresetDefinition] = [
        PresetDefinition(
            id: .custom,
            path: "",
            extraHeaderName: "",
            remainNumeratorPath: "",
            remainDenominatorPath: "",
            showRemainRatio: false,
            seeds: []
        ),
        PresetDefinition(
            id: .newapiToken,
            path: "/api/usage/token",
            extraHeaderName: "",
            remainNumeratorPath: "data.total_available",
            remainDenominatorPath: "data.total_granted",
            showRemainRatio: false,
            seeds: [
                seed("data.total_available", statusBar: true, menu: true, category: .quota, format: .currency, scale: quotaPerDollar),
                seed("data.total_used", statusBar: false, menu: true, delta: true, category: .quota, format: .currency, scale: quotaPerDollar),
                seed(DerivedField.deltaPath(for: "data.total_used"), statusBar: true, menu: true, category: .derived, format: .currency, scale: quotaPerDollar),
                seed("data.total_granted", statusBar: false, menu: true, category: .quota, format: .currency, scale: quotaPerDollar),
                seed("data.unlimited_quota", statusBar: false, menu: true, category: .quota),
                seed("data.name", statusBar: false, menu: true, category: .account),
                seed("data.expires_at", statusBar: false, menu: true, category: .account, format: .datetime)
            ]
        ),
        PresetDefinition(
            id: .newapiUser,
            path: "/api/user/self",
            extraHeaderName: "New-Api-User",
            remainNumeratorPath: "data.quota",
            remainDenominatorPath: "",
            showRemainRatio: false,
            seeds: [
                seed("data.quota", statusBar: true, menu: true, category: .quota, format: .currency, scale: quotaPerDollar),
                seed("data.used_quota", statusBar: false, menu: true, delta: true, category: .quota, format: .currency, scale: quotaPerDollar),
                seed(DerivedField.deltaPath(for: "data.used_quota"), statusBar: true, menu: true, category: .derived, format: .currency, scale: quotaPerDollar),
                seed("data.request_count", statusBar: false, menu: true, delta: true, category: .request, format: .integer),
                seed(DerivedField.deltaPath(for: "data.request_count"), statusBar: false, menu: true, category: .derived, format: .integer),
                seed("data.username", statusBar: false, menu: true, category: .account),
                seed("data.display_name", statusBar: false, menu: true, category: .account),
                seed("data.group", statusBar: false, menu: true, category: .account)
            ]
        ),
        PresetDefinition(
            id: .openaiUsage,
            path: "/v1/dashboard/billing/usage",
            extraHeaderName: "",
            remainNumeratorPath: "",
            remainDenominatorPath: "",
            showRemainRatio: false,
            seeds: [
                seed("total_usage", statusBar: true, menu: true, delta: true, category: .quota, format: .currency, scale: 0.01),
                seed(DerivedField.deltaPath(for: "total_usage"), statusBar: true, menu: true, category: .derived, format: .currency, scale: 0.01)
            ]
        ),
        PresetDefinition(
            id: .openaiSubscription,
            path: "/v1/dashboard/billing/subscription",
            extraHeaderName: "",
            remainNumeratorPath: "",
            remainDenominatorPath: "",
            showRemainRatio: false,
            seeds: [
                seed("hard_limit_usd", statusBar: true, menu: true, category: .quota, format: .currency),
                seed("soft_limit_usd", statusBar: false, menu: true, category: .quota, format: .currency),
                seed("access_until", statusBar: false, menu: true, category: .account, format: .datetime),
                seed("has_payment_method", statusBar: false, menu: true, category: .account)
            ]
        )
    ]

    static func definition(for id: String) -> PresetDefinition {
        PresetID(rawValue: id).flatMap { id in all.first { $0.id == id } } ?? all[0]
    }

    static func apply(_ preset: PresetDefinition, to config: inout AppConfig) {
        config.presetId = preset.id.rawValue
        config.endpointURL = rewrittenURL(current: config.endpointURL, path: preset.path)
        if !preset.extraHeaderName.isEmpty, config.extraHeaderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            config.extraHeaderName = preset.extraHeaderName
        }
        config.remainNumeratorPath = preset.remainNumeratorPath
        config.remainDenominatorPath = preset.remainDenominatorPath
        config.showRemainRatio = preset.showRemainRatio
        if preset.id != .custom {
            config.fields = preset.seeds.enumerated().map { index, seed in
                var field = seed
                if preset.id == .newapiToken, seed.path == "data.name" {
                    field.displayName = L10n(language: AppLanguage.current).fieldToken
                } else {
                    field.displayName = FieldAliasTable.defaultDisplayName(path: seed.path)
                }
                field.sortOrder = index
                return field
            }
        }
    }

    static func rewrittenURL(current: String, path: String) -> String {
        guard !path.isEmpty else { return current }
        if let origin = origin(from: current) {
            return origin + path
        }
        return "https://your-api.example.com" + path
    }

    static func origin(from urlString: String) -> String? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), let scheme = url.scheme, let host = url.host else { return nil }
        if let port = url.port {
            return "\(scheme)://\(host):\(port)"
        }
        return "\(scheme)://\(host)"
    }

    private static func seed(
        _ path: String,
        statusBar: Bool,
        menu: Bool,
        delta: Bool = false,
        category: FieldCategory,
        format: FieldFormat = .auto,
        scale: Double = 1
    ) -> FieldConfig {
        FieldConfig(
            path: path,
            displayName: "",
            showInStatusBar: statusBar,
            showInMenu: menu,
            generateDeltaToday: delta,
            format: format,
            decimalPlaces: format == .currency ? 2 : 2,
            scale: scale,
            sortOrder: 0,
            category: category
        )
    }
}
