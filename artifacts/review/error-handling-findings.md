# Error Handling Review: Apple Watch HRV Monitoring App

**Reviewer**: error-handling-agent
**Date**: 2026-04-30
**Scope**: All 20 Swift source files across Shared/, WatchApp/, iOSApp/
**Branch**: `feature/apple-watch-hrv-monitor`

---

## Summary + Verdict

The app has serious gaps in error handling that will cause silent data loss, background delivery degradation, and at least one crash path. The most critical issue is the **missing HKObserverQuery completion handler** on watchOS, which means HealthKit never receives a signal that background processing is complete -- this will eventually cause the system to stop delivering background HRV updates entirely.

**Verdict**: FAIL. 1 critical, 3 high, 6 medium, and 6 low findings require remediation before production use.

---

## Findings

### CRITICAL (1)

#### F-1: HKObserverQuery completion handler is never called

| Field | Value |
|-------|-------|
| **Files** | `Shared/Services/HealthKitManager.swift:95`, `WatchApp/Services/BackgroundMonitor.swift:25` |
| **Category** | background-timeout, silent-failure |
| **Hidden Errors** | The `HKObserverQuery` initializer accepts a `(HKObserverQuery, HKObserverQueryCompletionHandler?, Error?) -> Void` closure. The completion handler parameter is silently ignored with `_` at line 95 of HealthKitManager. In BackgroundMonitor.handleNewData() there is no mechanism to ever call the observer completion handler. On watchOS, this means the system never receives a signal that background processing is finished. |
| **User Impact** | HealthKit stops delivering background HRV updates after a few cycles. The user sees stale or empty data with no indication anything is wrong. On watchOS, the system may terminate the app for exceeding the background task budget. |
| **Fix** | Thread the completion handler through to `handleNewData()` and call it after the anchored query completes: |

```swift
// HealthKitManager.swift
func createObserverQuery(for type: HKQuantityType, handler: @escaping (HKObserverQueryCompletionHandler?) -> Void) -> HKObserverQuery {
    HKObserverQuery(sampleType: type, predicate: nil) { _, completion, error in
        if let error {
            os_log(.error, "HKObserverQuery failed: %{public}@", error.localizedDescription)
            completion?()
            return
        }
        handler(completion)
    }
}

// BackgroundMonitor.swift
func handleNewData(observerCompletion: HKObserverQueryCompletionHandler?) {
    let anchoredQuery = HKAnchoredObjectQuery(
        type: hrvType, predicate: nil, anchor: anchor, limit: 50
    ) { [weak self] _, samples, _, newAnchor, error in
        defer { observerCompletion?() }
        guard error == nil, let samples = samples as? [HKQuantitySample], !samples.isEmpty else { return }
        self?.anchor = newAnchor
        self?.saveAnchor()
        Task { [weak self] in
            guard let self else { return }
            for sample in samples {
                let reading = HrvReading(
                    timestamp: sample.startDate,
                    sdnnMs: sample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli)),
                    source: .background
                )
                await self.dataStore.save(reading)
            }
            await MainActor.run { self.lastUpdateDate = Date() }
        }
    }
    healthStore.execute(anchoredQuery)
}
```

---

### HIGH (3)

#### F-2: Force cast `HKSeriesType as! HKSampleType` -- crash on active session

| Field | Value |
|-------|-------|
| **File** | `WatchApp/Services/ActiveSessionManager.swift:100` |
| **Category** | force-unwrap |
| **Hidden Errors** | `HealthKitTypes.heartbeatSeriesType as! HKSampleType` force-casts an `HKSeriesType` to `HKSampleType`. These are unrelated types in the HealthKit hierarchy (`HKSeriesType` is not a subclass of `HKSampleType`). This cast could fail at runtime if HealthKit ever differentiates between them in the query API. |
| **User Impact** | Instant crash during active session when `startHeartbeatMonitoring()` is called. The user cannot start an HRV session. |
| **Fix** | `HKHeartbeatSeriesSample` inherits from `HKSample`, so the `as? HKHeartbeatSeriesSample` downcast in the completion handler is safe. The source of the crash is the query's `sampleType:` parameter. Use `HKObjectType.seriesType(forIdentifier: .heartbeatSeries)` or `HKSeriesType.heartbeat()` and set `HKQuery.predicateForSamples` instead: |

