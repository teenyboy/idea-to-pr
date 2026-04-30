# Test Coverage Findings: Apple Watch HRV Monitoring App

**Reviewer**: test-coverage-agent
**Date**: 2026-04-30
**Branch**: `feature/apple-watch-hrv-monitor`
**Source files**: 20
**Test files**: 3

---

## Summary

| Metric | Value |
|--------|-------|
| Source files | 20 |
| Test files | 3 |
| Files with any test coverage | 4 (20%) |
| Files with **zero** test coverage | 16 (80%) |
| Test-to-source ratio (by line) | ~7.8% |

**Verdict**: CRITICAL coverage gap. Only 4 of 20 source files receive any test coverage. Three of the most complex service classes (`BackgroundMonitor`, `ActiveSessionManager`, `WatchConnectivityManager`) have zero tests. All 3 ViewModels are untested. The existing `DataStoreTests` file has a fatal initialization defect (nil actor reference). The `RMSSDCalculator.extractIBIs` function, which interfaces with real HealthKit queries, is untested.

---

## Coverage Map

| Source File | Lines | Test File | Coverage Scope | Status |
|---|---|---|---|---|
| `Shared/Models/HrvReading.swift` | 37 | -- | Model instantiation (indirect via DataStoreTests) | INDIRECT ONLY |
| `Shared/Models/HealthKitTypes.swift` | 27 | `HealthKitManagerTests.swift` | Type identifiers, `all` set membership | COVERED |
| `Shared/Services/HealthKitManager.swift` | 104 | `HealthKitManagerTests.swift` | Auth flow only (minimal); query methods untested | MINIMAL |
| `Shared/Services/RMSSDCalculator.swift` | 55 | `RMSSDCalculatorTests.swift` | `calculate()` tested; `extractIBIs()` untested | PARTIAL |
| `Shared/Services/DataStore.swift` | 96 | `DataStoreTests.swift` | CRUD partial; `deleteAll`, `weeklyAverage`, `monthlyAverage` untested | PARTIAL |
| `Shared/Services/WatchConnectivityManager.swift` | 98 | -- | -- | **ZERO** |
| `WatchApp/Services/BackgroundMonitor.swift` | 85 | -- | -- | **ZERO** |
| `WatchApp/Services/ActiveSessionManager.swift` | 205 | -- | -- | **ZERO** |
| `WatchApp/ViewModels/DashboardViewModel.swift` | 59 | -- | -- | **ZERO** |
| `WatchApp/ViewModels/SessionViewModel.swift` | 39 | -- | -- | **ZERO** |
| `iOSApp/ViewModels/DashboardViewModel.swift` | 63 | -- | -- | **ZERO** |
| `WatchApp/Views/DashboardView.swift` | 131 | -- | -- | ZERO (view) |
| `WatchApp/Views/SessionView.swift` | 82 | -- | -- | ZERO (view) |
| `WatchApp/Views/HistoryView.swift` | 47 | -- | -- | ZERO (view) |
| `iOSApp/Views/DashboardView.swift` | 213 | -- | -- | ZERO (view) |
| `iOSApp/Views/ChartsView.swift` | 140 | -- | -- | ZERO (view) |
| `iOSApp/Views/ExportView.swift` | 129 | -- | -- | ZERO (view) |
| `WatchApp/Complication/HrvComplication.swift` | 68 | -- | -- | ZERO (view) |
| `WatchApp/HrvWatchApp.swift` | 36 | -- | -- | ZERO (entry) |
| `iOSApp/HrvApp.swift` | 40 | -- | -- | ZERO (entry) |

**Adjusted for business logic** (excluding views, complications, app entries): 11 logic files, 4 with some coverage (36%), 7 completely untested (64%).

---

## Critical Gaps

### GAP-1: RMSSDCalculator.extractIBIs() Untested [CRITICAL]

**File**: `Shared/Services/RMSSDCalculator.swift` (lines 30-54)
**Severity**: CRITICAL
**Location**: `extractIBIs(from:healthStore:completion:)`
**Criticality Score**: 9/10

**Issue**: The `extractIBIs` function executes an `HKHeartbeatSeriesQuery` against HealthKit and transforms raw time-point data into IBI values (seconds to milliseconds, adjacent-difference). It branches on `precededByGap` and `done` flags. A bug in this function silently produces corrupted RMSSD values because the output feeds directly into `RMSSDCalculator.calculate()`. The `calculate()` function IS tested, but the HealthKit query that produces its input is NOT.

