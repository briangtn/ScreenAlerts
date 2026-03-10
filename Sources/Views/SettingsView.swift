import SwiftUI
import EventKit
import UniformTypeIdentifiers
import Sparkle

/// Preferences window accessible from the menu bar.
struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var calendarService = CalendarService.shared
    
    let updater: SPUUpdater

    var body: some View {
        TabView {
            GeneralSettingsView()
                .environmentObject(appState)
                .tabItem {
                    Label("Général", systemImage: "gear")
                }

            AppearanceSettingsView()
                .environmentObject(appState)
                .tabItem {
                    Label("Apparence", systemImage: "paintbrush")
                }

            CalendarSettingsView(calendarService: calendarService)
                .environmentObject(appState)
                .tabItem {
                    Label("Calendriers", systemImage: "calendar")
                }
                
            UpdatesSettingsView(updater: updater)
                .tabItem {
                    Label("Mises à jour", systemImage: "arrow.triangle.2.circlepath")
                }
        }
        .frame(width: 520, height: 480)
        .onAppear {
            NSApp.activate(ignoringOtherApps: true)
            DispatchQueue.main.async {
                NSApp.keyWindow?.makeKeyAndOrderFront(nil)
                NSApp.keyWindow?.orderFrontRegardless()
            }
        }
    }
}

// MARK: - Updates Settings

struct UpdatesSettingsView: View {
    let updater: SPUUpdater
    @StateObject private var updaterViewModel: UpdaterViewModel
    @State private var automaticallyChecksForUpdates: Bool
    
    init(updater: SPUUpdater) {
        self.updater = updater
        _updaterViewModel = StateObject(wrappedValue: UpdaterViewModel(updater: updater))
        _automaticallyChecksForUpdates = State(initialValue: updater.automaticallyChecksForUpdates)
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.blue)
                            
