import Foundation

enum AppLanguage: String, Codable, CaseIterable, Identifiable, Sendable {
    case english = "en"
    case chinese = "zh-Hans"

    var id: String { rawValue }

    /// Always shown in that language so the picker is recognizable either way.
    var title: String {
        switch self {
        case .english: "English"
        case .chinese: "简体中文"
        }
    }

    var isChinese: Bool { self == .chinese }

    var locale: Locale {
        switch self {
        case .english: Locale(identifier: "en_US")
        case .chinese: Locale(identifier: "zh_CN")
        }
    }

    static var current: AppLanguage {
        get { CurrentLanguage.shared.value }
        set { CurrentLanguage.shared.value = newValue }
    }

    static func resolve(_ stored: String?) -> AppLanguage {
        if let stored, let language = AppLanguage(rawValue: stored) {
            return language
        }
        return detectSystem()
    }

    static func detectSystem() -> AppLanguage {
        for identifier in Locale.preferredLanguages where isChineseIdentifier(identifier) {
            return .chinese
        }
        if let code = Locale.current.language.languageCode?.identifier, isChineseIdentifier(code) {
            return .chinese
        }
        return .english
    }

    private static func isChineseIdentifier(_ identifier: String) -> Bool {
        let lowered = identifier.lowercased()
        return lowered == "zh" || lowered.hasPrefix("zh-") || lowered.hasPrefix("zh_")
    }
}

private final class CurrentLanguage: @unchecked Sendable {
    static let shared = CurrentLanguage()
    private let lock = NSLock()
    private var stored: AppLanguage = .english

    var value: AppLanguage {
        get {
            lock.lock()
            defer { lock.unlock() }
            return stored
        }
        set {
            lock.lock()
            stored = newValue
            lock.unlock()
        }
    }
}

struct L10n {
    var language: AppLanguage

    private var zh: Bool { language.isChinese }

    private func t(_ english: String, _ chinese: String) -> String {
        zh ? chinese : english
    }

    var settingsTitle: String { t("ZApiInfo Settings", "ZApiInfo 设置") }
    var tabSource: String { t("Source", "数据源") }
    var tabFields: String { t("Fields", "展示字段") }
    var tabGeneral: String { t("General", "通用") }

    var sectionSources: String { t("Sources", "数据源") }
    var pickerSource: String { t("Current source", "当前数据源") }
    var sourceName: String { t("Name", "名称") }
    var addSource: String { t("Add", "添加") }
    var duplicateSource: String { t("Duplicate", "复制") }
    var deleteSource: String { t("Delete", "删除") }
    var sourceHint: String {
        t(
            "Each source keeps its own URL, API key, fields, and status-bar selection. Switch sources here or in the menu-bar window.",
            "每个数据源单独保存 URL、API Key、字段和状态栏勾选。可在这里或菜单栏窗口里切换。"
        )
    }

    func untitledSource(_ index: Int) -> String {
        t("Source \(index)", "数据源 \(index)")
    }

    func duplicatedSource(_ name: String) -> String {
        t("\(name) copy", "\(name) 副本")
    }

    var sectionPreset: String { t("Preset", "预设") }
    var pickerTemplate: String { t("Template", "模板") }
    var presetHint: String {
        t(
            "Choosing a preset rewrites the URL path and fills recommended fields. It does not overwrite the API key or save immediately. Test after changing the hostname, then click Save.",
            "选择预设会改写 URL 路径并填入推荐字段，不会覆盖 API Key，也不会立刻保存。改好主机名后请先测试，再点保存。"
        )
    }
    var sectionRequest: String { t("Request", "请求") }
    var httpWarning: String {
        t(
            "HTTP is in use. Prefer this only on a private network or for development.",
            "当前为 HTTP，仅建议用于内网或开发环境。"
        )
    }
    var pickerAuth: String { t("Auth", "鉴权") }
    var hide: String { t("Hide", "隐藏") }
    var show: String { t("Show", "显示") }
    var extraHeaderName: String { t("Extra header name", "额外请求头名") }
    var extraHeaderValue: String { t("Extra header value", "额外请求头值") }
    var extraHeaderHint: String {
        t(
            "Put secrets in the API Key field. Extra headers are for gateway user IDs and similar.",
            "密钥请放在 API Key 栏。额外头用于网关要求的用户 ID 等。"
        )
    }
    var sectionRefresh: String { t("Refresh", "刷新") }
    var pickerInterval: String { t("Interval", "间隔") }
    var testConnection: String { t("Test connection", "测试连接") }
    var save: String { t("Save", "保存") }
    var testing: String { t("Testing…", "测试中…") }
    var invalidURL: String {
        t(
            "Invalid URL. Use an address that starts with http:// or https:// and includes a hostname.",
            "URL 无效，请填写以 http:// 或 https:// 开头、带主机名的地址。"
        )
    }
    var savedRefreshing: String { t("Saved. Refreshing now.", "已保存，开始刷新。") }

