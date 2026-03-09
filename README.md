# ScreenAlert

A macOS menu bar app that displays full-screen overlay alerts before your calendar events start.

## Features

- **Full-screen alerts** -- an overlay appears above everything (including full-screen apps) before each event
- **Configurable timing** -- set alerts from 1 to 15 minutes before events
- **Video conference integration** -- one-click "Join" button for Zoom, Google Meet, Teams, Webex, and Slack links
- **Snooze & dismiss** -- snooze with configurable durations or dismiss instantly
- **Multi-screen support** -- alerts can appear on all connected displays
- **Calendar selection** -- choose which Apple Calendar calendars to monitor
- **Customizable appearance** -- overlay color, opacity, and alert sound
- **Launch at login** -- optional auto-start via ServiceManagement

## Installation

1. Telecharger `ScreenAlert.zip` depuis la [derniere release](https://github.com/briangtn/ScreenAlerts/releases/latest)
2. Dezipper l'archive
3. Copier `ScreenAlert.app` dans `/Applications`
4. Lancer l'app -- elle apparaitra dans la barre de menu
5. Autoriser l'acces au calendrier quand macOS le demande

## Requirements

- macOS 14.0+
- Calendar access permission

## Build

```bash
# Debug build
./build.sh

# Release build
./build.sh release

# Build and run
./build.sh run
```

The build script compiles via Swift Package Manager, creates a `.app` bundle, signs it ad-hoc with the required entitlements, and installs it to `/Applications`.

## Project Structure

```
Sources/
├── ScreenAlertApp.swift             # App entry point
├── AppDelegate.swift                # Lifecycle, calendar access
├── AppState.swift                   # Observable state (UserDefaults-backed)
├── Managers/
│   └── FullScreenWindowManager.swift
├── Models/
│   ├── CalendarEvent.swift
│   └── VideoLink.swift
├── Services/
│   ├── AlertScheduler.swift
│   └── CalendarService.swift
└── Views/
    ├── AlertOverlayView.swift
    ├── MenuBarView.swift
    └── SettingsView.swift
```

## License

All rights reserved.
