import SwiftUI

struct SettingsSourceView: View {
    @Environment(UsageStore.self) private var store
    @State private var showKey = false
    @State private var isTesting = false

    var body: some View {
        @Bindable var store = store
        let copy = store.copy
        Form {
            Section(copy.sectionPreset) {
                Picker(copy.pickerTemplate, selection: $store.draftPreset) {
                    ForEach(PresetID.allCases) { item in
                        Text(copy.preset(item)).tag(item)
                    }
                }
                .onChange(of: store.draftPreset) { _, newValue in
                    store.applyPreset(newValue)
                }
                Text(copy.presetHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(copy.sectionRequest) {
                TextField("URL", text: $store.draftURL, prompt: Text("https://api.example.com/api/usage/token"))
                    .textFieldStyle(.roundedBorder)
                if store.draftURL.lowercased().hasPrefix("http://") {
                    Text(copy.httpWarning)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                Picker(copy.pickerAuth, selection: $store.draftAuth) {
                    ForEach(AuthScheme.allCases, id: \.self) { scheme in
                        Text(copy.auth(scheme)).tag(scheme)
                    }
                }

                HStack {
                    if showKey {
                        TextField("API Key", text: $store.draftKey)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        SecureField("API Key", text: $store.draftKey)
                            .textFieldStyle(.roundedBorder)
                    }
                    Button(showKey ? copy.hide : copy.show) { showKey.toggle() }
                        .controlSize(.small)
                }

                HStack {
                    TextField(copy.extraHeaderName, text: $store.draftExtraName, prompt: Text("New-Api-User"))
                    TextField(copy.extraHeaderValue, text: $store.draftExtraValue)
                }
                Text(copy.extraHeaderHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(copy.sectionRefresh) {
                Picker(copy.pickerInterval, selection: $store.draftInterval) {
                    Text(copy.intervalLabel(15)).tag(15)
                    Text(copy.intervalLabel(30)).tag(30)
                    Text(copy.intervalLabel(60)).tag(60)
                    Text(copy.intervalLabel(300)).tag(300)
                    Text(copy.intervalLabel(900)).tag(900)
                }
                Stepper(value: $store.draftTimeout, in: 3...30) {
                    Text(copy.timeoutLabel(store.draftTimeout))
                }
            }

            Section {
                HStack {
                    Button(copy.testConnection) {
                        Task {
                            isTesting = true
                            await store.testConnection()
                            isTesting = false
                        }
                    }
                    .disabled(store.draftURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isTesting)

                    Button(copy.save) {
                        store.saveDraft()
                    }
                    .keyboardShortcut(.defaultAction)
                }
                if isTesting {
                    ProgressView(copy.testing)
                        .controlSize(.small)
                }
                if let message = store.testMessage {
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                if let message = store.saveMessage {
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
        .formStyle(.grouped)
        .padding(8)
    }
}
