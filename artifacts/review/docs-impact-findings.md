# Documentation Impact Findings: Apple Watch HRV Monitoring App

**Reviewer**: docs-impact-agent
**Date**: 2026-04-30
**Branch**: feature/apple-watch-hrv-monitor

---

## Summary

**Verdict: DOCUMENTATION IS NEEDED.** The project has zero documentation files (no CLAUDE.md, no README.md, no Makefile, no setup scripts) despite being a non-trivial 24-file, dual-target (iOS + watchOS) Swift project with 2019 lines of code. It relies on XcodeGen for project generation and HealthKit/WatchConnectivity for its core functionality. Three distinct documentation gaps are identified, with suggested content provided below.

---

## Project Statistics

| Metric | Value |
|--------|-------|
| Source files | 20 Swift, 1 project.yml |
| Test files | 3 XCTest files |
| Total lines | 2019 |
| Documentation files (CLAUDE.md, README.md, etc.) | **0** |
| Targets | 2 (iOS app + watchOS app) |
| Shared code directory | `Shared/` (compiled into both targets) |
| External tool dependency | XcodeGen (required to generate .xcodeproj from project.yml) |
| Min OS targets | iOS 18.0, watchOS 11.0 |
| Swift version | 6.0 |

---

## Finding 1: Missing CLAUDE.md

**Severity**: HIGH
**Category**: missing-docs
**Document**: CLAUDE.md (to be created)

### Issue

The project introduces a complete codebase with defined architectural conventions, shared code patterns, and build prerequisites. A CLAUDE.md is needed to document:
- Directory layout and the role of each directory
- MVVM + Service pattern conventions used across all files
- SwiftData @Model / @ModelActor usage patterns
- Build prerequisites (XcodeGen, Xcode 16+, iOS 18.0 / watchOS 11.0)
- How the shared directory maps to both targets
- Code conventions (rounding to 1 decimal, error handling pattern)
- Data flow from HealthKit through to UI

### Suggested Content

```markdown
# HRV Monitor - Apple Watch HRV Tracking App

## Project Structure

```
project.yml              # XcodeGen project spec (source of truth)
Shared/                  # Shared code compiled into both targets
  Models/
    HrvReading.swift       # SwiftData @Model for HRV readings
    HealthKitTypes.swift   # HealthKit type definitions
  Services/
    HealthKitManager.swift # HKHealthStore auth + queries
    RMSSDCalculator.swift  # IBI extraction + RMSSD algorithm
    DataStore.swift        # SwiftData CRUD via @ModelActor
    WatchConnectivityManager.swift  # iPhone-Watch sync via WCSession
iOSApp/                  # iOS companion app target
  HrvApp.swift            # Entry point, TabView (Dashboard, Charts, Export)
  ViewModels/
    DashboardViewModel.swift  # Aggregation + sync state
  Views/
    DashboardView.swift       # Today card, trend, 7-day chart
    ChartsView.swift          # Full chart view with time range picker
    ExportView.swift          # CSV export + data management
WatchApp/                # watchOS app target
  HrvWatchApp.swift         # Entry point, background monitor init
  Services/
    BackgroundMonitor.swift  # HKObserverQuery for background SDNN collection
    ActiveSessionManager.swift  # HKWorkoutSession for live RMSSD monitoring
  ViewModels/
    DashboardViewModel.swift   # Watch dashboard state
    SessionViewModel.swift     # Active session state
  Views/
    DashboardView.swift    # Watch home: HRV card, trend, navigation
    SessionView.swift      # Live monitoring UI
    HistoryView.swift      # Historical readings list
  Complication/
    HrvComplication.swift  # ClockKit complication timeline
Tests/                   # XCTest test suite
```

## Build Prerequisites

- Xcode 16+
- XcodeGen (`brew install xcodegen`)
- iOS 18.0+ / watchOS 11.0+
- Swift 6.0

## Build Steps

```bash
xcodegen generate   # Produces Hrv.xcodeproj from project.yml
open Hrv.xcodeproj  # Or: xcodebuild
```

## Architecture & Conventions

### MVVM + Service Layer

- **Models** use `@Model` (SwiftData). Enums conforming to `String, Codable` for persistence.
- **Services** are `@Observable` classes (HealthKitManager, WatchConnectivityManager) or stateless structs (RMSSDCalculator). DataStore uses `@ModelActor` for thread-safe SwiftData access.
- **ViewModels** are `@Observable` classes injected into Views via `@State` initializer pattern.
- **Views** are SwiftUI structs with `@State private var viewModel`.

### Key Patterns

- **Rounding**: All HRV values are rounded to 1 decimal place: `(value * 10).rounded() / 10`
- **Error handling**: Custom `LocalizedError` enums per service domain (HealthKitError, WatchConnectivityError)
- **Concurrency**: `async/await` for HealthKit auth and data store operations; callback-based for HK queries
- **Background monitoring**: HKObserverQuery + HKAnchoredObjectQuery with anchor persisted to UserDefaults
- **Active sessions**: HKWorkoutSession + HKHeartbeatSeriesQuery for live RMSSD extraction

### Data Flow

```
HealthKit (HKObserverQuery / HKWorkoutSession)
  -> Service Layer (HealthKitManager, BackgroundMonitor, ActiveSessionManager)
    -> SwiftData (DataStore via @ModelActor)
      -> WatchConnectivityManager (watch -> iPhone transfer)
        -> ViewModels
          -> SwiftUI Views
