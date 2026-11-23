import AppKit
import CryptoKit
import Foundation
import Security

@MainActor
struct ChatGPTOAuth {
    private let session: URLSession
    private static let resource = "https://api.openai.com/v1"
    private static let issuer = "https://auth.openai.com"
    private static let hostKey = "chatgptHostID"

    init(session: URLSession = .shared) {
        self.session = session
    }

    func signIn(as existing: ChatGPTAccount?) async throws -> ChatGPTAccount {
        let state = try randomToken()
        let nonce = try randomToken()
        let verifier = try randomToken()
        let challenge = IdentityToken.encode(Data(SHA256.hash(data: Data(verifier.utf8))))
        let callback = try OAuthCallback(state: state)
        let redirectURI = try await callback.redirectURI()
        var authorize = URLComponents(string: Self.issuer + "/api/accounts/authorize")!
        var parameters = [
            "client_id": existing?.id ?? "dynamic_agent_client",
            "ext_agent_host_id": hostID(),
            "response_type": "code",
            "redirect_uri": redirectURI,
            "scope": "openid profile email offline_access resource.invoke chatgpt.tokens.use.direct",
            "resource": Self.resource,
            "state": state,
            "nonce": nonce,
            "code_challenge": challenge,
            "code_challenge_method": "S256"
        ]
        if let existing {
            parameters["login_hint"] = existing.email
            parameters["id_token_hint"] = existing.credentials?.idToken
        } else {
            parameters["agent_name_hint"] = "Word Cadence"
        }
        authorize.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        try Task.checkCancellation()
        guard let url = authorize.url, NSWorkspace.shared.open(url) else {
            throw AppFailure.setup("Could not open ChatGPT sign-in in your browser.")
        }

        let query = try await callback.wait().queryItems ?? []
        if query.contains(where: { $0.name == "error" }) {
            throw AppFailure.setup("ChatGPT sign-in was declined or could not be completed.")
        }
        let returnedID = query.first(where: { $0.name == "client_id" })?.value
        guard let clientID = existing?.id ?? returnedID, clientID.hasPrefix("oaiapp_"),
              returnedID == nil || clientID == returnedID,
              let code = query.first(where: { $0.name == "code" })?.value, !code.isEmpty else {
            throw AppFailure.setup("ChatGPT returned an incomplete account registration.")
        }
        let token = try await exchange([
            "grant_type": "authorization_code", "client_id": clientID, "code": code,
            "code_verifier": verifier, "redirect_uri": redirectURI, "resource": Self.resource
        ])
        guard let idToken = token.idToken else {
            throw AppFailure.setup("ChatGPT did not return an account identity.")
        }
        let identity = try await IdentityToken.verify(idToken, clientID: clientID, nonce: nonce, session: session)
        if let existing, existing.subject != identity.subject {
            throw AppFailure.setup("ChatGPT returned a different account. Choose Add account to connect it separately.")
        }
        return ChatGPTAccount(id: clientID, subject: identity.subject, email: identity.email,
                              credentials: try credentials(from: token, idToken: idToken))
    }

    func refresh(_ account: ChatGPTAccount) async throws -> ChatGPTCredentials {
        guard let previous = account.credentials else {
            throw AppFailure.setup("Reconnect your ChatGPT account first.")
        }
        let token = try await exchange([
            "grant_type": "refresh_token", "client_id": account.id,
            "refresh_token": previous.refreshToken, "resource": Self.resource
        ])
        return try credentials(from: token, idToken: previous.idToken)
    }

    func revoke(_ account: ChatGPTAccount) async -> Bool {
        guard let refresh = account.credentials?.refreshToken else { return true }
        let request = formRequest("/api/accounts/oauth/revoke", fields: [
            "token": refresh, "token_type_hint": "refresh_token", "client_id": account.id
        ])
        for delay in [0, 1, 2] {
            if delay > 0 { try? await Task.sleep(for: .seconds(delay)) }
            do {
                let (_, response) = try await session.data(for: request)
                guard let status = (response as? HTTPURLResponse)?.statusCode else { return false }
                if status == 200 { return true }
                if status < 500 { return false }
            } catch {
                if Task.isCancelled { return false }
            }
        }
        return false
    }

    private func exchange(_ fields: [String: String]) async throws -> Token {
        let (data, response) = try await session.data(for: formRequest("/api/accounts/oauth/token", fields: fields))
        guard let status = (response as? HTTPURLResponse)?.statusCode else {
            throw AppFailure.setup("ChatGPT returned an invalid sign-in response.")
        }
        guard status == 200 else {
            throw AppFailure.setup("ChatGPT could not authorize or renew the connection (HTTP \(status)). Try reconnecting.")
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(Token.self, from: data)
    }

    private func credentials(from token: Token, idToken: String) throws -> ChatGPTCredentials {
        let scopes = Set(token.scope.split(whereSeparator: \.isWhitespace).map(String.init))
        guard scopes.contains("chatgpt.tokens.use.direct"), scopes.contains("resource.invoke") else {
            throw AppFailure.setup("Approve ChatGPT plan usage for Word Cadence to transcribe images.")
        }
        guard token.tokenType.caseInsensitiveCompare("Bearer") == .orderedSame,
              !token.accessToken.isEmpty, !token.refreshToken.isEmpty, token.expiresIn > 0 else {
            throw AppFailure.setup("ChatGPT returned unusable session credentials.")
        }
        return ChatGPTCredentials(accessToken: token.accessToken, refreshToken: token.refreshToken,
                                   idToken: idToken, expiresAt: Date().addingTimeInterval(token.expiresIn))
    }

    private func hostID() -> String {
        let defaults = UserDefaults.standard
        if let saved = defaults.string(forKey: Self.hostKey) { return saved }
        let fresh = "urn:uuid:" + UUID().uuidString.lowercased()
        defaults.set(fresh, forKey: Self.hostKey)
        return fresh
    }

    private func randomToken() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = bytes.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, $0.count, $0.baseAddress!) }
        guard status == errSecSuccess else { throw AppFailure.setup("Could not start secure ChatGPT sign-in.") }
        return IdentityToken.encode(Data(bytes))
    }

    private func formRequest(_ path: String, fields: [String: String]) -> URLRequest {
        let safe = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        let encoded = fields.map { key, value in
            key + "=" + (value.addingPercentEncoding(withAllowedCharacters: safe) ?? "")
        }.joined(separator: "&")
        var request = URLRequest(url: URL(string: Self.issuer + path)!, cachePolicy: .reloadIgnoringLocalCacheData,
                                 timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(encoded.utf8)
        return request
    }

    private struct Token: Decodable {
        let accessToken: String
        let refreshToken: String
        let idToken: String?
        let expiresIn: Double
        let scope: String
        let tokenType: String
    }
}
