//
//  AuthService.swift
//  MAIC
//
//  Google OAuth 2.0 (via ASWebAuthenticationSession) + Keychain token 管理
//  不需額外 SDK，純 iOS 內建框架
//

import Foundation
import AuthenticationServices
import Security
import LocalAuthentication

// MARK: - Auth 狀態

enum AuthState: Equatable {
    case unknown       // 還沒檢查
    case authenticated(token: String)
    case unauthenticated

    var isAuthenticated: Bool {
        if case .authenticated = self { return true }
        return false
    }
}

// MARK: - Auth 錯誤

enum AuthError: LocalizedError {
    case cancelled
    case noAuthCode
    case tokenExchangeFailed(String)
    case noRefreshToken
    case keychainError(OSStatus)
    case notConfigured

    var errorDescription: String? {
        switch self {
        case .cancelled: return "登入已取消"
        case .noAuthCode: return "未取得授權碼"
        case .tokenExchangeFailed(let msg): return "Token 交換失敗: \(msg)"
        case .noRefreshToken: return "無 refresh token"
        case .keychainError(let status): return "鑰匙圈錯誤: \(status)"
        case .notConfigured: return "Google OAuth 尚未設定"
        }
    }
}

// MARK: - Auth Service

@Observable
final class AuthService: NSObject {
    static let shared = AuthService()

    // MARK: 設定（請填入你的值）

    /// Google Cloud Console → OAuth 2.0 Client ID (iOS type)
    var googleClientID: String {
        ProcessInfo.processInfo.environment["GOOGLE_CLIENT_ID"]
            ?? "YOUR_GOOGLE_CLIENT_ID.apps.googleusercontent.com"
    }

    /// 自訂 URL Scheme（需在 Info.plist 註冊）
    private var redirectScheme: String { "acutap" }
    private var redirectHost: String { "oauth-callback" }
    private var redirectURI: String { "\(redirectScheme)://\(redirectHost)" }

    /// 後端 token exchange endpoint
    private var tokenExchangeURL: URL {
        URL(string: APIConfig.baseURL + "/api/auth/google")!
    }

    // MARK: State

    private(set) var state: AuthState = .unknown
    private(set) var isLoading = false
    private(set) var userEmail: String?
    private(set) var userName: String?

    // MARK: Keychain Keys

    private let keychainService = "com.wusandwitch.acutap.auth"
    private let tokenKey = "auth_token"
    private let emailKey = "auth_email"
    private let nameKey = "auth_name"

    // MARK: - 初始化

    override private init() {
        super.init()
        // 啟動時嘗試從 Keychain 載入 token
        loadFromKeychain()
    }

    /// 從 Keychain 載入已存 token
    private func loadFromKeychain() {
        if let token = readFromKeychain(key: tokenKey),
           let email = readFromKeychain(key: emailKey) {
            self.state = .authenticated(token: token)
            self.userEmail = email
            self.userName = readFromKeychain(key: nameKey)
        } else {
            self.state = .unauthenticated
        }
    }

    // MARK: - Google 登入

    /// 執行 Google OAuth 2.0 登入
    @MainActor
    func signInWithGoogle() async throws {
        guard googleClientID != "YOUR_GOOGLE_CLIENT_ID.apps.googleusercontent.com" else {
            throw AuthError.notConfigured
        }

        isLoading = true
        defer { isLoading = false }

        // 1. 建立 OAuth URL
        let authURL = try buildAuthURL()
        var code: String?

        // 2. 用 ASWebAuthenticationSession 打開 Google 登入頁
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: redirectScheme
            ) { callbackURL, error in
                if let error = error {
                    let nsError = error as NSError
                    if nsError.domain == ASWebAuthenticationSessionErrorDomain,
                       nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        continuation.resume(throwing: AuthError.cancelled)
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }

                guard let callbackURL = callbackURL,
                      let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                      let queryCode = components.queryItems?.first(where: { $0.name == "code" })?.value else {
                    continuation.resume(throwing: AuthError.noAuthCode)
                    return
                }

                code = queryCode
                continuation.resume(returning: ())
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }

        guard let authCode = code else {
            throw AuthError.noAuthCode
        }

        // 3. 將 authorization code 送到後端交換 JWT
        let token = try await exchangeCodeForToken(authCode)

        // 4. 存入 Keychain
        saveToKeychain(value: token, key: tokenKey)

        // 5. 解碼 JWT 取得用戶資訊（不依賴額外 SDK）
        let payload = decodeJWTPayload(token)
        if let email = payload["email"] as? String {
            userEmail = email
            saveToKeychain(value: email, key: emailKey)
        }
        if let name = payload["name"] as? String {
            userName = name
            saveToKeychain(value: name, key: nameKey)
        }

        state = .authenticated(token: token)
    }

    // MARK: 登出

    func signOut() {
        clearKeychain()
        state = .unauthenticated
        userEmail = nil
        userName = nil
    }

    // MARK: - API Token Helper

    /// 目前 JWT token（用於 API 請求的 Authorization header）
    var token: String? {
        if case .authenticated(let t) = state { return t }
        return nil
    }

    // MARK: - Private: OAuth URL

    private func buildAuthURL() throws -> URL {
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: googleClientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "openid email profile"),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent"),
        ]
        guard let url = components.url else {
            throw AuthError.notConfigured
        }
        return url
    }

    // MARK: Token Exchange (後端)

    private func exchangeCodeForToken(_ code: String) async throws -> String {
        var request = URLRequest(url: tokenExchangeURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let body = [
            "code": code,
            "redirect_uri": redirectURI,
            "client_id": googleClientID,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown"
            throw AuthError.tokenExchangeFailed(msg)
        }

        struct TokenResponse: Codable {
            let accessToken: String
            let tokenType: String?
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let tokenResponse = try decoder.decode(TokenResponse.self, from: data)
        return tokenResponse.accessToken
    }

    // MARK: JWT Decode (簡單解 payload，不驗證簽章)

    private func decodeJWTPayload(_ token: String) -> [String: Any] {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return [:] }

        // Base64url decode payload
        var base64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        // Pad with =
        while base64.count % 4 != 0 { base64 += "=" }

        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return json
    }

    // MARK: - Keychain

    private func saveToKeychain(value: String, key: String) {
        guard let data = value.data(using: .utf8) else { return }

        // 先刪除舊值
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // 寫入新值
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    private func readFromKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value
    }

    private func clearKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension AuthService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // 用最簡單的方式取得 key window
        for scene in UIApplication.shared.connectedScenes {
            if let windowScene = scene as? UIWindowScene,
               let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
                return window
            }
        }
        return UIWindow()
    }
}
