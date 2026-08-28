import SwiftUI

struct SettingsGeneralView: View {
    @Environment(UsageStore.self) private var store
    @State private var confirmClear = false
    @State private var alsoDeleteKey = false

    var body: some View {
        let copy = store.copy
        Form {
            Section(copy.sectionLanguage) {
                Picker(copy.pickerLanguage, selection: languageBinding) {
                    ForEach(AppLanguage.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                Text(copy.languageHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(copy.sectionStartup) {
                Toggle(copy.launchAtLogin, isOn: Binding(
                    get: { store.config.launchAtLogin },
                    set: { store.setLaunchAtLogin($0) }
                ))
            }

            Section(copy.sectionSnapshots) {
                Button(copy.resetAllSnapshots) {
                    store.resetAllSnapshots()
                }
                Text(copy.snapshotsHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(copy.sectionData) {
                Toggle(copy.alsoDeleteKey, isOn: $alsoDeleteKey)
                Button(copy.clearLocalData, role: .destructive) {
                    confirmClear = true
                }
            }

            Section(copy.sectionAbout) {
                LabeledContent(copy.version, value: versionString)
                LabeledContent("Bundle") {
                    Text("com.zapiinfo.ZApiInfo")
                        .textSelection(.enabled)
                }
                Text(copy.aboutHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(8)
        .alert(copy.clearAlertTitle, isPresented: $confirmClear) {
            Button(copy.cancel, role: .cancel) {}
            Button(copy.clear, role: .destructive) {
                store.clearLocalData(includingKey: alsoDeleteKey)
            }
        } message: {
            Text(alsoDeleteKey ? copy.clearMessageWithKey : copy.clearMessageKeepKey)
        }
    }

    private var languageBinding: Binding<AppLanguage> {
        Binding(
            get: { store.language },
            set: { store.setLanguage($0) }
        )
    }

    private var versionString: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }
}