    func intervalLabel(_ seconds: Int) -> String {
        switch seconds {
        case 15: t("15 seconds", "15 秒")
        case 30: t("30 seconds", "30 秒")
        case 60: t("1 minute", "1 分钟")
        case 300: t("5 minutes", "5 分钟")
        case 900: t("15 minutes", "15 分钟")
        default: t("\(seconds) seconds", "\(seconds) 秒")
        }
    }

    func timeoutLabel(_ seconds: Int) -> String {
        t("Timeout \(seconds) s", "超时 \(seconds) 秒")
    }

    func connected(fieldCount: Int) -> String {
        t(
            "Connected. Parsed \(fieldCount) displayable field(s). Click Save to write the URL and start refreshing.",
            "连接成功，解析到 \(fieldCount) 个可显示字段。请再点「保存」才会写入 URL 并开始刷新。"
        )
    }

    var selectAllMenu: String { t("Select all menu", "全选明细") }
    var catalogOnly: String { t("Catalog fields only", "仅目录字段") }
    var deselectAll: String { t("Deselect all", "全不选") }
    var showProtocolFields: String { t("Show protocol fields", "显示协议字段") }
    var menuVsStatusBarHint: String {
        t(
            "Menu controls whether an item appears in the popover. Status bar controls whether it stays in the menu-bar text.",
            "「明细」控制点开菜单后是否显示；「状态栏」控制是否出现在菜单栏常驻文字里。"
        )
    }
    var separator: String { t("Separator", "分隔符") }
    var compactLargeNumbers: String { t("Compact large numbers", "大数缩写") }
    var currency: String { t("Currency", "货币符号") }
    var currencyHelp: String {
        t(
            "If the JSON includes unit (e.g. USD), quota and cost fields prefer that unit",
            "接口 JSON 含 unit（如 USD）时，额度/费用优先用接口单位"
        )
    }
    var showRemainRatio: String { t("Show remaining ratio", "显示剩余占比") }
    var unitFallbackHint: String {
        t(
            "If the response includes unit (for example USD), remaining / used / daily quota fields use that unit. This symbol is a fallback.",
            "若响应里有 unit（例如 USD），剩余/已用/日费等额度字段会按该单位显示；此项仅作后备。"
        )
    }

    func statusBarTooWide(_ count: Int) -> String {
        t(
            "\(count) items are selected for the status bar; the menu bar may get too wide.",
            "状态栏已勾选 \(count) 项，菜单栏可能过宽。"
        )
    }

    var addFieldPath: String { t("Add field path", "手动添加字段路径") }
    var add: String { t("Add", "添加") }
    var ratioNumerator: String { t("Ratio numerator", "占比分子") }
    var ratioDenominator: String { t("Ratio denominator", "占比分母") }
    var notSet: String { t("Not set", "未设置") }
    var menu: String { t("Menu", "明细") }
    var statusBar: String { t("Status bar", "状态栏") }
    var displayName: String { t("Display name", "显示名") }
    var menuHelp: String { t("Show this item in the popover", "点开菜单栏后是否显示这一项") }
    var statusBarHelp: String { t("Show this item in the persistent menu-bar text", "是否显示在菜单栏常驻文字中") }
    var moveUp: String { t("Move up", "上移") }
    var moveDown: String { t("Move down", "下移") }
    var todayDelta: String { t("Today delta", "今日增量") }
    var missingThisTime: String { t("Missing this time", "本次缺失") }
    var format: String { t("Format", "格式") }
    var scale: String { t("Scale", "系数") }
    var resetToday: String { t("Reset today", "重置今日") }