**Untested Code Paths**:
- Time point accumulation when `!precededByGap`
- Time point exclusion when `precededByGap` is true
- IBI computation at `done = true`
- Millisecond conversion: `(timePoints[i] - timePoints[i-1]) * 1000`
- Empty time points array after filtering all gaps

**Why This Matters**: This is the raw sensor data pipeline. Any error in IBI extraction — wrong subtraction order, incorrect unit conversion, gap mishandling — produces invalid RMSSD values that look plausible. The test that validates `calculate()` with hardcoded IBIs will pass, but the real pipeline will produce wrong results.

---

### GAP-2: WatchConnectivityManager Completely Untested [CRITICAL]

**File**: `Shared/Services/WatchConnectivityManager.swift` (98 lines)
**Severity**: CRITICAL
**Location**: Entire file
**Criticality Score**: 9/10

**Issue**: The entire iPhone-Apple Watch communication layer is untested. `WCSession` is a singleton that requires a real paired device, so all 98 lines of code are unreachable in normal test environments. No mock/protocol abstraction exists.

**Untested Code**:
| Method | Lines | What It Does |
|--------|-------|-------------|
| `activate()` | 4 | guards on `isSupported()`, sets delegate, calls `activate()` |
| `sendHrvReading(_:)` | 17 | encodes 6+ fields into dictionary, calls `transferUserInfo` |
| `sendComplicationUpdate(_:)` | 7 | encodes 3 fields, calls `transferCurrentComplicationUserInfo` |
| `session(_:activationDidCompleteWith:error:)` | 7 | two branches: error vs. success |
| `sessionReachabilityDidChange(_:)` | 3 | updates `isReachable` and `isPaired` |
| `sessionDidBecomeInactive` / `sessionDidDeactivate` | 4 | iOS-only lifecycle |

**Why This Matters**: If encoding or session state is wrong, HRV data never reaches the iPhone companion app. The user sees no data on their phone with no error indication.

---

### GAP-3: BackgroundMonitor Completely Untested [CRITICAL]

**File**: `WatchApp/Services/BackgroundMonitor.swift` (85 lines)
**Severity**: CRITICAL
**Location**: Entire file
**Criticality Score**: 8/10

**Issue**: The entire background monitoring engine is untested. It manages `HKObserverQuery`, `HKAnchoredObjectQuery`, anchor persistence via `UserDefaults`, and async `DataStore` saves.

**Untested Code**:
| Method | Lines | Branching Logic |
|--------|-------|----------------|
| `startMonitoring()` | 14 | guard against double-start, query creation, background delivery Task |
| `stopMonitoring()` | 5 | guard nil query, stop, nil assignment |
| `handleNewData()` | 29 | anchored query error guard, sample cast, nil/empty check, async save loop, `lastUpdateDate` update |
| `loadAnchor()` | 3 | UserDefaults nil guard, unarchive |
| `saveAnchor()` | 3 | anchor nil guard, archive, UserDefaults set |

**Why This Matters**: If the background monitor fails silently — observer query not registered, anchor not persisted, samples not converted correctly — the app collects no background HRV data. The user sees an empty dashboard with no error.

---

### GAP-4: ActiveSessionManager Completely Untested [HIGH]

**File**: `WatchApp/Services/ActiveSessionManager.swift` (205 lines)
**Severity**: HIGH
**Location**: Entire file
**Criticality Score**: 8/10

**Issue**: This is the largest and most complex file in the project (205 lines). It manages a state machine (`idle` -> `preparing` -> `active` -> `finished`/`failed`), `HKWorkoutSession`, `HKLiveWorkoutBuilder`, `HKHeartbeatSeriesQuery`, timer management, IBI accumulation, and RMSSD computation. It has zero tests.