                        VStack(alignment: .leading) {
                            Text("Mises à jour de ScreenAlert")
                                .font(.headline)
                            Text("Version actuelle : \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Inconnue") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.leading, 8)
                    }
                    .padding(.bottom, 8)
                    
                    Toggle("Vérifier automatiquement les mises à jour", isOn: $automaticallyChecksForUpdates)
                        .onChange(of: automaticallyChecksForUpdates) { _, newValue in
                            updater.automaticallyChecksForUpdates = newValue
                        }
                    
                    Button("Vérifier maintenant...") {
                        updater.checkForUpdates()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!updaterViewModel.canCheckForUpdates)
                }
                .padding()
            }
        }
        .formStyle(.grouped)
        .padding(20)
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @EnvironmentObject var appState: AppState

    private let alertOptions = [0, 1, 2, 3, 5, 10, 15]
    private let availableSnoozeValues = [1, 2, 3, 5, 10, 15, 30, 60]

    var body: some View {
        Form {
            // Alert timing
            Section {
                Picker("Alerte avant l'événement :", selection: $appState.alertMinutesBefore) {
                    ForEach(alertOptions, id: \.self) { minutes in
                        if minutes == 0 {
                            Text("Pile à l'heure").tag(minutes)
                        } else {
                            Text("\(minutes) minute\(minutes > 1 ? "s" : "")").tag(minutes)
                        }
                    }
                }
                .pickerStyle(.menu)
            }

            // Alerts on/off
            Section {
                Toggle("Alertes activées", isOn: Binding(
                    get: { !appState.isPaused },
                    set: { appState.isPaused = !$0 }
                ))

                Text("Quand activé, une alerte plein écran s'affichera avant chaque événement.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Snooze durations
            Section("Boutons de snooze") {
                ForEach(availableSnoozeValues, id: \.self) { minutes in
                    Toggle(snoozeLabel(minutes: minutes), isOn: Binding(
                        get: { appState.snoozeDurations.contains(minutes) },
                        set: { enabled in
                            if enabled {
                                appState.snoozeDurations.append(minutes)
                                appState.snoozeDurations.sort()
                            } else {
                                appState.snoozeDurations.removeAll { $0 == minutes }
                            }
                        }
                    ))
                }

                Text("Sélectionnez les durées de snooze affichées sur l'alerte.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Sound
            Section("Son") {
                Toggle("Jouer un son", isOn: $appState.alertSoundEnabled)

                if appState.alertSoundEnabled {
                    Picker("Son :", selection: $appState.alertSoundName) {
                        Text("Bip système").tag("")
                        ForEach(AppState.availableSounds, id: \.self) { name in
                            Text(name).tag(name)
                        }
                        Divider()
                        Text("Son personnalisé…").tag("__custom__")
                    }
                    .pickerStyle(.menu)

                    if appState.alertSoundName == "__custom__" {
                        HStack {
                            if appState.customSoundPath.isEmpty {
                                Text("Aucun fichier sélectionné")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            } else {
                                Text(URL(fileURLWithPath: appState.customSoundPath).lastPathComponent)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            Spacer()
                            Button("Choisir…") {
                                selectCustomSoundFile()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }

                    HStack {
                        Text("Volume :")
                        Slider(value: Binding(
                            get: { Double(appState.alertVolume) },
                            set: { appState.alertVolume = Float($0) }
                        ), in: 0.0...1.0, step: 0.05)
                        Text("\(Int(appState.alertVolume * 100))%")
                            .monospacedDigit()
                            .frame(width: 40, alignment: .trailing)
                    }

                    if appState.alertSoundName.isEmpty {
                        Text("Le volume ne s'applique pas au bip système. Choisissez un son pour régler le volume.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Button("Aperçu") {
                        appState.playAlertSound()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            // Display
            Section("Affichage") {
                Picker("Écrans :", selection: $appState.alertOnAllScreens) {
                    Text("Tous les écrans").tag(true)
                    Text("Écran principal uniquement").tag(false)
                }
                .pickerStyle(.menu)

                Toggle("Inclure les événements sur la journée entière", isOn: $appState.includeAllDayEvents)
            }

            // Launch at login
            Section {
                Toggle("Lancer au démarrage", isOn: Binding(
                    get: { appState.launchAtLogin },
                    set: { appState.launchAtLogin = $0 }
                ))

                Text("L'application se lancera automatiquement à l'ouverture de session.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Test
            Section("Test") {
                Button("Tester une alerte maintenant") {
                    AlertScheduler.shared.showTestAlert()
                }
                .buttonStyle(.bordered)
            }
        }
        .formStyle(.grouped)
        .padding(20)
    }

    private func snoozeLabel(minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) minute\(minutes > 1 ? "s" : "")"
        }
        let hours = minutes / 60
        return "\(hours) heure\(hours > 1 ? "s" : "")"
    }

    private func selectCustomSoundFile() {
        let panel = NSOpenPanel()
        panel.title = "Choisir un fichier son"
        panel.allowedContentTypes = [
            .audio,
            .mp3,
            .wav,
            .aiff
        ]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        if panel.runModal() == .OK, let url = panel.url {
            appState.customSoundPath = url.path
        }
    }
}

// MARK: - Appearance Settings

struct AppearanceSettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Form {
            // Overlay
            Section("Fond de l'alerte") {
                HStack {
                    Text("Opacité :")
                    Slider(value: $appState.overlayOpacity, in: 0.3...1.0, step: 0.05)
                    Text("\(Int(appState.overlayOpacity * 100))%")
                        .monospacedDigit()
                        .frame(width: 40, alignment: .trailing)
                }

                ColorPicker("Couleur de fond :", selection: overlayColorBinding, supportsOpacity: false)
            }

            // Accent color
            Section("Bouton Rejoindre") {
                ColorPicker("Couleur du bouton :", selection: accentColorBinding, supportsOpacity: false)
            }

            // Preview
            Section("Aperçu") {
                ZStack {
                    appState.overlayColor.opacity(appState.overlayOpacity)

                    VStack(spacing: 12) {
                        Text("Réunion d'exemple")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text("Dans 2 min 30 s")
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(.white.opacity(0.7))

                        HStack(spacing: 12) {
                            previewButton(title: "5 min", color: .white.opacity(0.15))
                            previewButton(title: "Rejoindre", color: appState.accentColor)
                            previewButton(title: "Fermer", color: .white.opacity(0.15))
                        }
                    }
                    .padding(20)
                }
                .frame(height: 160)
                .cornerRadius(12)
            }
        }
        .formStyle(.grouped)
        .padding(20)
    }

    private func previewButton(title: String, color: Color) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(color)
            .cornerRadius(8)
    }

    // MARK: - Color Bindings

    private var overlayColorBinding: Binding<Color> {
        Binding(
            get: {
                Color(red: appState.overlayColorRed, green: appState.overlayColorGreen, blue: appState.overlayColorBlue)
            },
            set: { newColor in
                if let components = newColor.cgColor?.components, components.count >= 3 {
                    appState.overlayColorRed = Double(components[0])
                    appState.overlayColorGreen = Double(components[1])
                    appState.overlayColorBlue = Double(components[2])
                }
            }
        )
    }

    private var accentColorBinding: Binding<Color> {
        Binding(
            get: {
                Color(red: appState.accentColorRed, green: appState.accentColorGreen, blue: appState.accentColorBlue)
            },
            set: { newColor in
                if let components = newColor.cgColor?.components, components.count >= 3 {
                    appState.accentColorRed = Double(components[0])
                    appState.accentColorGreen = Double(components[1])
                    appState.accentColorBlue = Double(components[2])
                }
            }
        )
    }
}

// MARK: - Calendar Settings

struct CalendarSettingsView: View {
    @ObservedObject var calendarService: CalendarService
    @EnvironmentObject var appState: AppState

    var body: some View {
        Form {
            if calendarService.calendars.isEmpty {
                Text("Aucun calendrier disponible")
                    .foregroundColor(.secondary)
            } else {
                Section("Sélectionnez les calendriers à surveiller") {
                    ForEach(calendarService.calendars, id: \.calendarIdentifier) { calendar in
                        Toggle(isOn: calendarBinding(for: calendar)) {
                            HStack {
                                Circle()
                                    .fill(Color(nsColor: calendar.color ?? .systemGray))
                                    .frame(width: 10, height: 10)
                                Text(calendar.title)
                                Spacer()
                                Text(calendar.source?.title ?? "")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                    }
                }

                Section {
                    Text("Les calendriers désactivés ne déclencheront pas d'alertes et n'apparaîtront pas dans la liste des événements.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack {
                        Button("Tout activer") {
                            appState.excludedCalendarIDs.removeAll()
                            CalendarService.shared.refreshEvents()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button("Tout désactiver") {
                            appState.excludedCalendarIDs = Set(calendarService.calendars.map(\.calendarIdentifier))
                            CalendarService.shared.refreshEvents()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding(20)
    }

    private func calendarBinding(for calendar: EKCalendar) -> Binding<Bool> {
        Binding(
            get: {
                !appState.excludedCalendarIDs.contains(calendar.calendarIdentifier)
            },
            set: { enabled in
                if enabled {
                    appState.excludedCalendarIDs.remove(calendar.calendarIdentifier)
                } else {
                    appState.excludedCalendarIDs.insert(calendar.calendarIdentifier)
                }
                CalendarService.shared.refreshEvents()
            }
        )
    }
}

// MARK: - CalendarEvent manual init for testing

extension CalendarEvent {
    init(
        id: String,
        title: String,
        startDate: Date,
        endDate: Date,
        calendarTitle: String,
        calendarColor: NSColor,
        notes: String?,
        url: URL?,
        location: String?,
        videoLink: VideoLink?
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.calendarTitle = calendarTitle
        self.calendarColor = calendarColor
        self.notes = notes
        self.url = url
        self.location = location
        self.videoLink = videoLink
    }
}
