//
//  AuthService.swift
//  MAIC
//
//  Google OAuth 2.0 (Authorization Code + PKCE) + Keychain token 管理
//  不需 client_secret — iOS client type 用 PKCE 驗證
//

import Foundation
import AuthenticationServices
import Security
import CryptoKit

// MARK: - Auth 狀態

enum AuthState: Equatable {
    case unknown
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
    case keychainError(OSStatus)

    var errorDescription: String? {
        switch self {
        case .cancelled: return "登入已取消"
        case .noAuthCode: return "未取得授權碼"
        case .tokenExchangeFailed(let msg): return "Token 交換失敗: \(msg)"
        case .keychainError(let status): return "鑰匙圈錯誤: \(status)"
        }
    }
}

// MARK: - Data Extension (base64url)

extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// MARK: - Auth Service

@Observable
final class AuthService: NSObject {
    static let shared = AuthService()

    private let googleClientID = "988106203094-uu3tbireufumti5ts5jd53kdggh9a8og.apps.googleusercontent.com"
    private let redirectURI = "com.googleusercontent.apps.988106203094-uu3tbireufumti5ts5jd53kdggh9a8og:/oauth2callback"
    private let callbackScheme = "com.googleusercontent.apps.988106203094-uu3tbireufumti5ts5jd53kdggh9a8og"

    private var verifyTokenURL: URL {
        URL(string: APIConfig.baseURL + "/api/auth/verify")!
    }

    // MARK: State

    private(set) var state: AuthState = .unknown
    private(set) var isLoading = false
    private(set) var userEmail: String?
    private(set) var userName: String?

    // MARK: PKCE

    private var codeVerifier = ""
    private var codeChallenge = ""

    private func generatePKCE() {
        var buffer = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
        codeVerifier = Data(buffer).base64URLEncodedString()
        let hash = SHA256.hash(data: Data(codeVerifier.utf8))
        codeChallenge = Data(hash).base64URLEncodedString()
    }

    // MARK: Keychain Keys

    private let keychainService = "com.wusandwitch.acutap.auth"
    private let tokenKey = "auth_token"
    private let emailKey = "auth_email"
    private let nameKey = "auth_name"

    // MARK: Init

    override private init() {
        super.init()
        loadFromKeychain()
    }

    private func loadFromKeychain() {
        if let token = readFromKeychain(key: tokenKey),
           let email = readFromKeychain(key: emailKey) {
            state = .authenticated(token: token)
            userEmail = email
            userName = readFromKeychain(key: nameKey)
        } else {
            state = .unauthenticated
        }
    }

    // MARK: Google Sign-In (Authorization Code + PKCE)

    @MainActor
    func signInWithGoogle() async throws {
        isLoading = true
        defer { isLoading = false }

        generatePKCE()
        let authURL = try buildAuthURL()
        var authCode = ""

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: callbackScheme
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
                      let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
                    continuation.resume(throwing: AuthError.noAuthCode)
                    return
                }

                authCode = code
                continuation.resume(returning: ())
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }

        // 後端驗證 code + PKCE verifier → 取得 JWT
        let jwt = try await verifyCode(authCode)
        saveToKeychain(value: jwt, key: tokenKey)

        // 從 JWT payload 讀用戶資訊
        let payload = decodeJWTPayload(jwt)
        if let email = payload["email"] as? String {
            userEmail = email
            saveToKeychain(value: email, key: emailKey)
        }
        if let name = payload["name"] as? String {
            userName = name
            saveToKeychain(value: name, key: nameKey)
        }
        state = .authenticated(token: jwt)
    }

    func signOut() {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                     kSecAttrService as String: keychainService]
        SecItemDelete(query as CFDictionary)
        state = .unauthenticated
        userEmail = nil
        userName = nil
    }

    var token: String? {
        if case .authenticated(let t) = state { return t }
        return nil
    }

    // MARK: OAuth URL

    private func buildAuthURL() throws -> URL {
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: googleClientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "openid email profile"),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
        ]
        guard let url = components.url else {
            throw AuthError.noAuthCode
        }
        return url
    }

    // MARK: Backend Code Verification (PKCE)

    private func verifyCode(_ code: String) async throws -> String {
        var request = URLRequest(url: verifyTokenURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let body: [String: String] = [
            "code": code,
            "code_verifier": codeVerifier,
            "client_id": googleClientID,
            "redirect_uri": redirectURI,
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
        return try decoder.decode(TokenResponse.self, from: data).accessToken
    }

    // MARK: JWT Decode (不驗證簽章)

    private func decodeJWTPayload(_ token: String) -> [String: Any] {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return [:] }
        var base64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64 += "=" }
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return json
    }

    // MARK: Keychain

    private func saveToKeychain(value: String, key: String) {
        guard let data = value.data(using: .utf8) else { return }
        let deleteQuery: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                           kSecAttrService as String: keychainService,
                                           kSecAttrAccount as String: key]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                        kSecAttrService as String: keychainService,
                                        kSecAttrAccount as String: key,
                                        kSecValueData as String: data,
                                        kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    private func readFromKeychain(key: String) -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                     kSecAttrService as String: keychainService,
                                     kSecAttrAccount as String: key,
                                     kSecReturnData as String: true,
                                     kSecMatchLimit as String: kSecMatchLimitOne]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else { return nil }
        return value
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension AuthService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        for scene in UIApplication.shared.connectedScenes {
            if let windowScene = scene as? UIWindowScene,
               let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
                return window
            }
        }
        return UIWindow()
    }
}
