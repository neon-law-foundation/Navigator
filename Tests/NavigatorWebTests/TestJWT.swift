import Foundation

@testable import NavigatorWeb

/// Test helpers for generating mock JWT tokens in tests.
///
/// Generates a minimal JWT-like token (header.payload.signature) without a valid
/// cryptographic signature, since `AuthMiddleware` decodes the sub claim from the
/// payload without signature verification (API Gateway handles verification in production).
struct TestJWT {
    static func token(sub: String = "test-sub-\(UUID())") -> String {
        let header = base64URLEncode(#"{"alg":"RS256","typ":"JWT"}"#)
        let payload = base64URLEncode("{\"sub\":\"\(sub)\"}")
        return "\(header).\(payload).fakesignature"
    }

    private static func base64URLEncode(_ string: String) -> String {
        Data(string.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
