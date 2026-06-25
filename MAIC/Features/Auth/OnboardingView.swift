//
//  OnboardingView.swift
//  MAIC
//
//  新手引導 — 權限 + TCM 體質問卷
//

import SwiftUI
import AVFoundation
import HealthKit

enum OnboardingStep: Int, CaseIterable {
    case welcome = 0
    case camera
    case health
    case constitution
    case done
}

// TCM 體質問卷題目
struct ConstitutionQuestion {
    let text: String
    let scores: [(answer: String, constitution: Constitution, weight: Double)]
}

let constitutionQuestions: [ConstitutionQuestion] = [
    .init(text: "平常容易疲倦、沒有精神嗎？", scores: [
        ("很少", .balanced, 0), ("有時", .qiDeficiency, 0.3), ("經常", .qiDeficiency, 0.6),
    ]),
    .init(text: "手腳容易冰冷嗎？", scores: [
        ("不會", .balanced, 0), ("天氣冷才會", .yangDeficiency, 0.3), ("常常冰冷", .yangDeficiency, 0.6),
    ]),
    .init(text: "容易口乾舌燥、手心發熱嗎？", scores: [
        ("不會", .balanced, 0), ("偶爾", .yinDeficiency, 0.3), ("經常", .yinDeficiency, 0.6),
    ]),
    .init(text: "容易緊張焦慮、胸悶嘆氣嗎？", scores: [
        ("很少", .balanced, 0), ("有時", .qiStagnation, 0.3), ("經常", .qiStagnation, 0.6),
    ]),
    .init(text: "皮膚容易出油、長痘或覺得身體沉重嗎？", scores: [
        ("不會", .balanced, 0), ("輕微", .dampHeat, 0.3), ("明顯", .dampHeat, 0.6),
    ]),
    .init(text: "容易過敏（鼻子、皮膚）嗎？", scores: [
        ("不會", .balanced, 0), ("輕微", .specialDiathesis, 0.3), ("明顯", .specialDiathesis, 0.6),
    ]),
]

struct OnboardingView: View {
    @State private var step: OnboardingStep = .welcome
    @State private var cameraGranted = false
    @State private var healthGranted = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var constitutionScores: [Constitution: Double] = [:]
    @State private var currentQuestion = 0
    @State private var savedConstitution: (Constitution, Double)?

    var onComplete: (UserProfile) -> Void

    var body: some View {
        VStack(spacing: 0) {
            progressBar

            Spacer()

            Group {
                switch step {
                case .welcome: welcomePage
                case .camera: cameraPage
                case .health: healthPage
                case .constitution: constitutionPage
                case .done: Color.clear
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))

            Spacer()

            VStack(spacing: Theme.Spacing.s) {
                if showError {
                    Text(errorMessage).font(.caption).foregroundStyle(.red).multilineTextAlignment(.center)
                }
                GlowButton(title: nextButtonTitle, systemImage: nextButtonIcon, action: handleNext)
                    .disabled(nextDisabled)
                if step != .welcome && step != .constitution {
                    Button("跳過") {
                        withAnimation(Theme.Motion.smooth) {
                            step = OnboardingStep(rawValue: step.rawValue + 1) ?? .done
                        }
                    }
                    .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .background(Color(.systemBackground))
    }

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(OnboardingStep.allCases, id: \.rawValue) { s in
                if s != .done {
                    Capsule()
                        .fill(s.rawValue <= step.rawValue ? Theme.teal : Color(.systemGray5))
                        .frame(height: 4)
                        .animation(.easeInOut, value: step)
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.top, Theme.Spacing.m)
    }

    // MARK: Buttons

    private var nextButtonTitle: String {
        switch step {
        case .welcome: "開始設定"
        case .camera: "允許相機權限"
        case .health: "下一步"
        case .constitution: currentQuestion < constitutionQuestions.count - 1 ? "下一題" : "完成"
        case .done: ""
        }
    }

    private var nextButtonIcon: String {
        switch step {
        case .welcome: "arrow.right"
        case .camera: "camera.viewfinder"
        case .health: "arrow.right"
        case .constitution: "arrow.right"
        case .done: ""
        }
    }

    private var nextDisabled: Bool {
        if step == .constitution { return savedConstitution == nil }
        return false
    }

    private func handleNext() {
        showError = false
        switch step {
        case .welcome:
            withAnimation(Theme.Motion.smooth) { step = .camera }
        case .camera:
            requestCameraAccess()
        case .health:
            requestHealthAccess()
        case .constitution:
            if currentQuestion < constitutionQuestions.count - 1 {
                currentQuestion += 1
                savedConstitution = nil
            } else {
                completeOnboarding()
            }
        case .done:
            break
        }
    }

    // MARK: Pages

    private var welcomePage: some View { /* same as before */ welcomeContent }
    private var cameraPage: some View { /* same */ cameraContent }
    private var healthPage: some View { /* same */ healthContent }

    // MARK: Constitution

    private var constitutionPage: some View {
        VStack(spacing: Theme.Spacing.l) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 40)).foregroundStyle(Theme.teal)
            Text("體質分析")
                .font(.title2.weight(.bold))
            Text(constitutionQuestions[currentQuestion].text)
                .font(.body).multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xl)

            VStack(spacing: 12) {
                ForEach(constitutionQuestions[currentQuestion].scores, id: \.answer) { opt in
                    Button {
                        selectAnswer(opt.constitution, weight: opt.weight)
                    } label: {
                        HStack {
                            Image(systemName: savedConstitution?.0 == opt.constitution ? "circle.fill" : "circle")
                                .foregroundStyle(Theme.teal)
                            Text(opt.answer)
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)

            if currentQuestion > 0 {
                Text("第 \(currentQuestion + 1) / \(constitutionQuestions.count) 題")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func selectAnswer(_ constitution: Constitution, weight: Double) {
        constitutionScores[constitution] = (constitutionScores[constitution] ?? 0) + weight
        // 如果選 balanced，不加分（維持現狀）
        if constitution == .balanced {
            // 不加分，但記錄選擇
        }
        savedConstitution = (constitution, weight)
        // 自動跳到下一題
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if currentQuestion < constitutionQuestions.count - 1 {
                withAnimation(Theme.Motion.smooth) {
                    currentQuestion += 1
                    savedConstitution = nil
                }
            } else {
                completeOnboarding()
            }
        }
    }

    private func completeOnboarding() {
        // 計算最高分的體質
        let dominant: Constitution
        if constitutionScores.isEmpty {
            dominant = .balanced
        } else {
            dominant = constitutionScores.max(by: { $0.value < $1.value })?.key ?? .balanced
        }
        // 歸一化分數
        let total = constitutionScores.values.reduce(0, +)
        let normalized = total > 0
            ? Dictionary(uniqueKeysWithValues: constitutionScores.map { ($0.key, $0.value / total) })
            : [.balanced: 1.0]

        let profile = UserProfile(
            name: "使用者",
            birthYear: Calendar.current.component(.year, from: Date()) - 25,
            constitution: normalized
        )
        withAnimation(Theme.Motion.smooth) { step = .done }
        onComplete(profile)
    }

    // MARK: Permissions

    private func requestCameraAccess() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraGranted = true; withAnimation { step = .health }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async { cameraGranted = granted; withAnimation { step = .health } }
            }
        default:
            showError = true; errorMessage = "請到設定 → 隱私權 → 相機 開啟權限"
        }
    }

    private func requestHealthAccess() {
        guard HKHealthStore.isHealthDataAvailable() else {
            healthGranted = false; withAnimation { step = .constitution }
            return
        }
        let types: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.quantityType(forIdentifier: .oxygenSaturation)!,
        ]
        HKHealthStore().requestAuthorization(toShare: nil, read: types) { success, _ in
            DispatchQueue.main.async {
                healthGranted = success
                withAnimation { step = .constitution }
            }
        }
    }
}

