import Foundation
import Security

enum KeychainStore {
    static let service = "com.zapiinfo.ZApiInfo"
    private static let legacyAccount = "api-key"

    static func account(for sourceID: UUID) -> String {
        "api-key.\(sourceID.uuidString)"
    }

    static func load(sourceID: UUID) -> String {
        load(account: account(for: sourceID))
    }

    static func save(_ key: String, sourceID: UUID) {
        save(key, account: account(for: sourceID))
    }

    static func delete(sourceID: UUID) {
        delete(account: account(for: sourceID))
    }

    static func loadLegacy() -> String {
        load(account: legacyAccount)
    }

    static func deleteLegacy() {
        delete(account: legacyAccount)
    }

    static func migrateLegacyKey(to sourceID: UUID) {
        let legacy = loadLegacy()
        guard !legacy.isEmpty else { return }
        if load(sourceID: sourceID).isEmpty {
            save(legacy, sourceID: sourceID)
        }
        deleteLegacy()
    }

    private static func load(account: String) -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    private static func save(_ key: String, account: String) {
        delete(account: account)
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    private static func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
