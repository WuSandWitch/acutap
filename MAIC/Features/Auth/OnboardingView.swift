//
//  OnboardingView.swift
//  MAIC
//
//  新手引導 — 只做權限要求（名字從 Google 帳號取）
//

import SwiftUI
import AVFoundation
import HealthKit

enum OnboardingStep: Int, CaseIterable {
    case welcome = 0
    case camera
    case health
    case done

    var title: String {
        switch self {
        case .welcome: "穴新達"
        case .camera: "相機權限"
        case .health: "健康資料"
        case .done: "開始"
        }
    }
}

struct OnboardingView: View {
    @State private var step: OnboardingStep = .welcome
    @State private var cameraGranted = false
    @State private var healthGranted = false
    @State private var showError = false
    @State private var errorMessage = ""

    var onComplete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // 進度條
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

            Spacer()

            Group {
                switch step {
                case .welcome: welcomePage
                case .camera: cameraPage
                case .health: healthPage
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
                    Text(errorMessage)
                        .font(.caption).foregroundStyle(.red).multilineTextAlignment(.center)
                }
                GlowButton(title: nextButtonTitle, systemImage: nextButtonIcon, action: handleNext)
                if step != .welcome {
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

    private var nextButtonTitle: String {
        switch step {
        case .welcome: "開始設定"
        case .camera: "允許相機權限"
        case .health: "完成，前往登入"
        case .done: ""
        }
    }

    private var nextButtonIcon: String {
        switch step {
        case .welcome: "arrow.right"
        case .camera: "camera.viewfinder"
        case .health: "arrow.right"
        case .done: ""
        }
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
        case .done:
            break
        }
    }

    // MARK: Pages

    private var welcomePage: some View {
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
                .padding(.horizontal, Theme.Spacing.xl)
            VStack(alignment: .leading, spacing: 16) {
                featureRow("camera.viewfinder", Theme.teal, "AR 即時點穴", "前鏡頭偵測人體，穴位投影在真人身上")
                featureRow("heart.text.clipboard", .orange, "健康分析", "讀取 Apple Health 資料，個人化養生建議")
                featureRow("sparkles", .purple, "AI 中醫助手", "症狀分析 + 穴位推薦")
            }
            .padding(.horizontal, Theme.Spacing.m)
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

    private var cameraPage: some View {
        VStack(spacing: Theme.Spacing.l) {
            Image(systemName: "camera.viewfinder").font(.system(size: 60)).foregroundStyle(Theme.teal).padding(.bottom, 8)
            Text("需要相機權限").font(.title2.weight(.bold))
            Text("穴新達需要使用前鏡頭\n在您的身體上即時投影穴位位置")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
            statusBadge(cameraGranted ? "已允許" : "未授權", cameraGranted ? .green : .red)
        }
        .padding(.horizontal, Theme.Spacing.xl)
    }

    private var healthPage: some View {
        VStack(spacing: Theme.Spacing.l) {
            Image(systemName: "heart.text.clipboard").font(.system(size: 60)).foregroundStyle(.orange).padding(.bottom, 8)
            Text("需要健康資料權限").font(.title2.weight(.bold))
            Text("讀取心率、睡眠、步數等資料\n提供更精準的個人化穴位養生建議")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
            statusBadge(healthGranted ? "已允許" : "未授權", healthGranted ? .green : .red)
        }
        .padding(.horizontal, Theme.Spacing.xl)
    }

    private func statusBadge(_ label: String, _ color: Color) -> some View {
        Text(label).font(.caption.weight(.semibold)).foregroundStyle(color)
            .padding(.horizontal, 12).padding(.vertical, 5)
            .background(color.opacity(0.12), in: Capsule())
    }

    // MARK: Permissions

    private func requestCameraAccess() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraGranted = true
            withAnimation(Theme.Motion.smooth) { step = .health }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    cameraGranted = granted
                    withAnimation(Theme.Motion.smooth) { step = .health }
                }
            }
        default:
            cameraGranted = false
            errorMessage = "請到設定 → 隱私權 → 相機 開啟權限"
            showError = true
        }
    }

    private func requestHealthAccess() {
        guard HKHealthStore.isHealthDataAvailable() else {
            healthGranted = false
            withAnimation(Theme.Motion.smooth) { step = .done }
            onComplete()
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
                withAnimation(Theme.Motion.smooth) { step = .done }
                onComplete()
            }
        }
    }
}

#Preview {
    OnboardingView(onComplete: {})
}
