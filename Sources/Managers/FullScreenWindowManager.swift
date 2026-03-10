import AppKit
import SwiftUI

/// Manages full-screen overlay panels that block the user's screen.
/// Uses NSPanel (a subclass of NSWindow) positioned at `.screenSaver` level
/// to appear above everything including full-screen apps.
class FullScreenWindowManager {
    static let shared = FullScreenWindowManager()

    private var panels: [NSPanel] = []
    private var keyMonitor: Any?

    // MARK: - Public API

    func showAlert(for event: CalendarEvent) {
        // Close any existing panels without resetting activeAlert
        closeAllPanels()

        // Show on all screens or primary only based on preference
        let screens: [NSScreen]
        if AppState.shared.alertOnAllScreens {
            screens = NSScreen.screens
        } else {
            screens = [NSScreen.main ?? NSScreen.screens[0]]
        }

        for screen in screens {
            let panel = createPanel(for: screen, event: event)
            panels.append(panel)
        }

        // Activate the app to bring panels to front
        NSApp.activate(ignoringOtherApps: true)

        // Make the primary panel key
        panels.first?.makeKeyAndOrderFront(nil)

        // Install keyboard shortcuts
        installKeyboardMonitor(for: event)
    }

    func dismissAlert() {
        closeAllPanels()
        AppState.shared.activeAlert = nil
    }

    // MARK: - Private

    /// Close all overlay panels and remove keyboard monitor,
    /// without touching `activeAlert` state.
    private func closeAllPanels() {
        removeKeyboardMonitor()
        for panel in panels {
            // Animate out
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.25
                panel.animator().alphaValue = 0
            } completionHandler: { [weak panel] in
                panel?.close()
            }
        }
        panels.removeAll()
    }

    private func installKeyboardMonitor(for calendarEvent: CalendarEvent) {
        removeKeyboardMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { nsEvent in
            switch nsEvent.keyCode {
            case 36, 76: // Return, Enter (numpad)
                if let videoLink = calendarEvent.videoLink {
                    NSWorkspace.shared.open(videoLink.url)
                    AlertScheduler.shared.dismiss(event: calendarEvent)
                }
                return nil
            case 53: // Escape
                AlertScheduler.shared.dismiss(event: calendarEvent)
                return nil
            default:
                return nsEvent
            }
        }
    }

    private func removeKeyboardMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    private func createPanel(for screen: NSScreen, event: CalendarEvent) -> NSPanel {
        let panel = NSPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // Window level: screenSaver is above almost everything
        panel.level = .init(rawValue: Int(CGShieldingWindowLevel()))
        // Appear on all Spaces (virtual desktops) and alongside full-screen apps
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = false
        panel.isReleasedWhenClosed = false
        panel.alphaValue = 0 // start transparent, animate in

        let alertView = AlertOverlayView(
            event: event,
            onDismiss: {
                AlertScheduler.shared.dismiss(event: event)
            },
            onSnooze: { minutes in
                AlertScheduler.shared.snooze(event: event, minutes: minutes)
            },
            onJoin: { url in
                NSWorkspace.shared.open(url)
                AlertScheduler.shared.dismiss(event: event)
            }
        )

        panel.contentView = NSHostingView(rootView: alertView)

        // Animate in
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.4
            panel.animator().alphaValue = 1
        }

        return panel
    }
}
