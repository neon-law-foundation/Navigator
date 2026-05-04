import Crypto
import Foundation

enum HMACVerifier {
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    static func verify(payload: Data, signature: String, secret: String) -> Bool {
        guard !secret.isEmpty else { return false }
        guard signature.hasPrefix("sha256=") else { return false }
        let hexDigest = String(signature.dropFirst("sha256=".count))
        guard let signatureBytes = Data(hexString: hexDigest) else { return false }
        let key = SymmetricKey(data: Data(secret.utf8))
        return HMAC<SHA256>.isValidAuthenticationCode(
            signatureBytes,
            authenticating: payload,
            using: key
        )
    }
}

extension Data {
    init?(hexString: String) {
        let chars = Array(hexString)
        guard chars.count.isMultiple(of: 2) else { return nil }
        var data = Data(capacity: chars.count / 2)
        for i in stride(from: 0, to: chars.count, by: 2) {
            guard let byte = UInt8(String(chars[i...i + 1]), radix: 16) else { return nil }
            data.append(byte)
        }
        self = data
    }
}
