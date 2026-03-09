import AppKit
import ServiceManagement

/// App delegate handling lifecycle events.
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Request calendar access and start monitoring
        CalendarService.shared.requestAccess()
        AlertScheduler.shared.start()

        // Log launch at login status for diagnostics
        let status = SMAppService.mainApp.status
        let statusLabel: String
        switch status {
        case .enabled:
            statusLabel = "enabled"
        case .notRegistered:
            statusLabel = "notRegistered"
        case .notFound:
            statusLabel = "notFound"
        case .requiresApproval:
            statusLabel = "requiresApproval"
        @unknown default:
            statusLabel = "unknown(\(status.rawValue))"
        }
        print("[ScreenAlert] App launched. Launch at login status: \(statusLabel). Monitoring calendars...")
    }

    func applicationWillTerminate(_ notification: Notification) {
        AlertScheduler.shared.stop()
    }
}
