import AppKit
import Foundation
import Network
import Observation

@MainActor
@Observable
final class UsageStore {
    static let shared = UsageStore()

    var appState: AppState
    var config: AppConfig
    var apiKey: String
    var sourceName = ""
    var values: [String: JSONLeafValue] = [:]
    var missingPaths: Set<String> = []
    var lastSuccessAt: Date?
    var lastError: AppError?
    var lastRequest: LastRequestInfo?
    var isRefreshing = false
    var snapshots: [DailySnapshot]
    var testMessage: String?
    var saveMessage: String?
    var draftURL = ""
    var draftKey = ""
    var draftExtraName = ""
    var draftExtraValue = ""
    var draftAuth: AuthScheme = .bearer
    var draftInterval = 60
    var draftTimeout = 10
    var draftPreset: PresetID = .custom
    @ObservationIgnored private var lastRawData: Data?

    @ObservationIgnored private var pollTask: Task<Void, Never>?
    @ObservationIgnored private var lastManualRefresh = Date.distantPast
    @ObservationIgnored private var failureStreak = 0
    @ObservationIgnored private var pathMonitor: NWPathMonitor?
    @ObservationIgnored private var wakeObserver: NSObjectProtocol?
    @ObservationIgnored private var lastPathSatisfied = true

    private init() {
        var state = ConfigStore.loadState()
        let language = AppLanguage.resolve(state.languageCode)
        AppLanguage.current = language
        state.languageCode = language.rawValue
        state.launchAtLogin = LaunchAtLogin.isEnabled
        let active = state.active
        let loadedConfig = active.asConfig(languageCode: state.languageCode, launchAtLogin: state.launchAtLogin)
        let loadedKey = KeychainStore.load(sourceID: active.id)
        let loadedSnapshots = ConfigStore.loadSnapshots(sourceID: active.id)
        let loadedCache = ConfigStore.loadCache(sourceID: active.id)
        appState = state
        config = loadedConfig
        sourceName = active.name
        apiKey = loadedKey
        snapshots = loadedSnapshots
        if let loadedCache {
            lastSuccessAt = loadedCache.lastSuccessAt
            values = loadedCache.values.compactMapValues(\.value)
        }
        fillDraftsFromConfig()
        ConfigStore.saveState(state)
    }

    var activeSourceID: UUID { appState.activeSourceID }

    var sources: [SourceProfile] { appState.sources }

    var sourceDisplayTitle: String {
        appState.active.resolvedName(fallbackIndex: appState.activeIndex + 1, language: language)
    }

    var language: AppLanguage {
        AppLanguage(rawValue: appState.languageCode ?? AppLanguage.current.rawValue) ?? AppLanguage.current
    }

    var copy: L10n { L10n(language: language) }

    var status: AppStatus {
        if !config.isConfigured { return .unconfigured }
        if lastError != nil {
            if lastSuccessAt != nil, !values.isEmpty { return .stale }
            if isRefreshing { return .refreshing }
            return .error
        }
        if isRefreshing && values.isEmpty { return .refreshing }
        return .ok
    }

    var statusBarIcon: String {
        switch status {
        case .error: "exclamationmark.triangle"
        case .stale: "chart.bar"
        default: "chart.bar.doc.horizontal"
        }
    }

    var statusBarText: String {
        let copy = copy
        switch status {
        case .unconfigured:
            return copy.notConfigured
        case .error:
            return lastError?.statusBarText ?? copy.requestFailed
        case .refreshing:
            if values.isEmpty { return copy.refreshing }
            return composedStatusBarText(stale: false)
        case .stale:
            return composedStatusBarText(stale: true)
        case .ok:
            return composedStatusBarText(stale: false)
        }
    }

    var statusBarAccessibilityLabel: String {
        "ZApiInfo \(statusBarText)"
    }

    func start() {
        let expanded = TotalTodaySplit.expand(values.map { FlattenedLeaf(path: $0.key, value: $0.value) })
        values = Dictionary(expanded.map { ($0.path, $0.value) }, uniquingKeysWith: { _, last in last })
        mergeDiscoveredFields(expanded, persist: false)
        persistConfig()
        registerNotifications()
        restartPolling()
    }

