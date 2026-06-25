//
//  LoginView.swift
//  MAIC
//
//  Google OAuth 登入頁 — 簡單漂亮，適合 Demo
//

import SwiftUI

struct LoginView: View {
    @State private var auth = AuthService.shared
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Logo 區
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Theme.brandGradient)
                        .frame(width: 100, height: 100)
                        .shadow(color: Theme.teal.opacity(0.4), radius: 20, y: 8)

                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(.white)
                }

                Text("穴新達")
                    .font(.system(size: 36, weight: .bold))

                Text("Acutap")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                Text("AI 智慧點穴，隨時隨地")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }

            Spacer()

            // 說明
            VStack(spacing: 8) {
                Text("登入後即可使用完整功能")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 16) {
                    featureItem(icon: "camera.viewfinder", text: "AR 點穴")
                    featureItem(icon: "heart.text.clipboard", text: "健康分析")
                    featureItem(icon: "sparkles", text: "AI 建議")
                }
                .padding(.top, 8)
            }

            Spacer()

            // Google 登入按鈕
            VStack(spacing: 12) {
                if auth.isLoading {
                    ProgressView()
                        .controlSize(.large)
                    Text("正在登入…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Button {
                        Task {
                            do {
                                try await auth.signInWithGoogle()
                            } catch AuthError.cancelled {
                                // 使用者取消，不顯示錯誤
                            } catch AuthError.notConfigured {
                                errorMessage = "Google OAuth 尚未設定。請設定 GOOGLE_CLIENT_ID。"
                                showError = true
                            } catch {
                                errorMessage = error.localizedDescription
                                showError = true
                            }
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "g.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.blue)

                            Text("使用 Google 帳號登入")
                                .font(.headline.weight(.medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.white)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
                    }
                    .buttonStyle(.pressable)
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)

            Spacer()

            // Footer
            Text("登入即表示您同意服務條款與隱私權政策")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.bottom, Theme.Spacing.l)
        }
        .padding(.horizontal, Theme.Spacing.l)
        .background(
            LinearGradient(
                colors: [.black, Color(.systemGray6)],
                startPoint: .top, endPoint: .bottom
            )
        )
        .preferredColorScheme(.dark)
        .alert("登入失敗", isPresented: $showError) {
            Button("確定", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "未知錯誤")
        }
    }

    private func featureItem(icon: String, text: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(Theme.teal)
            Text(text)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(width: 70)
    }
}

#Preview {
    LoginView()
}