**Untested Code Paths**:
| Method | Lines | Key Logic |
|--------|-------|-----------|
| `startSession()` | 30 | state guard, `HKWorkoutSession` creation, builder setup, `beginCollection` |
| `stopSession()` | 13 | state guard, heartbeat cleanup, `end()`, timer invalidation, `endCollection` |
| `startHeartbeatMonitoring()` | 12 | `HKSampleQuery` for heartbeat series |
| `queryHeartbeatSeries(_:)` | 37 | `HKHeartbeatSeriesQuery` callback, IBI calc, RMSSD calc, DataStore save, recursive monitoring |
| `calculateIBIs(from:)` | 8 | time-point to IBI conversion |
| `startTimer()` | 4 | 1-second repeating timer with weak self |
| `workoutSession(_:didChangeTo:from:date:)` | 11 | state transitions to `.active` or `.finished` |
| `workoutSession(_:didFailWithError:)` | 2 | failure state |
| `workoutBuilder(_:didCollectDataOf:)` | 9 | heart rate extraction from `HKStatistics` |

**Why This Matters**: A state-machine bug could leave the session stuck in `.preparing` and the user never sees the active monitoring screen. Or a memory leak from the timer (weak self not working correctly) could cause continuous UI updates after session ends.

---

### GAP-5: DataStore Missing Aggregate + DeleteAll Tests [HIGH]

**File**: `Shared/Services/DataStore.swift` / `Tests/DataStoreTests.swift`
**Severity**: HIGH
**Criticality Score**: 7/10

**Issue**: The DataStoreTests file has a fatal defect: `var dataStore: DataStore!` is never initialized in `setUp()` — there is only a comment placeholder. All test methods that call `await dataStore.save(...)` will crash at runtime due to force-unwrap of nil.

Beyond the initialization defect, these methods are untested:
- `deleteAll()` — batch delete + save
- `weeklyAverage(for:)` — calendar date math, edge case where `date(from:)` returns nil
- `monthlyAverage(for:)` — calendar date math, edge case where `date(byAdding:)` returns nil
- `dailyAverage(for:)` — partial (covered once but not edge cases)
- `aggregate(_:)` — private method tested indirectly in some paths, but no coverage of empty RMSSD values or rounding

**Missing Edge Cases**:
- Fetch from empty store
- `fetchRecent(limit: 0)` returns empty or all
- Weekly boundary: reading at exact week boundary should be included
- Monthly boundary: reading at month boundary
- Aggregation with mixed RMSSD present/absent
- `dailyAverage` when `date(byAdding:)` returns nil (should return nil, not crash)

---

### GAP-6: All ViewModels Untested [HIGH]

**Files**:
- `WatchApp/ViewModels/DashboardViewModel.swift` (59 lines)
- `WatchApp/ViewModels/SessionViewModel.swift` (39 lines)
- `iOSApp/ViewModels/DashboardViewModel.swift` (63 lines)

**Severity**: HIGH
**Criticality Score**: 6/10

**Issue**: The three ViewModels orchestrate data flow between services and views. They contain branching logic, trend calculations, and state mapping that are exercised every time a screen loads.

**Watch DashboardViewModel**:
- `loadData()` — fetches latest HRV via closure callback, fetches daily+weekly aggregates, computes weekly trend percentage
- Branch: `fetchLatestHrv` result handling (only `.success` with non-nil sample)
- Branch: empty readings returns early
- Branch: nil `thisWeekStart` or `lastWeekStart` skips trend

**SessionViewModel**:
- `startSession()` / `stopSession()` — delegation
- `refreshState()` — maps 4+ properties, formats elapsed time string
- Formatting: `elapsedSeconds` to `MM:SS` via integer division

**iOS DashboardViewModel**:
- `loadData()` — fetches daily, weekly, monthly aggregates; weekly trend
- `dailyAggregations(forLastDays:)` — generates array of 7 `(date, sdnn, rmssd)` tuples
- `connectWatch()` — activates session, sets `isSyncing = true` with async reset

---

### GAP-7: HealthKitManager Query Methods Untested [MEDIUM]

**File**: `Shared/Services/HealthKitManager.swift` (lines 60-103)
**Severity**: MEDIUM
**Criticality Score**: 5/10

**Issue**: Only the auth flow (`requestAuthorization`) is exercised (minimally, with a timeout-based expectation that does not assert any post-condition). The HealthKit type validation tests in `HealthKitManagerTests` cover `HealthKitTypes` (a separate model file) rather than `HealthKitManager` itself.

**Untested Methods**:
- `fetchLatestHrv(completion:)` — `HKSampleQuery` creation, error vs. success paths, nil vs. valid sample handling
- `fetchHrvSamples(from:)` — `HKAnchoredObjectQuery` creation, update handler
- `createObserverQuery(for:handler:)` — query init, error guard in handler
- `enableBackgroundDelivery(for:frequency:)` — async throw, error propagation

