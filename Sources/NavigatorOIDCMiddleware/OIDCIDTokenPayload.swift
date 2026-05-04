import JWTKit

/// Standard OIDC ID token payload.
///
/// Uses only claims defined in the OIDC Core specification (RFC 7519 / OpenID Connect Core 1.0).
/// No provider-specific claims appear here, so this works with any standards-compliant OIDC
/// provider — Cognito, Auth0, Dex, etc.
///
/// Clients must send the **ID token** (not the access token) in the `Authorization: Bearer` header.
public struct OIDCIDTokenPayload: JWTPayload {
    /// Issuer — must match the configured `OIDC_ISSUER_URL`.
    public var iss: IssuerClaim

    /// Subject — the unique user identifier from the OIDC provider.
    public var sub: SubjectClaim

    /// Audience — must contain the configured `OIDC_CLIENT_ID`.
    public var aud: AudienceClaim

    /// Expiration time.
    public var exp: ExpirationClaim

    /// Issued-at time (optional but common).
    public var iat: IssuedAtClaim?

    /// User's email address (standard OIDC profile claim).
    public var email: String?

    public init(
        iss: IssuerClaim,
        sub: SubjectClaim,
        aud: AudienceClaim,
        exp: ExpirationClaim,
        iat: IssuedAtClaim? = nil,
        email: String? = nil
    ) {
        self.iss = iss
        self.sub = sub
        self.aud = aud
        self.exp = exp
        self.iat = iat
        self.email = email
    }

    public func verify(using algorithm: some JWTAlgorithm) async throws {
        try exp.verifyNotExpired()
    }
}
