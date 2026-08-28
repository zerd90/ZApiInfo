import Foundation

enum ValueFormatter {
    static func text(
        for value: JSONLeafValue?,
        field: FieldConfig,
        config: AppConfig,
        missing: Bool,
        unit: ResponseUnit = .none
    ) -> String {
        if missing || value == nil { return "—" }
        guard let value else { return "—" }

        switch value {
        case .bool(let flag):
            return flag ? L10n(language: AppLanguage.current).yes : L10n(language: AppLanguage.current).no
        case .string(let text):
            return text
        case .number(let raw):
            return format(number: raw, field: field, config: config, unit: unit)
        }
    }

    static func format(number raw: Double, field: FieldConfig, config: AppConfig, unit: ResponseUnit = .none) -> String {
        if field.format == .datetime {
            return formatTimestamp(raw)
        }
        let scaled = raw * field.scale
        if shouldRenderAsCurrency(field: field, unit: unit) {
            let symbol = unit.currencySymbol ?? config.currencySymbol
            let body = decimal(scaled, places: max(field.decimalPlaces, 2), compact: false)
            return symbol + body
        }
        if shouldAppendUnitLabel(field: field, unit: unit), let label = unit.suffixLabel {
            let body: String = {
                if abs(scaled - scaled.rounded()) < 0.000_000_1, abs(scaled) >= 1 || scaled == 0 {
                    return grouped(Int64(scaled.rounded()), compact: config.compactLargeNumbers)
                }
                return decimal(scaled, places: field.decimalPlaces, compact: config.compactLargeNumbers)
            }()
            return "\(body) \(label)"
        }
        switch field.format {
        case .integer:
            return grouped(Int64(scaled.rounded()), compact: config.compactLargeNumbers)
        case .decimal:
            return decimal(scaled, places: field.decimalPlaces, compact: config.compactLargeNumbers)
        case .percent:
            return String(format: "%.\(max(0, field.decimalPlaces))f%%", scaled * 100)
        case .currency:
            let body = decimal(scaled, places: max(field.decimalPlaces, 2), compact: false)
            return config.currencySymbol + body
        case .datetime:
            return formatTimestamp(raw)
        case .auto:
            if abs(scaled - scaled.rounded()) < 0.000_000_1, abs(scaled) >= 1 || scaled == 0 {
                return grouped(Int64(scaled.rounded()), compact: config.compactLargeNumbers)
            }
            return decimal(scaled, places: field.decimalPlaces, compact: config.compactLargeNumbers)
        }
    }

    static func remainRatioText(numerator: Double?, denominator: Double?, unlimited: Bool) -> String {
        if unlimited { return "∞" }
        guard let numerator, let denominator, denominator != 0 else { return "—" }
        let ratio = numerator / denominator
        return String(format: "%.1f%%", ratio * 100)
    }

    private static func formatTimestamp(_ raw: Double) -> String {
        if raw == 0 { return L10n(language: AppLanguage.current).neverExpires }
        let date = Date(timeIntervalSince1970: raw)
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.current.locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private static func grouped(_ value: Int64, compact: Bool) -> String {
        if compact, abs(value) >= 10_000 {
            return compactNumber(Double(value))
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = AppLanguage.current.locale
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private static func decimal(_ value: Double, places: Int, compact: Bool) -> String {
        if compact, abs(value) >= 10_000 {
            return compactNumber(value)
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = AppLanguage.current.locale
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = max(0, places)
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.\(places)f", value)
    }

    private static func compactNumber(_ value: Double) -> String {
        let absValue = abs(value)
        let sign = value < 0 ? "-" : ""
        if absValue >= 1_000_000 {
            return String(format: "%@%.1fM", sign, absValue / 1_000_000)
        }
        return String(format: "%@%.1fk", sign, absValue / 1_000)
    }

    private static func shouldRenderAsCurrency(field: FieldConfig, unit: ResponseUnit) -> Bool {
        guard unit.isCurrency || field.format == .currency else { return false }
        guard appliesQuotaUnit(to: field) else {
            return field.format == .currency && unit.isCurrency
        }
        switch field.format {
        case .auto, .currency, .decimal: return unit.isCurrency || field.format == .currency
        default: return false
        }
    }

    private static func shouldAppendUnitLabel(field: FieldConfig, unit: ResponseUnit) -> Bool {
        guard case .labeled = unit else { return false }
        guard appliesQuotaUnit(to: field) else { return false }
        switch field.format {
        case .auto, .decimal: return true
        default: return false
        }
    }

    private static func appliesQuotaUnit(to field: FieldConfig) -> Bool {
        let last = field.lastComponent.lowercased()
        if last == "unit" || last == "unlimited_quota" { return false }
        if field.category == .quota { return true }
        let quotaKeys: Set<String> = [
            "remaining", "remain_quota", "total_available", "balance",
            "used", "used_quota", "total_used",
            "limit", "quota_limit", "total_granted", "total_quota",
            "cost", "actual_cost", "account_cost", "total_usage"
        ]
        return quotaKeys.contains(last)
    }
}

enum ResponseUnit: Equatable, Sendable {
    case currency(symbol: String)
    case labeled(String)
    case none

    var isCurrency: Bool {
        if case .currency = self { return true }
        return false
    }

    var currencySymbol: String? {
        if case .currency(let symbol) = self { return symbol }
        return nil
    }

    var suffixLabel: String? {
        if case .labeled(let label) = self { return label }
        return nil
    }

    static func detect(from values: [String: JSONLeafValue]) -> ResponseUnit {
        let keys = ["quota.unit", "data.quota.unit", "unit", "data.unit", "usage.unit"]
        for key in keys {
            if let raw = values[key]?.textValue?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty {
                return parse(raw)
            }
        }
        return .none
    }

    static func parse(_ raw: String) -> ResponseUnit {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let upper = trimmed.uppercased()
        let symbols: [String: String] = [
            "USD": "$", "US$": "$", "$": "$",
            "CNY": "¥", "RMB": "¥", "CNH": "¥", "YUAN": "¥", "元": "¥",
            "JPY": "¥", "JPY¥": "¥",
            "EUR": "€", "GBP": "£",
            "HKD": "HK$", "KRW": "₩",
            "AUD": "A$", "CAD": "C$", "SGD": "S$"
        ]
        if let symbol = symbols[upper] ?? symbols[trimmed] {
            return .currency(symbol: symbol)
        }
        return .labeled(trimmed)
    }
}

enum LocalDay {
    static func todayString(_ date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = Calendar.current.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