---

## Test Suggestions

### Suggestion 1: RMSSDCalculator.extractIBIs Unit Test

```swift
// Tests/ExtractIBIsTests.swift
final class ExtractIBIsTests: XCTestCase {
    func testExtractIBIs_withNormalHeartbeats() {
        let mockStore = MockHKHealthStore()
        mockStore.stubHeartbeatSeriesBehavior = { handler in
            // Simulate 4 heartbeats at 0.8s intervals
            // timeSinceSeriesStart: 0.0, 0.8, 1.6, 2.4
            handler(nil, 0.0, false, false, nil)
            handler(nil, 0.8, false, false, nil)
            handler(nil, 1.6, false, false, nil)
            handler(nil, 2.4, false, true, nil)  // done=true
        }

        let exp = expectation(description: "extractIBIs completes")
        RMSSDCalculator.extractIBIs(from: mockSample, healthStore: mockStore) { ibis in
            XCTAssertEqual(ibis, [800, 800, 800]) // all 800ms intervals
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }

    func testExtractIBIs_skipsPrecededByGap() {
        // Same setup, but second heartbeat has precededByGap=true
        // handler(nil, 0.0, false, false, nil)
        // handler(nil, 0.9, true, false, nil)  // gap, skip this
        // handler(nil, 1.8, false, false, nil)
        // handler(nil, 2.7, false, true, nil)
        // Expected IBIs: [1800] (0.0 position + gap-skipped -> 1.8 interval)
    }

    func testExtractIBIs_withSingleBeat_returnsEmpty() {
        // Only one time point delivered, then done=true
        // Expected: [] (need at least 2 points for 1 IBI)
    }
}
```

### Suggestion 2: DataStore Tests (Fix + Expand)

```swift
// Fix: initialize in-memory store in setUp
override func setUp() {
    super.setUp()
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: HrvReading.self, configurations: config)
    dataStore = DataStore(modelContainer: container)
}

func testDeleteAll_removesAllReadings() async {
    await dataStore.save(HrvReading(timestamp: Date(), sdnnMs: 40, source: .background))
    await dataStore.save(HrvReading(timestamp: Date(), sdnnMs: 50, source: .background))
    await dataStore.deleteAll()
    let recent = await dataStore.fetchRecent(limit: 100)
    XCTAssertTrue(recent.isEmpty)
}

func testWeeklyAverage_excludesReadingsOutsideWeek() async {
    let calendar = Calendar.current
    let thisWeek = Date()
    let lastWeek = calendar.date(byAdding: .day, value: -10, to: thisWeek)!

    await dataStore.save(HrvReading(timestamp: thisWeek, sdnnMs: 50, source: .background))
    await dataStore.save(HrvReading(timestamp: lastWeek, sdnnMs: 30, source: .background))

    let avg = await dataStore.weeklyAverage(for: thisWeek)
    XCTAssertNotNil(avg)
    XCTAssertEqual(avg!.sampleCount, 1)
    XCTAssertEqual(avg!.averageSdnn, 50.0)
}

func testMonthlyAverage_withNoData_returnsNil() async {
    let distant = Date.distantPast
    let result = await dataStore.monthlyAverage(for: distant)
    XCTAssertNil(result)
}

func testDailyAverage_calendarBoundary() async {
    // Save reading at 23:59:59 and another at 00:00:01 next day
    // Verify only today's reading is included
}
```

### Suggestion 3: BackgroundMonitor Test (Protocol-Based)