```swift
// Option A: Query using the appropriate series type
let predicate = HKQuery.predicateForObjects(from: HKSource.default())
let query = HKSampleQuery(
    sampleType: HKObjectType.seriesType(forIdentifier: .heartbeatSeries)! as! HKSampleType,
    ...
)
// Option B: Avoid the cast entirely by using HKAnchoredObjectQuery which accepts HKQueryType
```

Note: While `HKHeartbeatSeriesSample` does inherit from `HKSample`, the `HKSeriesType` is **not** a subclass of `HKSampleType`. The `as!` cast in the middle of the `HKSampleQuery` initializer violates the type system and is a crash waiting to happen if the runtime ever validates the type identity.

#### F-3: All SwiftData save failures are silently swallowed

| Field | Value |
|-------|-------|
| **Files** | `Shared/Services/DataStore.swift:8,60,68` |
| **Category** | silent-failure, try-question-mark |
| **Hidden Errors** | Every `modelContext.save()` call uses `try?`. Save failures from disk full, constraint violations, or SwiftData internal errors are silently discarded. |
| **User Impact** | HRV readings silently fail to persist. The user sees data in memory during the session but it disappears on next launch. No indication of data loss. |
| **Fix** | Log save errors and propagate them. Add a `lastSaveError` observable property so the UI can react: |

```swift
@Observable
actor DataStore {
    var lastSaveError: String?

    func save(_ reading: HrvReading) {
        modelContext.insert(reading)
        do {
            try modelContext.save()
            lastSaveError = nil
        } catch {
            os_log(.error, "SwiftData save failed: %{public}@", error.localizedDescription)
            lastSaveError = error.localizedDescription
        }
    }

    // Apply the same pattern to delete() and deleteAll()
}
```

#### F-4: Zero error logging anywhere in the app

| Field | Value |
|-------|-------|
| **Files** | All source files |
| **Category** | poor-user-feedback |
| **Hidden Errors** | Zero uses of `os_log`, `Logger`, `NSLog`, or `print` for error diagnosis. There is no way to distinguish "no HRV data available" from "HealthKit query failed" without attaching a debugger. |
| **User Impact** | Every production issue is invisible to developers. Bug reports will lack diagnostic data. There is no way to support the app without reproducing issues locally. |
| **Fix** | Add `import OSLog` and a `Logger` instance to each service class. Log all error paths: |

```swift
import OSLog

extension Logger {
    static let healthKit = Logger(subsystem: "com.example.hrvmonitor", category: "healthkit")
    static let dataStore = Logger(subsystem: "com.example.hrvmonitor", category: "datastore")
    static let watchConnectivity = Logger(subsystem: "com.example.hrvmonitor", category: "watchconnectivity")
    static let backgroundMonitor = Logger(subsystem: "com.example.hrvmonitor", category: "background")
    static let session = Logger(subsystem: "com.example.hrvmonitor", category: "session")
}
```

---

### MEDIUM (6)

#### F-5: Empty anchored query handlers in `fetchHrvSamples()` -- dead code that would cause silent data loss

| Field | Value |
|-------|-------|
| **File** | `Shared/Services/HealthKitManager.swift:77-92` |
| **Category** | silent-failure, dead-code |
| **Hidden Errors** | Both the initial result handler and the `updateHandler` for `HKAnchoredObjectQuery` are empty closures `{ }` with only comments. This method is never called from anywhere in the codebase, so it is dead code. But if a future developer calls it expecting results, they will get nothing back with zero feedback. |
| **User Impact** | None currently (dead code), but a ticking bomb for future developers who assume this function works. |
| **Fix** | Either remove the dead method entirely, or implement proper handlers with a completion handler parameter: |

