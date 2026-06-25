//
//  ConstitutionTestView.swift
//  MAIC
//
//  體質分析測驗（可從 Profile 重新填寫）
//

import SwiftUI

struct ConstitutionTestView: View {
    @State private var currentQuestion = 0
    @State private var constitutionScores: [Constitution: Double] = [:]
    @State private var savedConstitution: (Constitution, Double)?
    @State private var showResult = false

    var onComplete: (UserProfile) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.xl) {
                // 進度條
                HStack(spacing: 6) {
                    ForEach(0..<constitutionQuestions.count, id: \.self) { i in
                        Capsule()
                            .fill(i <= currentQuestion ? Theme.teal : Color(.systemGray5))
                            .frame(height: 4)
                    }
                }
                .padding(.horizontal, Theme.Spacing.xl)

                Spacer()

                if showResult {
                    resultView
                } else {
                    questionView
                }

                Spacer()
            }
            .padding(.top, Theme.Spacing.m)
            .background(Color(.systemBackground))
            .navigationTitle("體質分析")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { onComplete(UserProfile(
                        name: "使用者",
                        birthYear: Calendar.current.component(.year, from: Date()) - 25,
                        constitution: [.balanced: 1.0]
                    ))}
                }
            }
        }
    }

    private var questionView: some View {
        VStack(spacing: Theme.Spacing.l) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 40)).foregroundStyle(Theme.teal)
            Text(constitutionQuestions[currentQuestion].text)
                .font(.title3.weight(.medium))
                .multilineTextAlignment(.center)
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
                            if savedConstitution?.0 == opt.constitution {
                                Image(systemName: "checkmark").foregroundStyle(Theme.teal)
                            }
                        }
                        .padding()
                        .background(savedConstitution?.0 == opt.constitution
                            ? Theme.teal.opacity(0.1)
                            : Color(.secondarySystemBackground),
                            in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)

            Text("第 \(currentQuestion + 1) / \(constitutionQuestions.count) 題")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var resultView: some View {
        VStack(spacing: Theme.Spacing.l) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60)).foregroundStyle(.green)
            Text("分析完成！")
                .font(.title2.weight(.bold))

            if let dominant = constitutionScores.max(by: { $0.value < $1.value }) {
                VStack(spacing: 8) {
                    Text("主要體質傾向")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text(dominant.key.displayName)
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(Theme.teal)
                    Text(dominant.key.description)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, Theme.Spacing.xl)
                }
            }

            GlowButton(title: "儲存結果", systemImage: "checkmark") {
                let total = constitutionScores.values.reduce(0, +)
                let normalized = total > 0
                    ? Dictionary(uniqueKeysWithValues: constitutionScores.map { ($0.key, $0.value / total) })
                    : [.balanced: 1.0]
                let profile = UserProfile(
                    name: "使用者",
                    birthYear: Calendar.current.component(.year, from: Date()) - 25,
                    constitution: normalized
                )
                onComplete(profile)
            }
        }
        .padding(.horizontal, Theme.Spacing.xl)
    }

    private func selectAnswer(_ constitution: Constitution, weight: Double) {
        constitutionScores[constitution] = (constitutionScores[constitution] ?? 0) + weight
        savedConstitution = (constitution, weight)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if currentQuestion < constitutionQuestions.count - 1 {
                withAnimation(Theme.Motion.smooth) {
                    currentQuestion += 1
                    savedConstitution = nil
                }
            } else {
                withAnimation { showResult = true }
            }
        }
    }
}
