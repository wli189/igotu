# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

`igotu` is an iOS SwiftUI app prototype for a context-aware wellness reminder. The product concept is documented in [Context-Aware Wellness Reminder.md](Context-Aware%20Wellness%20Reminder.md), and the visual direction is documented in [DESIGN.md](DESIGN.md). The repository currently contains the default SwiftUI/SwiftData CRUD scaffold; the context, behavior, activity-awareness, reminder-engine, and notification-scheduling layers described in the product document are planned concepts, not implemented modules.

## Development commands

The project requires Xcode 26.6 and targets iOS 26.5. The shared scheme is `igotu`, and the available targets are `igotu`, `igotuTests`, and `igotuUITests`.

```sh
# Open the project in Xcode
open igotu.xcodeproj

# Inspect schemes and targets
xcodebuild -list -project igotu.xcodeproj

# List available simulator/device destinations
xcodebuild -showdestinations -project igotu.xcodeproj -scheme igotu

# Build for the installed iPhone 17 / iOS 26.5 simulator
xcodebuild -project igotu.xcodeproj \
  -scheme igotu \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' \
  build

# Run all unit and UI tests
xcodebuild -project igotu.xcodeproj \
  -scheme igotu \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' \
  test

# Run one Swift Testing unit test
xcodebuild -project igotu.xcodeproj \
  -scheme igotu \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' \
  -only-testing:igotuTests/igotuTests/example \
  test

# Run one UI test method
xcodebuild -project igotu.xcodeproj \
  -scheme igotu \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' \
  -only-testing:igotuUITests/igotuUITests/testExample \
  test
```

Replace the simulator name/OS with a destination from `-showdestinations` when the local Xcode installation differs. There is no package manager, custom build script, lint configuration, or repository-provided lint command. Use Xcode's build analyzer/compiler warnings for static checks unless a future change adds a formatter or linter.

## Architecture

### Current implementation

- `igotu/igotuApp.swift` is the `@main` SwiftUI entry point. It builds a persistent `SwiftData.ModelContainer` for `Item` and injects it into the `WindowGroup` with `.modelContainer(...)`.
- `igotu/ContentView.swift` is currently the only app screen. It reads persisted `Item` models with `@Query`, displays them in a `NavigationSplitView`, and inserts/deletes items through the environment `modelContext`. Its preview uses an in-memory SwiftData container.
- `igotu/Item.swift` is the only persisted domain model. It is an `@Model` class containing a `timestamp: Date`.
- `igotu/Assets.xcassets` contains the generated app icon and accent-color catalogs. The Xcode project uses filesystem-synchronized groups, so Swift files added under the app or test directories are picked up by the project automatically.

### Test targets

- `igotuTests` uses Swift Testing (`import Testing`) and imports the app with `@testable import igotu`.
- `igotuUITests` uses XCTest/XCUIAutomation and launches the `igotu` application. The current files are Xcode-generated examples, including a launch screenshot and a launch-performance test.
- Both test targets depend on the app target through the Xcode scheme; run them through `xcodebuild ... test` rather than invoking Swift Package Manager commands.

### Intended product boundary

When implementing the wellness product, use the product document's conceptual separation as the starting boundary:

```text
SwiftUI views
    -> view models / presentation state
    -> reminder engine
       -> active-context resolution
       -> behavior rules and frequency
       -> activity state
       -> notification scheduling
    -> SwiftData persistence and iOS system services
```

The product document names the planned concepts `ContextManager`, `Behavior`, `ReminderRule`, `ReminderEngine`, an activity monitor, and a notification scheduler. Keep the engine responsible for the decision “should I remind the user right now?” and keep platform concerns such as HealthKit and notifications behind dedicated boundaries. Do not treat the architecture diagram as evidence that those types already exist.

### UI direction

New UI should follow the Ambient Calm specification in `DESIGN.md`: native SwiftUI, dynamic light/dark colors, material-backed cards, restrained context-specific accents, and calm transitions/haptics. The product document's home screen is intended to answer “What should I do right now?” rather than present a dense health dashboard.

## Repository conventions

- Keep app code in `igotu/`, unit tests in `igotuTests/`, and UI tests in `igotuUITests/`; the synchronized Xcode groups make the directory location part of target membership.
- Preserve SwiftUI previews with in-memory model containers so previews do not write to the persistent store.
- Keep persistence changes aligned between the SwiftData model declarations and the `ModelContainer` schema in `igotuApp.swift`.
- The repository has no `README.md`, `CLAUDE.md`, `AGENTS.md`, Cursor rules, or Copilot instructions to merge into this guidance.

## External-agent configuration

No repository-local Codex or Gemini configuration was found. If you use Codex or Gemini configuration at the user level and want it imported, reply `/import` to scan and list importable MCP servers, slash commands, subagents, skills, and instructions; then run `/import --yes=<digest>` with the digest shown by the scan. If `/import` is unavailable on this surface, run `claude import` from a terminal.
