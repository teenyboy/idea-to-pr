# Feature: Apple Watch HRV 监测应用

## Summary

构建一个专为 Apple Watch 设计的 HRV（心率变异性）监测应用，支持后台自动采集 SDNN 和 RMSSD 指标，提供实时监测会话、历史趋势、数据导出功能。配套 iPhone 应用提供深度分析与可视化。核心技术栈：SwiftUI + HealthKit + SwiftData + WatchConnectivity。

## User Story

作为一名关注心脏健康和自主神经系统的用户
我想要在 Apple Watch 上准确监测 HRV 数据
以便追踪我的压力恢复状态和整体健康趋势

## Problem Statement

Apple Watch 原生 Health App 仅提供 SDNN 这一种 HRV 指标，且数据查看体验碎片化。第三方 HRV 应用要么价格昂贵，要么数据不准确，要么无法在 watchOS 上离线工作。用户需要一个**免费、准确、专注 HRV** 的 watchOS 原生应用。

## Solution Statement

watchOS 原生 SwiftUI 应用，通过 HealthKit API 读取 Apple Watch 自动测量的 SDNN 数据，同时通过 HKHeartbeatSeriesSample 手动计算 RMSSD 指标。支持后台被动监测和主动监测会话两种模式。数据本地存储，通过 WatchConnectivity 同步到 iPhone 配套应用。

## Metadata

| Field | Value |
|-------|-------|
| Type | NEW_CAPABILITY（全新项目） |
| Complexity | HIGH |
| Systems Affected | Xcode 项目结构、HealthKit、SwiftData、WatchConnectivity |
| Dependencies | iOS 18+ / watchOS 11+, Xcode 16+ |
| Estimated Tasks | 12 |

---

## UX Design

### watchOS App UI

```
┌──────────────────────┐
│    HRV Monitor       │
│                      │
│  ┌────────────────┐  │
│  │    HRV Today    │  │
│  │    45 ms       │  │
│  │    SDNN        │  │
│  │  ────────────  │  │
│  │    42 ms       │  │
│  │    RMSSD       │  │
│  └────────────────┘  │
│                      │
│  ┌────────────────┐  │
│  │ 7天趋势 ▲12%   │  │
│  └────────────────┘  │
│                      │
│  [开始监测]  [历史]   │
└──────────────────────┘
```

### 主动监测会话 UI

```
┌──────────────────────┐
│    监测中  00:05:30  │
│                      │
│  ┌────────────────┐  │
│  │  实时 HRV      │  │
│  │  48 ms         │  │
│  └────────────────┘  │
│                      │
│  HR: 72 bpm          │
│  采样: 12次          │
│                      │
│    [结束]            │
└──────────────────────┘
```

### iPhone App UI

```
┌──────────────────────────────────────┐
│  HRV Monitor           [sync] [⚙]   │
│                                      │
│  ┌────────────────────────────────┐  │
│  │  今日 HRV                      │  │
│  │  📊 [折线图: 24h HRV 趋势]    │  │
│  │  平均: 45ms  |  最高: 62ms    │  │
│  │  SDNN ● RMSSD ●              │  │
│  └────────────────────────────────┘  │
│                                      │
│  ┌────────────────────────────────┐  │
│  │  7 天                          │  │
│  │  ████████████░░░░ 45ms        │  │
│  │  上周: 40ms  ▲12%             │  │
│  └────────────────────────────────┘  │
│                                      │
│  ┌────────────────────────────────┐  │
│  │  30 天                         │  │
│  │  ████████████░░░░ 43ms        │  │
│  └────────────────────────────────┘  │
│                                      │
│  [导出 CSV]  [数据源管理]            │
└──────────────────────────────────────┘
```

### Interaction Changes

