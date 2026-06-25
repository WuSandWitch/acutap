import SwiftUI
import Combine
import Vision

// MARK: - 身體區域（自由探索用，由 AI 與 AR 共用）

enum BodyRegion: String, CaseIterable, Identifiable {
    case head, neckShoulder, chest, abdomen, arm, leg
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .head: "頭部"
        case .neckShoulder: "頸肩"
        case .chest: "胸口"
        case .abdomen: "腹部"
        case .arm: "手部"
        case .leg: "腿足"
        }
    }
    var symbol: String {
        switch self {
        case .head: "brain.head.profile"
        case .neckShoulder: "figure.stand"
        case .chest: "lungs.fill"
        case .abdomen: "circle.grid.cross"
        case .arm: "hand.raised.fill"
        case .leg: "figure.walk"
        }
    }
    var symptomHint: String {
        switch self {
        case .head: "頭痛、頭暈、提神醒腦"
        case .neckShoulder: "肩頸僵硬、落枕"
        case .chest: "胸悶、心悸、氣短"
        case .abdomen: "脹氣、消化不良、經痛"
        case .arm: "手痠、滑鼠手、安神"
        case .leg: "腿痠、疲倦、助眠"
        }
    }
    var acupointIDs: [String] {
        switch self {
        case .head: ["GV20", "GB20"]
        case .neckShoulder: ["GB21", "GB20", "LI4"]
        case .chest: ["CV17", "PC6", "LU7"]
        case .abdomen: ["ST36", "SP6"]
        case .arm: ["PC6", "HT7", "LI4"]
        case .leg: ["ST36", "SP6", "LV3", "BL23"]
        }
    }
}

// MARK: - AR 點穴主畫面

struct ARAcupointView: View {
    let initialSession: PointSession?

    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    @State private var camera = CameraController()
    @State private var activeSession: PointSession?
    @State private var selectedRegion: BodyRegion = .head
    @State private var index = 0
    @State private var elapsed = 0
    @State private var running = true
    @State private var completed = false
    @State private var scan = false
    @State private var appeared = false
    @State private var showFaceHint = false
    @State private var showDebugJoints = true

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(session: PointSession? = nil) {
        self.initialSession = session
        _activeSession = State(initialValue: session)
    }

    private var isGuided: Bool { activeSession != nil }
    private var launchedModally: Bool { initialSession != nil }

    /// 偵測模式標籤
    private var modeLabel: String {
        guard camera.isLive else { return "示意模式" }
        switch camera.poseDetector.detectionMode {
        case .fullBody:  return "AR 全身點穴"
        case .faceOnly:  return "AR 臉部穴位"
        case .none:      return "AR 待偵測"
        }
    }

    /// 當前要顯示的穴位
    private var markers: [Acupoint] {
        if let s = activeSession { return s.acupoints }
        return env.data.acupoints(ids: selectedRegion.acupointIDs)
    }
    /// 引導模式中是否有身體穴位（非純臉部）
    private var hasBodyAcupoints: Bool {
        guard let s = activeSession else { return false }
        return s.acupoints.contains { !DetectedBody.isFaceAcupoint($0.bodyPoint) }
    }
    private var current: Acupoint? {
        guard isGuided, !markers.isEmpty else { return nil }
        return markers[min(index, markers.count - 1)]
    }

    var body: some View {
        ZStack {
            cameraLayer
            legibilityGradient
            GeometryReader { geo in
                ZStack {
                    if !isGuided { scannerGuide(in: geo.size) }
                    meridianPath(in: geo.size)
                    markerOverlay(in: geo.size)
                    if showDebugJoints { debugJointOverlay(in: geo.size) }
                }
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                topHUD
                Spacer()
                if isGuided { guidedPanel } else { freePanel }
            }
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.top, Theme.Spacing.s)
            .padding(.bottom, Theme.Spacing.l)

            // FaceOnly 提示
            if showFaceHint {
                VStack(spacing: 8) {
                    Image(systemName: "arrowshape.turn.up.backward.fill")
                        .font(.title2)
                    Text("請退後讓鏡頭看到全身")
                        .font(.headline)
                    Text("目前只偵測到臉部，看不到身體穴位")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .foregroundStyle(.white)
                .padding(20)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .environment(\.colorScheme, .dark)
                .transition(.move(edge: .top).combined(with: .opacity))
                .frame(maxHeight: .infinity, alignment: .center)
                .padding(.bottom, 100)
            }

            if completed { completionOverlay }
        }
        .background(Color.black)
        .preferredColorScheme(.dark)
        .statusBarHidden(isGuided)
        .onAppear {
            camera.start()
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { scan = true }
            withAnimation(Theme.Motion.smooth) { appeared = true }
            if isGuided { elapsed = 0; running = true }
        }
        .onDisappear { camera.stop() }
        .onReceive(timer) { _ in tick() }
        .onChange(of: camera.poseDetector.detectionMode) { _, mode in
            // faceOnly + session 有身體穴位 → 提示
            if mode == .faceOnly && hasBodyAcupoints {
                withAnimation { showFaceHint = true }
            } else {
                withAnimation { showFaceHint = false }
            }
        }
    }

