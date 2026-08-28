import AppKit
import SwiftUI

@main
struct ZApiInfoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Menu-bar apps have no WindowGroup. SwiftUI Settings often fails to appear for LSUIElement apps.
        // Settings… uses SettingsWindowController; this scene satisfies the App protocol and backs ⌘,.
        Settings {
            SettingsRootView()
                .environment(UsageStore.shared)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBar: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        UsageStore.shared.start()
        statusBar = StatusBarController(store: UsageStore.shared)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationDidResignActive(_ notification: Notification) {
        AppActivation.hideToAccessoryIfNoSettings()
    }
}

@MainActor
enum AppActivation {
    static func showRegular() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    static func hideToAccessoryIfNoSettings() {
        guard !SettingsWindowController.shared.isShowing else { return }
        // Switching to accessory while still active does not hide the Dock icon; hide first so the app resigns.
        NSApp.hide(nil)
        NSApp.setActivationPolicy(.accessory)
    }

    static func openSettings() {
        StatusBarController.shared?.dismissPopover()
        showRegular()
        DispatchQueue.main.async {
            SettingsWindowController.shared.show()
        }
    }
}

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    var isShowing: Bool { window?.isVisible == true }

    func show() {
        AppActivation.showRegular()
        if window == nil {
            let root = SettingsRootView()
                .environment(UsageStore.shared)
            let hosting = NSHostingController(rootView: root)
            let win = NSWindow(contentViewController: hosting)
            win.title = L10n(language: AppLanguage.current).settingsTitle
            win.styleMask = [.titled, .closable]
            win.isReleasedWhenClosed = false
            win.delegate = self
            win.collectionBehavior = [.moveToActiveSpace]
            win.center()
            window = win
        }
        window?.orderFrontRegardless()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func syncTitle() {
        window?.title = L10n(language: AppLanguage.current).settingsTitle
    }

    func windowWillClose(_ notification: Notification) {
        (notification.object as? NSWindow)?.orderOut(nil)
        DispatchQueue.main.async {
            AppActivation.hideToAccessoryIfNoSettings()
        }
    }
}
