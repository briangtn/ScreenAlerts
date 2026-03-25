import AppKit
import ServiceManagement

/// App delegate handling lifecycle events.
class AppDelegate: NSObject, NSApplicationDelegate {

    /// Token returned by ProcessInfo to keep App Nap disabled for the
    /// lifetime of the process.  Without this, macOS may throttle our
    /// 1-second NSTimer when the app has no visible window, causing the
    /// alert window to be silently missed.
    private var activityToken: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Prevent App Nap — critical for a menu-bar-only app whose timers
        // must fire reliably even when no window is on screen.
        activityToken = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .idleSystemSleepDisabled],
            reason: "Monitoring calendar events for screen alerts"
        )

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