| Location | Before | After | User Impact |
|----------|--------|-------|-------------|
| Apple Watch | 无 HRV 专用查看工具 | 主屏显示 SDNN + RMSSD + 趋势 | 抬手即见 HRV 数据 |
| Watch - 主动监测 | 无 | 启动 workout 会话，高频采集 | 可在静坐/冥想时精确测量 |
| iPhone | Health App 数据分散 | 可视化图表 + 趋势分析 | 一目了然了解长期趋势 |
| 数据管理 | HealthKit 仅 SDNN | SDNN + RMSSD 双指标 | 获得更全面的 HRV 分析 |

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Apple Watch                           │
│                                                         │
│  ┌──────────────┐    ┌──────────────────────────────┐   │
│  │  SwiftUI UI  │◄──►│       ViewModels             │   │
│  │  - Dashboard │    │  - DashboardViewModel        │   │
│  │  - Session   │    │  - SessionViewModel          │   │
│  │  - History   │    │  - HistoryViewModel          │   │
│  └──────────────┘    └──────────┬───────────────────┘   │
│                                 │                        │
│  ┌──────────────────────────────▼───────────────────┐   │
│  │              Services Layer                      │   │
│  │  ┌─────────────┐  ┌──────────┐  ┌──────────┐   │   │
│  │  │HealthKitMgr │  │DataStore │  │WatchCon  │   │   │
│  │  │- ObserverQ  │  │- SwiftData│  │- WCSess  │   │   │
│  │  │- WorkoutSess│  │- CRUD    │  │- Sync    │   │   │
│  │  │- RMSSD Calc│  │          │  │          │   │   │
│  │  └─────────────┘  └──────────┘  └──────────┘   │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ┌──────────────────┐  ┌─────────────────────────┐      │
│  │ Complications    │  │ Background Tasks        │      │
│  │ - HRV Complicat  │  │ - HKObserverQuery       │      │
│  └──────────────────┘  │ - WKExtRuntimeSession   │      │
│                        └─────────────────────────┘      │
└──────────────────────────┬──────────────────────────────┘
                           │ WatchConnectivity
┌──────────────────────────▼──────────────────────────────┐
│                    iPhone                                │
│  ┌──────────────┐    ┌──────────────────────────────┐   │
│  │  SwiftUI UI  │◄──►│       ViewModels             │   │
│  │  - Dashboard │    │  - DashboardViewModel        │   │
│  │  - Charts    │    │  - ChartViewModel            │   │
│  │  - Export    │    │  - ExportViewModel           │   │
│  └──────────────┘    └──────────┬───────────────────┘   │
│                                 │                        │
│  ┌──────────────────────────────▼───────────────────┐   │
│  │              Services Layer                      │   │
│  │  ┌─────────────┐  ┌──────────┐  ┌──────────┐   │   │
│  │  │HealthKitMgr │  │DataStore │  │WatchCon  │   │   │
│  │  │- Read only  │  │- SwiftData│  │- WCSess  │   │   │
│  │  └─────────────┘  └──────────┘  └──────────┘   │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

---

## Data Flow

```
Apple Watch Sensor
    │ (background, ~5min intervals)
    ▼
HealthKit Store (SDNN + HeartbeatSeries)
    │
    ├─── HKObserverQuery (background wake-up)
    │       │
    │       ▼
    │   HKAnchoredObjectQuery ←→ SwiftData (local store)
    │       │
    │       ▼
    │   WCSession.transferCurrentComplicationUserInfo
    │       │ (to iPhone)
    │       ▼
    │   iPhone SwiftData (synced copy)
    │
    └─── HKWorkoutSession (active monitoring)
            │
            ▼
        HKHeartbeatSeriesQuery
            │
            ▼
        RMSSD Calculator → SwiftData
            │
            ▼
        Real-time UI update
```

---

## Patterns to Mirror

**NAMING_CONVENTION:**
```swift
// Standard Swift/SwiftUI naming conventions
// Types: UpperCamelCase (HealthKitManager, HrvReading)
// Functions/Variables: lowerCamelCase (startMonitoring, currentHrvValue)
// Services: XxxManager or XxxService naming
```

**ERROR_HANDLING:**
```swift
// Handle HealthKit errors with user-facing alerts
// Use enum-based error types
enum HealthKitError: LocalizedError {
    case notAvailable
    case notAuthorized
    case queryFailed(Error)
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .notAvailable: return "HealthKit not available on this device"
        case .notAuthorized: return "HRV data access not authorized"
        case .queryFailed(let error): return "Query failed: \(error.localizedDescription)"
        case .unknown: return "An unknown error occurred"
        }
    }
}
```

**TEST_STRUCTURE:**
```swift
// Standard XCTest patterns
import XCTest
@testable import HrvWatch

final class HealthKitManagerTests: XCTestCase {
    var sut: HealthKitManager!
    
    override func setUp() { /* ... */ }
    override func tearDown() { /* ... */ }
    
    func testRequestAuthorization_whenHealthKitUnavailable_returnsError() { /* ... */ }
    func testCalculateRMSSD_withValidData_returnsCorrectValue() { /* ... */ }
    func testCalculateRMSSD_withInsufficientData_returnsNil() { /* ... */ }
}
```

