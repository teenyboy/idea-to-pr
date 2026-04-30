# PR Review Scope: Local Project

**Title**: Apple Watch HRV Monitoring App
**URL**: N/A (local project, no remote)
**Branch**: `feature/apple-watch-hrv-monitor`
**Date**: 2026-04-30T23:00

---

## Pre-Review Status

| Check | Status | Notes |
|-------|--------|-------|
| Size | ⚠️ Large | 29 files, 2091 lines |

---

## Changed Files

| File | Type |
|------|------|
| `Shared/Models/HrvReading.swift` | source - model |
| `Shared/Models/HealthKitTypes.swift` | source - model |
| `Shared/Services/HealthKitManager.swift` | source - service |
| `Shared/Services/RMSSDCalculator.swift` | source - service |
| `Shared/Services/DataStore.swift` | source - service |
| `Shared/Services/WatchConnectivityManager.swift` | source - service |
| `WatchApp/Services/BackgroundMonitor.swift` | source - service |
| `WatchApp/Services/ActiveSessionManager.swift` | source - service |
| `WatchApp/ViewModels/DashboardViewModel.swift` | source - viewmodel |
| `WatchApp/ViewModels/SessionViewModel.swift` | source - viewmodel |
| `WatchApp/Views/DashboardView.swift` | source - view |
| `WatchApp/Views/SessionView.swift` | source - view |
| `WatchApp/Views/HistoryView.swift` | source - view |
| `WatchApp/Complication/HrvComplication.swift` | source - complication |
| `WatchApp/HrvWatchApp.swift` | source - entry |
| `iOSApp/ViewModels/DashboardViewModel.swift` | source - viewmodel |
| `iOSApp/Views/DashboardView.swift` | source - view |
| `iOSApp/Views/ChartsView.swift` | source - view |
| `iOSApp/Views/ExportView.swift` | source - view |
| `iOSApp/HrvApp.swift` | source - entry |
| `project.yml` | config |
| `Tests/RMSSDCalculatorTests.swift` | test |
| `Tests/DataStoreTests.swift` | test |
| `Tests/HealthKitManagerTests.swift` | test |

**Total**: 24 source files, 3 test files, 1 config file, 1 .gitignore

---

## File Categories

### Source Files (20)
- Models (2), Services (6), ViewModels (4), Views (7), App entries (2), Complication (1)

### Service Files
- `HealthKitManager.swift` — HealthKit authorization and queries
- `RMSSDCalculator.swift` — IBI extraction + RMSSD calculation
- `DataStore.swift` — SwiftData CRUD + aggregation
- `WatchConnectivityManager.swift` — iPhone-Watch sync
- `BackgroundMonitor.swift` — Background HKObserverQuery
- `ActiveSessionManager.swift` — HKWorkoutSession manager

### Test Files (3)
- `RMSSDCalculatorTests.swift` — Algorithm correctness
- `DataStoreTests.swift` — CRUD + aggregation
- `HealthKitManagerTests.swift` — Auth flow + type validation

### Configuration (1)
- `project.yml` — XcodeGen project spec

---

## Review Focus Areas

1. **HealthKit Integration**: Proper use of HKObserverQuery, HKAnchoredObjectQuery, background delivery
2. **RMSSD Algorithm**: Mathematical correctness, edge cases (insufficient IBIs)
3. **Error Handling**: HealthKit unavailable, authorization denied, background watchdog timeout
4. **MVVM Architecture**: Proper separation of concerns, data flow
5. **Test Coverage**: Edge cases covered (empty data, insufficient IBIs, auth failures)
6. **SwiftUI Patterns**: @Observable usage, proper data binding
7. **watchOS Specifics**: Complication timeline, background task limits

---

## Workflow Context

### Scope Limits (NOT Building)

**CRITICAL FOR REVIEWERS**: These items are **intentionally excluded** from scope. Do NOT flag them as bugs or missing features.

**IN SCOPE:**
- SDNN background monitoring via HKObserverQuery
- RMSSD calculation via HKHeartbeatSeriesQuery
- Active monitoring sessions via HKWorkoutSession
- SwiftData local storage
- WatchConnectivity sync to iPhone
- watchOS complication
- iOS companion app with charts and CSV export

**OUT OF SCOPE (do not touch):**
- Third-party Bluetooth HR monitor support (v1 only uses Apple Watch built-in sensor)
- iCloud sync (local WatchConnectivity only)
- AI analysis / anomaly detection (v2 feature)
- Complex notifications / alerts (v2 feature)
- Breathing guidance (not core to HRV monitoring)

### Implementation Deviations

- **No xcodebuild**: Xcode.app not available on dev machine, code written to compile with Xcode 16+
- **XcodeGen project.yml**: Instead of .xcodeproj (cannot generate from CLI)
- **Shared directory as filesystem group**: Not Xcode groups

---

## Metadata

- **Scope created**: 2026-04-30T23:00
- **Artifact path**: `.claude/skills/idea-to-pr/artifacts/review/`
