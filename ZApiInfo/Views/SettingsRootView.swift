import SwiftUI

struct SettingsRootView: View {
    @Environment(UsageStore.self) private var store

    var body: some View {
        let copy = store.copy
        TabView {
            SettingsSourceView()
                .tabItem { Label(copy.tabSource, systemImage: "link") }
            SettingsFieldsView()
                .tabItem { Label(copy.tabFields, systemImage: "list.bullet.rectangle") }
            SettingsGeneralView()
                .tabItem { Label(copy.tabGeneral, systemImage: "gearshape") }
        }
        .frame(width: 640, height: 560)
    }
}
