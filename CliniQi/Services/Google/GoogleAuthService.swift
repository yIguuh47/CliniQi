//
//  GoogleAuthService.swift
//  CliniQi
//

import CryptoKit
import Foundation
import Observation

enum GoogleError: LocalizedError {
    case notConfigured
    case notSignedIn
    case cancelled
    case http(Int, String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "A conexão com o Google ainda não foi configurada no app (Client ID ausente em GoogleConfig.swift)."
        case .notSignedIn:
            "Sua conta Google foi desconectada. Entre novamente."
        case .cancelled:
            "Login cancelado."
        case let .http(status, message):
            "Google respondeu com erro \(status): \(message)"
        case .invalidResponse:
            "Resposta inesperada do Google."
        }
    }
}

/// Login com Google via OAuth 2.0 + PKCE (fluxo oficial para apps iOS, sem SDK).
/// O refresh token fica no Keychain; o access token é renovado automaticamente.
@MainActor
@Observable
final class GoogleAuthService {
    /// Abre a página de login do Google e devolve a URL de retorno.
    typealias Authenticator = (_ url: URL, _ callbackScheme: String) async throws -> URL

    private(set) var email: String?
    var isSignedIn: Bool { refreshToken != nil }

    private var refreshToken: String?
    private var accessToken: String?
    private var accessTokenExpiry: Date = .distantPast

    private enum Key {
        static let refreshToken = "refreshToken"
        static let email = "email"
    }

    init() {
        refreshToken = KeychainStore.get(Key.refreshToken)
        email = KeychainStore.get(Key.email)
    }

    func signIn(using authenticate: Authenticator) async throws {
        guard GoogleConfig.isConfigured else { throw GoogleError.notConfigured }

        let verifier = Self.randomURLSafeString(bytes: 32)
        let challenge = Self.base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
        let state = Self.randomURLSafeString(bytes: 16)

        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: GoogleConfig.clientID),
            URLQueryItem(name: "redirect_uri", value: GoogleConfig.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: GoogleConfig.scopes.joined(separator: " ")),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "prompt", value: "select_account consent")
        ]

        let callback: URL
        do {
            callback = try await authenticate(components.url!, GoogleConfig.redirectScheme)
        } catch {
            throw GoogleError.cancelled
        }

        let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        guard items.first(where: { $0.name == "state" })?.value == state,
              let code = items.first(where: { $0.name == "code" })?.value
        else {
            let erro = items.first(where: { $0.name == "error" })?.value ?? "sem código de autorização"
            throw GoogleError.http(400, erro)
        }

        let token = try await requestToken([
            "code": code,
            "client_id": GoogleConfig.clientID,
            "redirect_uri": GoogleConfig.redirectURI,
            "grant_type": "authorization_code",
            "code_verifier": verifier
        ])
        guard let refresh = token.refresh_token else { throw GoogleError.invalidResponse }

        store(token)
        refreshToken = refresh
        KeychainStore.set(refresh, for: Key.refreshToken)

        email = try? await fetchEmail()
        KeychainStore.set(email, for: Key.email)
    }

    func signOut() async {
        if let token = refreshToken {
            var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/revoke")!)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpBody = Self.formBody(["token": token])
            _ = try? await URLSession.shared.data(for: request)
        }
        clear()
    }

    /// Access token válido (renova com o refresh token quando expira).
    func validAccessToken() async throws -> String {
        if let accessToken, accessTokenExpiry > .now.addingTimeInterval(60) {
            return accessToken
        }
        guard let refreshToken else { throw GoogleError.notSignedIn }

        do {
            let token = try await requestToken([
                "refresh_token": refreshToken,
                "client_id": GoogleConfig.clientID,
                "grant_type": "refresh_token"
            ])
            store(token)
            return token.access_token
        } catch GoogleError.http(let status, _) where status == 400 || status == 401 {
            // Acesso revogado na conta Google: pede login de novo.
            clear()
            throw GoogleError.notSignedIn
        }
    }

    // MARK: - Privado

    private struct TokenResponse: Decodable {
        let access_token: String
        let expires_in: Double
        let refresh_token: String?
    }

    private func requestToken(_ parameters: [String: String]) async throws -> TokenResponse {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.formBody(parameters)

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw GoogleError.http(status, String(data: data, encoding: .utf8) ?? "")
        }
        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }

    private func fetchEmail() async throws -> String? {
        struct UserInfo: Decodable { let email: String? }
        var request = URLRequest(url: URL(string: "https://openidconnect.googleapis.com/v1/userinfo")!)
        request.setValue("Bearer \(try await validAccessToken())", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(UserInfo.self, from: data).email
    }

    private func store(_ token: TokenResponse) {
        accessToken = token.access_token
        accessTokenExpiry = .now.addingTimeInterval(token.expires_in)
    }

    private func clear() {
        refreshToken = nil
        accessToken = nil
        accessTokenExpiry = .distantPast
        email = nil
        KeychainStore.set(nil, for: Key.refreshToken)
        KeychainStore.set(nil, for: Key.email)
    }

    private static func formBody(_ parameters: [String: String]) -> Data {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return parameters
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: allowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8) ?? Data()
    }

    private static func randomURLSafeString(bytes count: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: count)
        _ = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        return base64URL(Data(bytes))
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