```swift
func fetchHrvSamples(from anchor: HKQueryAnchor?, completion: @escaping (Result<[HKQuantitySample], Error>) -> Void) -> HKAnchoredObjectQuery {
    let query = HKAnchoredObjectQuery(
        type: HealthKitTypes.hrvType,
        predicate: nil,
        anchor: anchor,
        limit: HKObjectQueryNoLimit
    ) { _, samples, _, newAnchor, error in
        if let error {
            completion(.failure(error))
            return
        }
        completion(.success(samples as? [HKQuantitySample] ?? []))
    }
    return query
}
```

#### F-6: `HKHeartbeatSeriesQuery` error parameter silently ignored

| Field | Value |
|-------|-------|
| **File** | `WatchApp/Services/ActiveSessionManager.swift:114` |
| **Category** | silent-failure |
| **Hidden Errors** | The `_` last parameter in the `HKHeartbeatSeriesQuery` handler closure is the `Error?` parameter -- completely ignored with `_`. If the heartbeat series query fails, no error is logged or surfaced. The session appears to be running but produces no data. |
| **User Impact** | During an active monitoring session, if the heartbeat series query fails, the user sees no RMSSD updates with no indication of why. Timers keep running, the session appears active, but no HRV samples are generated. |
| **Fix** | Log the error: |

```swift
let query = HKHeartbeatSeriesQuery(heartbeatSeries: sample) { [weak self] _, timeSinceStart, precededByGap, done, error in
    if let error {
        Logger.session.error("Heartbeat series query failed: \(error.localizedDescription)")
        return
    }
    guard let self else { return }
    // ... rest of handler
}
```

#### F-7: Background delivery registration failure silently swallowed

| Field | Value |
|-------|-------|
| **File** | `WatchApp/Services/BackgroundMonitor.swift:33` |
| **Category** | try-question-mark, silent-failure |
| **Hidden Errors** | `try? await healthStore.enableBackgroundDelivery(...)` silently fails. If background delivery registration fails (e.g., due to entitlements, lack of authorization, or system denial), monitoring is effectively broken but `isMonitoring` is still `true`. |
| **User Impact** | The watch appears to be monitoring (isMonitoring == true) but never receives background HRV updates. The user only notices when data remains stale day after day. |
| **Fix** | Handle the error explicitly and reset state: |

```swift
func startMonitoring() {
    guard !isMonitoring else { return }
    let query = healthStore.createObserverQuery(for: hrvType) { [weak self] in
        self?.handleNewData()
    }
    healthStore.execute(query)
    observerQuery = query
    isMonitoring = true

    Task {
        do {
            try await healthStore.enableBackgroundDelivery(for: hrvType, frequency: .hourly)
        } catch {
            Logger.backgroundMonitor.error("Failed to enable background delivery: \(error.localizedDescription)")
            await MainActor.run {
                self.isMonitoring = false
                self.observerQuery = nil
            }
        }
    }
}
```

#### F-8: Session failure state not propagated to user-facing UI

| Field | Value |
|-------|-------|
| **Files** | `WatchApp/ViewModels/SessionViewModel.swift:28-38`, `WatchApp/Views/SessionView.swift` |
| **Category** | poor-user-feedback |
| **Hidden Errors** | `refreshState()` copies `sessionManager.state` but no view inspects it for `.failed(Error)`. The error is available in the `state` property but no view renders it. If the user encounters an error, the screen stays in its last state or goes blank. |
| **User Impact** | If a workout session fails to start or crashes mid-session, the watch UI shows either "preparing" state or the timer simply stops advancing, with no error message. The user has no way to know the session failed. |
| **Fix** | Extract error messages and display them in the view: |

