# Plan Context

**Generated**: 2026-04-30 23:00
**Workflow ID**: idea-to-pr
**Plan Source**: `.claude/skills/idea-to-pr/artifacts/plan.md`

---

## Branch

| Field | Value |
|-------|-------|
| **Branch** | `feature/apple-watch-hrv-monitor` |
| **Base** | `main` (initial commit) |

---

## Plan Summary

**Title**: Apple Watch HRV 监测应用

**Overview**: 构建一个专为 Apple Watch 设计的 HRV（心率变异性）监测应用，支持后台自动采集 SDNN 和 RMSSD 指标，提供实时监测会话、历史趋势、数据导出功能。核心技术栈：SwiftUI + HealthKit + SwiftData + WatchConnectivity。

---

## Files to Create

| File | Action |
|------|--------|
| Xcode Project | CREATE |
| `Shared/Models/HrvReading.swift` | CREATE |
| `Shared/Models/HealthKitTypes.swift` | CREATE |
| `Shared/Services/HealthKitManager.swift` | CREATE |
| `Shared/Services/RMSSDCalculator.swift` | CREATE |
| `Shared/Services/WatchConnectivityManager.swift` | CREATE |
| `WatchApp/Services/BackgroundMonitor.swift` | CREATE |
| `WatchApp/Services/ActiveSessionManager.swift` | CREATE |
| `WatchApp/ViewModels/DashboardViewModel.swift` | CREATE |
| `WatchApp/ViewModels/SessionViewModel.swift` | CREATE |
| `WatchApp/Views/DashboardView.swift` | CREATE |
| `WatchApp/Views/SessionView.swift` | CREATE |
| `WatchApp/Views/HistoryView.swift` | CREATE |
| `WatchApp/Complication/HrvComplication.swift` | CREATE |
| `WatchApp/HrvWatchApp.swift` | CREATE |
| `iOSApp/ViewModels/DashboardViewModel.swift` | CREATE |
| `iOSApp/Views/DashboardView.swift` | CREATE |
| `iOSApp/Views/ChartsView.swift` | CREATE |
| `iOSApp/Views/ExportView.swift` | CREATE |
| `iOSApp/HrvApp.swift` | CREATE |
| `Shared/Services/DataStore.swift` | CREATE |

---

## NOT Building (Scope Limits)

**CRITICAL FOR REVIEWERS**: These items are **intentionally excluded** from scope. Do NOT flag them as bugs or missing features.

- **第三方蓝牙 HR 监测器支持** — 第一期仅使用 Apple Watch 内置 sensor
- **云端同步 / iCloud** — 仅通过 WatchConnectivity 本地同步
- **AI 分析/异常检测** — 第二期功能，第一期仅展示原始数据
- **复杂通知/提醒** — 第二期实现阈值报警
- **呼吸引导** — 不属于 HRV 监测核心功能

---

## Validation Commands

### Level 1: BUILD

```bash
xcodebuild build -scheme HrvWatch -sdk watchos11.0
xcodebuild build -scheme Hrv -sdk iphoneos18.0
```

**EXPECT**: Exit 0, no errors or warnings

### Level 2: UNIT_TESTS

```bash
xcodebuild test -scheme HrvWatch -destination "platform=watchOS Simulator,name=Apple Watch Ultra 2 (49mm)"
```

**EXPECT**: All tests pass

### Level 3: FULL_SUITE

```bash
xcodebuild test -scheme Hrv -destination "platform=iOS Simulator,name=iPhone 16"
xcodebuild test -scheme HrvWatch -destination "platform=watchOS Simulator,name=Apple Watch Ultra 2 (49mm)"
```

**EXPECT**: All tests pass

---

## Acceptance Criteria

- [ ] Apple Watch 主屏显示当前 HRV (SDNN + RMSSD)
- [ ] 后台每 ~1 小时自动更新 HRV 数据
- [ ] 主动监测会话模式可手动启动/结束
- [ ] 主动监测提供实时 HRV 更新（~5 秒间隔）
- [ ] 历史数据按日/周/月聚合展示
- [ ] iPhone 配套 App 同步显示 Watch 数据
- [ ] 表盘复杂功能支持显示最新 HRV
- [ ] CSV 数据导出功能
- [ ] 所有错误场景有用户友好提示
- [ ] HealthKit 授权流程完整

---

## Patterns to Mirror

| Pattern | Source | Details |
|---------|--------|---------|
| NAMING_CONVENTION | Standard Swift | UpperCamelCase types, lowerCamelCase vars/funcs |
| ERROR_HANDLING | Swift standard | `LocalizedError` enum, user-facing alerts |
| TEST_STRUCTURE | XCTest | setUp/tearDown, XCTestCase subclasses |
| ARCHITECTURE | MVVM | Services → ViewModels → Views |

---

## Next Steps

1. `archon-confirm-plan` - Verify patterns still exist
2. `archon-implement-tasks` - Execute the plan
3. `archon-validate` - Run full validation
4. `archon-finalize-pr` - Create PR and mark ready
