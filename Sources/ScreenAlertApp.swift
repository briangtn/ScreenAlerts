import SwiftUI

@main
struct ScreenAlertApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        // Menu bar icon + dropdown window
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
        } label: {
            Label("ScreenAlert", systemImage: appState.isPaused ? "bell.slash" : "bell.badge")
        }
        .menuBarExtraStyle(.window)

        // Settings window (opened via "Préférences..." or Cmd+,)
        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}