---

## Files to Create

| File | Action | Justification |
|------|--------|---------------|
| Xcode Project | CREATE | 项目根结构（iOS + watchOS targets） |
| `Shared/Models/HrvReading.swift` | CREATE | HRV 数据模型定义 |
| `Shared/Models/HealthKitTypes.swift` | CREATE | HealthKit 类型定义 |
| `Shared/Services/HealthKitManager.swift` | CREATE | HealthKit 授权 + 查询服务 |
| `Shared/Services/RMSSDCalculator.swift` | CREATE | RMSSD 手动计算 |
| `Shared/Services/WatchConnectivityManager.swift` | CREATE | iPhone ↔ Watch 通信 |
| `WatchApp/Services/BackgroundMonitor.swift` | CREATE | 后台 HKObserverQuery 管理 |
| `WatchApp/Services/ActiveSessionManager.swift` | CREATE | Workout 实时监测会话 |
| `WatchApp/ViewModels/DashboardViewModel.swift` | CREATE | Watch 主屏 VM |
| `WatchApp/ViewModels/SessionViewModel.swift` | CREATE | 监测会话 VM |
| `WatchApp/Views/DashboardView.swift` | CREATE | Watch 主屏 |
| `WatchApp/Views/SessionView.swift` | CREATE | 活跃会话 UI |
| `WatchApp/Views/HistoryView.swift` | CREATE | 历史数据 |
| `WatchApp/Complication/HrvComplication.swift` | CREATE | 表盘复杂功能 |
| `WatchApp/HrvWatchApp.swift` | CREATE | Watch App 入口 |
| `iOSApp/ViewModels/DashboardViewModel.swift` | CREATE | iPhone 主屏 VM |
| `iOSApp/Views/DashboardView.swift` | CREATE | iPhone 仪表板 |
| `iOSApp/Views/ChartsView.swift` | CREATE | 图表分析 |
| `iOSApp/Views/ExportView.swift` | CREATE | 数据导出 |
| `iOSApp/HrvApp.swift` | CREATE | iOS App 入口 |
| `Shared/Services/DataStore.swift` | CREATE | SwiftData 本地存储 |

---

## NOT Building (Scope Limits)

- **第三方蓝牙 HR 监测器支持** — 第一期仅使用 Apple Watch 内置 sensor
- **云端同步 / iCloud** — 仅通过 WatchConnectivity 本地同步
- **AI 分析/异常检测** — 第二期功能，第一期仅展示原始数据
- **复杂通知/提醒** — 第二期实现阈值报警
- **呼吸引导** — 不属于 HRV 监测核心功能

---

## Step-by-Step Tasks

Execute in order. Each task is atomic and independently verifiable.

### Task 1: 创建 Xcode 项目结构

- **ACTION**: CREATE 新 Xcode 项目
- **IMPLEMENT**: 创建 iOS App + watchOS App 双 target 项目
  - iOS target: SwiftUI, iOS 18+
  - watchOS target: SwiftUI, watchOS 11+
  - 添加 HealthKit Capability 到两个 target
  - 添加 Info.plist 隐私描述: `NSHealthShareUsageDescription`, `NSHealthUpdateUsageDescription`
  - 创建共享代码组 `Shared/` 用于共享 Models + Services
- **VALIDATE**: 项目能在模拟器中 build 成功

### Task 2: 实现数据模型 (HrvReading)

- **ACTION**: CREATE `Shared/Models/HrvReading.swift` + `HealthKitTypes.swift`
- **IMPLEMENT**: SwiftData `@Model` class
  ```swift
  @Model
  class HrvReading {
      var id: UUID
      var timestamp: Date
      var sdnnMs: Double
      var rmssdMs: Double?
      var heartRate: Double?
      var source: String // "background" or "session"
      var sessionId: UUID?
  }
  ```
- **VALIDATE**: 单元测试可创建和查询 HrvReading

### Task 3: 实现 HealthKit 授权管理器

- **ACTION**: CREATE `Shared/Services/HealthKitManager.swift`
- **IMPLEMENT**:
  - 检查 HealthKit 可用性 (`HKHealthStore.isHealthDataAvailable()`)
  - 请求读写授权 (SDNN + HeartbeatSeries + HeartRate)
  - 错误处理（不可用 / 未授权 / 拒绝）
  - 异步接口 (async/await)
