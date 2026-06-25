# Acutap — AR 智慧點穴

iOS 即時 AR 點穴 App。用前鏡頭偵測人體，在真人身上投影穴位，引導按壓。

## 🚀 功能

- **即時 AR 點穴** — 前鏡頭 + Vision 人體姿勢偵測，穴位投影在真人身上
- **三種偵測模式** — 自動切換：
  - 🟢 **全身模式** — 偵測到 6+ 關節，全身穴位投影
  - 🟠 **臉部模式** — 只有臉部可見，自動切換到 Face Mesh 投影臉部穴位
  - **數學 Fallback** — 沒人時自動降級到排版模式
- **引導點穴** — 選部位 → 跟著計時器按壓
- **79 個真實穴位** — 基於 bankroz/acupoint-platform (MediaPipe 骨骼定位) + WHO 標準
- **AI 助手** — 情緒/症狀 → 推薦穴位

## 📁 架構

```
MAIC/
├── Features/AR/
│   ├── ARAcupointView.swift      ← AR 主畫面
│   ├── BodyPoseDetector.swift    ← Vision 人體 + 臉部偵測
│   ├── CameraPreview.swift       ← 前鏡頭串接
│   └── RealAcupointData.swift    ← 79 穴位真實資料集
├── Services/
│   ├── MockDataProvider.swift    ← 資料提供（已改用真實穴位）
│   ├── AppEnvironment.swift      ← 全域環境
│   ├── PrescriptionEngine.swift  ← 處方推薦引擎
│   └── HealthService.swift       ← HealthKit（Mock）
├── Models/Models.swift           ← 資料模型
├── DesignSystem/                 ← Theme + Components
├── AI/AIAssistantView.swift      ← AI 聊天助手
├── Daily/DailyView.swift         ← 每日點穴
└── App/RootTabView.swift         ← 主分頁
```

## 🧠 AR 偵測流程

```
AVCaptureSession (前鏡頭)
  └→ AVCaptureVideoDataOutput
       └→ VNDetectHumanBodyPoseRequest   (18 關節)
       └→ VNDetectFaceRectanglesRequest  (臉部範圍)
       └→ VNDetectFaceLandmarksRequest   (臉部特徵點)
            └→ DetectedBody
                 ├── detectionMode: .fullBody / .faceOnly / .none
                 ├── project(bodyPoint)      → 全身投影
                 └── projectFace(bodyPoint)  → 臉部投影
                      └→ ARAcupointView 顯示穴位標記
```

## 🗺️ 穴位資料

79 穴，涵蓋 14 經脈 + 經外奇穴：

| 經脈 | 穴數 | 涵蓋 |
|:----|:----|:-----|
| 任脈 | 11 | 膻中、關元、中脘… |
| 督脈 | 11 | 百會、命門、大椎… |
| 足太陽膀胱經 | 15 | 肺俞、腎俞、委中… |
| 足陽明胃經 | 14 | 足三里、天樞… |
| 足少陽膽經 | 11 | 風池、肩井、環跳… |
| 其他經脈 | 17 | 合谷、內關、神門… |

資料來源：
- [bankroz/acupoint-platform](https://github.com/bankroz/acupoint-platform) — MediaPipe Pose 骨骼定位
- WHO Standard Acupuncture Point Locations

## 📋 開發狀態

### ✅ 已正式

| 功能 | 狀態 | 技術 |
|:----|:-----|:-----|
| 穴位資料 | ✅ **已正式** 79穴 (bankroz + WHO) | `RealAcupointData.swift` |
| AR 人體偵測 | ✅ **已正式** Vision + Face Mesh | `BodyPoseDetector.swift` |
| 即時 AR 投影 | ✅ **已正式** 全身 / 臉部 / fallback 三模式 | `ARAcupointView.swift` |
| AR 引導點穴 | ✅ **已正式** 計時器 + 導引流程 | `ARAcupointView.swift` |
| 每日點穴主畫面 | ✅ **已正式** UI 完整 | `DailyView.swift` |
| AI 助手 UI | ✅ **已正式** 對話 + 複選 | `AIAssistantView.swift` |
| 設計系統 | ✅ **已正式** 漸層、動畫、元件 | `DesignSystem/` |

### ⚠️ 仍為 Mock（待實作）

#### HealthService.swift — 真實健康資料 🔴 P0

```swift
// 現在：MockHealthService → SeededRandom 亂數
func latestSnapshot() -> VitalSnapshot { provider.latestVital }
// 需要：HKHealthStore 讀取真實 HRV、睡眠、靜息心率、步數
```

#### AIAssistantView.swift — 真實 AI 對話 🔴 P0

```swift
// 現在：12 組 if-else keyword matching
private func match(_ q: String) -> (String, [String]) { ... }
// 需要：串接 LLM API (OpenAI GPT-4o-mini / Claude)
```

#### MockDataProvider.swift — 天氣 + 節氣 🟡 P1

| 現在（死寫） | 需要改成 |
|:------------|:---------|
| `weather: 臺北市 29°C 濕悶` | OpenWeatherMap API 即時天氣 |
| `currentSolarTerm: 小滿` | 節氣計算公式或 API |
| `weeklyVitals: SeededRandom` | HealthKit 真實 7 天資料 |

#### AppEnvironment.swift — 真實用戶資料 🟡 P1

| 現在 | 需要改成 |
|:----|:---------|
| `profile: .demo (Luis)` | 註冊流程 + UserDefaults / CloudKit |
| `practiceHistory: []` 記憶體陣列 | 雲端同步（Firebase / iCloud） |
| `todaysPrescription` 無自動更新 | 每日定時重新生成 |

#### ProfileView.swift — 版本 🟢 P2

| 現在 | 需要改成 |
|:----|:---------|
| `版本: 0.1.0 (Mock)` | 正確版號 |
| `資料來源: 本地端模擬` | 真實資料來源描述 |

### 🗺️ 後端架構構思

```
┌─────────────────────────────────────┐
│          iOS App (MAIC)             │
├──────────────────┬──────────────────┤
│  Local Only      │  Needs Backend   │
├──────────────────┼──────────────────┤
│  • Vision AR     │  • AI 對話       │
│  • AVFoundation  │    (OpenAI API)  │
│  • HealthKit     │  • 天氣 + 節氣   │
│  • UserDefaults  │    (OpenWeather) │
│  • SwiftUI       │  • 雲端存檔      │
│                  │    (Firebase)    │
│                  │  • 用戶認證      │
│                  │    (Sign in w/   │
│                  │     Apple)       │
└──────────────────┴──────────────────┘
```

#### 建議服務

| 服務 | 用途 | 成本 |
|:----|:------|:-----|
| 🌤 **OpenWeatherMap API** | 天氣溫度 + 濕度 | 免費（60 calls/min） |
| 🧠 **OpenAI GPT-4o-mini** | AI 助手對話 | ~$0.15/1M tokens |
| ☁️ **Firebase Firestore** | 用戶設定 + 紀錄同步 | 免費 tier |
| 🔑 **Sign in with Apple** | 認證 | 免費 |
| 📱 **HealthKit** | 心率、睡眠、步數 | 免費（原生） |

> 💡 **MVP 建議：** 先做 HealthKit（無需後端）+ OpenAI API 接起來（一條 API key 搞定），就有感升級。

## 🛠️ 開發

```bash
# 需要 Xcode 15+ / iOS 17+
open MAIC.xcodeproj
```

## 📦 依賴

- Vision (`VNDetectHumanBodyPoseRequest`, `VNDetectFaceLandmarksRequest`)
- AVFoundation (`AVCaptureSession`)
- SwiftUI
- Swift