```

## Out of Scope (v1)

- Third-party Bluetooth HR monitors
- iCloud sync
- AI anomaly detection
- Complex notifications / alerts
- Breathing guidance
```

---

## Finding 2: Missing README

**Severity**: HIGH
**Category**: missing-docs
**Document**: README.md (to be created)

### Issue

This is a new project with no remote repository page to describe the app. Anyone discovering the project needs to know what the app does, how to build it, and what its prerequisites are. A README serves as the front door for contributors and users.

### Suggested Content

```markdown
# HRV Monitor

Heart rate variability (HRV) monitoring app for Apple Watch with an iOS companion app.

## Features

- **Background HRV monitoring** on Apple Watch via HKObserverQuery (SDNN collection)
- **Active monitoring sessions** via HKWorkoutSession with live RMSSD calculation
- **watchOS complication** showing current SDNN and trend direction
- **iOS companion app** with charts, daily/weekly/monthly aggregation, and CSV export
- **Watch-to-iPhone sync** via WatchConnectivity
- **Local storage** via SwiftData

## Requirements

- Xcode 16+
- XcodeGen (`brew install xcodegen`)
- iOS 18.0+ device (simulator has limited HealthKit support)
- watchOS 11.0+ paired Apple Watch

## Setup

```bash
git clone <repo-url>
cd ios_hrv
xcodegen generate
open Hrv.xcodeproj
```

Select the `HrvWatch` target, pair with your Apple Watch, and run. Grant HealthKit permissions when prompted.

## Architecture

The app uses MVVM with a service layer. Shared code (models, services) lives in `Shared/` and is compiled into both the iOS and watchOS targets. See CLAUDE.md for full architecture documentation.

## Testing

Open the project in Xcode and run tests (Cmd+U) for the `HrvWatch` scheme, or use:

```bash
xcodebuild test -scheme HrvWatch -destination 'platform=watchOS Simulator,name=Apple Watch Ultra 2 (49mm)'
```

## Project Generation

This project uses XcodeGen (project.yml) instead of a checked-in .xcodeproj. The .xcodeproj is gitignored. Always run `xcodegen generate` after cloning or pulling changes to project.yml.

## License

Proprietary.
```

---

## Finding 3: Missing Build / Setup Automation

**Severity**: MEDIUM
**Category**: missing-setup
**Document**: Makefile (optional, to be created)

### Issue

The project depends on XcodeGen, which must be installed separately. There is no Makefile or script to automate the generation step. While this is documented in Findings 1 and 2, a Makefile would reduce friction for repeated use.

### Suggested Content

```makefile
.PHONY: generate open test

generate:
	xcodegen generate

open: generate
	open Hrv.xcodeproj

test: generate
	xcodebuild test -scheme HrvWatch -destination 'platform=watchOS Simulator,name=Apple Watch Ultra 2 (49mm)'
```

---

## Finding 4: Architecture Patterns Not Documented

**Severity**: MEDIUM
**Category**: missing-architecture-docs
**Document**: CLAUDE.md (covered in Finding 1)

### Issue

The project has several architectural decisions worth documenting:
1. MVVM pattern with @Observable ViewModels and dependency injection via initializers
2. @ModelActor for thread-safe SwiftData access (an unusual but correct pattern)
3. The dual-role of Shared/ directory (filesystem group compiled into both targets)
4. Custom rounded-to-1-decimal convention for all HRV values
5. Error handling pattern using LocalizedError enums per service domain
6. Dual monitoring modes (background observer vs. active workout session)

The CLAUDE.md content suggested in Finding 1 comprehensively addresses this, covering architecture, conventions, data flow, and key patterns. No separate architecture document is needed.

---

## Finding 5: XcodeGen Dependency Undocumented Elsewhere

**Severity**: LOW
**Category**: missing-setup-info
**Document**: CLAUDE.md + README.md (covered in Findings 1 and 2)

### Issue

The project uses XcodeGen (project.yml) instead of a checked-in .xcodeproj. The .gitignore already excludes `*.xcodeproj/` and `*.xcodegen/`. However, nothing in the repository tells a new contributor to run `xcodegen generate` before opening the project. This is indirectly addressed in the CLAUDE.md and README.md content above.

---

## Statistics

| Severity | Count | Documents Affected |
|----------|-------|--------------------|
| CRITICAL | 0 | - |
| HIGH | 2 | CLAUDE.md, README.md |
| MEDIUM | 2 | Makefile (optional), architecture docs (covered by CLAUDE.md) |
| LOW | 1 | Setup info (covered by README/CLAUDE.md) |

## Priority Action Items

| Priority | Action | Files to Create |
|----------|--------|-----------------|
| **P0** | Create CLAUDE.md with project structure, conventions, build steps, and architecture | `CLAUDE.md` |
| **P0** | Create README.md with project description, features, and setup guide | `README.md` |
| **P1** | Consider adding Makefile for common tasks | `Makefile` (optional) |

Creating CLAUDE.md and README.md closes all four review focus areas (CLAUDE.md impact, README impact, setup instructions, architecture documentation) with two files.
