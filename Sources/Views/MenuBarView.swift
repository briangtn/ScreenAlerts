import SwiftUI
import EventKit
import Sparkle

/// Content of the MenuBarExtra dropdown window.
struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var calendarService: CalendarService
    
    let updater: SPUUpdater
    @StateObject private var updaterViewModel: UpdaterViewModel

    // Local copies of CalendarService data, updated via onReceive.
    // On macOS 26 (Tahoe), MenuBarExtra(.window) does not re-render
    // when @EnvironmentObject / @Published properties change.  Using
    // @State + onReceive guarantees the view refreshes.
    @State private var events: [CalendarEvent] = []
    @State private var authStatus: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)

    init(updater: SPUUpdater) {
        self.updater = updater
        _updaterViewModel = StateObject(wrappedValue: UpdaterViewModel(updater: updater))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("ScreenAlert")
                    .font(.headline)
                Spacer()
                Button {
                    AlertScheduler.shared.showTestAlert()
                } label: {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 14))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Simuler une alerte de test")

                Button(appState.isPaused ? "Reprendre" : "Pause") {
                    appState.isPaused.toggle()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(appState.isPaused ? .green : .orange)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Content — driven by local @State copies
            contentView

            Divider()

            // Footer
            HStack {
                SettingsLink {
                    Text("Préférences...")
                }
                .buttonStyle(.borderless)
                
                Button("Mises à jour") {
                    updater.checkForUpdates()
                }
                .buttonStyle(.borderless)
                .disabled(!updaterViewModel.canCheckForUpdates)
                .padding(.leading, 8)

                Spacer()

                Button("Quitter") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.borderless)
                .foregroundColor(.red)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(width: 360)
        .onAppear {
            // Force a fresh data load every time the menu opens.
            calendarService.requestAccess()
            // Snapshot current state immediately (in case onReceive
            // hasn't fired yet).
            events = calendarService.events
            authStatus = calendarService.authStatus
        }
        // Explicitly subscribe to Combine publishers so @State changes
        // trigger a guaranteed re-render, even if @EnvironmentObject
        // observation is broken in MenuBarExtra on macOS 26.
        .onReceive(calendarService.$events) { events = $0 }
        .onReceive(calendarService.$authStatus) { authStatus = $0 }
    }

    // MARK: - Sub-views

    /// Picks the right content view based on local @State copies.
    @ViewBuilder
    private var contentView: some View {
        switch authStatus {
        case .fullAccess:
            if events.isEmpty {
                emptyView
            } else {
                eventListView
            }

        case .writeOnly:
            writeOnlyAccessView

        case .notDetermined:
            noAccessView

        case .denied, .restricted:
            noAccessView

        @unknown default:
            noAccessView
        }
    }

    private var noAccessView: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 36))
                .foregroundColor(.secondary)
            Text("Accès au calendrier requis")
                .font(.subheadline)
                .fontWeight(.medium)
            Text("Autorisez l'accès dans\nRéglages Système > Confidentialité > Calendriers")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Ouvrir Réglages Système") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .padding(.top, 4)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
    }

    private var writeOnlyAccessView: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 36))
                .foregroundColor(.orange)
            Text("Accès limité (écriture seule)")
                .font(.subheadline)
                .fontWeight(.medium)
            Text("ScreenAlert a besoin de lire vos événements.\nDans Réglages Système > Confidentialité > Calendriers,\npassez ScreenAlert en « Accès complet ».")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Ouvrir Réglages Système") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .padding(.top, 4)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar")
                .font(.system(size: 36))
                .foregroundColor(.secondary)
            Text("Aucun événement à venir")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
    }

    private var eventListView: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(events.prefix(10)) { event in
                EventRow(event: event, onShowAlert: {
                    AlertScheduler.shared.showAlertManually(for: event)
                })
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Event Row

struct EventRow: View {
    let event: CalendarEvent
    var onShowAlert: (() -> Void)? = nil

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            // Calendar color bar
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(nsColor: event.calendarColor))
                .frame(width: 4, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(event.startDate, style: .time)
                    Text("—")
                    Text(event.endDate, style: .time)

                    if event.videoLink != nil {
                        Image(systemName: "video.fill")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                }
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            }

            Spacer()

            // Show alert button (visible on hover)
            if let onShowAlert = onShowAlert {
                Button {
                    onShowAlert()
                } label: {
                    Image(systemName: "bell.badge")
                        .font(.system(size: 13))
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .opacity(isHovered ? 1 : 0)
                .help("Afficher l'alerte pour cet événement")
            }

            if event.timeUntilStart > 0 {
                Text(relativeTimeText)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.orange)
            } else {
                Text("En cours")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.green)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }

    private var relativeTimeText: String {
        let minutes = Int(event.timeUntilStart / 60)
        if minutes < 1 { return "< 1 min" }
        if minutes < 60 { return "\(minutes) min" }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if remainingMinutes > 0 {
            return "\(hours)h\(String(format: "%02d", remainingMinutes))"
        }
        return "\(hours)h"
    }
}
