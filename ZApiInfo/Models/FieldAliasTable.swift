import Foundation

struct FieldAlias: Sendable {
    var keys: Set<String>
    var englishName: String
    var chineseName: String
    var category: FieldCategory
    var preferStatusBar: Bool
    var preferMenu: Bool
    var format: FieldFormat
    var scale: Double

    init(
        keys: Set<String>,
        en: String,
        zh: String,
        category: FieldCategory,
        preferStatusBar: Bool,
        format: FieldFormat,
        scale: Double,
        preferMenu: Bool = true
    ) {
        self.keys = keys
        self.englishName = en
        self.chineseName = zh
        self.category = category
        self.preferStatusBar = preferStatusBar
        self.preferMenu = preferMenu
        self.format = format
        self.scale = scale
    }

    func displayName(_ language: AppLanguage = .current) -> String {
        language.isChinese ? chineseName : englishName
    }
}

enum FieldNameRole: Equatable, Sendable {
    case plain
    case total
    case today
}

struct FieldNameInfo: Sendable {
    var sourcePath: String
    var baseKey: String
    var role: FieldNameRole
}

enum FieldAliasTable {
    static let protocolKeys: Set<String> = [
        "success", "code", "message", "object", "error"
    ]

    private static let todayKeys: Set<String> = ["today", "daily", "day"]
    private static let totalKeys: Set<String> = ["total", "sum", "all"]
    private static let spendKeys: Set<String> = ["used_quota", "total_used", "used", "total_usage", "cost"]
    private static let redundantKeys: [String: String] = [
        "actual_cost": "cost",
        "account_cost": "cost"
    ]

    private static let aliases: [FieldAlias] = [
        FieldAlias(keys: ["quota", "total_available", "remaining", "remain_quota", "balance"], en: "Remaining", zh: "剩余", category: .quota, preferStatusBar: true, format: .auto, scale: 1),
        FieldAlias(keys: ["used_quota", "total_used", "used"], en: "Used", zh: "已用", category: .quota, preferStatusBar: false, format: .auto, scale: 1),
        FieldAlias(keys: ["limit", "quota_limit"], en: "Limit", zh: "限额", category: .quota, preferStatusBar: false, format: .auto, scale: 1),
        FieldAlias(keys: ["total_granted", "total_quota"], en: "Granted", zh: "总额", category: .quota, preferStatusBar: false, format: .auto, scale: 1),
        FieldAlias(keys: ["hard_limit_usd"], en: "Hard limit", zh: "硬限额", category: .quota, preferStatusBar: true, format: .currency, scale: 1),
        FieldAlias(keys: ["soft_limit_usd"], en: "Soft limit", zh: "软限额", category: .quota, preferStatusBar: false, format: .currency, scale: 1),
        FieldAlias(keys: ["system_hard_limit_usd"], en: "System hard limit", zh: "系统硬限额", category: .quota, preferStatusBar: false, format: .currency, scale: 1),
        FieldAlias(keys: ["total_usage"], en: "Usage", zh: "用量", category: .quota, preferStatusBar: true, format: .currency, scale: 0.01),
        FieldAlias(keys: ["cost"], en: "Cost", zh: "费用", category: .quota, preferStatusBar: false, format: .currency, scale: 1),
        FieldAlias(keys: ["actual_cost"], en: "Actual cost", zh: "实付", category: .quota, preferStatusBar: false, format: .currency, scale: 1),
        FieldAlias(keys: ["account_cost"], en: "Account cost", zh: "账户费用", category: .quota, preferStatusBar: false, format: .currency, scale: 1),
        FieldAlias(keys: ["unlimited_quota"], en: "Unlimited", zh: "无限额度", category: .quota, preferStatusBar: false, format: .auto, scale: 1),
        FieldAlias(keys: ["unit"], en: "Unit", zh: "单位", category: .quota, preferStatusBar: false, format: .auto, scale: 1, preferMenu: false),
        FieldAlias(keys: ["prompt_tokens", "input_tokens", "upload", "upload_tokens"], en: "Upload", zh: "上传", category: .token, preferStatusBar: true, format: .integer, scale: 1),
        FieldAlias(keys: ["completion_tokens", "output_tokens", "download", "download_tokens"], en: "Download", zh: "下载", category: .token, preferStatusBar: true, format: .integer, scale: 1),
        FieldAlias(keys: ["total_tokens", "token", "tokens"], en: "Tokens", zh: "总 Token", category: .token, preferStatusBar: false, format: .integer, scale: 1),
        FieldAlias(keys: ["cached_tokens", "cache_tokens", "cache_read_tokens"], en: "Cache read", zh: "缓存读", category: .token, preferStatusBar: false, format: .integer, scale: 1),
        FieldAlias(keys: ["cache_write_tokens"], en: "Cache write", zh: "缓存写", category: .token, preferStatusBar: false, format: .integer, scale: 1),
        FieldAlias(keys: ["cache_creation_tokens"], en: "Cache create", zh: "缓存创建", category: .token, preferStatusBar: false, format: .integer, scale: 1),
        FieldAlias(keys: ["reasoning_tokens"], en: "Reasoning tokens", zh: "推理 Token", category: .token, preferStatusBar: false, format: .integer, scale: 1),
        FieldAlias(keys: ["audio_tokens"], en: "Audio tokens", zh: "音频 Token", category: .token, preferStatusBar: false, format: .integer, scale: 1),
        FieldAlias(keys: ["request_count", "requests"], en: "Requests", zh: "请求", category: .request, preferStatusBar: false, format: .integer, scale: 1),
        FieldAlias(keys: ["rpm"], en: "RPM", zh: "RPM", category: .request, preferStatusBar: false, format: .integer, scale: 1),
        FieldAlias(keys: ["tpm"], en: "TPM", zh: "TPM", category: .request, preferStatusBar: false, format: .integer, scale: 1),
        FieldAlias(keys: ["average_duration_ms", "avg_duration_ms"], en: "Avg duration", zh: "平均耗时", category: .request, preferStatusBar: false, format: .decimal, scale: 1),
        FieldAlias(keys: ["name", "token_name", "username", "display_name"], en: "Name", zh: "名称", category: .account, preferStatusBar: false, format: .auto, scale: 1),
        FieldAlias(keys: ["group"], en: "Group", zh: "分组", category: .account, preferStatusBar: false, format: .auto, scale: 1),
        FieldAlias(keys: ["status"], en: "Status", zh: "状态", category: .account, preferStatusBar: false, format: .auto, scale: 1, preferMenu: false),
        FieldAlias(keys: ["mode"], en: "Mode", zh: "模式", category: .account, preferStatusBar: false, format: .auto, scale: 1, preferMenu: false),
        FieldAlias(keys: ["isvalid", "is_valid"], en: "Valid", zh: "有效", category: .account, preferStatusBar: false, format: .auto, scale: 1, preferMenu: false),
        FieldAlias(keys: ["expires_at", "access_until"], en: "Expires", zh: "到期", category: .account, preferStatusBar: false, format: .datetime, scale: 1),
        FieldAlias(keys: ["has_payment_method"], en: "Payment method", zh: "已绑支付", category: .account, preferStatusBar: false, format: .auto, scale: 1)
    ]

