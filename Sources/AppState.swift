import SwiftUI
import Combine
import ServiceManagement

/// Shared application state, observable by all views.
class AppState: ObservableObject {
    static let shared = AppState()

    /// Whether alerts are currently paused.
    @Published var isPaused: Bool = false

    /// How many minutes before an event to trigger the alert.
    @Published var alertMinutesBefore: Int = 1

    /// The event currently being displayed as a full-screen alert (nil if none).
    @Published var activeAlert: CalendarEvent? = nil

    // MARK: - Snooze

    /// Available snooze durations in minutes (shown as buttons on the alert).
    @Published var snoozeDurations: [Int] = [1, 5, 15]

    // MARK: - Sound

    /// Whether to play a sound when an alert is shown.
    @Published var alertSoundEnabled: Bool = true

    /// The name of the system sound to play (empty string = system beep, "__custom__" = custom file).
    @Published var alertSoundName: String = ""

    /// Path to a custom sound file selected by the user.
    @Published var customSoundPath: String = ""

    // MARK: - Display

    /// Whether to show the alert on all screens or only the primary screen.
    @Published var alertOnAllScreens: Bool = true

    /// Whether to include all-day events in the event list.
    @Published var includeAllDayEvents: Bool = false

    // MARK: - Appearance

    /// Overlay background opacity (0.0 - 1.0).
    @Published var overlayOpacity: Double = 0.88

    /// Overlay background color components (RGB, 0.0 - 1.0).
    @Published var overlayColorRed: Double = 0.0
    @Published var overlayColorGreen: Double = 0.0
    @Published var overlayColorBlue: Double = 0.0

    /// Accent color for the "Join" button (RGB, 0.0 - 1.0).
    @Published var accentColorRed: Double = 0.0
    @Published var accentColorGreen: Double = 0.8
    @Published var accentColorBlue: Double = 0.0

    // MARK: - Calendars

    /// Calendar identifiers that are excluded from alerts.
    @Published var excludedCalendarIDs: Set<String> = []

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Colors

    var overlayColor: Color {
        Color(red: overlayColorRed, green: overlayColorGreen, blue: overlayColorBlue)
    }

    var accentColor: Color {
        Color(red: accentColorRed, green: accentColorGreen, blue: accentColorBlue)
    }

    // MARK: - Launch at Login