    func persistConfig() {
        flushActiveToState()
        ConfigStore.saveState(appState)
        KeychainStore.save(apiKey, sourceID: activeSourceID)
        ConfigStore.saveSnapshots(snapshots, sourceID: activeSourceID)
        persistValueCache()
    }

    private func flushActiveToState() {
        let id = activeSourceID
        let profile = SourceProfile.from(config, id: id, name: sourceName)
        if let index = appState.sources.firstIndex(where: { $0.id == id }) {
            appState.sources[index] = profile
        } else {
            appState.sources.append(profile)
        }
        appState.languageCode = config.languageCode
        appState.launchAtLogin = config.launchAtLogin
    }

    private func loadActiveSource() {
        let active = appState.active
        appState.activeSourceID = active.id
        config = active.asConfig(languageCode: appState.languageCode, launchAtLogin: appState.launchAtLogin)
        sourceName = active.name
        apiKey = KeychainStore.load(sourceID: active.id)
        snapshots = ConfigStore.loadSnapshots(sourceID: active.id)
        if let cache = ConfigStore.loadCache(sourceID: active.id) {
            lastSuccessAt = cache.lastSuccessAt
            values = cache.values.compactMapValues(\.value)
        } else {
            lastSuccessAt = nil
            values = [:]
        }
        missingPaths = []
        lastError = nil
        lastRequest = nil
        lastRawData = nil
        fillDraftsFromConfig()
    }

    private func fillDraftsFromConfig() {
        draftURL = config.endpointURL
        draftKey = apiKey
        draftExtraName = config.extraHeaderName
        draftExtraValue = config.extraHeaderValue
        draftAuth = config.authScheme
        draftInterval = config.refreshIntervalSec
        draftTimeout = config.timeoutSec
        draftPreset = PresetID(rawValue: config.presetId) ?? .custom
    }

    func setLanguage(_ language: AppLanguage) {
        guard appState.languageCode != language.rawValue else { return }
        AppLanguage.current = language
        appState.languageCode = language.rawValue
        config.languageCode = language.rawValue
        testMessage = nil
        saveMessage = nil
        refreshDefaultDisplayNames()
        persistConfig()
        SettingsWindowController.shared.syncTitle()
    }

    func setSourceName(_ name: String) {
        sourceName = name
        persistConfig()
    }

    func switchSource(_ id: UUID) {
        guard id != activeSourceID, sources.contains(where: { $0.id == id }) else { return }
        persistConfig()
        appState.activeSourceID = id
        loadActiveSource()
        testMessage = nil
        saveMessage = nil
        ConfigStore.saveState(appState)
        restartPolling()
    }

    func addSource() {
        persistConfig()
        let index = appState.sources.count + 1
        let profile = SourceProfile.empty(name: copy.untitledSource(index))
        appState.sources.append(profile)
        appState.activeSourceID = profile.id
        loadActiveSource()
        testMessage = nil
        saveMessage = nil
        persistConfig()
        restartPolling()
    }

    func duplicateSource() {
        persistConfig()
        var copyProfile = appState.active
        copyProfile.id = UUID()
        let base = copyProfile.resolvedName(fallbackIndex: appState.activeIndex + 1, language: language)
        copyProfile.name = copy.duplicatedSource(base)
        appState.sources.append(copyProfile)
        KeychainStore.save(apiKey, sourceID: copyProfile.id)
        ConfigStore.saveSnapshots(snapshots, sourceID: copyProfile.id)
        if let cache = ConfigStore.loadCache(sourceID: activeSourceID) {
            ConfigStore.saveCache(cache, sourceID: copyProfile.id)
        }
        appState.activeSourceID = copyProfile.id
        loadActiveSource()
        testMessage = nil
        saveMessage = nil
        persistConfig()
        restartPolling()
    }

