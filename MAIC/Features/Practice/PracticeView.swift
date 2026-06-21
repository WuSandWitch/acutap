import SwiftUI
import Combine

struct PracticeView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    let prescription: Prescription

    @State private var currentIndex = 0
    @State private var elapsed: Int = 0
    @State private var isRunning = true
    @State private var side: BodyPoint.Side = .front
    @State private var showARSheet = false
    @State private var completed = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var current: Acupoint {
        prescription.acupoints[min(currentIndex, prescription.acupoints.count - 1)]
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            sidePicker
            BodyMapView(side: side, points: prescription.acupoints, highlighted: current)
                .frame(maxHeight: .infinity)
                .padding(.horizontal, Theme.Spacing.l)
            infoCard
            timerSection
        }
        .padding(.bottom, Theme.Spacing.l)
        .background(Color(.systemBackground))
        .navigationTitle("穴位引導")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showARSheet = true } label: {
                    Image(systemName: "visionpro")
                }
            }
        }
        .fullScreenCover(isPresented: $showARSheet) { ARPlaceholderView() }
        .fullScreenCover(isPresented: $completed) { completionView }
        .onReceive(timer) { _ in tick() }
        .onAppear { side = current.bodyPoint.side }
    }

    private var sidePicker: some View {
        Picker("", selection: $side) {
            Text("正面").tag(BodyPoint.Side.front)
            Text("背面").tag(BodyPoint.Side.back)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, Theme.Spacing.l)
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(current.nameZh).font(.title3.weight(.semibold))
                Text(current.pinyin).font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                PillTag(text: current.meridian)
            }
            Text(current.location)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                ForEach(current.indications, id: \.self) { ind in
                    Text(ind).font(.caption).foregroundStyle(.secondary)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color(.secondarySystemBackground), in: Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .padding(.horizontal, Theme.Spacing.m)
    }

    private var timerSection: some View {
        HStack(spacing: Theme.Spacing.l) {
            RingTimer(progress: Double(elapsed) / Double(max(1, current.pressSeconds)),
                      label: "\(max(0, current.pressSeconds - elapsed))")
                .frame(width: 110, height: 110)
            VStack(alignment: .leading, spacing: 10) {
                Text("Step \(currentIndex + 1) / \(prescription.acupoints.count)")
                    .font(.subheadline).foregroundStyle(.secondary)
                HStack(spacing: Theme.Spacing.s) {
                    Button {
                        isRunning.toggle()
                    } label: {
                        Image(systemName: isRunning ? "pause.fill" : "play.fill")
                            .frame(width: 44, height: 44)
                            .background(Color(.secondarySystemBackground), in: Circle())
                            .foregroundStyle(.primary)
                    }
                    Button(action: advance) {
                        HStack { Text("下一步"); Image(systemName: "chevron.right") }
                            .font(.headline)
                            .padding(.horizontal, Theme.Spacing.l)
                            .padding(.vertical, 12)
                            .background(Theme.brandGradient, in: Capsule())
                            .foregroundStyle(.white)
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.l)
    }

    private var completionView: some View {
        VStack(spacing: Theme.Spacing.l) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 80))
                .foregroundStyle(Theme.brandGradient)
            Text("完成今日按摩").font(.title.weight(.semibold))
            Text("已完成 \(prescription.acupoints.count) 個穴位 · \(prescription.totalSeconds) 秒")
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                env.recordCompletion(prescription)
                completed = false
                dismiss()
            } label: {
                Text("返回")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.brandGradient, in: Capsule())
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, Theme.Spacing.l)
            Button("再來一次") {
                completed = false
                currentIndex = 0
                elapsed = 0
                isRunning = true
            }
            .foregroundStyle(.secondary)
            .padding(.bottom, Theme.Spacing.l)
        }
        .background(Color(.systemBackground).ignoresSafeArea())
    }

    private func tick() {
        guard isRunning, !completed else { return }
        elapsed += 1
        if elapsed >= current.pressSeconds {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            advance()
        }
    }

    private func advance() {
        if currentIndex + 1 >= prescription.acupoints.count {
            completed = true
            isRunning = false
        } else {
            currentIndex += 1
            elapsed = 0
            side = current.bodyPoint.side
        }
    }
}

struct ARPlaceholderView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Image("ARPreview")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            // 漸層遮罩讓上下 HUD 文字更易讀
            LinearGradient(
                colors: [.black.opacity(0.55), .clear, .clear, .black.opacity(0.55)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack {
                HStack {
                    PillTag(text: "AR 即時引導", systemImage: "visionpro")
                        .colorScheme(.dark)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                }
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.top, Theme.Spacing.s)

                Spacer()

                VStack(spacing: 4) {
                    Text("Step 1 / 4 · 太陽穴")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("跟著光點，深吸 3 秒 · 慢按 3 秒")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 18)
                .background(.ultraThinMaterial, in: Capsule())
                .colorScheme(.dark)
                .padding(.bottom, Theme.Spacing.xl)
            }
        }
        .statusBarHidden()
    }
}
