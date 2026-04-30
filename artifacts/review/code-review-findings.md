# Code Review: Apple Watch HRV Monitoring App

**Reviewer**: code-review-agent
**Date**: 2026-04-30
**Branch**: `feature/apple-watch-hrv-monitor`
**Files Reviewed**: 24 source files (Shared/, WatchApp/, iOSApp/, Tests/)

---

## Summary

The codebase implements a well-structured Apple Watch HRV monitoring app with background SDNN collection, active session RMSSD calculation, SwiftData persistence, WatchConnectivity sync, and an iOS companion app. The architecture follows MVVM with `@Observable` classes and Swift 6's `@ModelActor` for data access.

**Verdict**: REJECT -- contains 5 critical issues (compile errors, runtime crashes, logic bugs) that must be resolved before the code can function.

---

## Findings

### CRITICAL (5)

#### C1. `BackgroundMonitor` calls method on `HKHealthStore` that does not exist

**Location**: `/Users/xiaotongxie/Documents/project/ios_hrv/WatchApp/Services/BackgroundMonitor.swift`, line 25

**Issue**: `BackgroundMonitor` stores `healthStore: HKHealthStore` but calls `healthStore.createObserverQuery(for:handler:)`. The method `createObserverQuery(for:handler:)` is defined on `HealthKitManager`, not on `HKHealthStore`. This produces a compile error.

```swift
// Line 25 -- ERROR: HKHealthStore has no method createObserverQuery
let query = healthStore.createObserverQuery(for: hrvType) { [weak self] in
    self?.handleNewData()
}
```

**Fix**: Either accept a `HealthKitManager` in `BackgroundMonitor`, or create the `HKObserverQuery` directly:

```swift
// Fix: Create HKObserverQuery directly
func startMonitoring() {
    guard !isMonitoring else { return }
    let query = HKObserverQuery(sampleType: hrvType, predicate: nil) { [weak self] _, _, error in
        guard error == nil else { return }
        self?.handleNewData()
    }
    healthStore.execute(query)
    observerQuery = query
    isMonitoring = true
    Task {
        try? await healthStore.enableBackgroundDelivery(for: hrvType, frequency: .hourly)
    }
}
```

---

#### C2. `HKSeriesType` force-cast to `HKSampleType` crashes at runtime

**Location**: `/Users/xiaotongxie/Documents/project/ios_hrv/WatchApp/Services/ActiveSessionManager.swift`, line 100

**Issue**: `HKSeriesType.heartbeat()` returns `HKSeriesType`, which inherits from `HKObjectType`. `HKSampleType` is a **sibling** subclass of `HKObjectType`, not a superclass. The force-cast `as! HKSampleType` crashes because the types are unrelated in the class hierarchy. This is an unconditional runtime crash whenever a session is started.

```swift
sampleType: HealthKitTypes.heartbeatSeriesType as! HKSampleType,  // CRASH
```

**Fix**: `HKHeartbeatSeriesSample` cannot be queried via `HKSampleQuery`. The architecture needs to be reworked to collect heart rate data through the `HKLiveWorkoutBuilder` and then use `HKHeartbeatSeriesQuery` on the collected samples. Remove the `HKSampleQuery`-based polling entirely.

---

#### C3. Actor method called without `await` in synchronous function

**Location**: `/Users/xiaotongxie/Documents/project/ios_hrv/iOSApp/ViewModels/DashboardViewModel.swift`, line 49

**Issue**: `DataStore` is a `@ModelActor` actor. Calling `dataStore.dailyAverage(for: date)` requires `await`, but the enclosing function `dailyAggregations(forLastDays:)` is not marked `async`. Compile error.

```swift
func dailyAggregations(forLastDays days: Int) -> [(date: Date, sdnn: Double, rmssd: Double)] {
    // ...
    let agg = dataStore.dailyAverage(for: date)  // ERROR: requires await
    // ...
}
```

**Fix**: Make the function `async` and add `await` to the actor call:

```swift
func dailyAggregations(forLastDays days: Int) async -> [(date: Date, sdnn: Double, rmssd: Double)] {
    let calendar = Calendar.current
    let today = Date()
    var results: [(Date, Double, Double)] = []
    for day in (0..<days).reversed() {
        guard let date = calendar.date(byAdding: .day, value: -day, to: today) else { continue }
        let agg = await dataStore.dailyAverage(for: date)
        results.append((date, agg?.averageSdnn ?? 0, agg?.averageRmssd ?? 0))
    }
    return results
}
```

Then update the call site in `iOSApp/Views/DashboardView.swift` to be `async` as well.

