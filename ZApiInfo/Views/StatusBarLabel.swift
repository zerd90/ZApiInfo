import SwiftUI

struct StatusBarLabel: View {
    var store: UsageStore

    var body: some View {
        Group {
            if shouldShowMetrics {
                metricsRow
            } else {
                Text(store.statusBarText)
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 4)
            }
        }
        .frame(height: 18)
        .fixedSize()
        .accessibilityLabel(store.statusBarAccessibilityLabel)
    }

    private var shouldShowMetrics: Bool {
        if store.status == .unconfigured { return false }
        if store.status == .error, store.values.isEmpty { return false }
        return !store.statusBarFields().isEmpty
    }

    private var metricsRow: some View {
        HStack(alignment: .center, spacing: 8) {
            ForEach(store.statusBarFields()) { field in
                VStack(alignment: .leading, spacing: 0) {
                    Text(field.resolvedDisplayName)
                        .font(.system(size: 8, weight: .semibold, design: .rounded))
                        .opacity(0.85)
                        .lineLimit(1)
                    Text(store.displayText(for: field))
                        .font(.system(size: 12, weight: .bold).monospacedDigit())
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 2)
    }
}
