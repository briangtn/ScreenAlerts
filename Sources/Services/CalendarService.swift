import EventKit
import Combine
import Foundation

/// Wraps EventKit to provide calendar events as a reactive stream.
class CalendarService: ObservableObject {
    static let shared = CalendarService()

    /// The underlying EventKit store. Recreated when authorization changes
    /// to force a fresh connection (important after macOS upgrades).
    private(set) var eventStore = EKEventStore()

    @Published var events: [CalendarEvent] = []
    @Published var hasAccess: Bool = false
    @Published var calendars: [EKCalendar] = []

    /// Current EventKit authorization status, published so views can react
    /// to every state (fullAccess, writeOnly, denied, etc.).
    @Published var authStatus: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)

    private var refreshTimer: Timer?
    private var isMonitoring = false

    // MARK: - Public API

    /// Check the current authorization status and, if needed, request
    /// full access.  Safe to call multiple times (e.g. on wake).
    func requestAccess() {
        let status = EKEventStore.authorizationStatus(for: .event)

        DispatchQueue.main.async {
            self.authStatus = status
        }

        switch status {
        case .fullAccess:
            // Already authorised – load data directly.
            DispatchQueue.main.async {
                self.hasAccess = true
                self.loadCalendars()
                self.refreshEvents()
                self.startMonitoring()
            }

        case .notDetermined:
            // First launch or reset – show the system prompt.
            eventStore.requestFullAccessToEvents { [weak self] granted, error in
                DispatchQueue.main.async {
                    let newStatus = EKEventStore.authorizationStatus(for: .event)
                    self?.authStatus = newStatus
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

        case .writeOnly:
            // macOS 14+ : user granted write-only in System Settings.
            // We need full (read) access; guide the user.
            DispatchQueue.main.async {
                self.hasAccess = false
            }

        case .denied, .restricted:
            DispatchQueue.main.async {
                self.hasAccess = false
            }

        @unknown default:
            DispatchQueue.main.async {
                self.hasAccess = false
            }
        }
    }

    func loadCalendars() {
        calendars = eventStore.calendars(for: .event)
    }

    func refreshEvents() {
        // Re-check authorization each time – it can change at any moment
        // (user toggling in System Settings, macOS upgrade, etc.).
        let status = EKEventStore.authorizationStatus(for: .event)
        if status != authStatus {
            DispatchQueue.main.async { self.authStatus = status }

            if status != .fullAccess {
                DispatchQueue.main.async {
                    self.hasAccess = false
                    self.events = []
                }
                return
            } else {
                // Regained full access – recreate the store to get a fresh
                // connection (important after macOS upgrades that may
                // invalidate the previous store).
                eventStore = EKEventStore()
                DispatchQueue.main.async { self.hasAccess = true }
                loadCalendars()
            }
        }

        guard status == .fullAccess else {
            DispatchQueue.main.async { self.events = [] }
            return
        }

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
        guard !isMonitoring else { return }
        isMonitoring = true

        // Auto-refresh every 5 minutes.
        // Use .common RunLoop mode so the timer fires even when menus are open.
        let t = Timer(timeInterval: 300, repeats: true) { [weak self] _ in
            self?.refreshEvents()
        }
        RunLoop.main.add(t, forMode: .common)
        refreshTimer?.invalidate()
        refreshTimer = t

        // React to external calendar changes (e.g. new event added in Apple Calendar)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(calendarChanged),
            name: .EKEventStoreChanged,
            object: nil      // listen to any store (covers store recreation)
        )
    }

    @objc private func calendarChanged() {
        // EKEventStoreChanged is posted on a background thread. Dispatch to main
        // so that EventKit calls in refreshEvents() run on the main thread, as
        // Apple recommends.
        DispatchQueue.main.async {
            self.loadCalendars()
            self.refreshEvents()
        }
    }
}

// MARK: - EKAuthorizationStatus helpers

extension EKAuthorizationStatus {
    /// Human-readable label for logging.
    var label: String {
        switch self {
        case .notDetermined: return "notDetermined"
        case .restricted:    return "restricted"
        case .denied:        return "denied"
        case .fullAccess:    return "fullAccess"
        case .writeOnly:     return "writeOnly"
        @unknown default:    return "unknown(\(rawValue))"
        }
    }
}
