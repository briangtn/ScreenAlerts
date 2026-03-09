import EventKit
import Foundation
import AppKit

struct CalendarEvent: Identifiable, Equatable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let calendarTitle: String
    let calendarColor: NSColor
    let notes: String?
    let url: URL?
    let location: String?
    var videoLink: VideoLink?

    init(from ekEvent: EKEvent) {
        self.id = ekEvent.eventIdentifier ?? UUID().uuidString
        self.title = ekEvent.title ?? "Sans titre"
        self.startDate = ekEvent.startDate
        self.endDate = ekEvent.endDate
        self.calendarTitle = ekEvent.calendar?.title ?? ""
        self.calendarColor = ekEvent.calendar?.color ?? .systemBlue
        self.notes = ekEvent.notes
        self.url = ekEvent.url
        self.location = ekEvent.location
        self.videoLink = VideoLinkParser.extractLink(from: ekEvent)
    }

    /// Time remaining (in seconds) before the event starts.
    var timeUntilStart: TimeInterval {
        startDate.timeIntervalSinceNow
    }

    static func == (lhs: CalendarEvent, rhs: CalendarEvent) -> Bool {
        lhs.id == rhs.id
    }
}
