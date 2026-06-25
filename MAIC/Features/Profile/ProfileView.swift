import SwiftUI

struct ProfileView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var auth = AuthService.shared
    @AppStorage("appearance") private var appearance: String = "system"
    @AppStorage("notifications") private var notifications: Bool = true
    @State private var showingLogoutAlert = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: Theme.Spacing.m) {
                        Circle().fill(Theme.brandGradient)
                            .frame(width: 56, height: 56)
                            .overlay(
                                Text(String(env.profile.name.prefix(1)))
                                    .font(.title2.weight(.semibold))
                                    .foregroundStyle(.white)
                            )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(env.profile.name).font(.headline)
                            Text("體質傾向：\(env.profile.dominantConstitution.displayName)")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("體質分析") {
                    if env.profile.constitution.count == 1 && env.profile.constitution[.balanced] == 1.0 {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("尚無分析資料", systemImage: "clock")
                                .font(.subheadline).foregroundStyle(.secondary)
                            Text("完成健康資料同步後，AI 將根據您的 HRV、睡眠、心率等數據分析體質傾向。")
                                .font(.caption).foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 6)
                    } else {
                        ForEach(env.profile.constitution.sorted(by: { $0.value > $1.value }), id: \.key) { (c, v) in
                            HStack {
                                Text(c.displayName)
                                Spacer()
                                Text("\(Int(v * 100))%")
                                    .foregroundStyle(.secondary).monospacedDigit()
                            }
                        }
                    }
                }

                Section("設定") {
                    Toggle("每日按摩提醒", isOn: $notifications)
                    Picker("外觀", selection: $appearance) {
                        Text("跟隨系統").tag("system")
                        Text("淺色").tag("light")
                        Text("深色").tag("dark")
                    }
                }

                Section("關於") {
                    LabeledContent("版本", value: "1.0.0")
                    LabeledContent("資料來源", value: "WHO標準穴位 + bankroz骨骼定位")
                    LabeledContent("後端", value: "acutap-backend.zudo.cc")
                    if let email = auth.userEmail {
                        LabeledContent("帳號", value: email)
                    }
                }

                // 登出
                Section {
                    Button(role: .destructive) {
                        showingLogoutAlert = true
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("登出")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("個人")
            .alert("登出", isPresented: $showingLogoutAlert) {
                Button("取消", role: .cancel) {}
                Button("登出", role: .destructive) {
                    auth.signOut()
                }
            } message: {
                Text("登出後需要重新使用 Google 帳號登入。")
            }
        }
    }
}
