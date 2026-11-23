import Foundation
import Security

struct VerifiedIdentity {
    let subject: String
    let email: String
}

enum IdentityToken {
    private static let keysURL = URL(string: "https://auth.openai.com/.well-known/jwks.json")!

    static func verify(_ token: String, clientID: String, nonce: String, session: URLSession) async throws -> VerifiedIdentity {
        let segments = token.split(separator: ".", omittingEmptySubsequences: false)
        guard segments.count == 3,
              let headerData = decode(String(segments[0])),
              let claimsData = decode(String(segments[1])),
              let signature = decode(String(segments[2])) else { throw invalid }
        let decoder = JSONDecoder()
        let header = try decoder.decode(Header.self, from: headerData)
        guard header.alg == "RS256" else { throw invalid }

        let (keysData, response) = try await session.data(from: keysURL)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw invalid }
        let keys = try decoder.decode(Keys.self, from: keysData)
        guard let jwk = keys.keys.first(where: { $0.kid == header.kid && $0.kty == "RSA" }),
              let modulus = decode(jwk.n), let exponent = decode(jwk.e),
              let rsa = rsaKey(modulus: modulus, exponent: exponent) else { throw invalid }
        let message = Data("\(segments[0]).\(segments[1])".utf8)
        guard SecKeyVerifySignature(rsa, .rsaSignatureMessagePKCS1v15SHA256, message as CFData, signature as CFData, nil) else {
            throw invalid
        }

        let claims = try decoder.decode(Claims.self, from: claimsData)
        let audiences = claims.aud.values
        guard claims.iss == "https://auth.openai.com", audiences.contains(clientID),
              (audiences.count == 1 || claims.azp == clientID),
              (claims.azp == nil || claims.azp == clientID),
              claims.exp > Date().timeIntervalSince1970,
              claims.nonce == nonce, !claims.sub.isEmpty else { throw invalid }
        return VerifiedIdentity(subject: claims.sub, email: claims.email ?? "ChatGPT account")
    }

    static func encode(_ bytes: Data) -> String {
        bytes.base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }

    private static func decode(_ string: String) -> Data? {
        let base64 = string.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let padding = String(repeating: "=", count: (4 - base64.count % 4) % 4)
        return Data(base64Encoded: base64 + padding)
    }

    private static func rsaKey(modulus: Data, exponent: Data) -> SecKey? {
        guard !modulus.isEmpty, !exponent.isEmpty else { return nil }
        let sequence = der(0x30, integer(modulus) + integer(exponent))
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
            kSecAttrKeySizeInBits as String: modulus.count * 8
        ]
        return SecKeyCreateWithData(sequence as CFData, attributes as CFDictionary, nil)
    }

    private static func integer(_ unsigned: Data) -> Data {
        let needsPadding = unsigned.first.map { $0 & 0x80 != 0 } ?? false
        return der(0x02, needsPadding ? Data([0]) + unsigned : unsigned)
    }

    private static func der(_ tag: UInt8, _ value: Data) -> Data {
        if value.count < 128 { return Data([tag, UInt8(value.count)]) + value }
        var length = value.count
        var lengthBytes: [UInt8] = []
        while length > 0 {
            lengthBytes.insert(UInt8(length & 0xff), at: 0)
            length >>= 8
        }
        return Data([tag, 0x80 | UInt8(lengthBytes.count)] + lengthBytes) + value
    }

    private static var invalid: AppFailure { .setup("Could not verify the ChatGPT account identity.") }

    private struct Header: Decodable { let alg: String; let kid: String }
    private struct Keys: Decodable {
        struct JWK: Decodable { let kid: String; let kty: String; let n: String; let e: String }
        let keys: [JWK]
    }

    private struct Claims: Decodable {
        let iss: String
        let aud: Audience
        let azp: String?
        let exp: Double
        let nonce: String
        let sub: String
        let email: String?
    }

    private struct Audience: Decodable {
        let values: [String]
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let single = try? container.decode(String.self) {
                values = [single]
            } else {
                values = try container.decode([String].self)
            }
        }
    }
}