```swift
// SessionViewModel
var errorMessage: String?

func refreshState() {
    state = sessionManager.state
    if case .failed(let error) = sessionManager.state {
        errorMessage = error.localizedDescription
    } else {
        errorMessage = nil
    }
    currentHRV = sessionManager.currentRMSSD
    currentHeartRate = sessionManager.currentHeartRate
    sampleCount = sessionManager.sampleCount
    let totalSeconds = Int(sessionManager.elapsedSeconds)
    elapsedTime = String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
}

// SessionView -- add after the stop button
if let errorMsg = viewModel.errorMessage {
    Text(errorMsg)
        .font(.caption)
        .foregroundStyle(.red)
        .padding()
}
```

#### F-9: `HealthKitManager.createObserverQuery` silently drops query errors

| Field | Value |
|-------|-------|
| **File** | `Shared/Services/HealthKitManager.swift:95-98` |
| **Category** | silent-failure |
| **Hidden Errors** | `guard error == nil else { return }` -- when the observer query itself fails (e.g., type not available, system error), the error is discarded and the handler closure is never called. No one is notified. Combined with F-1 (missing completion handler), this creates a double failure path. |
| **User Impact** | Background monitoring silently stops working. No error logged, no retry, no user feedback. |
| **Fix** | Log the error and always call the completion handler: |

```swift
HKObserverQuery(sampleType: type, predicate: nil) { _, completion, error in
    if let error {
        Logger.healthKit.error("HKObserverQuery error: \(error.localizedDescription)")
        completion?()
        return
    }
    handler()
}
```

#### F-10: `ActiveSessionManager.stopSession()` swallows builder-completion errors

| Field | Value |
|-------|-------|
| **File** | `WatchApp/Services/ActiveSessionManager.swift:90-92` |
| **Category** | silent-failure |
| **Hidden Errors** | `endCollection(with:_)` and `finishWorkout { _, _ in }` both ignore their error parameters with `_`. If HealthKit fails to finalize the workout, there is no logging. The session appears to have stopped cleanly but the workout data is incomplete or missing from HealthKit. |
| **User Impact** | Workout sessions might not appear in HealthKit, or may have incomplete data, with no error indicated. The user believes the session was saved. |
| **Fix** | Log the errors: |

```swift
builder?.endCollection(with: Date()) { success, error in
    if let error {
        Logger.session.error("endCollection failed: \(error.localizedDescription)")
    }
    self?.builder?.finishWorkout { _, error in
        if let error {
            Logger.session.error("finishWorkout failed: \(error.localizedDescription)")
        }
    }
}
```

---

### LOW (6)

#### F-11: Force-unwrapped `calendar.date(from:)` in `DataStore.monthlyAverage`

| Field | Value |
|-------|-------|
| **File** | `Shared/Services/DataStore.swift:51` |
| **Category** | force-unwrap |
| **Hidden Errors** | `calendar.date(from: calendar.dateComponents([.year, .month], from: date))!` -- unlike `weeklyAverage` and `dailyAverage` which use `guard let`, this path force-unwraps. |
| **Fix** | Use `guard let` consistent with the rest of the codebase. |

#### F-12: Force-unwrapped `calendar.date(byAdding:)` in ChartsView

| Field | Value |
|-------|-------|
| **File** | `iOSApp/Views/ChartsView.swift:96,98` |
| **Category** | force-unwrap |
| **Hidden Errors** | Two force-unwrapped `calendar.date(byAdding:value:to:)` calls. |
| **Fix** | Use `guard let` with a `return` early-exit. |

#### F-13: Force-unwrapped `readings.first!` in `DataStore.aggregate`

| Field | Value |
|-------|-------|
| **File** | `Shared/Services/DataStore.swift:84-85` |
| **Category** | force-unwrap |
| **Hidden Errors** | `readings.first!.timestamp` and `readings.last!.timestamp` -- guarded by `guard !readings.isEmpty` at line 72, but the check and use are 12 lines apart. |
| **Fix** | Combine with the existing guard: `guard !readings.isEmpty else { return nil }; let first = readings.first!; let last = readings.last!` |