    // MARK: Camera / background

    @ViewBuilder private var cameraLayer: some View {
        if camera.isLive {
            CameraPreview(session: camera.session)
                .ignoresSafeArea()
                .transition(.opacity)
        } else {
            // Fallback：模擬器/未授權時顯示示意畫面
            Image("ARPreview")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .overlay(Color.black.opacity(0.25))
        }
    }

    private var legibilityGradient: some View {
        LinearGradient(
            colors: [.black.opacity(0.55), .clear, .clear, .black.opacity(0.7)],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: Scanner guide（自由模式：對齊框 + 掃描線）

    private func scannerGuide(in size: CGSize) -> some View {
        let rect = CGRect(x: size.width * 0.16, y: size.height * 0.16,
                          width: size.width * 0.68, height: size.height * 0.64)
        return ZStack {
            // 四角括弧
            ForEach(0..<4, id: \.self) { corner in
                CornerBracket()
                    .stroke(Theme.aqua.opacity(0.9), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 34, height: 34)
                    .rotationEffect(.degrees(Double(corner) * 90))
                    .position(cornerPoint(corner, in: rect))
            }
            // 掃描線
            LinearGradient(colors: [.clear, Theme.aqua.opacity(0.9), .clear],
                           startPoint: .leading, endPoint: .trailing)
                .frame(width: rect.width, height: 2.5)
                .shadow(color: Theme.aqua, radius: 6)
                .position(x: rect.midX,
                          y: rect.minY + rect.height * (scan ? 0.96 : 0.04))
        }
    }

    private func cornerPoint(_ c: Int, in r: CGRect) -> CGPoint {
        switch c {
        case 0: CGPoint(x: r.minX + 17, y: r.minY + 17)
        case 1: CGPoint(x: r.maxX - 17, y: r.minY + 17)
        case 2: CGPoint(x: r.maxX - 17, y: r.maxY - 17)
        default: CGPoint(x: r.minX + 17, y: r.maxY - 17)
        }
    }

    // MARK: 經絡連線

    private func meridianPath(in size: CGSize) -> some View {
        Path { p in
            let pts = markers.enumerated().map { (i, point) in
                position(for: point, index: i, total: markers.count, in: size)
            }
            guard let first = pts.first else { return }
            p.move(to: first)
            for pt in pts.dropFirst() { p.addLine(to: pt) }
        }
        .stroke(Theme.aqua.opacity(0.35),
                style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [2, 6]))
        .opacity(appeared ? 1 : 0)
    }

    // MARK: 穴位光點

    private func markerOverlay(in size: CGSize) -> some View {
        ForEach(Array(markers.enumerated()), id: \.element.id) { i, point in
            let isCurrent = isGuided && point.id == current?.id
            VStack(spacing: 6) {
                BreathingDot(size: isCurrent ? 34 : 22, labelInitial: nil)
                    .scaleEffect(isCurrent ? 1.0 : 0.9)
                Text(point.nameZh)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(.ultraThinMaterial, in: Capsule())
                    .opacity(isGuided && !isCurrent ? 0.45 : 1)
            }
            .position(position(for: point, index: i, total: markers.count, in: size))
            .scaleEffect(appeared ? 1 : 0.3)
            .opacity(appeared ? 1 : 0)
            .animation(Theme.Motion.bouncy.delay(Double(i) * 0.08), value: appeared)
            .animation(Theme.Motion.snappy, value: current?.id)
        }
    }

    /// 將穴位投射到螢幕位置（智能選擇投影模式）
    private func position(for acupoint: Acupoint, index: Int, total: Int, in size: CGSize) -> CGPoint {
        guard let body = camera.poseDetector.detectedBody, body.boundingBox != .zero else {
            return fallbackAnchor(index: index, total: total, in: size)
        }

        // 1. 嘗試 Vision 關節點定位（62 個核心穴精準對位）
        // 2. 臉部穴位用臉部 box
        // 3. 全身 bounding box fallback
        return body.smartProject(acupoint: acupoint, viewSize: size)
    }

    /// 數學編排（無身體偵測時的 fallback）
    private func fallbackAnchor(index i: Int, total n: Int, in size: CGSize) -> CGPoint {
        let t = n <= 1 ? 0.5 : Double(i) / Double(n - 1)
        let y = 0.26 + t * 0.5
        let x = 0.5 + sin(t * .pi * 2) * 0.17
        return CGPoint(x: x * size.width, y: y * size.height)
    }

    // MARK: Debug — 顯示 Vision 關節點

    private func debugJointOverlay(in size: CGSize) -> some View {
        guard let body = camera.poseDetector.detectedBody else {
            return AnyView(EmptyView())
        }
        var dots: [String: CGPoint] = [:]

        // Body joints
        let jointLabels: [VNHumanBodyPoseObservation.JointName: String] = [
            .neck: "頸", .root: "根",
            .leftShoulder: "左肩", .rightShoulder: "右肩",
            .leftElbow: "左肘", .rightElbow: "右肘",
            .leftWrist: "左腕", .rightWrist: "右腕",
            .leftHip: "左髖", .rightHip: "右髖",
            .leftKnee: "左膝", .rightKnee: "右膝",
            .leftAnkle: "左踝", .rightAnkle: "右踝",
            .leftEar: "左耳", .rightEar: "右耳",
        ]
        for (joint, label) in jointLabels {
            if let pt = body.joints[joint] {
                let x = pt.x * size.width
                let y = pt.y * size.height
                dots[label] = CGPoint(x: x, y: y)
            }
        }

        // Face rect
        var faceRect: CGRect?
        if let fr = body.faceRect {
            let x = fr.minX * size.width
            let y = fr.minY * size.height
            let w = fr.width * size.width
            let h = fr.height * size.height
            faceRect = CGRect(x: x, y: y, width: w, height: h)
        }

        return AnyView(
            ZStack {
                // Face box
                if let fr = faceRect {
                    Rectangle()
                        .stroke(Color.orange.opacity(0.6), lineWidth: 2)
                        .frame(width: fr.width, height: fr.height)
                        .position(x: fr.midX, y: fr.midY)
                }

                // Joint dots
                ForEach(Array(dots.keys.sorted()), id: \.self) { label in
                    if let pt = dots[label] {
                        ZStack {
                            Circle().fill(Color.yellow.opacity(0.8))
                                .frame(width: 12, height: 12)
                            Text(label)
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.yellow)
                                .offset(y: -14)
                        }
                        .position(pt)
                    }
                }

                // Hand joints
                if let leftHand = body.handJoints[.left] {
                    ForEach(Array(leftHand.keys), id: \.rawValue) { j in
                        if let pt = leftHand[j] {
                            let x = pt.x * size.width
                            let y = pt.y * size.height
                            Circle().fill(Color.cyan.opacity(0.8))
                                .frame(width: 6, height: 6)
                                .position(x: x, y: y)
                        }
                    }
                }
                if let rightHand = body.handJoints[.right] {
                    ForEach(Array(rightHand.keys), id: \.rawValue) { j in
                        if let pt = rightHand[j] {
                            let x = pt.x * size.width
                            let y = pt.y * size.height
                            Circle().fill(Color.green.opacity(0.8))
                                .frame(width: 6, height: 6)
                                .position(x: x, y: y)
                        }
                    }
                }
            }
        )
    }