    private static let lookup: [String: FieldAlias] = {
        var map: [String: FieldAlias] = [:]
        for alias in aliases {
            for key in alias.keys {
                map[key] = alias
            }
        }
        return map
    }()

    static func unwrapDerived(_ path: String) -> String {
        if path.hasPrefix(DerivedField.todayPrefix) {
            return String(path.dropFirst(DerivedField.todayPrefix.count))
        }
        if path.hasPrefix(DerivedField.deltaPrefix) {
            return String(path.dropFirst(DerivedField.deltaPrefix.count))
        }
        return path
    }

    static func lastKey(_ path: String) -> String {
        path.split(separator: ".").last.map(String.init)?.lowercased() ?? path.lowercased()
    }

    static func analyze(_ path: String) -> FieldNameInfo {
        if path.hasPrefix(DerivedField.todayPrefix) || path.hasPrefix(DerivedField.deltaPrefix) {
            let source = unwrapDerived(path)
            let inner = analyze(source)
            return FieldNameInfo(sourcePath: source, baseKey: inner.baseKey, role: .today)
        }
        let parts = path.split(separator: ".").map { String($0) }
        let last = parts.last?.lowercased() ?? path.lowercased()

        if todayKeys.contains(last) || totalKeys.contains(last) {
            let parentParts = parts.dropLast()
            let baseKey = parentParts.last?.lowercased() ?? last
            let sourcePath = parentParts.joined(separator: ".")
            return FieldNameInfo(
                sourcePath: sourcePath.isEmpty ? path : sourcePath,
                baseKey: baseKey,
                role: todayKeys.contains(last) ? .today : .total
            )
        }

        // usage.today.output_tokens / usage.total.input_tokens: scope is a middle segment
        if parts.count >= 2 {
            for index in stride(from: parts.count - 2, through: 0, by: -1) {
                let key = parts[index].lowercased()
                if key == "today" || key == "daily" {
                    return FieldNameInfo(sourcePath: path, baseKey: last, role: .today)
                }
                if key == "total" {
                    return FieldNameInfo(sourcePath: path, baseKey: last, role: .total)
                }
            }
        }

        // total_used / total_tokens are catalog keys; do not treat them as a Total prefix
        if lookup[last] != nil {
            return FieldNameInfo(sourcePath: path, baseKey: last, role: .plain)
        }

        if let stripped = stripAffix(last, prefixes: ["today_", "daily_", "day_"], suffixes: ["_today", "_daily", "_day"]) {
            return FieldNameInfo(sourcePath: path, baseKey: stripped, role: .today)
        }
        if let stripped = stripAffix(last, prefixes: ["total_", "sum_"], suffixes: ["_total", "_sum"]) {
            return FieldNameInfo(sourcePath: path, baseKey: stripped, role: .total)
        }

        return FieldNameInfo(sourcePath: path, baseKey: last, role: .plain)
    }

