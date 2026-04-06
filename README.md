# Runboard for iOS

Runboard turns every weekly run into a head-to-head competition with the people you actually care about beating. Create a board, share a code, and watch the leaderboard come alive — powered by the runs you're already tracking in Apple Health.

## How it works

1. Create a board and get a 6-character invite code.
2. Share the code with friends.
3. Each member's running data syncs from Apple Health automatically.
4. A live leaderboard ranks everyone by weekly kilometers or VO2 Max.

All data flows through Apple CloudKit (public database) and Apple HealthKit. There is no custom backend.

## Features

- **Weekly leaderboard** ranked by distance (km) or VO2 Max, with pull-to-refresh
- **Board management** -- create, join via code, leave, or remove members (creator only)
- **Historical stats chart** -- line graph of weekly snapshots across all members
- **Home screen widgets** -- small (top 3), medium (top 5), and large (top 8) sizes, configurable between distance and VO2 Max
- **Offline support** -- cached member data via App Groups shared between app and widget

## Tech stack

| Layer | Technology |
|---|---|
| Language | Swift |
| UI | SwiftUI |
| Backend | Apple CloudKit (public database) |
| Health data | Apple HealthKit |
| Widgets | WidgetKit + AppIntents |
| Charts | Swift Charts |
| Min. target | iOS 17 |

No third-party dependencies.

## Project structure

```
runboard/
  runboard/                  # Main app
    runboardApp.swift        # Entry point
    AppState.swift           # Observable state
    ContentView.swift        # Root view / onboarding gate
    DashboardView.swift      # Leaderboard UI
    BoardSetupView.swift     # Create / join board
    CloudKitManager.swift    # CloudKit read/write
    HealthKitManager.swift   # HealthKit queries
    StatsGraphView.swift     # Historical line chart
    Theme.swift              # Colors, fonts, design tokens
    Shared/
      SharedModels.swift     # BoardMember, WeeklySnapshot
      SharedDataStore.swift  # UserDefaults (App Groups)
  RunboardWidget/            # Widget extension
    RunboardWidget.swift     # Widget config & entry
    WidgetViews.swift        # Small / Medium / Large layouts
    RunboardTimelineProvider.swift
    RunboardWidgetIntent.swift
scripts/
  logo-converter/            # Python icon generation
GeistPixel/                  # Custom pixel font (GeistPixel-Circle)
```

## Building

**Requirements:** Xcode 15.3+, Apple Developer account (for CloudKit and HealthKit entitlements).

```bash
git clone https://github.com/PaulGoldschmidt/runboard.git
open runboard/runboard.xcodeproj
```

1. Select the `runboard` scheme.
2. Enable the CloudKit and HealthKit capabilities under Signing & Capabilities.
3. Build and run on a physical device (HealthKit data is unavailable in the simulator).

The CloudKit container ID is `iCloud.p3g3.runboard` and the App Group is `group.p3g3.runboard`, both referenced in `SharedDataStore.swift`.

## Data model

Two CloudKit record types:

- **Board** -- board code, creator name, list of member record IDs
- **BoardMember** -- display name, weekly kilometers, VO2 Max, last updated timestamp, stats history (weekly snapshots)

Locally, board state is cached in `UserDefaults` (via App Groups) so the widget can read it without a network call.

## License

MIT -- see [LICENSE](LICENSE).
