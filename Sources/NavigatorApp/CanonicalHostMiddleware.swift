import Vapor

/// Middleware that 301-redirects requests on the apex hostname
/// `neonlaw.com` to the canonical `https://www.neonlaw.com` form,
/// preserving the request path and query string.
///
/// Search engines treat `neonlaw.com` and `www.neonlaw.com` as distinct
/// origins. Without this redirect, organic traffic that lands on the
/// apex would split link equity across two hostnames and dilute the
/// canonical signal. Doing the redirect at the application layer also
/// means the rule travels with the binary and does not depend on
/// out-of-band edge configuration.
///
/// The middleware is intentionally narrow:
///
/// - It only fires when the incoming `Host` header is exactly
///   `neonlaw.com` (case-insensitive). All other hosts pass through
///   unchanged so local development, the staging hostname, and the
///   canonical hostname itself behave normally.
/// - It does not handle the legacy `.org` hostname. That is a separate
///   external 301 owned by DNS / CDN configuration.
struct CanonicalHostMiddleware: AsyncMiddleware {
    /// The hostname requests are redirected to.
    static let canonicalHost: String = "www.neonlaw.com"

    /// Hosts that trigger an apex-to-www redirect. Matched
    /// case-insensitively against the request's `Host` header (port
    /// stripped).
    static let apexHosts: Set<String> = ["neonlaw.com"]

    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        guard let hostHeader = request.headers.first(name: .host) else {
            return try await next.respond(to: request)
        }

        // The Host header can carry an explicit `:port` suffix. Compare on
        // the bare hostname so the redirect rule does not accidentally
        // treat `neonlaw.com:8080` as a different origin from
        // `neonlaw.com`.
        let bareHost = hostHeader.split(separator: ":").first.map(String.init) ?? hostHeader
        let normalizedHost = bareHost.lowercased()

        guard Self.apexHosts.contains(normalizedHost) else {
            return try await next.respond(to: request)
        }

        let path = request.url.string.isEmpty ? "/" : request.url.string
        let target = "https://\(Self.canonicalHost)\(path)"
        return request.redirect(to: target, redirectType: .permanent)
    }
}