    private static func stripAffix(_ key: String, prefixes: [String], suffixes: [String]) -> String? {
        for prefix in prefixes where key.hasPrefix(prefix) {
            let remainder = String(key.dropFirst(prefix.count))
            if !remainder.isEmpty { return remainder }
        }
        for suffix in suffixes where key.hasSuffix(suffix) && key.count > suffix.count {
            return String(key.dropLast(suffix.count))
        }
        return nil
    }

    static func match(path: String) -> FieldAlias? {
        let info = analyze(path)
        if info.role != .plain, let parent = lookup[info.baseKey] {
            return parent
        }
        let last = lastKey(unwrapDerived(path))
        if let exact = lookup[last] { return exact }
        return lookup[info.baseKey]
    }

    static func defaultDisplayName(path: String, language: AppLanguage = .current) -> String {
        if path == DerivedField.remainRatio {
            return language.isChinese ? "剩余%" : "Remaining %"
        }
        if path.hasPrefix(DerivedField.deltaPrefix) || path.hasPrefix(DerivedField.todayPrefix) {
            let source = unwrapDerived(path)
            return defaultDeltaDisplayName(
                sourcePath: source,
                sourceDisplayName: defaultDisplayName(path: source, language: language),
                language: language
            )
        }
        let info = analyze(path)
        let aliasName = match(path: path)?.displayName(language)
        let fallback = path.split(separator: ".").last.map(String.init) ?? path
        switch info.role {
        case .plain:
            return aliasName ?? fallback
        case .total:
            return defaultTotalDisplayName(aliasName ?? (language.isChinese ? "总额" : "Granted"), language: language)
        case .today:
            let baseName = aliasName ?? (info.baseKey.isEmpty ? (language.isChinese ? "用量" : "Usage") : info.baseKey)
            return defaultDeltaDisplayName(sourcePath: info.sourcePath, sourceDisplayName: baseName, language: language)
        }
    }

    static func defaultDeltaDisplayName(
        sourcePath: String,
        sourceDisplayName: String,
        language: AppLanguage = .current
    ) -> String {
        let info = analyze(sourcePath)
        if spendKeys.contains(info.baseKey) || spendKeys.contains(lastKey(sourcePath)) {
            return language.isChinese ? "日费" : "Daily"
        }
        if language.isChinese {
            if sourceDisplayName.hasPrefix("今日") { return sourceDisplayName }
            return "今日\(sourceDisplayName)"
        }
        if sourceDisplayName.hasPrefix("Today ") { return sourceDisplayName }
        return "Today \(sourceDisplayName)"
    }

    static func defaultTotalDisplayName(_ sourceDisplayName: String, language: AppLanguage = .current) -> String {
        if language.isChinese {
            if sourceDisplayName.hasPrefix("累计") { return sourceDisplayName }
            return "累计\(sourceDisplayName)"
        }
        if sourceDisplayName.hasPrefix("Total ") { return sourceDisplayName }
        return "Total \(sourceDisplayName)"
    }

    static func preferMenu(path: String) -> Bool {
        match(path: path)?.preferMenu ?? true
    }

    static func shouldUpdateDefaultDisplayName(current: String, path: String) -> Bool {
        let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return true }
        if trimmed == defaultDisplayName(path: path) { return false }
        return AppLanguage.allCases.contains { language in
            trimmed == defaultDisplayName(path: path, language: language)
        }
    }

    static func preferStatusBar(path: String) -> Bool {
        let info = analyze(path)
        if info.role == .today {
            let name = defaultDisplayName(path: path)
            return name == "Daily" || name == "日费"
        }
        return match(path: path)?.preferStatusBar ?? false
    }

    static func category(path: String) -> FieldCategory {
        if path.hasPrefix("_derived.") { return .derived }
        if let alias = match(path: path) { return alias.category }
        switch analyze(path).role {
        case .plain: return .other
        case .total, .today: return .quota
        }
    }

    static func isProtocolField(path: String) -> Bool {
        let parts = path.split(separator: ".").map(String.init)
        guard let first = parts.first?.lowercased() else { return false }
        if parts.count == 1 { return protocolKeys.contains(first) }
        return false
    }

    static func isSensitive(path: String, value: JSONLeafValue) -> Bool {
        let last = lastKey(unwrapDerived(path))
        let secretNames: Set<String> = ["access_token", "api_key", "password", "secret", "authorization"]
        if secretNames.contains(last) { return true }
        if last.hasSuffix("_tokens") || last == "tokens" || last == "total_tokens" { return false }
        if last.contains("token") {
            if case .string(let text) = value {
                if text.hasPrefix("sk-") || text.count > 40 { return true }
            }
        }
        return false
    }

    static func isCatalogField(path: String) -> Bool {
        if match(path: path) != nil { return true }
        if path.hasPrefix("_derived.") { return true }
        return analyze(path).role != .plain
    }
}
