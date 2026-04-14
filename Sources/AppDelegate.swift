import AppKit
import ServiceManagement

/// App delegate handling lifecycle events.
class AppDelegate: NSObject, NSApplicationDelegate {

    /// Token returned by ProcessInfo to prevent App Nap for the lifetime
    /// of the process. Without this, macOS may throttle our 1-second NSTimer
    /// when the app has no visible window, causing alerts to be silently missed.
    /// Note: .userInitiated prevents App Nap / timer throttling while still
    /// allowing idle system sleep (no battery/thermal impact).
    private var activityToken: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Prevent App Nap — critical for a menu-bar-only app whose timers
        // must fire reliably even when no window is on screen.
        // .userInitiated is sufficient: it blocks App Nap without preventing
        // idle system sleep (unlike .idleSystemSleepDisabled).
        activityToken = ProcessInfo.processInfo.beginActivity(
            options: .userInitiated,
            reason: "Monitoring calendar events for screen alerts"
        )

        // Request calendar access and start monitoring
        CalendarService.shared.requestAccess()
        AlertScheduler.shared.start()

        // React to system wake from sleep: refresh stale calendar data and
        // clear dismissed-event tracking so the first morning alert fires.
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleSystemWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )

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
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        if let token = activityToken {
            ProcessInfo.processInfo.endActivity(token)
        }
    }

    // MARK: - Sleep / Wake

    @objc private func handleSystemWake() {
        print("[ScreenAlert] System woke from sleep. Refreshing calendar data…")

        // The event list is stale (last refresh was before sleep, possibly
        // hours ago). Reload calendars and events immediately so the
        // scheduler has up-to-date data for the first check after wake.
        let calendarService = CalendarService.shared
        calendarService.requestAccess()

        // Clear dismissed/snoozed event IDs — after an overnight sleep they
        // are obsolete and would prevent legitimate alerts from firing.
        AlertScheduler.shared.reset()
    }
}