    var sectionLanguage: String { t("Language", "语言") }
    var pickerLanguage: String { t("App language", "应用语言") }
    var languageHint: String {
        t(
            "Chosen on first launch from the system language. Changing it updates UI copy and default field names; custom names are kept.",
            "首次启动按系统语言选定。更改后会更新界面文案和默认显示名，自定义名称会保留。"
        )
    }
    var sectionStartup: String { t("Startup", "启动") }
    var launchAtLogin: String { t("Launch at login", "登录时启动") }
    var sectionSnapshots: String { t("Snapshots", "快照") }
    var resetAllSnapshots: String { t("Reset all today snapshots", "重置全部今日快照") }
    var snapshotsHint: String {
        t(
            "Treat current values as today's baseline. Today's deltas start from 0 again.",
            "把当前值当作今日起点，今日增量会从 0 重新累计。"
        )
    }
    var sectionData: String { t("Data", "数据") }
    var alsoDeleteKey: String { t("Also delete API key", "同时删除 API Key") }
    var clearLocalData: String { t("Clear local data…", "清除本地数据…") }
    var sectionAbout: String { t("About", "关于") }
    var version: String { t("Version", "版本") }
    var aboutHint: String {
        t(
            "The API key is stored in the Keychain. Configuration is stored in UserDefaults. Nothing is uploaded.",
            "API Key 保存在本机钥匙串，配置保存在 UserDefaults。不会上传任何数据。"
        )
    }
    var clearAlertTitle: String { t("Clear local data?", "清除本地数据？") }
    var cancel: String { t("Cancel", "取消") }
    var clear: String { t("Clear", "清除") }
    var clearMessageWithKey: String {
        t(
            "This deletes the URL, field mapping, snapshots, and API key.",
            "将删除 URL、字段映射、快照和 API Key。"
        )
    }
    var clearMessageKeepKey: String {
        t(
            "This deletes the URL, field mapping, and snapshots. The API key in the Keychain is kept.",
            "将删除 URL、字段映射和快照，保留钥匙串中的 API Key。"
        )
    }

    var retry: String { t("Retry", "重试") }
    var noSource: String { t("No data source configured", "尚未配置数据源") }
    var noSourceHint: String {
        t(
            "Open Settings, enter the URL and API key, test, then click Save.",
            "打开设置，填写 URL 和 API Key，测试通过后点「保存」。"
        )
    }
    var noFieldsHint: String {
        t(
            "No fields to show. Test the connection, then enable fields in Settings.",
            "还没有可显示字段。测试连接后可在设置中勾选。"
        )
    }
    var cached: String { t("Cached", "缓存") }
    var refresh: String { t("Refresh", "刷新") }
    var copyRequest: String { t("Copy request info", "复制请求信息") }
    var settings: String { t("Settings…", "设置…") }
    var quit: String { t("Quit", "退出") }
    var notRefreshed: String { t("Not refreshed yet", "尚未成功刷新") }
    var noRequestRecorded: String { t("No request recorded", "暂无请求记录") }
    var copyStatus: String { t("Status", "状态码") }
    var copyDuration: String { t("Duration", "耗时") }
    var copyError: String { t("Error", "错误") }

    func lastSuccess(_ time: String) -> String {
        t("Last success \(time)", "上次成功 \(time)")
    }

    var notConfigured: String { t("Not configured", "未配置") }
    var requestFailed: String { t("Request failed", "请求失败") }
    var refreshing: String { t("Refreshing", "刷新中") }
    var noFields: String { t("No fields", "无字段") }
    var yes: String { t("Yes", "是") }
    var no: String { t("No", "否") }
    var neverExpires: String { t("Never expires", "永不过期") }
    var fieldToken: String { t("Token", "令牌") }

    var categoryQuota: String { t("Quota", "额度") }
    var categoryToken: String { t("Token", "Token") }
    var categoryRequest: String { t("Request", "请求") }
    var categoryAccount: String { t("Account", "账户") }
    var categoryDerived: String { t("Derived", "派生") }
    var categoryOther: String { t("Other", "其它") }

    var formatAuto: String { t("Auto", "自动") }
    var formatInteger: String { t("Integer", "整数") }
    var formatDecimal: String { t("Decimal", "小数") }
    var formatPercent: String { t("Percent", "百分比") }
    var formatCurrency: String { t("Currency", "货币") }
    var formatDatetime: String { t("Date/time", "时间") }

    var authBearer: String { "Bearer Token" }
    var authNone: String { t("None", "无鉴权") }

