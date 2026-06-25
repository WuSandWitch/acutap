import SwiftUI
import Combine

// MARK: - 對話模型

struct ChatMessage: Identifiable, Hashable {
    enum Role { case user, assistant }
    let id = UUID()
    let role: Role
    let text: String
    var session: PointSession? = nil
}

@Observable
final class AssistantModel {
    enum Mode { case select, chat }

    private let data = MockDataProvider.shared
    private static let greeting = ChatMessage(
        role: .assistant,
        text: "你好，我是穴新達 AI 助手。\n描述你的感受，我會推薦對應穴位並帶你進入 AR 即時點穴。")

    var mode: Mode = .select
    var selected: [QuickIntent] = []
    var messages: [ChatMessage] = [greeting]
    var input = ""
    var isTyping = false

    // MARK: 複選

    func isSelected(_ intent: QuickIntent) -> Bool { selected.contains(intent) }
    func toggle(_ intent: QuickIntent) {
        if let i = selected.firstIndex(of: intent) { selected.remove(at: i) }
        else { selected.append(intent) }
    }

    func reset() {
        selected = []
        messages = [Self.greeting]
        input = ""
        mode = .select
    }

    // MARK: 由複選推薦 → 串接後端 + 健康資料

    func recommend(health: VitalSnapshot? = nil) {
        guard !selected.isEmpty else { return }
        let labels = selected.map(\.label).joined(separator: "、")
        messages.append(.init(role: .user, text: "我現在：\(labels)"))
        mode = .chat
        isTyping = true

        let symptoms = selected.map { $0.label }

        Task {
            do {
                let response = try await SymptomService.shared.analyze(
                    symptoms: symptoms,
                    hrv: health?.hrv, sleepScore: health?.sleepScore,
                    restingHR: health.flatMap { Int($0.restingHR) },
                    steps: health.flatMap { Int($0.steps) }
                )
                let ids = response.acupoints.map(\.id)
                let acupoints = MockDataProvider.shared.acupoints(ids: ids)
                let text = response.analysis
                let session = acupoints.isEmpty ? nil :
                    PointSession(title: "AI 建議 · 點穴", subtitle: labels, acupoints: acupoints)

                await MainActor.run {
                    self.messages.append(.init(role: .assistant, text: text, session: session))
                    self.isTyping = false
                }
            } catch {
                // 後端失敗 → 降級為本地推薦
                await MainActor.run {
                    self.fallbackRecommend(from: symptoms, subtitle: labels)
                }
            }
        }
    }

    private func fallbackRecommend(from symptoms: [String], subtitle: String) {
        var ids: [String] = []
        for intent in selected {
            for id in intent.acupointIDs where !ids.contains(id) { ids.append(id) }
        }
        ids = Array(ids.prefix(6))
        let names = data.acupoints(ids: ids).map(\.nameZh).joined(separator: "、")
        let text = "根據你選的狀態，為你推薦這組穴位：\(names)。\n依序按壓、配合深呼吸，點下方按鈕進入 AR 即時點穴。"
        self.messages.append(.init(role: .assistant, text: text,
                                   session: self.session(ids: ids, subtitle: subtitle)))
        self.isTyping = false
    }

    // MARK: 自然語言 → 串接後端 + 健康資料

    func send(_ text: String? = nil, health: VitalSnapshot? = nil) {
        let raw = (text ?? input).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }
        messages.append(.init(role: .user, text: raw))
        input = ""
        isTyping = true