- **VALIDATE**: 在 watchOS 模拟器中测试授权流程
- **GOTCHA**: watchOS 和 iOS 都需要独立授权，HealthKit store 不同步

### Task 4: 实现后台 HRV 监测 (BackgroundMonitor)

- **ACTION**: CREATE `WatchApp/Services/BackgroundMonitor.swift`
- **IMPLEMENT**:
  - HKObserverQuery 监听 SDNN 新数据
  - enableBackgroundDelivery(frequency: .hourly)
  - HKAnchoredObjectQuery 增量获取
  - 处理 background delivery 的回调（必须在 15s 内完成）
  - 新数据到达时写入 SwiftData
  - 触发 Complication 刷新
- **GOTCHA**: 务必在所有路径调用 completionHandler()，否则 watchdog 会 SIGKILL
- **VALIDATE**: 模拟器注入 HRV 样本，验证背景回调触发

### Task 5: 实现 RMSSD 计算器

- **ACTION**: CREATE `Shared/Services/RMSSDCalculator.swift`
- **IMPLEMENT**:
  - HKHeartbeatSeriesQuery 查询心跳间隔
  - RMSSD = sqrt(mean(squared successive differences of IBIs))
  - 输入验证：至少需要 3 个 IBI 值
  - 输出精度：保留 1 位小数
- **VALIDATE**: 单元测试
  - 已知 IBI 序列 → 预期 RMSSD 值
  - 不足 3 个 IBI → nil
  - 空输入 → nil

### Task 6: 实现主动监测会话 (ActiveSessionManager)

- **ACTION**: CREATE `WatchApp/Services/ActiveSessionManager.swift`
- **IMPLEMENT**:
  - HKWorkoutSession(configuration: .mindAndBody)
  - HKLiveWorkoutBuilder 实时心率数据
  - HKHeartbeatSeriesQuery 实时 IBI 数据 → 实时 RMSSD
  - 会话状态管理 (idle → preparing → active → finished)
  - 自动保存 HRV 样本到 SwiftData
- **VALIDATE**: 模拟 workout 会话，验证数据采集流程
- **GOTCHA**: .mindAndBody 会记录到 Activity Rings，需向用户说明

### Task 7: 实现本地数据存储 (DataStore)

- **ACTION**: CREATE `Shared/Services/DataStore.swift`
- **IMPLEMENT**:
  - SwiftData ModelContainer + ModelContext
  - CRUD 操作: save, fetchRecent, fetchByDateRange, delete
  - 聚合查询: dailyAverage, weeklyAverage, monthlyAverage
  - 趋势计算: 7 天滑动平均对比
- **VALIDATE**: 单元测试所有 CRUD + 聚合操作

### Task 8: 实现 WatchConnectivity 同步

- **ACTION**: CREATE `Shared/Services/WatchConnectivityManager.swift`
- **IMPLEMENT**:
  - WCSession 激活和管理
  - Watch → iPhone: transferCurrentComplicationUserInfo (HRV readings)
  - 批量同步: 新数据累积后批量发送
  - 连接状态 UI 反馈
- **VALIDATE**: 配对模拟器测试数据传输

### Task 9: 实现 watchOS UI

- **ACTION**: CREATE Watch App View 文件组
- **IMPLEMENT**:
  - `DashboardView`: HRV 主卡片（SDNN + RMSSD）、趋势指示器、开始监测/历史按钮
  - `SessionView`: 实时 HRV 大屏显示、心率辅助、会话计时器、结束按钮
  - `HistoryView`: 历史记录列表 + 简短统计
  - `HrvWatchApp.swift`: App 入口，注入 dependencies
  - HrvComplication: 表盘复杂功能（显示最新 HRV）
- **VALIDATE**: watchOS 模拟器 UI 预览正常

### Task 10: 实现 iOS App UI

- **ACTION**: CREATE iOS App View 文件组
- **IMPLEMENT**:
  - `DashboardView`: 今日 24h 趋势折线图、SDNN/RMSSD 切换、7/30 天聚合
  - `ChartsView`: 详细图表（使用 Swift Charts），周/月/自定义时间段
  - `ExportView`: CSV 导出、数据源管理
  - `HrvApp.swift`: App 入口