    var presetCustom: String { t("Custom", "自定义") }
    var presetNewapiToken: String { t("New API token usage", "New API 令牌用量") }
    var presetNewapiUser: String { t("New API user info", "New API 用户信息") }
    var presetOpenaiUsage: String { t("OpenAI-compatible Usage", "OpenAI 兼容 Usage") }
    var presetOpenaiSubscription: String { t("OpenAI-compatible Subscription", "OpenAI 兼容 Subscription") }

    var errorAuthFailed: String { t("Auth failed", "鉴权失败") }
    var errorTimeout: String { t("Timeout", "超时") }
    var errorHostNotFound: String { t("Host not found", "无法解析主机") }
    var errorNotJSON: String { t("Not JSON", "非 JSON") }
    var errorTooLarge: String { t("Response too large", "响应过大") }
    var errorInvalidURL: String { t("Invalid URL", "URL 无效") }
    var errorCancelled: String { t("Cancelled", "已取消") }

    var errorNotConfiguredDetail: String { t("Set a request URL in Settings first.", "请先在设置中填写请求 URL。") }
    var errorInvalidURLDetail: String { t("The URL could not be parsed. Check the format.", "URL 无法解析，请检查格式。") }
    var errorUnauthorizedDetail: String { t("Authentication failed. Check the API key.", "鉴权失败，请检查 API Key。") }
    var errorForbiddenDetail: String { t("Authentication failed. Check the API key or extra headers.", "鉴权失败，请检查 API Key 或额外请求头。") }
    var errorTimeoutDetail: String { t("Request timed out. Increase the timeout in Settings.", "请求超时，可在设置中加大超时时间。") }
    var errorHostDetail: String { t("Could not resolve the host. Check the URL or network.", "无法解析主机，请检查 URL 或网络。") }
    var errorNetworkDetail: String { t("Network request failed.", "网络请求失败。") }
    var errorNotJSONDetail: String { t("Response is not valid JSON.", "响应不是有效 JSON。") }
    var errorTooLargeDetail: String { t("Response exceeds 2 MB and was not parsed.", "响应超过 2MB，已拒绝解析。") }
    var errorCancelledDetail: String { t("Request cancelled.", "请求已取消。") }

    func errorHTTP(_ code: Int) -> String { "HTTP \(code)" }

    func errorHTTPDetail(_ code: Int) -> String {
        t("Server returned HTTP \(code).", "服务器返回 HTTP \(code)。")
    }

    func category(_ value: FieldCategory) -> String {
        switch value {
        case .quota: categoryQuota
        case .token: categoryToken
        case .request: categoryRequest
        case .account: categoryAccount
        case .derived: categoryDerived
        case .other: categoryOther
        }
    }

    func format(_ value: FieldFormat) -> String {
        switch value {
        case .auto: formatAuto
        case .integer: formatInteger
        case .decimal: formatDecimal
        case .percent: formatPercent
        case .currency: formatCurrency
        case .datetime: formatDatetime
        }
    }

    func auth(_ value: AuthScheme) -> String {
        switch value {
        case .bearer: authBearer
        case .none: authNone
        }
    }

    func preset(_ value: PresetID) -> String {
        switch value {
        case .custom: presetCustom
        case .newapiToken: presetNewapiToken
        case .newapiUser: presetNewapiUser
        case .openaiUsage: presetOpenaiUsage
        case .openaiSubscription: presetOpenaiSubscription
        }
    }

    func errorStatus(_ error: AppError) -> String {
        switch error {
        case .notConfigured: notConfigured
        case .unauthorized, .forbidden: errorAuthFailed
        case .http(let code): errorHTTP(code)
        case .timeout: errorTimeout
        case .cannotFindHost: errorHostNotFound
        case .network: requestFailed
        case .notJSON: errorNotJSON
        case .tooLarge: errorTooLarge
        case .invalidURL: errorInvalidURL
        case .cancelled: errorCancelled
        }
    }

    func errorDetail(_ error: AppError) -> String {
        switch error {
        case .notConfigured: errorNotConfiguredDetail
        case .invalidURL: errorInvalidURLDetail
        case .unauthorized: errorUnauthorizedDetail
        case .forbidden: errorForbiddenDetail
        case .http(let code): errorHTTPDetail(code)
        case .timeout: errorTimeoutDetail
        case .cannotFindHost: errorHostDetail
        case .network: errorNetworkDetail
        case .notJSON: errorNotJSONDetail
        case .tooLarge: errorTooLargeDetail
        case .cancelled: errorCancelledDetail
        }
    }
}