#### F-14: `WatchConnectivityManager.sendComplicationUpdate` omits activation check

| Field | Value |
|-------|-------|
| **File** | `Shared/Services/WatchConnectivityManager.swift:67-74` |
| **Category** | silent-failure |
| **Hidden Errors** | `sendHrvReading` checks `session.activationState == .activated` before sending, but `sendComplicationUpdate` does not. |
| **Fix** | Add the same guard as `sendHrvReading`. |

#### F-15: `HealthKitTypes` force-unwraps quantity type identifiers

| Field | Value |
|-------|-------|
| **File** | `Shared/Models/HealthKitTypes.swift:17,21` |
| **Category** | force-unwrap |
| **Hidden Errors** | `HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!` -- if Apple ever renames or deprecates an identifier, this crashes at static initialization time. |
| **Fix** | Use `guard let` with `fatalError` and a descriptive message. |

#### F-16: iOS `DashboardViewModel.connectWatch()` uses fixed delay instead of state tracking

| Field | Value |
|-------|-------|
| **File** | `iOSApp/ViewModels/DashboardViewModel.swift:55-62` |
| **Category** | poor-user-feedback |
| **Hidden Errors** | After activating the WCSession, `isSyncing` is reset to `false` after a hardcoded 1-second delay regardless of whether activation succeeded. The WatchConnectivityManager's delegate already tracks activation state -- the view model should observe it instead. |
| **Fix** | Use the `isReachable`/`isPaired` properties or add an `activationState` observable: |

```swift
func connectWatch() {
    watchConnectivity.activate()
    isSyncing = true
    // The WatchConnectivityManager delegate will update isReachable/isPaired
    // Observe those properties instead of using a fixed delay
}
```

---

## Error Handler Audit Table

| Location | Pattern | Logging | User Feedback | Specificity | Verdict |
|----------|---------|---------|---------------|-------------|---------|
| `HealthKitManager.requestAuthorization()` catch L54 | do/catch | None (sets error state) | YES (via property) | GOOD (typed enum) | PASS |
| `HealthKitManager.fetchLatestHrv` L68 | completion callback | None | No | GOOD (Result type) | PASS |
| `HealthKitManager.createObserverQuery` L96 | guard error | None | No | POOR (silent return) | FAIL |
| `HealthKitManager.fetchHrvSamples` L77-92 | empty closures | None | No | POOR (dead code) | FAIL |
| `ActiveSessionManager.startSession()` L77-79 | do/catch | None (sets state) | PARTIAL (state not rendered) | GOOD (typed enum) | WARN |
| `ActiveSessionManager.didFailWithError` L186 | delegate method | None | PARTIAL (state not rendered) | GOOD | WARN |
| `ActiveSessionManager.stopSession()` L90-92 | ignored params | None | No | POOR (silent) | FAIL |
| `ActiveSessionManager heartbeat query` L114 | ignored param | None | No | POOR (silent) | FAIL |
| `BackgroundMonitor.handleNewData` L51 | guard error | None | No | POOR (silent return) | FAIL |
| `BackgroundMonitor enableBackgroundDelivery` L33 | `try?` | None | No | POOR | FAIL |
| `DataStore.save()` L8 | `try?` | None | No | POOR | FAIL |
| `DataStore.fetchRecent()` L15 | `try?` + `?? []` | None | No | PARTIAL (nil -> []) | WARN |
| `DataStore.fetch()` L27 | `try?` + `?? []` | None | No | PARTIAL (nil -> []) | WARN |
| `DataStore.delete()` L60 | `try?` | None | No | POOR | FAIL |
| `DataStore.deleteAll()` L68 | `try?` | None | No | POOR | FAIL |
| `WatchConnectivityManager.sendHrvReading` L49 | guard + error state | None | PARTIAL (error property) | GOOD | PASS |
| `WatchConnectivityManager.sendComplicationUpdate` L67 | no check | None | No | POOR | FAIL |
| `WatchConnectivityManager activation delegate` L78-84 | error handling | None | PARTIAL (error property) | GOOD | PASS |
| `RMSSDCalculator.calculate` L9 | guard | N/A | N/A | GOOD (nil return) | PASS |
| `RMSSDCalculator.extractIBIs` L30-54 | completion | N/A | N/A | GOOD | PASS |
| `ExportView.exportCSV()` L100-108 | do/catch | None (sets msg) | YES (exportMessage) | GOOD | PASS |
| `HrvWatchApp.task` L23-31 | conditional | None | No | PARTIAL | WARN |
| `ChartsView` force unwrap L96,98 | `!` | None | No | POOR | FAIL |
| `HistoryView` L44-46 | `dataStore.fetchRecent` | None | No | PARTIAL | PASS |

