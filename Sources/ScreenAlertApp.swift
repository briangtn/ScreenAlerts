import SwiftUI
import Sparkle

@main
struct ScreenAlertApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState.shared
    @StateObject private var calendarService = CalendarService.shared
    
    // Setup Sparkle updater
    private let updaterController: SPUStandardUpdaterController
    
    init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    var body: some Scene {
        // Menu bar icon + dropdown window
        MenuBarExtra {
            MenuBarView(updater: updaterController.updater)
                .environmentObject(appState)
                .environmentObject(calendarService)
        } label: {
            Label("ScreenAlert", systemImage: appState.isPaused ? "bell.slash" : "bell.badge")
        }
        .menuBarExtraStyle(.window)

        // Settings window (opened via "Préférences..." or Cmd+,)
        Settings {
            SettingsView(updater: updaterController.updater)
                .environmentObject(appState)
                .environmentObject(calendarService)
        }
    }
}