        Task {
            do {
                let response = try await SymptomService.shared.analyze(
                    symptoms: [raw],
                    hrv: health?.hrv, sleepScore: health?.sleepScore,
                    restingHR: health.flatMap { Int($0.restingHR) },
                    steps: health.flatMap { Int($0.steps) }
                )
                let ids = response.acupoints.map(\.id)
                let acupoints = MockDataProvider.shared.acupoints(ids: ids)
                let session = acupoints.isEmpty ? nil :
                    PointSession(title: "AI 建議 · 點穴", subtitle: raw, acupoints: acupoints)

                await MainActor.run {
                    self.messages.append(.init(role: .assistant, text: response.analysis,
                                               session: session))
                    self.isTyping = false
                }
            } catch {
                // 後端失敗 → 降級為本地 keyword matching
                await MainActor.run {
                    let (reply, ids) = self.match(raw)
                    self.messages.append(.init(role: .assistant, text: reply,
                                               session: self.session(ids: ids, subtitle: raw)))
                    self.isTyping = false
                }
            }
        }
    }

    private func session(ids: [String], subtitle: String) -> PointSession? {
        let points = data.acupoints(ids: ids)
        guard !points.isEmpty else { return nil }
        return PointSession(title: "AI 建議 · 點穴", subtitle: subtitle, acupoints: points)
    }

    private func match(_ q: String) -> (String, [String]) {
        let s = q.lowercased()
        func has(_ ks: [String]) -> Bool { ks.contains { s.contains($0) } }

        if has(["頭痛", "頭暈", "偏頭痛"]) {
            return ("頭痛多與肝陽上亢或外感風寒有關。建議點 百會、風池、合谷，配合深呼吸放鬆。", ["GV20", "GB20", "LI4"])
        }
        if has(["失眠", "睡不著", "助眠", "淺眠", "多夢"]) {
            return ("睡不好常因心腎不交。睡前點 神門、三陰交、內關 有助安神入眠。", ["HT7", "SP6", "PC6"])
        }
        if has(["肩", "頸", "落枕", "僵硬"]) {
            return ("肩頸僵硬建議點 肩井、風池、合谷，搭配每 30 分鐘起身活動。", ["GB21", "GB20", "LI4"])
        }
        if has(["胸悶", "氣短", "心悸"]) {
            return ("胸悶常與氣鬱有關。點 膻中、內關、列缺，配合 4-7-8 呼吸法。", ["CV17", "PC6", "LU7"])
        }
        if has(["焦慮", "緊張", "壓力", "煩"]) {
            return ("感到焦慮緊張時，點 神門、內關、太衝 能幫助安定情緒、疏肝解鬱。", ["HT7", "PC6", "LV3"])
        }
        if has(["低落", "鬱悶", "難過", "情緒"]) {
            return ("心情低落時，點 膻中、太衝、內關 有助寬胸理氣、調暢情志。", ["CV17", "LV3", "PC6"])
        }
        if has(["疲倦", "累", "提神", "沒精神", "昏沉"]) {
            return ("疲倦想提神，點 足三里、百會、腎俞 能補氣升陽、恢復精力。", ["ST36", "GV20", "BL23"])
        }
        if has(["消化", "脹氣", "胃", "腸"]) {
            return ("幫助消化可點 足三里、三陰交，健運脾胃、緩解脹氣。", ["ST36", "SP6"])
        }
        if has(["經期", "生理期", "經痛", "月經"]) {
            return ("經期可點 太衝、內關 疏肝緩痛，並注意下腹保暖。", ["LV3", "PC6"])
        }
        if has(["免疫", "保健", "養生"]) {
            return ("日常保健、增強免疫，常點 足三里、合谷、腎俞。", ["ST36", "LI4", "BL23"])
        }
        return ("我先記下了。可多描述部位與感受（痠脹或刺痛），或回到狀態複選，我會推薦對應穴位帶你 AR 點穴。", ["LI4", "ST36", "PC6"])
    }
}

// MARK: - 主畫面

