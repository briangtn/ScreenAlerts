import Foundation
import Combine
import AppKit

/// Checks every 15 seconds for upcoming events and triggers full-screen alerts.
class AlertScheduler: ObservableObject {
    static let shared = AlertScheduler()

    private var timer: Timer?
    /// Event IDs that have already been shown and dismissed.
    private var alertedEventIDs: Set<String> = []
    /// Event IDs that are snoozed, mapped to the time when they should re-alert.
    private var snoozedEvents: [String: Date] = [:]

    // MARK: - Public API

    func start() {
        // Fire immediately, then every 15 seconds
        checkForUpcomingEvents()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.checkForUpcomingEvents()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func snooze(event: CalendarEvent, minutes: Int) {
        let snoozeUntil = Date().addingTimeInterval(TimeInterval(minutes * 60))
        snoozedEvents[event.id] = snoozeUntil
        alertedEventIDs.remove(event.id) // allow re-alert after snooze
        FullScreenWindowManager.shared.dismissAlert()
    }

    func dismiss(event: CalendarEvent) {
        alertedEventIDs.insert(event.id)
        FullScreenWindowManager.shared.dismissAlert()
    }

    /// Manually trigger the full-screen alert for a specific event,
    /// bypassing dismissed/snoozed state.
    func showAlertManually(for event: CalendarEvent) {
        // Clear any previous dismiss/snooze for this event
        alertedEventIDs.remove(event.id)
        snoozedEvents.removeValue(forKey: event.id)

        DispatchQueue.main.async {
            AppState.shared.activeAlert = event
            FullScreenWindowManager.shared.showAlert(for: event)
            AppState.shared.playAlertSound()
        }
    }

    /// Show a fake test alert (useful for demo / testing the overlay).
    func showTestAlert() {
        let testEvent = CalendarEvent(
            id: "test-\(UUID().uuidString)",
            title: "Réunion de test",
            startDate: Date().addingTimeInterval(30),
            endDate: Date().addingTimeInterval(3630),
            calendarTitle: "Test",
            calendarColor: .systemBlue,
            notes: nil,
            url: nil,
            location: nil,
            videoLink: VideoLink(service: .zoom, url: URL(string: "https://zoom.us/j/123456")!)
        )
        showAlertManually(for: testEvent)
    }

    /// Reset tracking (e.g. at midnight or when preferences change).
    func reset() {
        alertedEventIDs.removeAll()
        snoozedEvents.removeAll()
    }

    // MARK: - Private

    private func checkForUpcomingEvents() {
        let appState = AppState.shared
        guard !appState.isPaused else { return }
        guard appState.activeAlert == nil else { return } // don't stack alerts

        let alertSeconds = TimeInterval(appState.alertMinutesBefore * 60)
        let calendarService = CalendarService.shared

        for event in calendarService.events {
            // Skip already dismissed events
            if alertedEventIDs.contains(event.id) { continue }

            // Skip snoozed events whose snooze hasn't expired
            if let snoozeUntil = snoozedEvents[event.id], Date() < snoozeUntil { continue }

            // Check if this is a snoozed event whose snooze just expired
            let snoozeExpired = snoozedEvents[event.id] != nil

            // Is the event within the alert window?
            let timeUntil = event.startDate.timeIntervalSinceNow
            // Trigger if we passed the exact alert time, but not more than 60 seconds ago.
            // This ensures it fires exactly on the second while handling brief sleeps.
            let inAlertWindow = timeUntil <= alertSeconds && timeUntil > (alertSeconds - 60)
            
            // For snoozed events: re-alert if event hasn't ended yet
            let shouldRealertAfterSnooze = snoozeExpired && event.endDate.timeIntervalSinceNow > 0

            if inAlertWindow || shouldRealertAfterSnooze {
                snoozedEvents.removeValue(forKey: event.id)
                appState.activeAlert = event
                FullScreenWindowManager.shared.showAlert(for: event)
                appState.playAlertSound()
                return // one alert at a time
            }
        }
    }
}
