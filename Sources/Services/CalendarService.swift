import EventKit
import Combine
import Foundation

/// Wraps EventKit to provide calendar events as a reactive stream.
class CalendarService: ObservableObject {
    static let shared = CalendarService()

    let eventStore = EKEventStore()

    @Published var events: [CalendarEvent] = []
    @Published var hasAccess: Bool = false
    @Published var calendars: [EKCalendar] = []

    private var refreshTimer: Timer?

    // MARK: - Public API

    func requestAccess() {
        eventStore.requestFullAccessToEvents { [weak self] granted, error in
            DispatchQueue.main.async {
                self?.hasAccess = granted
                if granted {
                    self?.loadCalendars()
                    self?.refreshEvents()
                    self?.startMonitoring()
                }
                if let error = error {
                    print("[CalendarService] Access error: \(error.localizedDescription)")
                }
            }
        }
    }

    func loadCalendars() {
        calendars = eventStore.calendars(for: .event)
    }

    func refreshEvents() {
        let now = Date()
        guard let endDate = Calendar.current.date(byAdding: .hour, value: 24, to: now) else { return }

        let appState = AppState.shared
        let excludedIDs = appState.excludedCalendarIDs
        let includeAllDay = appState.includeAllDayEvents

        // Filter to non-excluded calendars only
        let activeCalendars = calendars.filter { !excludedIDs.contains($0.calendarIdentifier) }
        let predicate = eventStore.predicateForEvents(
            withStart: now,
            end: endDate,
            calendars: activeCalendars.isEmpty ? nil : activeCalendars
        )
        let ekEvents = eventStore.events(matching: predicate)

        DispatchQueue.main.async { [weak self] in
            self?.events = ekEvents
                .filter { includeAllDay || !$0.isAllDay }
                .filter { $0.status != .canceled }
                .filter { ekEvent in
                    guard let attendees = ekEvent.attendees,
                          let me = attendees.first(where: { $0.isCurrentUser }) else {
                        return true
                    }
                    return me.participantStatus != .declined
                }
                .sorted { $0.startDate < $1.startDate }
                .map { CalendarEvent(from: $0) }
        }
    }

    // MARK: - Private

    private func startMonitoring() {
        // Auto-refresh every 5 minutes
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.refreshEvents()
        }

        // React to external calendar changes (e.g. new event added in Apple Calendar)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(calendarChanged),
            name: .EKEventStoreChanged,
            object: eventStore
        )
    }

    @objc private func calendarChanged() {
        // EKEventStoreChanged is posted on a background thread. Dispatch to main
        // so that EventKit calls in refreshEvents() run on the main thread, as
        // Apple recommends.
        DispatchQueue.main.async { self.refreshEvents() }
    }
}