```swift
// Requires making BackgroundMonitor testable via protocol injection
func testBackgroundMonitor_startMonitoring_setsIsMonitoring() {
    let mockStore = MockHKHealthStore()
    let mockDataStore = MockDataStore()
    let monitor = BackgroundMonitor(healthStore: mockStore, dataStore: mockDataStore)

    monitor.startMonitoring()

    XCTAssertTrue(monitor.isMonitoring)
    XCTAssertTrue(mockStore.didCreateObserverQuery)
    XCTAssertTrue(mockStore.didExecuteQuery) // observer query executed
    XCTAssertTrue(mockStore.didCallEnableBackgroundDelivery)
}

func testBackgroundMonitor_handleNewData_savesReadings() async {
    let mockStore = MockHKHealthStore()
    let mockDataStore = MockDataStore()
    let monitor = BackgroundMonitor(healthStore: mockStore, dataStore: mockDataStore)

    // Stub anchored query results with 3 samples
    mockStore.stubAnchoredQueryResult = (samples: threeMockSamples, anchor: someAnchor)
    monitor.handleNewData()

    // Allow async Task to complete
    let samples = await mockDataStore.allSavedReadings
    XCTAssertEqual(samples.count, 3)
    XCTAssertNotNil(monitor.lastUpdateDate)
}

func testBackgroundMonitor_handleNewData_emptySamples_doesNotSave() async {
    let mockStore = MockHKHealthStore()
    let mockDataStore = MockDataStore()
    let monitor = BackgroundMonitor(healthStore: mockStore, dataStore: mockDataStore)

    mockStore.stubAnchoredQueryResult = (samples: [], anchor: nil)
    monitor.handleNewData()

    let samples = await mockDataStore.allSavedReadings
    XCTAssertTrue(samples.isEmpty)
    XCTAssertNil(monitor.lastUpdateDate)
}
```

### Suggestion 4: ActiveSessionManager State Machine Tests

```swift
func testStartSession_whenIdle_transitionsToPreparing() {
    let manager = makeManager()
    XCTAssertEqual(manager.state, .idle)
    manager.startSession()
    XCTAssertEqual(manager.state, .preparing)
}

func testStartSession_whenNotIdle_isNoop() {
    let manager = makeManager()
    manager.startSession() // transitions to .preparing
    manager.startSession() // second call should be no-op
    // Assert only 1 HKWorkoutSession was created
}

func testWorkoutSessionDelegate_running_setsActiveAndStartsTimer() {
    let manager = makeManager()
    manager.startSession()
    manager.workoutSession(mockSession, didChangeTo: .running, from: .preparing, date: Date())

    if case .active(let startedAt) = manager.state {
        XCTAssertEqual(startedAt.timeIntervalSince1970, Date().timeIntervalSince1970, accuracy: 1.0)
    } else {
        XCTFail("Expected .active state")
    }
}

func testStopSession_whenActive_transitionsToFinished() {
    let manager = makeManager()
    manager.startSession()
    manager.workoutSession(mockSession, didChangeTo: .running, from: .preparing, date: Date())
    manager.stopSession()
    XCTAssertEqual(manager.state, .finished)
}

func testCalculateIBIs_returnsCorrectMillisecondValues() {
    let manager = makeManager()
    let timePoints: [Double] = [0.0, 0.8, 1.6, 2.5]
    let ibis = manager.calculateIBIs(from: timePoints)
    XCTAssertEqual(ibis, [800, 800, 900])
}

func testSessionFailure_setsFailedState() {
    let manager = makeManager()
    let error = NSError(domain: "HK", code: -1)
    manager.workoutSession(mockSession, didFailWithError: error)
    XCTAssertEqual(manager.state, .failed(error))
}
```

### Suggestion 5: WatchConnectivityManager Mock-Based Tests

```swift
// Requires: protocol WCSessionProtocol { ... }
// And: WatchConnectivityManager(session: WCSessionProtocol)

func testActivate_whenNotSupported_setsError() {
    let mock = MockWCSession(isSupported: false)
    let manager = WatchConnectivityManager(session: mock)
    manager.activate()
    XCTAssertEqual(manager.lastError, .notAvailable)
}

func testSendHrvReading_whenNotActivated_setsError() {
    let mock = MockWCSession(activationState: .inactive, isSupported: true)
    let manager = WatchConnectivityManager(session: mock)
    manager.sendHrvReading(testReading)
    XCTAssertEqual(manager.lastError, .notActivated)
}

func testSendHrvReading_encodesAllFields() {
    let mock = MockWCSession(activationState: .activated, isSupported: true)
    let manager = WatchConnectivityManager(session: mock)
    manager.sendHrvReading(testReading)
    let data = mock.lastTransferUserInfo
    XCTAssertEqual(data?["sdnnMs"] as? Double, testReading.sdnnMs)
    XCTAssertEqual(data?["source"] as? String, testReading.source.rawValue)
    XCTAssertEqual(data?["id"] as? String, testReading.id.uuidString)
}

func testActivationDelegate_success_updatesProperties() {
    let mock = MockWCSession(activationState: .activated, isSupported: true, isPaired: true, isReachable: true)
    let manager = WatchConnectivityManager(session: mock)
    manager.session!(mock, activationDidCompleteWith: .activated, error: nil)
    XCTAssertTrue(manager.isPaired)
    XCTAssertTrue(manager.isReachable)
}
```