---

#### C4. `HrvWatchApp` creates two `BackgroundMonitor` instances -- one never started

**Location**: `/Users/xiaotongxie/Documents/project/ios_hrv/WatchApp/HrvWatchApp.swift`, lines 13-35

**Issue**: The `DashboardView` receives a `BackgroundMonitor` injected into its `DashboardViewModel`, but `startMonitoring()` is never called on it. Instead, a second, separate `BackgroundMonitor` is created inside the `.task` modifier and started there. This means:

- The view model's `backgroundMonitor` is never activated
- The orphaned second monitor's observable state (`isMonitoring`, `lastUpdateDate`) is disconnected from the UI
- Background monitoring state cannot be displayed or controlled from the UI

```swift
// In the view hierarchy (never started):
backgroundMonitor: BackgroundMonitor(healthStore: healthStore, dataStore: dataStore)

// In .task (separate instance, IS started):
let monitor = BackgroundMonitor(healthStore: healthStore, dataStore: dataStore)
monitor.startMonitoring()
```

**Fix**: Start the existing monitor after authorization instead of creating a new one:

```swift
.task {
    await healthKitManager.requestAuthorization()
    // Start the monitor that was injected into the view model
}
```

The view model should expose a method to start monitoring:

```swift
func startBackgroundMonitoring() {
    backgroundMonitor.startMonitoring()
}
```

---

#### C5. `DataStoreTests.dataStore` never initialized -- all tests crash

**Location**: `/Users/xiaotongxie/Documents/project/ios_hrv/Tests/DataStoreTests.swift`, lines 5-15

**Issue**: `dataStore` is declared as `var dataStore: DataStore!` (implicitly unwrapped optional) but `setUp()` only contains a TODO comment -- the variable is never assigned. Every test method that accesses `dataStore` crashes with a nil unwrap. **All 6 test methods in this file are non-functional.**

```swift
var dataStore: DataStore!

override func setUp() {
    super.setUp()
    // In-memory SwiftData store would be set up here  <-- Never executed
}
```

**Fix**: Initialize with an in-memory `ModelContainer`:

```swift
override func setUp() {
    super.setUp()
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: HrvReading.self, configurations: config)
    dataStore = DataStore(modelContainer: container)
}

override func tearDown() {
    dataStore = nil
    super.tearDown()
}
```

---

### HIGH (5)

#### H1. Multiple `DataStore()` instances create isolated data stores

**Location**: Throughout the codebase
- `/Users/xiaotongxie/Documents/project/ios_hrv/WatchApp/Views/HistoryView.swift:5`
- `/Users/xiaotongxie/Documents/project/ios_hrv/iOSApp/Views/ExportView.swift:4`
- `/Users/xiaotongxie/Documents/project/ios_hrv/iOSApp/Views/ChartsView.swift:5`
- Plus inline creation in `DashboardView.swift` NavigationLink destination

**Issue**: `DataStore()` is called with no arguments in at least 5 locations. With `@ModelActor`, each call likely creates a new `ModelContainer`. Even if they share the same underlying SQLite file, each has its own `ModelContext` with an independent row cache. Data saved by one context may not be visible to another until the process exits, causing stale or missing data in the UI.

**Fix**: Create a single `ModelContainer` at the app level and inject it into all `DataStore` instances. Views should receive their `DataStore` via initializer injection, not by calling `DataStore()`:

```swift
// Create once at app level
private let container = try! ModelContainer(for: HrvReading.self)
private let dataStore = DataStore(modelContainer: container)

// Inject into views that need it
HistoryView(dataStore: dataStore)
```

---

#### H2. Recursive query chain in `ActiveSessionManager` without stopping old queries

**Location**: `/Users/xiaotongxie/Documents/project/ios_hrv/WatchApp/Services/ActiveSessionManager.swift`, lines 97-147

**Issue**: `startHeartbeatMonitoring()` creates an `HKSampleQuery` that triggers `queryHeartbeatSeries()`, which upon completion calls `startHeartbeatMonitoring()` again. This creates a recursive chain where each cycle replaces `heartbeatQuery` but never stops the previous `HKHeartbeatSeriesQuery`. Over a long session, this leaks query objects and risks unbounded execution.

```
startHeartbeatMonitoring()
  -> queryHeartbeatSeries()
     -> on done: startHeartbeatMonitoring()  // recursive
```

**Fix**: Stop the previous heartbeat query before starting a new one, and add a guard to prevent re-entrancy:

```swift
private func startHeartbeatMonitoring() {
    stopHeartbeatMonitoring()  // Stop previous query first
    // ... create and execute new query
}
```