struct AIAssistantView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var model = AssistantModel()
    @State private var arSession: PointSession?
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                Divider().opacity(0.4)
                if model.mode == .select {
                    selectPanel
                } else {
                    messagesList
                    inputBar
                }
            }
            .background(Color(.systemBackground))
            .navigationBarHidden(true)
            .fullScreenCover(item: $arSession) { session in
                ARAcupointView(session: session).environment(env)
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: Theme.Spacing.s) {
            ZStack {
                Circle().fill(Theme.brandGradient).frame(width: 38, height: 38)
                    .shadow(color: Theme.teal.opacity(0.4), radius: 6, y: 2)
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("AI 助手").font(.headline)
                HStack(spacing: 4) {
                    Circle().fill(.green).frame(width: 6, height: 6)
                    Text("隨時待命").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if model.mode == .chat {
                Button { withAnimation(Theme.Motion.smooth) { model.reset() } } label: {
                    Label("狀態", systemImage: "checklist")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.teal)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Theme.teal.opacity(0.12), in: Capsule())
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, Theme.Spacing.s)
    }

    // MARK: 複選面板（預設）

    private var selectPanel: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("你現在的狀態？")
                            .font(.title2.weight(.bold))
                        Text("可複選，AI 會綜合推薦穴位並帶你 AR 點穴")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    ForEach(QuickIntent.Category.allCases) { cat in
                        VStack(alignment: .leading, spacing: 10) {
                            Label(cat.title, systemImage: cat.symbol)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.teal)
                            FlowLayout(spacing: 8) {
                                ForEach(env.data.quickIntents.filter { $0.category == cat }) { intent in
                                    ChoiceChip(text: intent.label, systemImage: intent.symbol,
                                               isSelected: model.isSelected(intent)) {
                                        withAnimation(Theme.Motion.snappy) { model.toggle(intent) }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(Theme.Spacing.l)
            }
            bottomActionBar
        }
    }

    private var bottomActionBar: some View {
        VStack(spacing: 12) {
            GlowButton(title: "讓 AI 推薦", systemImage: "sparkles",
                       subtitle: model.selected.isEmpty ? nil : "\(model.selected.count) 項") {
                focused = false
                withAnimation(Theme.Motion.smooth) { model.recommend(health: env.latestVital()) }
            }
            .opacity(model.selected.isEmpty ? 0.5 : 1)
            .disabled(model.selected.isEmpty)

            Button {
                withAnimation(Theme.Motion.smooth) { model.mode = .chat }
            } label: {
                Label("改用自然語言對話", systemImage: "text.bubble")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.teal)
            }
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.top, Theme.Spacing.s)
        .padding(.bottom, Theme.Spacing.m)
        .background(.bar)
    }

    // MARK: 對話

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: Theme.Spacing.m) {
                    ForEach(model.messages) { msg in
                        MessageBubble(message: msg) { session in arSession = session }
                            .id(msg.id)
                            .transition(.move(edge: msg.role == .user ? .trailing : .leading)
                                .combined(with: .opacity))
                    }
                    if model.isTyping { TypingBubble().id("typing") }
                }
                .padding(Theme.Spacing.m)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: model.messages.count) { _, _ in
                withAnimation(Theme.Motion.smooth) {
                    proxy.scrollTo(model.messages.last?.id, anchor: .bottom)
                }
            }
            .onChange(of: model.isTyping) { _, t in
                if t { withAnimation { proxy.scrollTo("typing", anchor: .bottom) } }
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: Theme.Spacing.s) {
            HStack {
                TextField("描述你的感受…", text: $model.input, axis: .vertical)
                    .lineLimit(1...4)
                    .focused($focused)
                    .submitLabel(.send)
                    .onSubmit { model.send(health: env.latestVital()) }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Color(.secondarySystemBackground),
                        in: RoundedRectangle(cornerRadius: 22, style: .continuous))

            Button {
                model.send(health: env.latestVital()); focused = false
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Theme.brandGradient, in: Circle())
                    .opacity(canSend ? 1 : 0.4)
                    .scaleEffect(canSend ? 1 : 0.92)
                    .animation(Theme.Motion.snappy, value: canSend)
            }
            .disabled(!canSend)
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, Theme.Spacing.s)
        .background(.bar)
    }

    private var canSend: Bool {
        !model.input.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

// MARK: - 自動換行排版

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: proposal.width ?? x, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX; y += rowHeight + spacing; rowHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - 氣泡

private struct MessageBubble: View {
    let message: ChatMessage
    let onStart: (PointSession) -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.role == .assistant { avatar } else { Spacer(minLength: 44) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 8) {
                Text(message.text)
                    .font(.subheadline)
                    .foregroundStyle(message.role == .user ? .white : .primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background {
                        if message.role == .user { Theme.brandGradient }
                        else { Color(.secondarySystemBackground) }
                    }
                    .clipShape(BubbleShape(isUser: message.role == .user))

                if let session = message.session {
                    Button { onStart(session) } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "camera.viewfinder")
                            Text("去 AR 點穴")
                            Text("· \(session.acupoints.count) 穴")
                                .font(.caption.monospacedDigit()).opacity(0.85)
                            Image(systemName: "arrow.right").font(.caption.weight(.bold))
                        }
                        .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(Theme.brandGradient, in: Capsule())
                        .shadow(color: Theme.teal.opacity(0.4), radius: 10, y: 4)
                    }
                    .buttonStyle(.pressable)
                }
            }

            if message.role == .user { EmptyView() } else { Spacer(minLength: 44) }
        }
        .frame(maxWidth: .infinity,
               alignment: message.role == .user ? .trailing : .leading)
    }

    private var avatar: some View {
        ZStack {
            Circle().fill(Theme.brandGradient).frame(width: 28, height: 28)
            Image(systemName: "sparkles").font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
        }
    }
}

private struct BubbleShape: Shape {
    let isUser: Bool
    func path(in rect: CGRect) -> Path {
        let r: CGFloat = 18
        let corners: UIRectCorner = isUser
            ? [.topLeft, .topRight, .bottomLeft]
            : [.topLeft, .topRight, .bottomRight]
        return Path(UIBezierPath(roundedRect: rect, byRoundingCorners: corners,
                                 cornerRadii: CGSize(width: r, height: r)).cgPath)
    }
}

private struct TypingBubble: View {
    @State private var phase = 0
    private let t = Timer.publish(every: 0.3, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ZStack {
                Circle().fill(Theme.brandGradient).frame(width: 28, height: 28)
                Image(systemName: "sparkles").font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
            }
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle().fill(Color.secondary)
                        .frame(width: 7, height: 7)
                        .opacity(phase == i ? 1 : 0.3)
                        .scaleEffect(phase == i ? 1.2 : 1)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(Color(.secondarySystemBackground),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            Spacer(minLength: 44)
        }
        .onReceive(t) { _ in withAnimation(.easeInOut(duration: 0.25)) { phase = (phase + 1) % 3 } }
    }
}