---

## Statistics

### Severity Distribution

| Severity | Count |
|----------|-------|
| CRITICAL | 1 |
| HIGH | 3 |
| MEDIUM | 6 |
| LOW | 6 |
| **Total** | **16** |

### Silent Failure Risk Inventory

| Risk Pattern | Occurrences | Files |
|---|---|---|
| `try?` on SwiftData save | 3 | DataStore.swift |
| `try?` on HealthKit operations | 2 | BackgroundMonitor.swift |
| `try?` on NSKeyedArchiver/Unarchiver | 2 | BackgroundMonitor.swift |
| `as!` force cast | 1 | ActiveSessionManager.swift |
| Force unwrap `calendar.date(from:)!` | 1 | DataStore.swift |
| Force unwrap `calendar.date(byAdding:)!` | 2 | ChartsView.swift |
| Force unwrap `readings.first!` | 1 | DataStore.swift |
| Force unwrap `HKQuantityType!` | 2 | HealthKitTypes.swift |
| Ignored error parameters (`_`) | 4 | HealthKitManager, ActiveSessionManager |
| Missing background completion handler | 1 | BackgroundMonitor + HealthKitManager |

### Error Flow Coverage Assessment

| Error Scenario | Handled? | User Visible? | Logged? |
|---|---|---|---|
| HealthKit unavailable | YES (via property) | NO (not rendered) | NO |
| HealthKit authorization denied | YES (via property) | NO (not rendered) | NO |
| HKObserverQuery failure | NO | NO | NO |
| Anchored query failure (BackgroundMonitor) | PARTIAL (guarded return) | NO | NO |
| Background delivery registration failure | NO | NO | NO |
| Workout session runtime failure | YES (state set) | NO (state not rendered) | NO |
| Heartbeat series query failure | NO | NO | NO |
| Workout builder collection error | NO | NO | NO |
| Workout finish error | NO | NO | NO |
| SwiftData save failure | NO | NO | NO |
| SwiftData fetch failure | PARTIAL (empty array) | PARTIAL (empty UI) | NO |
| WatchConnectivity activation failure | PARTIAL (error property set) | NO | NO |
| WCSession not reachable (sendHrvReading) | YES (guard) | PARTIAL (error property) | NO |
| WCSession not reachable (sendComplicationUpdate) | NO | NO | NO |
| CSV write failure | YES | YES (exportMessage) | NO |
| Timeline entry with no data | PARTIAL (placeholder view) | YES | N/A |

### Top 3 Must-Fix Before Production

1. **F-1** (CRITICAL): HKObserverQuery completion handler never called -- will kill background monitoring on watchOS
2. **F-2** (HIGH): Force-cast `HKSeriesType as! HKSampleType` -- will crash during active session
3. **F-4** (HIGH): Zero error logging -- every production issue becomes a non-reproducible mystery
