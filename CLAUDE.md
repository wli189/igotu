# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

`igotu` is an iOS/iPadOS SwiftUI app prototype for context-aware wellness reminders. The product and implementation baseline is documented in [Igotu Product Baseline.md](Igotu%20Product%20Baseline.md), and the visual direction is documented in [DESIGN.md](DESIGN.md). The app stores its schedule, reminder rules, daily goals, and reminder history in `UserDefaults`. The current notification architecture schedules multiple event-specific local notifications within a rolling window. Foreground delivery uses an in-app confirmation prompt; opening a background notification presents a full-screen confirmation view. `IgotuCore` is a local Swift package compiled for both iOS and macOS.

## Development commands

The project requires Xcode 26.6, targets iOS 26.5 and macOS 26.0, and includes the `igotu`, `igotuMac`, `igotuTests`, and `igotuUITests` targets.

```sh
# Open the project in Xcode
open igotu.xcodeproj

# Inspect schemes and targets
xcodebuild -list -project igotu.xcodeproj

# List available simulator/device destinations
xcodebuild -showdestinations -project igotu.xcodeproj -scheme igotu

# Build for a generic iOS device without signing
xcodebuild -project igotu.xcodeproj \
  -scheme igotu \
  -destination 'generic/platform=iOS' \
  -sdk iphoneos \
  CODE_SIGNING_ALLOWED=NO \
  build

# Run all unit and UI tests on an available simulator
xcodebuild -project igotu.xcodeproj \
  -scheme igotu \
  -destination 'platform=iOS Simulator,name=<available simulator>,OS=<available iOS>' \
  test

# Run one Swift Testing unit test
xcodebuild -project igotu.xcodeproj \
  -scheme igotu \
  -destination 'platform=iOS Simulator,name=<available simulator>,OS=<available iOS>' \
  -only-testing:igotuTests/igotuTests/example \
  test

# Run one UI test method
xcodebuild -project igotu.xcodeproj \
  -scheme igotu \
  -destination 'platform=iOS Simulator,name=<available simulator>,OS=<available iOS>' \
  -only-testing:igotuUITests/igotuUITests/testExample \
  test
```

Replace the simulator name/OS with a destination from `-showdestinations` when the local Xcode installation differs. There is no external package manager dependency, custom build script, or lint configuration. Use Xcode's build analyzer/compiler warnings and `swift build` in `IgotuCore/` for static checks.

## Architecture

### Current implementation

- `igotu/App/igotuApp.swift` is the `@main` SwiftUI entry point. It creates the configuration and history stores and injects them into the app views.
- `IgotuCore/Sources/IgotuCore/` contains the platform-neutral models, schedule timeline, validators, reminder engine/planner, payload types, and timing constants. The package has no SwiftUI, UIKit, AppKit, UserNotifications, or BackgroundTasks dependency.
- `DailyMetricsCalculator` is part of `IgotuCore`; `igotu/Services/Core/AppConfigurationStore.swift` and `ReminderHistoryStore` remain app-layer modules for now because they provide observable `UserDefaults` state to the SwiftUI views.
- `igotu/Services/iOS/ReminderCoordinator.swift` reconciles reminder events with the iOS local notification adapter and routes notification actions back through the event lifecycle.
- `igotu/Services/iOS/NotificationScheduler.swift` is the local notification adapter. `ReminderBackgroundScheduler` requests periodic refresh opportunities to replenish the rolling plan.
- `igotu/Navigation/MainTabView.swift` uses the existing TabView navigation for compact iPhone layouts and a NavigationSplitView sidebar for regular-width iPad layouts. Today and setup content use a bounded reading column on larger screens.
- Behavior options in `igotu/Views/Reminders/NotificationTestView.swift` create test events that reuse the production notification payload and confirmation flow; test events are excluded from planning and daily metrics. Wind Down testing remains a standalone notification.
- `igotu/Views/Reminders/ReminderToastView.swift` renders foreground reminder actions, while `ReminderConfirmationView.swift` renders the full-screen confirmation route opened from a notification.
- `igotu/Services/Core/AppConfigurationStore.swift` persists configuration in `UserDefaults` and normalizes legacy or incomplete rules/goals on load. `ReminderHistoryStore` persists a bounded event history and applies cooldown, expiration, and completion rules.
- `igotu/Resources/Assets.xcassets` contains the app icon and theme color catalogs. The Xcode project uses filesystem-synchronized groups, so Swift files added under app, extension, or test directories are picked up automatically.
- `igotuMac/App/igotuMacApp.swift` is the temporary macOS smoke-test app. It intentionally contains only a blank window; macOS product UI and platform services are not implemented yet.