    /// Whether the app is registered to launch at login.
    var launchAtLogin: Bool {
        get {
            SMAppService.mainApp.status == .enabled
        }
        set {
            objectWillChange.send()
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                    print("[ScreenAlert] Launch at login enabled.")
                } else {
                    try SMAppService.mainApp.unregister()
                    print("[ScreenAlert] Launch at login disabled.")
                }
            } catch {
                print("[ScreenAlert] Failed to \(newValue ? "enable" : "disable") launch at login: \(error)")
                DispatchQueue.main.async {
                    Self.showLaunchAtLoginError(enable: newValue, error: error)
                }
            }
        }
    }

    // MARK: - Available System Sounds

    static let availableSounds: [String] = {
        let soundDirs = [
            "/System/Library/Sounds",
            "/Library/Sounds"
        ]
        var sounds: [String] = []
        for dir in soundDirs {
            if let files = try? FileManager.default.contentsOfDirectory(atPath: dir) {
                for file in files {
                    let name = (file as NSString).deletingPathExtension
                    if !sounds.contains(name) {
                        sounds.append(name)
                    }
                }
            }
        }
        return sounds.sorted()
    }()

    // MARK: - Init

    private init() {
        let defaults = UserDefaults.standard

        // Restore from UserDefaults
        let stored = defaults.integer(forKey: "alertMinutesBefore")
        self.alertMinutesBefore = stored > 0 ? stored : 1
        self.isPaused = defaults.bool(forKey: "isPaused")

        // Snooze durations
        if let storedSnooze = defaults.array(forKey: "snoozeDurations") as? [Int], !storedSnooze.isEmpty {
            self.snoozeDurations = storedSnooze
        }

        // Sound
        if defaults.object(forKey: "alertSoundEnabled") != nil {
            self.alertSoundEnabled = defaults.bool(forKey: "alertSoundEnabled")
        }
        if let storedSoundName = defaults.string(forKey: "alertSoundName") {
            self.alertSoundName = storedSoundName
        }
        if let storedCustomPath = defaults.string(forKey: "customSoundPath") {
            self.customSoundPath = storedCustomPath
        }

        // Display
        if defaults.object(forKey: "alertOnAllScreens") != nil {
            self.alertOnAllScreens = defaults.bool(forKey: "alertOnAllScreens")
        }
        self.includeAllDayEvents = defaults.bool(forKey: "includeAllDayEvents")

        // Appearance
        if defaults.object(forKey: "overlayOpacity") != nil {
            self.overlayOpacity = defaults.double(forKey: "overlayOpacity")
        }
        if defaults.object(forKey: "overlayColorRed") != nil {
            self.overlayColorRed = defaults.double(forKey: "overlayColorRed")
            self.overlayColorGreen = defaults.double(forKey: "overlayColorGreen")
            self.overlayColorBlue = defaults.double(forKey: "overlayColorBlue")
        }
        if defaults.object(forKey: "accentColorRed") != nil {
            self.accentColorRed = defaults.double(forKey: "accentColorRed")
            self.accentColorGreen = defaults.double(forKey: "accentColorGreen")
            self.accentColorBlue = defaults.double(forKey: "accentColorBlue")
        }

        // Excluded calendars
        if let storedExcluded = defaults.array(forKey: "excludedCalendarIDs") as? [String] {
            self.excludedCalendarIDs = Set(storedExcluded)
        }

        // Auto-enable launch at login on first launch
        if !defaults.bool(forKey: "hasLaunchedBefore") {
            defaults.set(true, forKey: "hasLaunchedBefore")
            if SMAppService.mainApp.status != .enabled {
                do {
                    try SMAppService.mainApp.register()
                    print("[ScreenAlert] First launch: auto-enabled launch at login.")
                } catch {
                    print("[ScreenAlert] First launch: failed to auto-enable launch at login: \(error)")
                }
            }
        }

        // Persist changes
        $alertMinutesBefore.dropFirst()
            .sink { defaults.set($0, forKey: "alertMinutesBefore") }
            .store(in: &cancellables)
        $isPaused.dropFirst()
            .sink { defaults.set($0, forKey: "isPaused") }
            .store(in: &cancellables)
        $snoozeDurations.dropFirst()
            .sink { defaults.set($0, forKey: "snoozeDurations") }
            .store(in: &cancellables)
        $alertSoundEnabled.dropFirst()
            .sink { defaults.set($0, forKey: "alertSoundEnabled") }
            .store(in: &cancellables)
        $alertSoundName.dropFirst()
            .sink { defaults.set($0, forKey: "alertSoundName") }
            .store(in: &cancellables)
        $customSoundPath.dropFirst()
            .sink { defaults.set($0, forKey: "customSoundPath") }
            .store(in: &cancellables)
        $alertOnAllScreens.dropFirst()
            .sink { defaults.set($0, forKey: "alertOnAllScreens") }
            .store(in: &cancellables)
        $includeAllDayEvents.dropFirst()
            .sink { [weak self] val in
                defaults.set(val, forKey: "includeAllDayEvents")
                CalendarService.shared.refreshEvents()
                _ = self // prevent unused capture warning
            }
            .store(in: &cancellables)
        $overlayOpacity.dropFirst()
            .sink { defaults.set($0, forKey: "overlayOpacity") }
            .store(in: &cancellables)
        $overlayColorRed.dropFirst()
            .sink { defaults.set($0, forKey: "overlayColorRed") }
            .store(in: &cancellables)
        $overlayColorGreen.dropFirst()
            .sink { defaults.set($0, forKey: "overlayColorGreen") }
            .store(in: &cancellables)
        $overlayColorBlue.dropFirst()
            .sink { defaults.set($0, forKey: "overlayColorBlue") }
            .store(in: &cancellables)
        $accentColorRed.dropFirst()
            .sink { defaults.set($0, forKey: "accentColorRed") }
            .store(in: &cancellables)
        $accentColorGreen.dropFirst()
            .sink { defaults.set($0, forKey: "accentColorGreen") }
            .store(in: &cancellables)
        $accentColorBlue.dropFirst()
            .sink { defaults.set($0, forKey: "accentColorBlue") }
            .store(in: &cancellables)
        $excludedCalendarIDs.dropFirst()
            .sink { defaults.set(Array($0), forKey: "excludedCalendarIDs") }
            .store(in: &cancellables)
    }

    // MARK: - Helpers

    /// Play the configured alert sound.
    func playAlertSound() {
        guard alertSoundEnabled else { return }
        if alertSoundName == "__custom__" {
            if !customSoundPath.isEmpty,
               let sound = NSSound(contentsOfFile: customSoundPath, byReference: true) {
                sound.play()
            } else {
                NSSound.beep()
            }
        } else if alertSoundName.isEmpty {
            NSSound.beep()
        } else if let sound = NSSound(named: NSSound.Name(alertSoundName)) {
            sound.play()
        } else {
            NSSound.beep()
        }
    }

    /// Display a macOS alert when launch at login registration fails.
    private static func showLaunchAtLoginError(enable: Bool, error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = enable
            ? "Impossible d'activer le lancement au démarrage"
            : "Impossible de désactiver le lancement au démarrage"
        alert.informativeText = "Vérifiez que l'application se trouve dans le dossier /Applications.\n\nErreur : \(error.localizedDescription)"
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
