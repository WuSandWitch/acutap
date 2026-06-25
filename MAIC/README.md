# AcuTap — iOS App

AcuTap 是一個中醫穴位養生 App，透過 AR 即時點穴引導、AI 症狀分析、HealthKit 健康監測，提供個人化穴位養生體驗。

## 📱 功能總覽

| 功能 | 說明 | 資料來源 |
|:----|:-----|:---------|
| **今日點穴** | 每日推薦處方（依體質 × 節氣 × 健康） | 後端天氣/節氣 API + PrescriptionEngine |
| **AR 點穴** | 相機人體偵測 + 穴位光點疊合引導 | 本機 Vision / AVFoundation |
| **AI 症狀分析** | 輸入症狀 → 中醫辨證 → 穴位推薦 | 後端 `/api/symptom-analyze` |
| **HealthKit 同步** | 心率/睡眠/步數 → 中醫體質評估 | 本機 HealthKit → 後端 `/api/health/sync` |
| **天氣/節氣資訊** | 即時天氣 + 24節氣養生提示 | 後端 `/api/weather`, `/api/solar-term` |

## 🔄 前後端互動流程

```
┌──────────────────────────────────────────────────────────────────┐
│  iOS App 啟動流程                                                  │
│                                                                  │
│  MAICApp.task { await env.initialize() }                         │
│    ├─ 1. RealHealthService.requestAuthorization()                 │
│    │     ← HealthKit 授權（心率 HRV / 睡眠 / 步數 / SpO₂）       │
│    ├─ 2. GET /api/weather?city=Taipei                             │
│    │     ← 天氣 + TCM 養生提示                                    │
│    ├─ 3. GET /api/solar-term                                      │
│    │     ← 今日節氣 + 養生建議                                     │
│    ├─ 4. RealHealthService.fetchAndAnalyze()                      │
│    │     ← 從 HealthKit 讀取最新 7 天健康資料                      │
│    ├─ 5. POST /api/health/sync                                    │
│    │     ← 後端回傳中醫體質評估 + 建議                              │
│    └─ 6. PrescriptionEngine.generate(term, vitals, constitution)  │
│          ← 更新 DailyView 今日處方                                │
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│  AI 症狀分析流程                                                    │
│                                                                  │
│  AIAssistantView                                                  │
│    ├─ 使用者點選複選意圖（頭痛+失眠+焦慮）                         │
│    │  └─ POST /api/symptom-analyze                                │
│    │     Body: {"symptoms": ["頭痛","失眠","焦慮"]}               │
│    │     Response: {                                              │
│    │       "pattern": {"name": "肝氣鬱結", "description": "..."}, │
│    │       "acupoints": [{"id": "GV24", "nameZh": "神庭", ...}], │
│    │       "analysis": "根據您的症狀...",                          │
│    │       "lifestyleTips": ["練習深呼吸...", "多攝取..."]        │
│    │     }                                                        │
│    │                                                              │
│    ├─ 後端當機 → 降級為本地 keyword matching（10 組症狀組）       │
│    │                                                              │
│    └─ 使用者點「去 AR 點穴」→ ARAcupointView(session)             │
│          └─ BodyPoseDetector + AR 引導                            │
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│  HealthKit 同步流程                                                 │
│                                                                  │
│  1. App 啟動 → requestAuthorization()                            │
│     └─ 讀取：心率變異(HRV)、靜息心率、步數、睡眠、正念分鐘       │
│                                                                  │
│  2. fetchAndAnalyze()                                            │
│     └─ HKSampleQuery + HKStatisticsQuery 取最近 7 天             │
│                                                                  │
│  3. POST /api/health/sync                                        │
│     Body: {"snapshots": [{"date":"...", "hrv":45.2, ...}]}       │
│     Response: {                                                   │
│       "assessments": [{"name":"心率變異", "status":"一般", ...}], │
│       "overallStatus": "良好",                                    │
│       "tcmAssessment": "陰陽調和、心肺氣充足...",                 │
│       "recommendations": ["建議事項..."]                          │
│       "trend": {"direction": "improving", ...}                    │
│     }                                                             │
│                                                                  │
│  4. AppEnvironment.healthMetrics 更新                             │
│     └─ 顯示在 DailyView 健康摘要卡                                │
└──────────────────────────────────────────────────────────────────┘
```

