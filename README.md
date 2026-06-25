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
│   └── HealthService.swift       ← HealthKit
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

## 🛠️ 開發

### Build

```bash
# 需要 Xcode 15+ / iOS 17+
open MAIC.xcodeproj
```

### 已經正式

| 功能 | 狀態 | 技術 |
|:----|:-----|:-----|
| 穴位資料 | ✅ 79穴 (bankroz + WHO) | `RealAcupointData.swift` |
| AR 人體偵測 | ✅ Vision + Face Mesh | `BodyPoseDetector.swift` |
| 即時 AR 投影 | ✅ 全身 / 臉部 / fallback | `ARAcupointView.swift` |
| AR 引導點穴 | ✅ 計時器 + 導引流程 | `ARAcupointView.swift` |
| 每日點穴主畫面 | ✅ UI 完整 | `DailyView.swift` |
| AI 助手 UI | ✅ 對話 + 複選 | `AIAssistantView.swift` |
| 設計系統 | ✅ 漸層、動畫、元件 | `DesignSystem/` |

### 待實作

| 優先 | 功能 | 檔案 | 現在 | 需要改成 |
|:----:|:----|:-----|:-----|:---------|
| 🔴 P0 | **AI 真正對話** | `AIAssistantView.swift` | 12 組 keyword matching | 串 LLM API (OpenAI/Claude) |
| 🔴 P0 | **HealthKit** | `HealthService.swift` | `SeededRandom` 亂數 | 讀取 Apple Health 真實資料 |
| 🟡 P1 | **天氣 + 節氣** | `MockDataProvider.swift` | 死寫「小滿」「臺北 29°C」 | OpenWeatherMap + 節氣計算 |
| 🟡 P1 | **雲端存檔** | `AppEnvironment.swift` | App 重開就消失 | Firebase / iCloud Sync |
| 🟢 P2 | **用戶認證** | `ProfileView.swift` | 永遠的 Luis | Sign in with Apple |
| 🟢 P2 | **個人化處方** | `PrescriptionEngine.swift` | 硬編碼 8 組 | AI 動態生成 + TCM 知識庫 |

### 需要的後端

| 服務 | 用途 | 建議 |
|:----|:------|:-----|
| 🌤 OpenWeatherMap | 天氣 + TCM 提示 | 免費 tier |
| 🧠 OpenAI / Claude API | AI 助手對話 | GPT-4o-mini 便宜又快 |
| ☁️ Firebase | 認證 + 資料庫 | 免費 tier 夠用 |
| 📱 HealthKit | 心率、睡眠、步數 | 原生，免後端 |

## 📦 依賴

- Vision (`VNDetectHumanBodyPoseRequest`, `VNDetectFaceLandmarksRequest`)
- AVFoundation (`AVCaptureSession`)
- SwiftUI
- Swift
