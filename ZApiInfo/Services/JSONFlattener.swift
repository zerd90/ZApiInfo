import Foundation

enum JSONFlattener {
    static let maxBytes = 2_000_000
    static let maxStringLength = 120

    static func flatten(_ data: Data) throws -> [FlattenedLeaf] {
        if data.count > maxBytes { throw AppError.tooLarge }
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        } catch {
            throw AppError.notJSON
        }
        var leaves: [FlattenedLeaf] = []
        walk(object, path: "", into: &leaves)
        return deduplicate(leaves)
    }

    private static func walk(_ value: Any, path: String, into leaves: inout [FlattenedLeaf]) {
        if let dictionary = value as? [String: Any] {
            for (key, nested) in dictionary.sorted(by: { $0.key < $1.key }) {
                let next = path.isEmpty ? key : "\(path).\(key)"
                walk(nested, path: next, into: &leaves)
            }
            return
        }
        if value is [Any] { return }
        guard !path.isEmpty else { return }
        if let parsed = leafValue(value) {
            leaves.append(contentsOf: TotalTodaySplit.expandLeaf(FlattenedLeaf(path: path, value: parsed)))
        }
    }

    private static func leafValue(_ value: Any) -> JSONLeafValue? {
        if let bool = value as? Bool {
            return .bool(bool)
        }
        if let number = value as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return .bool(number.boolValue)
            }
            return .number(number.doubleValue)
        }
        if let string = value as? String {
            return .string(string)
        }
        return nil
    }

    static func isDisplayable(_ leaf: FlattenedLeaf, showProtocolFields: Bool) -> Bool {
        if FieldAliasTable.isSensitive(path: leaf.path, value: leaf.value) { return false }
        if !showProtocolFields && FieldAliasTable.isProtocolField(path: leaf.path) { return false }
        if case .string(let text) = leaf.value, text.count > maxStringLength { return false }
        return true
    }

    static func valuesMatch(_ lhs: JSONLeafValue, _ rhs: JSONLeafValue) -> Bool {
        switch (lhs, rhs) {
        case (.number(let a), .number(let b)):
            return abs(a - b) < 1e-9
        default:
            return lhs == rhs
        }
    }

    /// Drop leaves duplicated at the root (e.g. remaining vs quota.remaining) and sibling actual/account cost copies.
    static func deduplicate(_ leaves: [FlattenedLeaf]) -> [FlattenedLeaf] {
        let byPath = Dictionary(uniqueKeysWithValues: leaves.map { ($0.path, $0) })
        var drop: Set<String> = []

        for leaf in leaves {
            let parts = leaf.path.split(separator: ".").map(String.init)
            guard parts.count >= 2, let last = parts.last else { continue }
            if let root = byPath[last], valuesMatch(root.value, leaf.value) {
                drop.insert(last)
            }
            if let keepKey = redundantSiblingKey[last] {
                let parent = parts.dropLast().joined(separator: ".")
                let keepPath = parent.isEmpty ? keepKey : "\(parent).\(keepKey)"
                if let keep = byPath[keepPath], valuesMatch(keep.value, leaf.value) {
                    drop.insert(leaf.path)
                }
            }
        }

        return leaves.filter { !drop.contains($0.path) }
    }

    static func isRedundantPath(_ path: String, keptCanonical: Set<String>) -> Bool {
        if path.hasPrefix("_derived.") { return false }
        if keptCanonical.contains(path) { return false }
        if !path.contains(".") {
            return keptCanonical.contains { $0.hasSuffix(".\(path)") }
        }
        let parts = path.split(separator: ".").map(String.init)
        guard let last = parts.last, let keepKey = redundantSiblingKey[last] else { return false }
        let parent = parts.dropLast().joined(separator: ".")
        let keepPath = parent.isEmpty ? keepKey : "\(parent).\(keepKey)"
        return keptCanonical.contains(keepPath)
    }

    static func canonicalPath(for redundant: String, kept: [FlattenedLeaf]) -> String? {
        if !redundant.contains(".") {
            let matches = kept.map(\.path).filter { $0.hasSuffix(".\(redundant)") }
            return matches.first { $0.hasPrefix("quota.") } ?? matches.first
        }
        let parts = redundant.split(separator: ".").map(String.init)
        guard let last = parts.last, let keepKey = redundantSiblingKey[last] else { return nil }
        let parent = parts.dropLast().joined(separator: ".")
        let keepPath = parent.isEmpty ? keepKey : "\(parent).\(keepKey)"
        return kept.contains(where: { $0.path == keepPath }) ? keepPath : nil
    }

    private static let redundantSiblingKey: [String: String] = [
        "actual_cost": "cost",
        "account_cost": "cost"
    ]
}

enum TotalTodaySplit {
    static func expandLeaf(_ leaf: FlattenedLeaf) -> [FlattenedLeaf] {
        guard case .string(let text) = leaf.value, let pair = parsePair(text) else {
            return [leaf]
        }
        return [
            FlattenedLeaf(path: leaf.path, value: .number(pair.total)),
            FlattenedLeaf(path: DerivedField.todayPath(for: leaf.path), value: .number(pair.today))
        ]
    }

    static func expand(_ leaves: [FlattenedLeaf]) -> [FlattenedLeaf] {
        leaves.flatMap(expandLeaf)
    }

    static func parsePair(_ text: String) -> (total: Double, today: Double)? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }
        guard let total = parseNumber(String(parts[0])), let today = parseNumber(String(parts[1])) else {
            return nil
        }
        return (total, today)
    }

    static func parseNumber(_ raw: String) -> Double? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in ["$", "¥", "￥", "€", "£"] where text.hasPrefix(prefix) {
            text = String(text.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        text = text.replacingOccurrences(of: ",", with: "")
        guard !text.isEmpty else { return nil }
        let allowed = CharacterSet(charactersIn: "0123456789-+.eE")
        guard text.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return nil }
        return Double(text)
    }
}