    func deleteActiveSource() {
        guard appState.sources.count > 1 else { return }
        persistConfig()
        let removedID = activeSourceID
        let index = appState.activeIndex
        appState.sources.removeAll { $0.id == removedID }
        KeychainStore.delete(sourceID: removedID)
        ConfigStore.deleteSnapshots(sourceID: removedID)
        ConfigStore.deleteCache(sourceID: removedID)
        let nextIndex = min(index, appState.sources.count - 1)
        appState.activeSourceID = appState.sources[nextIndex].id
        loadActiveSource()
        testMessage = nil
        saveMessage = nil
        persistConfig()
        restartPolling()
    }

    func saveSource(url: String, key: String, extraName: String, extraValue: String, auth: AuthScheme, interval: Int, timeout: Int) {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isValidEndpoint(trimmed) else {
            saveMessage = copy.invalidURL
            return
        }
        config.endpointURL = trimmed
        config.extraHeaderName = extraName
        config.extraHeaderValue = extraValue
        config.authScheme = auth
        config.refreshIntervalSec = interval
        config.timeoutSec = min(30, max(3, timeout))
        if sourceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sourceName = URLComponents(string: trimmed)?.host ?? ""
        }
        apiKey = key
        draftURL = trimmed
        draftKey = key
        draftExtraName = extraName
        draftExtraValue = extraValue
        draftAuth = auth
        draftInterval = interval
        draftTimeout = config.timeoutSec
        saveMessage = copy.savedRefreshing
        testMessage = nil
        persistConfig()
        lastError = nil
        restartPolling()
        Task { await refresh(force: true) }
    }

    func saveDraft() {
        saveSource(
            url: draftURL,
            key: draftKey,
            extraName: draftExtraName,
            extraValue: draftExtraValue,
            auth: draftAuth,
            interval: draftInterval,
            timeout: draftTimeout
        )
    }

    func applyPreset(_ id: PresetID) {
        let preset = Presets.definition(for: id.rawValue)
        draftPreset = id
        var next = config
        next.endpointURL = draftURL
        Presets.apply(preset, to: &next)
        draftURL = next.endpointURL
        config.presetId = next.presetId
        config.fields = next.fields
        config.remainNumeratorPath = next.remainNumeratorPath
        config.remainDenominatorPath = next.remainDenominatorPath
        config.showRemainRatio = next.showRemainRatio
        if !preset.extraHeaderName.isEmpty, draftExtraName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            draftExtraName = preset.extraHeaderName
        }
    }

    func updateFields(_ mutate: (inout AppConfig) -> Void) {
        let previousProtocol = config.showProtocolFields
        mutate(&config)
        syncDerivedFields()
        persistConfig()
        if config.showProtocolFields != previousProtocol, let lastRawData {
            if let leaves = try? JSONFlattener.flatten(lastRawData) {
                mergeDiscoveredFields(leaves, persist: true)
                applyLeaves(leaves, persistConfig: true)
            }
        }
    }

    func addManualPath(_ path: String) {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, config.field(path: trimmed) == nil else { return }
        var field = FieldConfig(
            path: trimmed,
            displayName: FieldAliasTable.defaultDisplayName(path: trimmed),
            showInStatusBar: false,
            showInMenu: true,
            sortOrder: (config.fields.map(\.sortOrder).max() ?? -1) + 1,
            category: FieldAliasTable.category(path: trimmed)
        )
        if let alias = FieldAliasTable.match(path: trimmed) {
            field.format = alias.format
            field.scale = alias.scale
            field.category = alias.category
        }
        config.fields.append(field)
        persistConfig()
    }

    func moveField(path: String, by offset: Int) {
        var ordered = config.sortedFields
        guard let index = ordered.firstIndex(where: { $0.path == path }) else { return }
        let newIndex = index + offset
        guard ordered.indices.contains(newIndex) else { return }
        ordered.swapAt(index, newIndex)
        for (order, field) in ordered.enumerated() {
            if let existing = config.fields.firstIndex(where: { $0.path == field.path }) {
                config.fields[existing].sortOrder = order
            }
        }
        persistConfig()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LaunchAtLogin.setEnabled(enabled)
            config.launchAtLogin = LaunchAtLogin.isEnabled
        } catch {
            config.launchAtLogin = LaunchAtLogin.isEnabled
        }
        appState.launchAtLogin = config.launchAtLogin
        persistConfig()
    }

    func resetSnapshot(for sourcePath: String) {
        guard let raw = values[sourcePath]?.number else { return }
        upsertSnapshot(sourcePath: sourcePath, raw: raw)
        recomputeDerived()
        persistConfig()
    }

    func resetAllSnapshots() {
        snapshots.removeAll()
        for field in config.fields where field.generateDeltaToday {
            if let raw = values[field.path]?.number {
                upsertSnapshot(sourcePath: field.path, raw: raw)
            }
        }
        recomputeDerived()
        persistConfig()
    }

    func clearLocalData(includingKey: Bool) {
        let ids = appState.sources.map(\.id)
        let keptKey = includingKey ? "" : apiKey
        ConfigStore.clearAll()
        if includingKey {
            for id in ids { KeychainStore.delete(sourceID: id) }
            KeychainStore.deleteLegacy()
        }
        appState = .empty
        appState.languageCode = AppLanguage.current.rawValue
        appState.launchAtLogin = LaunchAtLogin.isEnabled
        loadActiveSource()
        apiKey = keptKey
        testMessage = nil
        saveMessage = nil
        persistConfig()
        restartPolling()
    }

    func refreshNow() {
        let now = Date()
        if now.timeIntervalSince(lastManualRefresh) < 3 { return }
        lastManualRefresh = now
        Task { await refresh(force: true) }
    }

    func testConnection() async {
        testMessage = copy.testing
        saveMessage = nil
        var draft = config
        draft.endpointURL = draftURL.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.extraHeaderName = draftExtraName
        draft.extraHeaderValue = draftExtraValue
        draft.timeoutSec = min(30, max(3, draftTimeout))
        draft.authScheme = draftAuth
        guard Self.isValidEndpoint(draft.endpointURL) else {
            testMessage = copy.invalidURL
            return
        }
        do {
            let result = try await fetch(config: draft, key: draftKey)
            lastRawData = result.data
            let leaves = try JSONFlattener.flatten(result.data)
            mergeDiscoveredFields(leaves, persist: false)
            applyLeaves(leaves, persistConfig: false)
            lastRequest = LastRequestInfo(
                url: result.url,
                statusCode: result.statusCode,
                durationMs: Int(result.duration * 1000),
                errorText: nil
            )
            let visibleCount = leaves.filter { JSONFlattener.isDisplayable($0, showProtocolFields: config.showProtocolFields) }.count
            testMessage = copy.connected(fieldCount: visibleCount)
        } catch let error as AppError {
            testMessage = error.detailText
        } catch {
            testMessage = AppError.network.detailText
        }
    }

    static func isValidEndpoint(_ urlString: String) -> Bool {
        guard let components = URLComponents(string: urlString) else { return false }
        let scheme = components.scheme?.lowercased()
        let host = components.host ?? ""
        return (scheme == "http" || scheme == "https") && !host.isEmpty
    }

    func displayText(for field: FieldConfig) -> String {
        let missing = missingPaths.contains(field.path) || values[field.path] == nil
        return ValueFormatter.text(
            for: values[field.path],
            field: field,
            config: config,
            missing: missing,
            unit: ResponseUnit.detect(from: values)
        )
    }

    func menuFields() -> [FieldConfig] {
        config.sortedFields.filter(\.showInMenu)
    }

    func statusBarFields() -> [FieldConfig] {
        config.sortedFields.filter(\.showInStatusBar)
    }

    private func composedStatusBarText(stale: Bool) -> String {
        let parts = statusBarFields().map { field in
            "\(field.resolvedDisplayName) \(displayText(for: field))"
        }
        let body = parts.isEmpty ? copy.noFields : parts.joined(separator: config.statusBarSeparator)
        return stale ? "\(body)*" : body
    }

    func restartPolling() {
        pollTask?.cancel()
        failureStreak = 0
        pollTask = Task { @MainActor [weak self] in
            await self?.refresh(force: true)
            while let self, !Task.isCancelled {
                let seconds = self.nextInterval()
                try? await Task.sleep(for: .seconds(seconds))
                guard !Task.isCancelled else { break }
                await self.refresh(force: false)
            }
        }
    }

    private func nextInterval() -> Int {
        if failureStreak == 0 { return max(15, config.refreshIntervalSec) }
        let backoff = min(300, config.refreshIntervalSec * Int(pow(2.0, Double(min(failureStreak, 4)))))
        return max(15, backoff)
    }

    func refresh(force: Bool) async {
        if !config.isConfigured {
            lastError = .notConfigured
            isRefreshing = false
            return
        }
        if isRefreshing, !force { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            let result = try await fetch(config: config, key: apiKey)
            lastRawData = result.data
            let leaves = try JSONFlattener.flatten(result.data)
            mergeDiscoveredFields(leaves, persist: true)
            applyLeaves(leaves, persistConfig: true)
            lastError = nil
            failureStreak = 0
            lastRequest = LastRequestInfo(url: result.url, statusCode: result.statusCode, durationMs: Int(result.duration * 1000), errorText: nil)
        } catch let error as AppError {
            if error == .cancelled { return }
            lastError = error
            failureStreak += 1
            lastRequest = LastRequestInfo(url: APIClient.redactedURL(URL(string: config.trimmedURL) ?? URL(fileURLWithPath: "/")), statusCode: statusCode(from: error), durationMs: 0, errorText: error.detailText)
        } catch {
            lastError = .network
            failureStreak += 1
        }
    }

    private func statusCode(from error: AppError) -> Int? {
        switch error {
        case .unauthorized: 401
        case .forbidden: 403
        case .http(let code): code
        default: nil
        }
    }

    private func fetch(config: AppConfig, key: String) async throws -> APIClient.FetchResult {
        guard let components = URLComponents(string: config.trimmedURL), let url = components.url else {
            throw AppError.invalidURL
        }
        let keyToSend = config.authScheme == .none ? "" : key
        return try await APIClient.get(
            url: url,
            apiKey: keyToSend,
            extraHeader: config.extraHeader,
            timeout: TimeInterval(config.timeoutSec)
        )
    }

    private func mergeDiscoveredFields(_ leaves: [FlattenedLeaf], persist: Bool) {
        pruneRedundantFields(keeping: leaves)
        let existing = Set(config.fields.map(\.path))
        var nextOrder = (config.fields.map(\.sortOrder).max() ?? -1) + 1
        let isCustom = config.presetId == PresetID.custom.rawValue
        for leaf in leaves where JSONFlattener.isDisplayable(leaf, showProtocolFields: config.showProtocolFields) {
            if existing.contains(leaf.path) { continue }
            let alias = FieldAliasTable.match(path: leaf.path)
            let catalog = FieldAliasTable.isCatalogField(path: leaf.path)
            var field = FieldConfig(
                path: leaf.path,
                displayName: FieldAliasTable.defaultDisplayName(path: leaf.path),
                showInStatusBar: isCustom && FieldAliasTable.preferStatusBar(path: leaf.path),
                showInMenu: catalog && FieldAliasTable.preferMenu(path: leaf.path),
                generateDeltaToday: false,
                format: alias?.format ?? .auto,
                decimalPlaces: 2,
                scale: alias?.scale ?? 1,
                sortOrder: nextOrder,
                category: FieldAliasTable.category(path: leaf.path)
            )
            if leaf.path.hasSuffix("expires_at") || leaf.path.hasSuffix("access_until") {
                field.format = .datetime
            }
            config.fields.append(field)
            nextOrder += 1
        }
        refreshDefaultDisplayNames()
        syncDerivedFields()
        if persist { persistConfig() }
    }

    private func pruneRedundantFields(keeping leaves: [FlattenedLeaf]) {
        let kept = Set(leaves.map(\.path))
        let displayable = leaves.filter { JSONFlattener.isDisplayable($0, showProtocolFields: config.showProtocolFields) }
        var migrate: [(from: FieldConfig, to: String)] = []
        for field in config.fields where JSONFlattener.isRedundantPath(field.path, keptCanonical: kept) {
            if let canonical = JSONFlattener.canonicalPath(for: field.path, kept: displayable) {
                migrate.append((field, canonical))
            }
        }
        for item in migrate {
            if let index = config.fields.firstIndex(where: { $0.path == item.to }) {
                if item.from.showInStatusBar {
                    config.fields[index].showInStatusBar = true
                }
                if item.from.showInMenu {
                    config.fields[index].showInMenu = true
                }
            }
        }
        let drop = Set(migrate.map(\.from.path)).union(
            config.fields.map(\.path).filter { JSONFlattener.isRedundantPath($0, keptCanonical: kept) }
        )
        config.fields.removeAll { drop.contains($0.path) }
    }

    private func refreshDefaultDisplayNames() {
        for index in config.fields.indices {
            let field = config.fields[index]
            let category = FieldAliasTable.category(path: field.path)
            if field.category == .other, category != .other {
                config.fields[index].category = category
            }
            if config.presetId == PresetID.newapiToken.rawValue, field.path == "data.name" {
                let tokenName = copy.fieldToken
                if field.displayName != tokenName,
                   AppLanguage.allCases.contains(where: { L10n(language: $0).fieldToken == field.displayName }) {
                    config.fields[index].displayName = tokenName
                }
                continue
            }
            guard FieldAliasTable.shouldUpdateDefaultDisplayName(current: field.displayName, path: field.path) else {
                continue
            }
            config.fields[index].displayName = FieldAliasTable.defaultDisplayName(path: field.path)
            if let alias = FieldAliasTable.match(path: field.path), field.format == .auto, alias.format != .auto {
                config.fields[index].format = alias.format
                config.fields[index].scale = alias.scale
            }
        }
    }

    private func applyLeaves(_ leaves: [FlattenedLeaf], persistConfig persist: Bool) {
        let previous = values
        let map = Dictionary(uniqueKeysWithValues: leaves.map { ($0.path, $0.value) })
        var next: [String: JSONLeafValue] = [:]
        var missing: Set<String> = []
        for field in config.fields where !DerivedField.isLocallyComputed(field.path) {
            if let value = map[field.path] {
                next[field.path] = value
            } else {
                missing.insert(field.path)
            }
        }
        values = next
        missingPaths = missing
        updateSnapshotsFromCurrentValues(previousValues: previous)
        recomputeDerived()
        lastSuccessAt = Date()
        persistValueCache()
        if persist { persistConfig() }
    }

    private func syncDerivedFields() {
        for field in config.fields where field.generateDeltaToday && !field.path.hasPrefix("_derived.") {
            let derivedPath = DerivedField.deltaPath(for: field.path)
            if config.field(path: derivedPath) == nil {
                let name = FieldAliasTable.defaultDeltaDisplayName(sourcePath: field.path, sourceDisplayName: field.resolvedDisplayName)
                let derived = FieldConfig(
                    path: derivedPath,
                    displayName: name,
                    showInStatusBar: false,
                    showInMenu: true,
                    generateDeltaToday: false,
                    format: field.format,
                    decimalPlaces: field.decimalPlaces,
                    scale: field.scale,
                    sortOrder: (config.fields.map(\.sortOrder).max() ?? -1) + 1,
                    category: .derived
                )
                config.fields.append(derived)
            } else if let index = config.fields.firstIndex(where: { $0.path == derivedPath }) {
                config.fields[index].scale = field.scale
                config.fields[index].format = field.format
                config.fields[index].decimalPlaces = field.decimalPlaces
            }
        }
        if config.showRemainRatio {
            if config.field(path: DerivedField.remainRatio) == nil {
                config.fields.append(
                    FieldConfig(
                        path: DerivedField.remainRatio,
                        displayName: FieldAliasTable.defaultDisplayName(path: DerivedField.remainRatio),
                        showInStatusBar: false,
                        showInMenu: true,
                        format: .percent,
                        sortOrder: (config.fields.map(\.sortOrder).max() ?? -1) + 1,
                        category: .derived
                    )
                )
            }
        }
    }

    private func updateSnapshotsFromCurrentValues(previousValues: [String: JSONLeafValue]) {
        let today = LocalDay.todayString()
        for field in config.fields where field.generateDeltaToday {
            guard let raw = values[field.path]?.number else { continue }
            if let index = snapshots.firstIndex(where: { $0.sourcePath == field.path }) {
                if snapshots[index].date != today {
                    snapshots[index].date = today
                    snapshots[index].rawValue = previousValues[field.path]?.number ?? raw
                }
            } else {
                snapshots.append(DailySnapshot(sourcePath: field.path, date: today, rawValue: raw))
            }
        }
        ConfigStore.saveSnapshots(snapshots, sourceID: activeSourceID)
    }

    private func upsertSnapshot(sourcePath: String, raw: Double) {
        let today = LocalDay.todayString()
        if let index = snapshots.firstIndex(where: { $0.sourcePath == sourcePath }) {
            snapshots[index].date = today
            snapshots[index].rawValue = raw
        } else {
            snapshots.append(DailySnapshot(sourcePath: sourcePath, date: today, rawValue: raw))
        }
        ConfigStore.saveSnapshots(snapshots, sourceID: activeSourceID)
    }

    private func recomputeDerived() {
        missingPaths = missingPaths.filter { !$0.hasPrefix("_derived.") }
        for field in config.fields where field.generateDeltaToday {
            let derivedPath = DerivedField.deltaPath(for: field.path)
            if let raw = values[field.path]?.number,
               let snapshot = snapshots.first(where: { $0.sourcePath == field.path }) {
                values[derivedPath] = .number(raw - snapshot.rawValue)
                missingPaths.remove(derivedPath)
            } else {
                missingPaths.insert(derivedPath)
                values.removeValue(forKey: derivedPath)
            }
        }

        if config.showRemainRatio {
            let unlimited = values["data.unlimited_quota"]?.number == 1
                || {
                    if case .bool(let flag) = values["data.unlimited_quota"] { return flag }
                    return false
                }()
            let numerator = numericValue(at: config.remainNumeratorPath)
            let denominator: Double? = {
                if !config.remainDenominatorPath.isEmpty {
                    return numericValue(at: config.remainDenominatorPath)
                }
                if let remaining = numericValue(at: config.remainNumeratorPath),
                   let used = numericValue(at: "data.used_quota") ?? numericValue(at: "data.total_used") {
                    return remaining + used
                }
                return nil
            }()
            if unlimited {
                values[DerivedField.remainRatio] = .string("∞")
                missingPaths.remove(DerivedField.remainRatio)
            } else if let numerator, let denominator, denominator != 0 {
                values[DerivedField.remainRatio] = .number(numerator / denominator)
                missingPaths.remove(DerivedField.remainRatio)
            } else {
                missingPaths.insert(DerivedField.remainRatio)
                values.removeValue(forKey: DerivedField.remainRatio)
            }
        }
    }

    private func numericValue(at path: String) -> Double? {
        guard !path.isEmpty else { return nil }
        return values[path]?.number
    }

    private func persistValueCache() {
        let cache = ValueCache(
            lastSuccessAt: lastSuccessAt,
            lastURL: config.trimmedURL,
            values: values.mapValues(CachedLeaf.init)
        )
        ConfigStore.saveCache(cache, sourceID: activeSourceID)
    }

    private func registerNotifications() {
        if wakeObserver == nil {
            wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didWakeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    await self?.refresh(force: true)
                }
            }
        }
        if pathMonitor == nil {
            let monitor = NWPathMonitor()
            monitor.pathUpdateHandler = { [weak self] path in
                Task { @MainActor in
                    guard let self else { return }
                    let satisfied = path.status == .satisfied
                    if satisfied && !self.lastPathSatisfied {
                        await self.refresh(force: true)
                    }
                    self.lastPathSatisfied = satisfied
                }
            }
            monitor.start(queue: DispatchQueue(label: "com.zapiinfo.path"))
            pathMonitor = monitor
        }
    }
}