- **VALIDATE**: iOS 模拟器 UI 预览正常

### Task 11: 实现 Complications

- **ACTION**: CREATE `WatchApp/Complication/HrvComplication.swift`
- **IMPLEMENT**:
  - CLKComplicationTimelineProvider
  - 显示最新 HRV 值 + 趋势箭头
  - 支持 Modular Small/Large, Circular, Graphic 等系列
  - 后台数据更新时刷新 complication
- **VALIDATE**: 在 complication 模拟器中验证

### Task 12: 集成测试 + 配置完善

- **ACTION**: 全面集成测试
- **IMPLEMENT**:
  - 模拟完整的 HRV 数据流：ObserverQuery → 存储 → UI → 同步
  - 测试 App 生命周期 (background/foreground 切换)
  - 测试授权拒绝/撤销场景
  - 测试无网络/低电量场景
- **VALIDATE**: 所有测试通过

---

## Testing Strategy

### Unit Tests to Write

| Test File | Test Cases | Validates |
|-----------|------------|-----------|
| `Tests/RMSSDCalculatorTests.swift` | Normal IBI → RMSSD, insufficient data, 0 input | RMSSD 算法正确性 |
| `Tests/DataStoreTests.swift` | CRUD, daily avg, weekly avg, date range query | 本地存储正确性 |
| `Tests/HealthKitManagerTests.swift` | Auth flow, query construction | HealthKit 管理 |
| `Tests/WatchConnectivityManagerTests.swift` | Message encoding/decoding | 数据传输 |

### Edge Cases Checklist

- [ ] 首次启动时 HealthKit 授权被拒绝
- [ ] 后台唤醒后 15 秒内未完成回调
- [ ] Apple Watch 未佩戴时（无 HRV 数据）
- [ ] watchOS 26 后台递送不稳定/停止
- [ ] 多次快速启动/停止监测会话
- [ ] 监测会话中 App 被系统终止
- [ ] iPhone ↔ Watch 连接断开（飞行模式）
- [ ] SwiftData 存储空间不足
- [ ] 时区/跨日线数据对齐

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

## Completion Checklist

- [ ] All 12 tasks completed in dependency order
- [ ] Each task validated immediately after completion
- [ ] All acceptance criteria met
- [ ] watchOS 模拟器完整流程测试通过
- [ ] iOS 模拟器完整流程测试通过

---

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| watchOS 26 后台 HKObserverQuery 不稳定 | HIGH | MEDIUM | 设计为容忍丢失更新；提供主动监测作为替代；用户可手动启动监测会话 |
| Apple Watch 第三方 App 无法触发实时心跳系列数据 | HIGH | HIGH | RMSSD 仅在主动 workout 会话期间可用；后台仅展示 SDNN |
| HealthKit 授权拒绝 | MEDIUM | HIGH | 优雅降级：无授权时显示引导界面，引导用户前往设置打开 |
| WatchConnectivity 同步延迟 | MEDIUM | LOW | 数据以 Watch 为主，iPhone 为辅；同步失败不影响本地数据 |
| 复杂功能更新频率受限 | LOW | MEDIUM | 使用 transferCurrentComplicationUserInfo 优化 |

---

## Notes

### 技术选型说明

- **SwiftData vs CoreData**: SwiftData 更现代，与 SwiftUI 集成更好，适用于 2025 年新项目
- **MVVM vs TCA**: MVVM 更简单，适合独立开发者；TCA 可后续引入
- **使用 HKWorkoutSession** 是因为这是 3rd party App 获取高频 HRV 数据的唯一可行途径
- RMSSD 计算参考了 HRV 学术标准 (Task Force of the European Society of Cardiology, 1996)

### 关于准确性的说明

Apple Watch 的 HRV 准确度在医学文献中已被验证：
- SDNN: Apple Watch 与 Polar H10 相关系数 r=0.82-0.92 (不同研究)
- RMSSD: 需要从 HeartbeatSeries 手动计算，支持 3rd party App 使用 workout session 获取
- 最佳准确场景：静坐/冥想时进行主动监测会话
- 影响因素：佩戴松紧、运动状态、皮肤温度

### 后续迭代方向 (第二期)

- iCloud 多设备同步
- 异常检测报警 (HRV 突然下降)
- 第三方蓝牙 HR 监测器支持 (Polar H10)
- 数据导出到 Apple Health
- HRV 生物反馈训练引导
