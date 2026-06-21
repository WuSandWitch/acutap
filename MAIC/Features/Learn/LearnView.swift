import SwiftUI

// MARK: - Chat model

struct ChatMessage: Identifiable, Hashable {
    enum Role { case user, assistant }
    let id = UUID()
    let role: Role
    let text: String
    let date: Date = .init()
}

@Observable
final class ChatViewModel {
    var messages: [ChatMessage] = [
        .init(role: .assistant,
              text: "你好，我是 Tap Tap 養生小助理。\n你最近有哪裡不舒服？或想了解什麼穴位、體質、節氣養生，都可以問我。")
    ]
    var input: String = ""
    var isTyping: Bool = false

    let suggestions: [String] = [
        "我頭痛怎麼按？",
        "怎麼改善失眠？",
        "肩頸僵硬可以按哪裡？",
        "經期可以按嗎？"
    ]

    func send(_ text: String? = nil) {
        let raw = (text ?? input).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }
        messages.append(.init(role: .user, text: raw))
        input = ""
        isTyping = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self else { return }
            self.messages.append(.init(role: .assistant, text: Self.mockReply(for: raw)))
            self.isTyping = false
        }
    }

    private static func mockReply(for q: String) -> String {
        let s = q.lowercased()
        if s.contains("頭痛") || s.contains("頭暈") {
            return "頭痛常與 肝陽上亢 或 風寒外感 有關。建議：\n• 太陽穴：指腹輕揉 30 秒\n• 風池（後頸髮際凹陷）：拇指上推 30 秒\n• 合谷（虎口）：按壓 30 秒\n配合深呼吸效果更好。如持續超過 3 天請就醫。"
        }
        if s.contains("失眠") || s.contains("睡不著") || s.contains("助眠") {
            return "失眠多與 心腎不交 有關。睡前 15 分鐘：\n• 神門（腕橫紋小指側）30 秒\n• 內關（腕橫紋上 2 寸）30 秒\n• 三陰交（內踝上 3 寸）45 秒\n避免睡前藍光與冰飲。"
        }
        if s.contains("肩") || s.contains("頸") || s.contains("落枕") {
            return "現代人滑手機久了肩頸最容易僵。建議：\n• 肩井（肩膀最高點）30 秒\n• 風池 30 秒\n• 合谷 30 秒\n搭配每 30 分鐘起身轉動頸部 1 分鐘。"
        }
        if s.contains("經期") || s.contains("生理期") || s.contains("月經") {
            return "經期可以按摩，但要避開 三陰交、合谷、肩井 等行氣較強的穴位。\n建議改按：\n• 太衝（足背第一二蹠骨間）30 秒，疏肝\n• 內關 30 秒，緩解情緒\n如有經痛可熱敷下腹。"
        }
        if s.contains("胸悶") || s.contains("氣短") || s.contains("心悸") {
            return "胸悶常與 氣鬱 或 心氣不足 有關：\n• 膻中（兩乳中點）30 秒\n• 內關 30 秒\n• 太衝 30 秒\n建議搭配 4-7-8 呼吸法：吸 4 秒、屏 7 秒、吐 8 秒。"
        }
        if s.contains("體質") || s.contains("氣虛") || s.contains("陰虛") || s.contains("濕熱") {
            return "中醫體質分九類，最常見有：平和、氣虛、陰虛、陽虛、濕熱、痰濕、血瘀、氣鬱、特稟。你可以在「個人」頁完成快測，我會根據結果為你客製每日處方。"
        }
        if s.contains("節氣") || s.contains("小滿") || s.contains("夏") {
            return "今天節氣為 小滿，濕氣漸盛。建議：\n• 飲食清淡，少冰冷、少油膩\n• 多按 足三里、三陰交 健運脾胃\n• 適度運動微出汗，幫助化濕"
        }
        return "我先記下了。建議在「AR 按摩指引」點擊不適部位，會列出對應穴位與引導步驟。若想針對特定症狀，可以多描述一下感受（例如：是緊繃、痠脹還是刺痛？）。"
    }
}

// MARK: - View

struct LearnView: View {
    @State private var vm = ChatViewModel()
    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                Divider().opacity(0.5)
                messagesList
                if vm.messages.count <= 1 {
                    suggestionStrip
                }
                inputBar
            }
            .background(Color(.systemBackground))
            .navigationBarHidden(true)
        }
    }

    private var header: some View {
        HStack(spacing: Theme.Spacing.s) {
            ZStack {
                Circle().fill(Theme.brandGradient).frame(width: 36, height: 36)
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("養生小助理").font(.headline)
                HStack(spacing: 4) {
                    Circle().fill(Color.green).frame(width: 6, height: 6)
                    Text("On-Device · 隨時待命")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button {
                vm.messages = [vm.messages.first!]
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .background(Color(.secondarySystemBackground), in: Circle())
            }
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, Theme.Spacing.s)
    }

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: Theme.Spacing.s) {
                    ForEach(vm.messages) { msg in
                        MessageBubble(message: msg).id(msg.id)
                    }
                    if vm.isTyping {
                        TypingBubble().id("typing")
                    }
                }
                .padding(.horizontal, Theme.Spacing.m)
                .padding(.vertical, Theme.Spacing.m)
            }
            .onChange(of: vm.messages.count) { _, _ in
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo(vm.messages.last?.id, anchor: .bottom)
                }
            }
            .onChange(of: vm.isTyping) { _, t in
                if t {
                    withAnimation { proxy.scrollTo("typing", anchor: .bottom) }
                }
            }
        }
    }

    private var suggestionStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(vm.suggestions, id: \.self) { s in
                    Button {
                        vm.send(s)
                    } label: {
                        Text(s)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            .background(Color.accentColor.opacity(0.12), in: Capsule())
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.bottom, Theme.Spacing.s)
        }
    }

    private var inputBar: some View {
        HStack(spacing: Theme.Spacing.s) {
            HStack {
                TextField("問我任何關於穴位、體質、養生…", text: $vm.input, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.plain)
                    .focused($inputFocused)
                    .submitLabel(.send)
                    .onSubmit { vm.send() }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))

            Button {
                vm.send()
                inputFocused = false
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Theme.brandGradient, in: Circle())
                    .opacity(vm.input.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)
            }
            .disabled(vm.input.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, Theme.Spacing.s)
        .background(.bar)
    }
}

// MARK: - Bubbles

private struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.role == .assistant {
                avatar
            } else {
                Spacer(minLength: 40)
            }

            Text(message.text)
                .font(.subheadline)
                .foregroundStyle(message.role == .user ? .white : .primary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background {
                    if message.role == .user {
                        Theme.brandGradient
                    } else {
                        Color(.secondarySystemBackground)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            if message.role == .user {
                EmptyView()
            } else {
                Spacer(minLength: 40)
            }
        }
        .frame(maxWidth: .infinity,
               alignment: message.role == .user ? .trailing : .leading)
    }

    private var avatar: some View {
        ZStack {
            Circle().fill(Theme.brandGradient).frame(width: 28, height: 28)
            Image(systemName: "sparkles")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}

private struct TypingBubble: View {
    @State private var phase: CGFloat = 0
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ZStack {
                Circle().fill(Theme.brandGradient).frame(width: 28, height: 28)
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            }
            HStack(spacing: 4) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 6, height: 6)
                        .opacity(opacity(for: i))
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(Color(.secondarySystemBackground),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            Spacer(minLength: 40)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
    }

    private func opacity(for i: Int) -> Double {
        let p = (Double(phase) * 3 - Double(i)).truncatingRemainder(dividingBy: 3)
        return max(0.3, 1 - abs(p - 1))
    }
}