### Test targets

- `igotuTests` uses Swift Testing (`import Testing`) and imports the app with `@testable import igotu`.
- `igotuUITests` uses XCTest/XCUIAutomation and launches the `igotu` application. The current files are Xcode-generated examples, including a launch screenshot and a launch-performance test.
- Both test targets depend on the app target through the Xcode scheme; run them through `xcodebuild ... test` rather than invoking Swift Package Manager commands.

### Product boundary

Keep platform effects behind their dedicated modules and keep schedule decisions testable through value-returning modules:

```text
SwiftUI views
    -> configuration/history stores
    -> reminder engine and local notification architecture
```

Keep schedule decisions in value-returning modules and keep platform effects behind dedicated adapters. Inject `Calendar` and random-offset providers in tests; avoid recreating schedule math in views or platform adapters.

### UI direction

New UI should follow the Ambient Calm specification in `DESIGN.md`: native SwiftUI, dynamic light/dark colors, material-backed cards, restrained context-specific accents, and calm transitions/haptics. The product document's home screen is intended to answer “What should I do right now?” rather than present a dense health dashboard.

### Directory layout policy

The canonical layout keeps iOS/iPadOS application code under `igotu/`, the shared core in `IgotuCore/`, and the macOS smoke-test target under `igotuMac/`:

```text
IgotuCore/
└── Sources/IgotuCore/          # Platform-neutral models and reminder logic

igotu/
├── App/                         # App entry point and composition
├── Services/
│   ├── Core/                    # Observable stores used by the app layer
│   └── iOS/                     # iOS and iPadOS system adapters
├── Views/
│   ├── Today/                   # Today feature views
│   ├── Schedule/                # Setup and schedule editing views
│   └── Reminders/               # Reminder settings and presentation views
├── Navigation/                 # iPhone tabs and iPad sidebar navigation
├── DesignSystem/               # Shared SwiftUI styling and theme services
└── Resources/                  # Asset catalogs and app resources

igotuMac/
└── App/                         # Temporary blank macOS smoke-test app
```

iPhone and iPadOS use the same target and the same `Services/iOS` implementation. UI differences are handled with size classes and adaptive SwiftUI layouts; do not create separate iPhone and iPad source trees. New iOS/iPadOS application code belongs under `igotu/`; platform-neutral logic belongs in `IgotuCore/`.

The `igotuMac` target is currently only a buildable blank window. Future macOS adapters and UI belong under `igotuMac/`; they should consume `IgotuCore` instead of duplicating its implementation.

## Repository conventions

- Keep platform-neutral models and services in `IgotuCore/`, iOS/iPadOS app code in `igotu/`, macOS app code in `igotuMac/`, unit tests in `igotuTests/`, and UI tests in `igotuUITests/`; the synchronized Xcode groups make the directory location part of target membership.
- Preserve SwiftUI previews with in-memory model containers so previews do not write to the persistent store.
- Keep scheduling, time-zone, and configuration behavior covered by focused tests before changing shared modules.
- The repository has no external package manager dependencies or custom lint command; `IgotuCore` is a local Swift package. Use Xcode compiler warnings, `swift build` in `IgotuCore/`, and `xcodebuild` for verification.

## External-agent configuration

No repository-local Codex or Gemini configuration was found. If you use Codex or Gemini configuration at the user level and want it imported, reply `/import` to scan and list importable MCP servers, slash commands, subagents, skills, and instructions; then run `/import --yes=<digest>` with the digest shown by the scan. If `/import` is unavailable on this surface, run `claude import` from a terminal.
