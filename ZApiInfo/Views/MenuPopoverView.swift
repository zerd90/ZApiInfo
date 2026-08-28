import AppKit
import SwiftUI

struct MenuPopoverView: View {
    @Environment(UsageStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            if let error = store.lastError, store.status != .unconfigured {
                errorBanner(error)
            }
            summary
            Divider()
            details
            Divider()
            meta
            actions
        }
        .padding(14)
        .frame(width: 380)
        .frame(maxHeight: 520)
    }

    private var copy: L10n { store.copy }

    private var header: some View {
        HStack {
            Text("ZApiInfo")
                .font(.headline)
            Spacer()
            if store.isRefreshing {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    private func errorBanner(_ error: AppError) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text(copy.errorDetail(error))
                .font(.caption)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
            Spacer()
            Button(copy.retry) { store.refreshNow() }
                .controlSize(.small)
        }
        .padding(8)
        .background(.yellow.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 6) {
            if store.status == .unconfigured {
                Text(copy.noSource)
                    .foregroundStyle(.secondary)
                Text(copy.noSourceHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            let highlight: [FieldConfig] = {
                let bar = store.statusBarFields()
                if !bar.isEmpty { return bar }
                return Array(store.menuFields().prefix(3))
            }()
            ForEach(highlight) { field in
                HStack {
                    Text(field.resolvedDisplayName)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(store.displayText(for: field))
                        .font(.title3.monospacedDigit().weight(.semibold))
                        .textSelection(.enabled)
                }
            }
        }
    }

    private var details: some View {
        let fields = store.menuFields()
        return Group {
            if fields.isEmpty {
                Text(copy.noFieldsHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(grouped(fields), id: \.category) { group in
                            Text(copy.category(group.category))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            ForEach(group.fields) { field in
                                HStack {
                                    Text(field.resolvedDisplayName)
                                    Spacer()
                                    Text(store.displayText(for: field))
                                        .foregroundStyle(store.missingPaths.contains(field.path) ? .secondary : .primary)
                                        .monospacedDigit()
                                        .textSelection(.enabled)
                                }
                                .font(.callout)
                            }
                        }
                    }
                }
                .frame(maxHeight: 280)
            }
        }
    }

    private var meta: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(refreshMeta)
                    .foregroundStyle(.secondary)
                Spacer()
                if store.status == .stale {
                    Text(copy.cached)
                        .foregroundStyle(.orange)
                }
            }
            .font(.caption)
            if let info = store.lastRequest {
                Text(info.url)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(info.url)
            }
        }
    }

    private var actions: some View {
        HStack {
            Button(copy.refresh, systemImage: "arrow.clockwise") {
                store.refreshNow()
            }
            Button(copy.copyRequest) {
                copyLastRequest()
            }
            Spacer()
            Button(copy.settings) {
                AppActivation.openSettings()
            }
            Button(copy.quit) {
                NSApp.terminate(nil)
            }
        }
        .controlSize(.small)
    }

    private var refreshMeta: String {
        if let date = store.lastSuccessAt {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            return copy.lastSuccess(formatter.string(from: date))
        }
        return copy.notRefreshed
    }

    private func grouped(_ fields: [FieldConfig]) -> [(category: FieldCategory, fields: [FieldConfig])] {
        var result: [(FieldCategory, [FieldConfig])] = []
        for category in FieldCategory.allCases {
            let items = fields.filter { $0.category == category }
            if !items.isEmpty {
                result.append((category, items))
            }
        }
        return result
    }

    private func copyLastRequest() {
        var lines: [String] = []
        if let info = store.lastRequest {
            lines.append("URL: \(info.url)")
            if let code = info.statusCode { lines.append("\(copy.copyStatus): \(code)") }
            lines.append("\(copy.copyDuration): \(info.durationMs) ms")
            if let error = info.errorText { lines.append("\(copy.copyError): \(error)") }
        } else {
            lines.append(copy.noRequestRecorded)
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lines.joined(separator: "\n"), forType: .string)
    }
}
