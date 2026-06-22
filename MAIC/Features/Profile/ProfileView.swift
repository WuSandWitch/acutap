import SwiftUI

struct ProfileView: View {
    @Environment(AppEnvironment.self) private var env
    @AppStorage("appearance") private var appearance: String = "system"
    @AppStorage("notifications") private var notifications: Bool = true

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

                Section("體質組成") {
                    ForEach(env.profile.constitution.sorted(by: { $0.value > $1.value }), id: \.key) { (c, v) in
                        HStack {
                            Text(c.displayName)
                            Spacer()
                            Text("\(Int(v * 100))%")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
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
                    LabeledContent("版本", value: "0.1.0 (Mock)")
                    LabeledContent("資料來源", value: "本地端模擬")
                }
            }
            .navigationTitle("個人")
        }
    }
}
