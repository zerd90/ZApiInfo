import SwiftUI

struct SettingsFieldsView: View {
    @Environment(UsageStore.self) private var store
    @State private var manualPath = ""

    var body: some View {
        let copy = store.copy
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button(copy.selectAllMenu) { setMenu(true, catalogOnly: false) }
                Button(copy.catalogOnly) { setMenu(true, catalogOnly: true) }
                Button(copy.deselectAll) { setMenu(false, catalogOnly: false) }
                Spacer()
                Toggle(copy.showProtocolFields, isOn: protocolBinding)
                    .toggleStyle(.checkbox)
            }
            .controlSize(.small)

            Text(copy.menuVsStatusBarHint)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                TextField(copy.separator, text: separatorBinding)
                    .frame(width: 80)
                Toggle(copy.compactLargeNumbers, isOn: compactBinding)
                    .toggleStyle(.checkbox)
                TextField(copy.currency, text: currencyBinding)
                    .frame(width: 50)
                    .help(copy.currencyHelp)
                Toggle(copy.showRemainRatio, isOn: remainBinding)
                    .toggleStyle(.checkbox)
            }
            .controlSize(.small)
            Text(copy.unitFallbackHint)
                .font(.caption)
                .foregroundStyle(.secondary)

            if store.statusBarFields().count > 4 {
                Text(copy.statusBarTooWide(store.statusBarFields().count))
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            remainPickers

            List {
                ForEach(FieldCategory.allCases, id: \.self) { category in
                    let fields = store.config.sortedFields.filter { $0.category == category }
                    if !fields.isEmpty {
                        Section(copy.category(category)) {
                            ForEach(fields) { field in
                                fieldRow(field)
                            }
                        }
                    }
                }
            }
            .listStyle(.inset)

            HStack {
                TextField(copy.addFieldPath, text: $manualPath, prompt: Text("data.prompt_tokens"))
                Button(copy.add) {
                    store.addManualPath(manualPath)
                    manualPath = ""
                }
                .disabled(manualPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(16)
    }

    private var copy: L10n { store.copy }

    private var remainPickers: some View {
        HStack {
            Picker(copy.ratioNumerator, selection: numeratorBinding) {
                Text(copy.notSet).tag("")
                ForEach(numericPaths, id: \.self) { path in
                    Text(path).tag(path)
                }
            }
            Picker(copy.ratioDenominator, selection: denominatorBinding) {
                Text(copy.notSet).tag("")
                ForEach(numericPaths, id: \.self) { path in
                    Text(path).tag(path)
                }
            }
        }
        .controlSize(.small)
    }

    private var numericPaths: [String] {
        store.config.sortedFields
            .filter { !$0.path.hasPrefix("_derived.") }
            .map(\.path)
    }

    private func fieldRow(_ field: FieldConfig) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Toggle(copy.menu, isOn: boolBinding(field.path, keyPath: \.showInMenu))
                    .toggleStyle(.checkbox)
                    .help(copy.menuHelp)
                Toggle(copy.statusBar, isOn: boolBinding(field.path, keyPath: \.showInStatusBar))
                    .toggleStyle(.checkbox)
                    .help(copy.statusBarHelp)
                TextField(copy.displayName, text: nameBinding(field.path))
                    .textFieldStyle(.roundedBorder)
                Button {
                    store.moveField(path: field.path, by: -1)
                } label: {
                    Image(systemName: "chevron.up")
                }
                .buttonStyle(.borderless)
                .help(copy.moveUp)
                Button {
                    store.moveField(path: field.path, by: 1)
                } label: {
                    Image(systemName: "chevron.down")
                }
                .buttonStyle(.borderless)
                .help(copy.moveDown)
                if !field.path.hasPrefix("_derived.") {
                    Toggle(copy.todayDelta, isOn: boolBinding(field.path, keyPath: \.generateDeltaToday))
                        .toggleStyle(.checkbox)
                }
            }
            HStack {
                Text(field.path)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                if store.missingPaths.contains(field.path) {
                    Text(copy.missingThisTime)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
                Spacer()
                Picker(copy.format, selection: formatBinding(field.path)) {
                    ForEach(FieldFormat.allCases) { format in
                        Text(copy.format(format)).tag(format)
                    }
                }
                .frame(width: 110)
                TextField(copy.scale, text: scaleBinding(field.path))
                    .frame(width: 72)
                if field.generateDeltaToday {
                    Button(copy.resetToday) {
                        store.resetSnapshot(for: field.path)
                    }
                    .controlSize(.mini)
                }
            }
            .controlSize(.small)
        }
        .padding(.vertical, 4)
    }

    private func setMenu(_ enabled: Bool, catalogOnly: Bool) {
        store.updateFields { config in
            for index in config.fields.indices {
                if enabled && catalogOnly && !FieldAliasTable.isCatalogField(path: config.fields[index].path) {
                    config.fields[index].showInMenu = false
                } else {
                    config.fields[index].showInMenu = enabled
                }
                if !enabled {
                    config.fields[index].showInStatusBar = false
                }
            }
        }
    }

    private var protocolBinding: Binding<Bool> {
        Binding(
            get: { store.config.showProtocolFields },
            set: { value in store.updateFields { $0.showProtocolFields = value } }
        )
    }

    private var separatorBinding: Binding<String> {
        Binding(
            get: { store.config.statusBarSeparator },
            set: { value in store.updateFields { $0.statusBarSeparator = value } }
        )
    }

    private var compactBinding: Binding<Bool> {
        Binding(
            get: { store.config.compactLargeNumbers },
            set: { value in store.updateFields { $0.compactLargeNumbers = value } }
        )
    }

    private var currencyBinding: Binding<String> {
        Binding(
            get: { store.config.currencySymbol },
            set: { value in store.updateFields { $0.currencySymbol = value } }
        )
    }

    private var remainBinding: Binding<Bool> {
        Binding(
            get: { store.config.showRemainRatio },
            set: { value in store.updateFields { $0.showRemainRatio = value } }
        )
    }

    private var numeratorBinding: Binding<String> {
        Binding(
            get: { store.config.remainNumeratorPath },
            set: { value in store.updateFields { $0.remainNumeratorPath = value } }
        )
    }

    private var denominatorBinding: Binding<String> {
        Binding(
            get: { store.config.remainDenominatorPath },
            set: { value in store.updateFields { $0.remainDenominatorPath = value } }
        )
    }

    private func boolBinding(_ path: String, keyPath: WritableKeyPath<FieldConfig, Bool>) -> Binding<Bool> {
        Binding(
            get: { store.config.field(path: path)?[keyPath: keyPath] ?? false },
            set: { value in
                store.updateFields { config in
                    guard let index = config.fields.firstIndex(where: { $0.path == path }) else { return }
                    config.fields[index][keyPath: keyPath] = value
                }
            }
        )
    }

    private func nameBinding(_ path: String) -> Binding<String> {
        Binding(
            get: { store.config.field(path: path)?.displayName ?? "" },
            set: { value in
                store.updateFields { config in
                    guard let index = config.fields.firstIndex(where: { $0.path == path }) else { return }
                    config.fields[index].displayName = value
                }
            }
        )
    }

    private func formatBinding(_ path: String) -> Binding<FieldFormat> {
        Binding(
            get: { store.config.field(path: path)?.format ?? .auto },
            set: { value in
                store.updateFields { config in
                    guard let index = config.fields.firstIndex(where: { $0.path == path }) else { return }
                    config.fields[index].format = value
                }
            }
        )
    }

    private func scaleBinding(_ path: String) -> Binding<String> {
        Binding(
            get: {
                guard let scale = store.config.field(path: path)?.scale else { return "1" }
                if abs(scale - 1.0 / 500_000.0) < 1e-12 { return "1/500000" }
                return String(scale)
            },
            set: { text in
                let parsed: Double?
                if text.contains("/") {
                    let parts = text.split(separator: "/").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
                    parsed = parts.count == 2 && parts[1] != 0 ? parts[0] / parts[1] : nil
                } else {
                    parsed = Double(text.trimmingCharacters(in: .whitespaces))
                }
                guard let parsed else { return }
                store.updateFields { config in
                    guard let index = config.fields.firstIndex(where: { $0.path == path }) else { return }
                    config.fields[index].scale = parsed
                }
            }
        )
    }
}
