/// Represents an authenticated user extracted from a verified OIDC ID token.
public struct AuthenticatedUser: Sendable {
    /// Subject identifier — the unique user ID from the OIDC provider.
    public let sub: String

    /// User's email address, if present in the ID token.
    public let email: String?

    public init(sub: String, email: String?) {
        self.sub = sub
        self.email = email
    }
}