---

#### H3. `SessionViewModel` polls via timer instead of using `@Observable` observation

**Location**: 
- `/Users/xiaotongxie/Documents/project/ios_hrv/WatchApp/ViewModels/SessionViewModel.swift`, lines 28-38
- `/Users/xiaotongxie/Documents/project/ios_hrv/WatchApp/Views/SessionView.swift`, line 78

**Issue**: `SessionViewModel.refreshState()` manually copies all state from `ActiveSessionManager` on a 1-second timer via `onReceive`. Both classes use `@Observable`, which is designed to propagate changes automatically. The manual polling approach:

- Adds 1-second latency to UI updates
- May miss rapid observation change notifications
- Adds unnecessary complexity
- Creates tight coupling between view model and timer lifecycle

**Fix**: Observe `ActiveSessionManager` properties directly in the view:

```swift
struct SessionView: View {
    @State private var sessionManager: ActiveSessionManager

    var body: some View {
        VStack(spacing: 16) {
            Text(formatTime(sessionManager.elapsedSeconds))
                .font(.system(.title, design: .monospaced))
            Text(sessionManager.currentRMSSD.map { "\($0, specifier: "%.0f")" } ?? "--")
                .font(.system(size: 48, weight: .bold, design: .rounded))
            // ...
        }
        .onAppear { sessionManager.startSession() }
        // No timer needed
    }
}
```

---

#### H4. HKObserverQuery completion handler not called

**Location**: `/Users/xiaotongxie/Documents/project/ios_hrv/Shared/Services/HealthKitManager.swift`, lines 94-98

**Issue**: The `HKObserverQuery` closure receives a completion handler parameter that **must** be called when background processing is complete. Without this call, HealthKit may throttle or delay future background deliveries. The current code ignores the parameter (uses `_`):

```swift
HKObserverQuery(sampleType: type, predicate: nil) { _, _, error in
    // ^^ Second _ is the completion handler -- MUST be called
    guard error == nil else { return }
    handler()
    // completionHandler is never invoked
}
```

**Fix**: Propagate and call the completion handler:

```swift
func createObserverQuery(for type: HKQuantityType, handler: @escaping (@escaping () -> Void) -> Void) -> HKObserverQuery {
    HKObserverQuery(sampleType: type, predicate: nil) { _, completionHandler, error in
        guard error == nil else {
            completionHandler?()
            return
        }
        handler(completionHandler ?? {})
    }
}
```

Update call site:
```swift
let query = healthKitManager.createObserverQuery(for: hrvType) { [weak self] completion in
    self?.handleNewData()
    completion()
}
```

---

#### H5. `BackgroundMonitor` modifies `@Observable` properties from background queue

**Location**: `/Users/xiaotongxie/Documents/project/ios_hrv/WatchApp/Services/BackgroundMonitor.swift`, lines 44-73

**Issue**: The `HKAnchoredObjectQuery` completion handler runs on an arbitrary background queue. The code modifies `@Observable` property `anchor` directly from this queue via `self?.anchor = newAnchor`. `@Observable` property modifications should occur on the `@MainActor` to ensure proper observation notifications and UI updates.

```swift
// In background queue completion handler:
self?.anchor = newAnchor         // Not main-actor safe
self?.saveAnchor()               // UserDefaults is thread-safe, OK
```

**Fix**: Dispatch the anchor update to MainActor:

```swift
Task { @MainActor [weak self] in
    self?.anchor = newAnchor
    self?.saveAnchor()
}
```

---

### MEDIUM (6)

#### M1. `NavigationLink` creates new service instances on every render

**Location**: `/Users/xiaotongxie/Documents/project/ios_hrv/WatchApp/Views/DashboardView.swift`, lines 108-116

**Issue**: The `NavigationLink` destination creates `HealthKitManager()`, `ActiveSessionManager(healthStore: HKHealthStore(), dataStore: DataStore())`, and `DataStore()` inline on every view render. This is wasteful (new `HKHealthStore` and isolated `DataStore` each time) and creates an unreferenced `HealthKitManager` that is never authorized.

**Fix**: Inject dependencies from the parent view hierarchy instead of creating them inline:

```swift
NavigationLink(destination: SessionView(
    viewModel: SessionViewModel(
        healthKitManager: healthKitManager,  // shared
        sessionManager: sessionManager        // shared
    )
)) { ... }
```

---

#### M2. `HealthKitManager.fetchLatestHrv` uses callback instead of async/await

**Location**: `/Users/xiaotongxie/Documents/project/ios_hrv/Shared/Services/HealthKitManager.swift`, lines 60-75

