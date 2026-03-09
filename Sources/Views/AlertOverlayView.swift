import SwiftUI

/// The full-screen alert view displayed when an event is about to start.
struct AlertOverlayView: View {
    let event: CalendarEvent
    let onDismiss: () -> Void
    let onSnooze: (Int) -> Void
    let onJoin: (URL) -> Void

    @State private var timeRemaining: TimeInterval = 0
    @State private var appeared = false

    private let appState = AppState.shared

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // Configurable background overlay
            appState.overlayColor.opacity(appState.overlayOpacity)
                .ignoresSafeArea()

            VStack(spacing: 30) {
                Spacer()

                // Calendar color indicator
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(nsColor: event.calendarColor))
                    .frame(width: 60, height: 8)

                // Event title
                Text(event.title)
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 60)
                    .shadow(color: .black.opacity(0.3), radius: 10, y: 5)

                // Time information
                VStack(spacing: 10) {
                    Text(event.startDate, style: .time)
                        .font(.system(size: 32, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))

                    Text(countdownText)
                        .font(.system(size: 24, weight: .regular, design: .monospaced))
                        .foregroundColor(countdownColor)
                        .contentTransition(.numericText())
                        .animation(.default, value: countdownText)
                }

                // Calendar name
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(nsColor: event.calendarColor))
                        .frame(width: 8, height: 8)
                    Text(event.calendarTitle)
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.5))
                }

                // Action buttons
                HStack(spacing: 20) {
                    // Snooze buttons (multiple, from preferences)
                    ForEach(appState.snoozeDurations, id: \.self) { minutes in
                        AlertButton(
                            title: snoozeLabel(minutes: minutes),
                            systemImage: "clock.arrow.circlepath",
                            style: .secondary
                        ) {
                            onSnooze(minutes)
                        }
                    }

                    // Join button (only if video link is detected)
                    if let videoLink = event.videoLink {
                        AlertButton(
                            title: "Rejoindre \(videoLink.service.rawValue)",
                            systemImage: "video.fill",
                            style: .primary,
                            accentColor: appState.accentColor
                        ) {
                            onJoin(videoLink.url)
                        }
                    }

                    // Dismiss button
                    AlertButton(
                        title: "Fermer",
                        systemImage: "xmark",
                        style: .secondary
                    ) {
                        onDismiss()
                    }
                }

                Spacer()
            }
        }
        .onAppear {
            timeRemaining = event.startDate.timeIntervalSinceNow
            withAnimation(.easeOut(duration: 0.6)) {
                appeared = true
            }
        }
        .onReceive(timer) { _ in
            timeRemaining = event.startDate.timeIntervalSinceNow
        }
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.92)
    }

    // MARK: - Helpers

    private func snoozeLabel(minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) min"
        }
        let hours = minutes / 60
        let remaining = minutes % 60
        if remaining == 0 {
            return "\(hours)h"
        }
        return "\(hours)h\(String(format: "%02d", remaining))"
    }

    // MARK: - Computed Properties

    private var countdownText: String {
        if timeRemaining <= 0 {
            return "Commence maintenant !"
        }
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        if minutes > 0 {
            return "Dans \(minutes) min \(String(format: "%02d", seconds)) s"
        }
        return "Dans \(seconds) s"
    }

    private var countdownColor: Color {
        if timeRemaining <= 0 {
            return .red
        } else if timeRemaining <= 60 {
            return .orange
        }
        return .white.opacity(0.7)
    }
}

// MARK: - Alert Button Component

private enum AlertButtonStyle {
    case primary
    case secondary
}

private struct AlertButton: View {
    let title: String
    let systemImage: String
    let style: AlertButtonStyle
    var accentColor: Color = .green
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 18, weight: style == .primary ? .bold : .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(background)
                .cornerRadius(14)
                .scaleEffect(isHovered ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }

    @ViewBuilder
    private var background: some View {
        switch style {
        case .primary:
            accentColor
        case .secondary:
            Color.white.opacity(isHovered ? 0.25 : 0.15)
        }
    }
}
