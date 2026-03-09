import Foundation
import EventKit

// MARK: - Video Service Enum

enum VideoService: String, CaseIterable {
    case zoom = "Zoom"
    case googleMeet = "Google Meet"
    case teams = "Microsoft Teams"
    case webex = "Webex"
    case slack = "Slack"
    case unknown = "Visioconférence"

    var systemImage: String {
        "video.fill"
    }
}

// MARK: - Video Link Model

struct VideoLink: Equatable {
    let service: VideoService
    let url: URL

    static func == (lhs: VideoLink, rhs: VideoLink) -> Bool {
        lhs.url == rhs.url
    }
}

// MARK: - Video Link Parser

struct VideoLinkParser {
    private static let patterns: [(VideoService, String)] = [
        (.zoom, #"https?://[\w.-]*zoom\.us/[jw]/[^\s<>\"]+"#),
        (.googleMeet, #"https?://meet\.google\.com/[\w-]+"#),
        (.teams, #"https?://teams\.microsoft\.com/l/meetup-join/[^\s<>\"]+"#),
        (.webex, #"https?://[\w.-]*\.webex\.com/[^\s<>\"]+"#),
        (.slack, #"https?://[\w.-]*\.slack\.com/[^\s<>\"]*huddle[^\s<>\"]*"#),
    ]

    static func extractLink(from event: EKEvent) -> VideoLink? {
        // 1. Check the dedicated URL field
        if let url = event.url {
            if let link = matchURL(url.absoluteString) {
                return link
            }
        }

        // 2. Check the location field (often contains meeting URLs)
        if let location = event.location, let link = matchURL(location) {
            return link
        }

        // 3. Check the notes field
        if let notes = event.notes, let link = matchURL(notes) {
            return link
        }

        return nil
    }

    private static func matchURL(_ text: String) -> VideoLink? {
        for (service, pattern) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range, in: text),
               let url = URL(string: String(text[range]))
            {
                return VideoLink(service: service, url: url)
            }
        }
        return nil
    }
}
