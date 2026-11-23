import Foundation
import Security

struct ChatGPTCredentials: Codable {
    let accessToken: String
    let refreshToken: String
    let idToken: String
    let expiresAt: Date
}

struct ChatGPTAccount: Codable, Identifiable {
    let id: String
    let subject: String
    let email: String
    var credentials: ChatGPTCredentials?

    var label: String { "\(email) (\(id.suffix(6)))" }
}

struct ChatGPTAccounts: Codable {
    var accounts: [ChatGPTAccount] = []
    var selectedID: String?
}

enum AccountKeychain {
    private static var query: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "tools.wordcadence.chatgpt",
            kSecAttrAccount as String: "registered-accounts"
        ]
    }

    static func load() throws -> ChatGPTAccounts {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        if status == errSecItemNotFound { return ChatGPTAccounts() }
        guard status == errSecSuccess, let data = result as? Data else { throw keychainError(status) }
        return try JSONDecoder().decode(ChatGPTAccounts.self, from: data)
    }

    static func save(_ accounts: ChatGPTAccounts) throws {
        let data = try JSONEncoder().encode(accounts)
        let attributes = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var insert = query
            insert[kSecValueData as String] = data
            let result = SecItemAdd(insert as CFDictionary, nil)
            guard result == errSecSuccess else { throw keychainError(result) }
        } else if status != errSecSuccess {
            throw keychainError(status)
        }
    }

    private static func keychainError(_ status: OSStatus) -> AppFailure {
        let description = SecCopyErrorMessageString(status, nil) as String? ?? "error \(status)"
        return .setup("Could not access the macOS Keychain. \(description)")
    }
}