---

## Risk Assessment

| Risk Area | Failure Mode | User Impact | Likelihood | Severity |
|-----------|-------------|-------------|-----------|----------|
| IBI extraction bug (GAP-1) | Wrong IBI values from heartbeat query | Corrupted RMSSD displayed to user | Medium (complex query callbacks) | High |
| Watch data not synced (GAP-2) | Encoding error or session not activated | iPhone companion app shows no data | Medium (singleton timing issues) | High |
| Background monitor silent failure (GAP-3) | Observer query not registered, anchor lost | No background HRV data collected | Low-Medium (HK API edge cases) | Critical |
| Active session crash / stuck state (GAP-4) | State machine bug, timer leak | User cannot finish workout session | Medium (complex state machine) | High |
| War Stories data loss (GAP-5) | deleteAll + save fails silently | User cannot clear data | Medium | High |
| ViewModel crash on empty state (GAP-6) | force-unwrap or nil access on load | App crash on dashboard open | Medium | Medium |
| HK query never completes (GAP-7) | fetchLatestHrv handler not called | Dashboard shows "no data" forever | Low | Medium |

### Overall Risk: HIGH

The codebase has a high probability of undetected regressions in the three core HealthKit service classes (BackgroundMonitor, ActiveSessionManager, RMSSDCalculator.extractIBIs) that account for ~345 lines of sensor-interfacing code with zero test coverage. The WatchConnectivityManager (98 lines) is another untested singleton that blocks the entire iPhone sync pipeline.

---

## Statistics

```
┌──────────────────────────────────────────────────────────────────┐
│                     COVERAGE STATISTICS                          │
├────────────────────────────────────┬─────────────────────────────┤
│ Total source files                 │ 20                          │
│ Total test files                   │  3                          │
│ Source lines (approx.)             │ ~2,400                      │
│ Test lines (approx.)               │ ~186                        │
│ Test-to-source ratio               │  ~7.8%                      │
├────────────────────────────────────┼─────────────────────────────┤
│ Covered source files (any test)    │  4 (20%)                    │
│ Fully tested files                 │  0 (0%)                     │
│ Partially covered files            │  3 (15%)                    │
│ Zero-coverage files                │ 16 (80%)                    │
│ Zero-coverage business-logic files │  7 (64%)                    │
├────────────────────────────────────┼─────────────────────────────┤
│ Tested methods / total methods     │ ~12 / ~68 (approximate)     │
│ Method coverage (approx.)          │  ~18%                       │
├────────────────────────────────────┼─────────────────────────────┤
│ Existing test file defects         │  1 (nil DataStore ref)      │
│ Tests that crash at runtime        │  DataStoreTests (all tests) │
├────────────────────────────────────┼─────────────────────────────┤
│ Gaps found                         │  7                          │
│  - CRITICAL                        │  3                          │
│  - HIGH                            │  3                          │
│  - MEDIUM                          │  1                          │
└────────────────────────────────────┴─────────────────────────────┘
```

### Priority Order for Remediation

1. **Fix DataStoreTests** — Initialize `DataStore` in `setUp()` with in-memory `ModelContainer`
2. **Add extractIBIs tests** — Mock `HKHealthStore` to validate IBI extraction (CRITICAL)
3. **Add HealthKitManager query tests** — Validate `fetchLatestHrv`, `createObserverQuery` (MEDIUM)
4. **Add BackgroundMonitor tests** — Protocol-based mocking for `HKHealthStore` and `DataStore` (CRITICAL)
5. **Add ActiveSessionManager tests** — Protocol-based mocks for workout session (HIGH)
6. **Add WatchConnectivityManager tests** — `WCSessionProtocol` abstraction layer (CRITICAL)
7. **Add ViewModel tests** — Mock dependency injection for all 3 ViewModels (HIGH)
8. **Expand DataStore tests** — `deleteAll`, `weeklyAverage`, `monthlyAverage`, edge cases (HIGH)