**Issue**: Mixed concurrency model -- `fetchLatestHrv` uses a completion handler callback while the rest of the codebase uses Swift concurrency (`async/await`). The callers in `DashboardViewModel.loadData()` must bridge manually.

**Fix**: Add an async variant using `withCheckedContinuation`:

```swift
func fetchLatestHrv() async throws -> HKQuantitySample? {
    try await withCheckedThrowingContinuation { continuation in
        fetchLatestHrv { result in
            continuation.resume(with: result)
        }
    }
}
```

---

#### M3. `fetchHrvSamples` update handler is empty -- never processes results

**Location**: `/Users/xiaotongxie/Documents/project/ios_hrv/Shared/Services/HealthKitManager.swift`, lines 77-92

**Issue**: Both the initial result handler and the `updateHandler` for `HKAnchoredObjectQuery` are empty no-ops. The method creates and returns the query but the caller receives no results. This appears to be dead/stub code that is never used effectively.

```swift
func fetchHrvSamples(from anchor: HKQueryAnchor?) -> HKAnchoredObjectQuery {
    let query = HKAnchoredObjectQuery(...) { _, _, _, _, _ in }
    query.updateHandler = { _, _, _, _, _ in }
    return query
}
```

**Fix**: Either implement the handlers to call a completion closure, or remove the method if unused:

```swift
func fetchHrvSamples(
    from anchor: HKQueryAnchor?,
    completion: @escaping ([HKQuantitySample]?, HKQueryAnchor?, Error?) -> Void
) -> HKAnchoredObjectQuery {
    let query = HKAnchoredObjectQuery(type: ..., predicate: ..., anchor: anchor, limit: ...) {
        _, samples, _, newAnchor, error in
        completion(samples as? [HKQuantitySample], newAnchor, error)
    }
    query.updateHandler = { _, samples, _, newAnchor, error in
        completion(samples as? [HKQuantitySample], newAnchor, error)
    }
    return query
}
```

---

#### M4. `HistoryView` creates its own `DataStore` instance

**Location**: `/Users/xiaotongxie/Documents/project/ios_hrv/WatchApp/Views/HistoryView.swift`, line 5

**Issue**: `HistoryView` creates a local `DataStore()` that is potentially isolated from the `DataStore` used by the rest of the app. This can cause the history list to show stale, empty, or inconsistent data if the contexts are not synchronized.

```swift
private let dataStore = DataStore()  // Potentially isolated instance
```

**Fix**: Accept `DataStore` via initializer injection:

```swift
struct HistoryView: View {
    let dataStore: DataStore
    @State private var readings: [HrvReading] = []
    // ...
}
```

---

#### M5. `HealthKitManager` is not `@MainActor` isolated

**Location**: `/Users/xiaotongxie/Documents/project/ios_hrv/Shared/Services/HealthKitManager.swift`, lines 24-25

**Issue**: The class is `@Observable` with `isAuthorized` and `authorizationError` properties used for UI binding in SwiftUI views. It is not marked `@MainActor`, so these properties could theoretically be accessed from background threads. While `requestAuthorization()` is correctly annotated `@MainActor`, the properties lack protection.

**Fix**: Add `@MainActor` to the class:

```swift
@MainActor
@Observable
final class HealthKitManager {
    // ...
}
```

---

#### M6. `HealthKitTypes` force-unwraps quantity type identifiers

**Location**: `/Users/xiaotongxie/Documents/project/ios_hrv/Shared/Models/HealthKitTypes.swift`, lines 17-26

**Issue**: Three computed properties force-unwrap `HKQuantityType.quantityType(forIdentifier:)` results. While Apple-defined identifiers always return values, force-unwraps are a crash risk if identifiers are ever deprecated, renamed, or unavailable on specific device configurations.

```swift
static var hrvType: HKQuantityType {
    HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
}
```

**Fix**: Replace with explicit `guard` and `fatalError` for better diagnostics, or use throwing property access:

```swift
static var hrvType: HKQuantityType {
    guard let type = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
        fatalError("HKQuantityType for heartRateVariabilitySDNN is unavailable")
    }
    return type
}
```

---

### LOW (4)

#### L1. Test force-unwrapping patterns in RMSSDCalculatorTests

**Location**: `/Users/xiaotongxie/Documents/project/ios_hrv/Tests/RMSSDCalculatorTests.swift`, lines 18, 30-31

**Issue**: `XCTAssertNotNil` followed by force-unwrapping the same value is a redundant pattern. `XCTUnwrap` is the idiomatic approach.

