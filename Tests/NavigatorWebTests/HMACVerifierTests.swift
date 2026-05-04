import Crypto
import Foundation
import Testing

@testable import NavigatorWeb

@Suite("HMAC Verifier", .serialized)
struct HMACVerifierTests {
    private let secret = "test-webhook-secret"

    private func sign(_ payload: String) -> String {
        let key = SymmetricKey(data: Data(secret.utf8))
        let signature = HMAC<SHA256>.authenticationCode(
            for: Data(payload.utf8),
            using: key
        )
        return "sha256=" + Data(signature).map { String(format: "%02x", $0) }.joined()
    }

    @Test("Valid signature passes verification")
    func validSignature() {
        let payload = "{\"messageId\":\"<test@example.com>\"}"
        let signature = sign(payload)
        let result = HMACVerifier.verify(
            payload: Data(payload.utf8),
            signature: signature,
            secret: secret
        )
        #expect(result)
    }

    @Test("Wrong signature fails verification")
    func wrongSignature() {
        let payload = "{\"messageId\":\"<test@example.com>\"}"
        let result = HMACVerifier.verify(
            payload: Data(payload.utf8),
            signature: "sha256=deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef",
            secret: secret
        )
        #expect(!result)
    }

    @Test("Missing sha256= prefix fails verification")
    func missingPrefix() {
        let payload = "test"
        let signature = sign(payload).replacingOccurrences(of: "sha256=", with: "")
        let result = HMACVerifier.verify(
            payload: Data(payload.utf8),
            signature: signature,
            secret: secret
        )
        #expect(!result)
    }

    @Test("Empty secret fails verification")
    func emptySecret() {
        let payload = "test"
        let result = HMACVerifier.verify(
            payload: Data(payload.utf8),
            signature: sign(payload),
            secret: ""
        )
        #expect(!result)
    }

    @Test("Tampered payload fails verification")
    func tamperedPayload() {
        let original = "{\"messageId\":\"<test@example.com>\"}"
        let tampered = "{\"messageId\":\"<evil@example.com>\"}"
        let signature = sign(original)
        let result = HMACVerifier.verify(
            payload: Data(tampered.utf8),
            signature: signature,
            secret: secret
        )
        #expect(!result)
    }

    @Test("Invalid hex in signature fails verification")
    func invalidHex() {
        let result = HMACVerifier.verify(
            payload: Data("test".utf8),
            signature: "sha256=zzzz",
            secret: secret
        )
        #expect(!result)
    }
}