## 🧩 資料架構

```
mock data            →  AppEnvironment.initialize() 成功後自動覆蓋
(user offline /       (所有 API 呼叫都有本地 fallback)
 backend down)
```

| 資料 | Mock 來源 | 真實來源 |
|:----|:----------|:---------|
| 天氣 | `MockDataProvider.weather` | 後端 GET /api/weather |
| 節氣 | `MockDataProvider.currentSolarTerm` | 後端 GET /api/solar-term |
| 健康 | `MockDataProvider.weeklyVitals` | 本機 HealthKit |
| 症狀分析 | `AssistantModel.match()` (keyword) | 後端 POST /api/symptom-analyze |
| AI 對話 | `AssistantModel.match()` (keyword) | 後端 POST /api/chat |
| 穴位資料 | `RealAcupointData.all` (79 穴) | 後端 GET /api/acupoints |

## 🏗 專案結構

```
MAIC/
├── MAICApp.swift              # @main — 啟動時 env.initialize()
├── App/
│   └── RootTabView.swift      # 3-Tab 導航
├── Features/
│   ├── Daily/DailyView.swift  # 每日首頁（今日處方 + 快捷點穴）
│   ├── AI/AIAssistantView.swift # AI 症狀分析 + 對話（串接後端）
│   ├── AR/
│   │   ├── ARAcupointView.swift   # AR 點穴主畫面
│   │   ├── BodyPoseDetector.swift # Vision 人體偵測
│   │   ├── CameraPreview.swift    # AVFoundation
│   │   └── RealAcupointData.swift # 79 穴真實資料
│   └── Profile/ProfileView.swift  # 個人設定
├── Services/
│   ├── APIConfig.swift         # 後端 Endpoint 設定
│   ├── APIService.swift        # HTTP client (async/await)
│   ├── SymptomService.swift    # 症狀分析 API 封裝
│   ├── RealHealthService.swift # HealthKit 真實服務
│   ├── MockDataProvider.swift  # 全部 Mock 資料
│   ├── HealthService.swift     # HealthServicing protocol
│   ├── AppEnvironment.swift    # 全域狀態（後端載入 + HealthKit）
│   └── PrescriptionEngine.swift # 處方生成引擎
├── Models/Models.swift         # 資料模型
└── DesignSystem/
    ├── Theme.swift             # 色彩/動畫系統
    └── Components.swift        # 通用 UI 元件
```

## 🔧 開發

### 必要設定

1. **HealthKit** — 在 Signing & Capabilities 加入 HealthKit，或在 Xcode 開啟專案時自動偵測（已加入 INFOPLIST_KEY 授權字串）
2. **後端 URL** — 預設 `http://localhost:8000`，可設定環境變數 `API_BASE_URL`
3. **Info.plist** — 已透過 INFOPLIST_KEY 設定相機 + HealthKit 授權說明

## 🧪 Mock → 真實資料切換策略

App 使用 **graceful degradation**：優先使用真實資料，後端不可用時自動降級到 Mock。

```
AppEnvironment.initialize()
  ├─ 後端可達 → 使用真實天氣、節氣、症狀分析
  └─ 後端不可達 → MockDataProvider 全部回退

HealthKit 未授權 → RealHealthService 回傳 MockDataProvider 資料
後端 API 失敗 → AssistantModel.match() 本地 keyword 降級
```

> iOS 17+ 最低版本，使用 SwiftUI + Observation framework + async/await