```swift
XCTAssertNotNil(result)
XCTAssertEqual(result!, 22.2, accuracy: 0.1)
```

**Fix**: Use `XCTUnwrap`:

```swift
let unwrapped = try XCTUnwrap(result)
XCTAssertEqual(unwrapped, 22.2, accuracy: 0.1)
```

#### L2. `testHealthKitNotAvailableInSimulator` has no assertions

**Location**: `/Users/xiaotongxie/Documents/project/ios_hrv/Tests/HealthKitManagerTests.swift`, lines 17-31

**Issue**: The test fulfills its expectation unconditionally without asserting any state on `manager.isAuthorized` or `manager.authorizationError`. It validates only that no crash occurs.

**Fix**: Add assertions that the error state is properly set:

```swift
Task {
    await manager.requestAuthorization()
    if !HKHealthStore.isHealthDataAvailable() {
        XCTAssertFalse(manager.isAuthorized)
        XCTAssertNotNil(manager.authorizationError)
    }
    expectation.fulfill()
}
```

#### L3. `project.yml` sets very recent deployment targets

**Location**: `/Users/xiaotongxie/Documents/project/ios_hrv/project.yml`, lines 5-7

**Issue**: iOS 18.0 / watchOS 11.0 / Xcode 16 minimum excludes older devices. This is an intentional choice for API access (noted in scope), but limits the user base.

#### L4. `HealthKitManager.init()` creates `HKHealthStore` even when HealthKit unavailable

**Location**: `/Users/xiaotongxie/Documents/project/ios_hrv/Shared/Services/HealthKitManager.swift`, lines 31-38

**Issue**: When `HKHealthStore.isHealthDataAvailable()` is false, the code still creates `healthStore = HKHealthStore()`. The instance enters a half-initialized state where the store exists but all operations will fail.

---

## Statistics

| Severity | Count |
|----------|-------|
| CRITICAL | 5 |
| HIGH     | 5 |
| MEDIUM   | 6 |
| LOW      | 4 |
| **Total** | **20** |

### Issue Distribution by Category

| Category | Count | Item IDs |
|----------|-------|----------|
| Compile Error | 2 | C1, C3 |
| Runtime Crash | 1 | C2 |
| Logic / Data Flow | 3 | C4, H1, H3 |
| Resource Leak | 1 | H2 |
| HealthKit API Misuse | 3 | C2, H4, M3 |
| Thread Safety | 2 | H5, M5 |
| Architecture / DI | 3 | M1, M4, C4 |
| Test Quality | 2 | C5, L1-L2 |
| Code Style / Low Risk | 3 | M6, L3, L4 |
| Mixed Concurrency | 1 | M2 |

---

## Positive Observations

1. **Strong use of Swift 6 features**: `@ModelActor` for thread-safe SwiftData access, `@Observable` for SwiftUI integration, and proper actor-based data isolation are forward-looking architectural choices.

2. **Clean MVVM separation**: ViewModels encapsulate business logic, views are purely declarative, and services handle infrastructure concerns. Good single-responsibility principle throughout.

3. **Excellent algorithm implementation**: `RMSSDCalculator.calculate()` is mathematically correct with proper edge case handling (minimum 3 IBIs, gap detection). The `extractIBIs` method correctly filters out heartbeat intervals preceded by gaps. Tests validate the algorithm thoroughly with known values.

4. **Proper HealthKit background setup**: The watch app correctly declares `WKBackgroundModes: ["healthkit"]` in Info.plist, uses `HKObserverQuery` for background monitoring, and calls `enableBackgroundDelivery` for periodic updates.

5. **Well-designed WatchConnectivity sync**: The `WatchConnectivityManager` properly validates session state (`isSupported`, `activationState == .activated`) before sending, uses `transferUserInfo` for general data and `transferCurrentComplicationUserInfo` for complication updates.

6. **Complete feature coverage**: The codebase covers the full monitoring lifecycle -- background collection, active workout sessions, local persistence with SwiftData, watchOS complication, iOS companion app with Charts framework visualizations, and CSV export -- all in a single well-organized project layout.

7. **Thoughtful SwiftUI patterns**: Views handle empty states gracefully (`ContentUnavailableView`, `"--"` placeholders), use system material backgrounds for platform-appropriate styling, and follow watchOS design conventions (larger fonts, minimal navigation, `.monospaced` timer display).

8. **Good error handling infrastructure**: The `HealthKitError` and `WatchConnectivityError` enums provide typed, localized error descriptions. Services gracefully degrade when HealthKit or WatchConnectivity are unavailable.