// Keep existing welcome/camera/health views
extension OnboardingView {
    private var welcomeContent: some View {
        VStack(spacing: Theme.Spacing.xl) {
            ZStack {
                Circle().fill(Theme.brandGradient).frame(width: 120, height: 120)
                    .shadow(color: Theme.teal.opacity(0.4), radius: 24, y: 8)
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 50, weight: .semibold)).foregroundStyle(.white)
            }
            VStack(spacing: 8) {
                Text("穴新達").font(.system(size: 40, weight: .bold))
                Text("Acutap").font(.title2).foregroundStyle(.secondary)
            }
            Text("用 AR 即時投影穴位在真人身上\n引導你正確按壓、養生保健")
                .font(.body).multilineTextAlignment(.center).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 16) {
                featureRow("camera.viewfinder", .teal, "AR 即時點穴", "前鏡頭偵測人體，穴位投影在真人身上")
                featureRow("heart.text.clipboard", .orange, "健康分析", "讀取 Apple Health 資料，個人化養生建議")
                featureRow("sparkles", .purple, "AI 中醫助手", "症狀分析 + 穴位推薦")
            }
        }
    }

    private var cameraContent: some View {
        VStack(spacing: Theme.Spacing.l) {
            Image(systemName: "camera.viewfinder").font(.system(size: 60)).foregroundStyle(Theme.teal)
            Text("需要相機權限").font(.title2.weight(.bold))
            Text("穴新達需要使用前鏡頭\n在您的身體上即時投影穴位位置")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
            statusBadge(cameraGranted ? "已允許" : "未授權", cameraGranted ? .green : .red)
        }
    }

    private var healthContent: some View {
        VStack(spacing: Theme.Spacing.l) {
            Image(systemName: "heart.text.clipboard").font(.system(size: 60)).foregroundStyle(.orange)
            Text("需要健康資料權限").font(.title2.weight(.bold))
            Text("讀取心率、睡眠、步數等資料\n提供更精準的個人化穴位養生建議")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
            statusBadge(healthGranted ? "已允許" : "未授權", healthGranted ? .green : .red)
        }
    }

    private func featureRow(_ icon: String, _ color: Color, _ title: String, _ desc: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.title3).foregroundStyle(color).frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(desc).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func statusBadge(_ label: String, _ color: Color) -> some View {
        Text(label).font(.caption.weight(.semibold)).foregroundStyle(color)
            .padding(.horizontal, 12).padding(.vertical, 5)
            .background(color.opacity(0.12), in: Capsule())
    }
}

#Preview {
    OnboardingView(onComplete: { _ in })
}