    // MARK: Top HUD

    private var topHUD: some View {
        HStack {
            HStack(spacing: 6) {
                // 偵測模式指示
                if let body = camera.poseDetector.detectedBody, body.boundingBox != .zero {
                    switch body.detectionMode {
                    case .fullBody:
                        Image(systemName: "figure.stand")
                            .font(.caption).foregroundStyle(.green)
                    case .faceOnly:
                        Image(systemName: "face.smiling")
                            .font(.caption).foregroundStyle(.orange)
                    case .none:
                        Image(systemName: "questionmark")
                            .font(.caption).foregroundStyle(.gray)
                    }
                }

                PillTag(text: modeLabel,
                        systemImage: "camera.viewfinder", tint: .white)
                    .environment(\.colorScheme, .dark)
                    .background(.ultraThinMaterial, in: Capsule())
            }

            Spacer()

            if isGuided {
                Button {
                    endGuided()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(.ultraThinMaterial, in: Circle())
                }
            }
        }
    }

    // MARK: 引導面板

    private var guidedPanel: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            if let c = current {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("Step \(index + 1) / \(markers.count)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.aqua)
                    Spacer()
                    Text(c.meridian)
                        .font(.caption).foregroundStyle(.white.opacity(0.7))
                }
                HStack(spacing: Theme.Spacing.m) {
                    RingTimer(progress: Double(elapsed) / Double(max(1, c.pressSeconds)),
                              label: "\(max(0, c.pressSeconds - elapsed))",
                              size: 84, lineWidth: 7)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(c.nameZh).font(.title3.weight(.bold)).foregroundStyle(.white)
                            Text(c.id).font(.caption.monospacedDigit()).foregroundStyle(.white.opacity(0.6))
                        }
                        Text(c.location)
                            .font(.caption).foregroundStyle(.white.opacity(0.8))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                }
                HStack(spacing: Theme.Spacing.s) {
                    controlButton(running ? "pause.fill" : "play.fill") { running.toggle() }
                    controlButton("backward.end.fill") { back() }
                        .opacity(index == 0 ? 0.4 : 1)
                        .disabled(index == 0)
                    Button(action: advance) {
                        HStack {
                            Text(index + 1 >= markers.count ? "完成" : "下一穴")
                            Image(systemName: "chevron.right")
                        }
                        .font(.headline).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(Theme.brandGradient, in: Capsule())
                    }
                    .buttonStyle(.pressable)
                }
            }
        }
        .padding(Theme.Spacing.m)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .environment(\.colorScheme, .dark)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func controlButton(_ symbol: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(.white.opacity(0.15), in: Circle())
        }
        .buttonStyle(.pressable)
    }

    // MARK: 自由探索面板

    private var freePanel: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(BodyRegion.allCases) { region in
                        ChoiceChip(text: region.displayName, systemImage: region.symbol,
                                   isSelected: region == selectedRegion) {
                            withAnimation(Theme.Motion.snappy) { selectedRegion = region }
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(selectedRegion.symptomHint)
                    .font(.subheadline).foregroundStyle(.white.opacity(0.85))
                HStack(spacing: 6) {
                    ForEach(markers) { a in
                        Text(a.nameZh)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 9).padding(.vertical, 4)
                            .background(.white.opacity(0.18), in: Capsule())
                            .foregroundStyle(.white)
                    }
                }
                GlowButton(title: "開始引導點穴", systemImage: "play.fill") {
                    startGuided(PointSession(title: "\(selectedRegion.displayName) · 舒緩",
                                             subtitle: selectedRegion.symptomHint,
                                             acupoints: markers))
                }
                .padding(.top, 4)
            }
            .padding(Theme.Spacing.m)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .environment(\.colorScheme, .dark)
        }
    }

    // MARK: 完成

    private var completionOverlay: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: Theme.Spacing.m) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(Theme.brandGradient)
                    .symbolEffect(.bounce, value: completed)
                Text("點穴完成").font(.title.weight(.bold)).foregroundStyle(.white)
                if let s = activeSession {
                    Text("\(s.acupoints.count) 個穴位 · \(s.totalSeconds) 秒")
                        .foregroundStyle(.white.opacity(0.8))
                }
                VStack(spacing: 10) {
                    GlowButton(title: "完成", systemImage: "checkmark") {
                        if let s = activeSession { env.recordCompletion(s) }
                        endGuided()
                    }
                    Button("再來一次") { resetGuided() }
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(.top, 8)
            }
            .padding(Theme.Spacing.xl)
            .frame(maxWidth: 340)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .environment(\.colorScheme, .dark)
            .padding(Theme.Spacing.l)
        }
        .transition(.opacity)
    }

    // MARK: Logic

    private func tick() {
        guard isGuided, running, !completed, let c = current else { return }
        elapsed += 1
        if elapsed >= c.pressSeconds {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            advance()
        }
    }

    private func advance() {
        guard isGuided else { return }
        if index + 1 >= markers.count {
            running = false
            withAnimation(Theme.Motion.smooth) { completed = true }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            withAnimation(Theme.Motion.snappy) { index += 1 }
            elapsed = 0
        }
    }

    private func back() {
        guard index > 0 else { return }
        withAnimation(Theme.Motion.snappy) { index -= 1 }
        elapsed = 0
    }

    private func startGuided(_ session: PointSession) {
        index = 0; elapsed = 0; running = true; completed = false
        withAnimation(Theme.Motion.smooth) { activeSession = session }
    }

    private func resetGuided() {
        index = 0; elapsed = 0; running = true
        withAnimation(Theme.Motion.smooth) { completed = false }
    }

    private func endGuided() {
        completed = false
        if launchedModally {
            dismiss()
        } else {
            withAnimation(Theme.Motion.smooth) { activeSession = nil }
        }
    }
}

// MARK: - 角括弧形狀

private struct CornerBracket: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return p
    }
}

#Preview {
    ARAcupointView().environment(AppEnvironment())
}
