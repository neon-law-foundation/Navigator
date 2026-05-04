import AsyncHTTPClient
import Foundation
import JWTKit
import NIOFoundationCompat

/// Minimal OIDC discovery document — only the fields this library needs.
private struct OIDCDiscoveryDocument: Decodable {
    let jwksURI: String

    enum CodingKeys: String, CodingKey {
        case jwksURI = "jwks_uri"
    }
}

/// Errors that can occur while building the JWT key collection from an OIDC provider.
public enum OIDCConfigError: Error {
    case invalidIssuerURL
    case invalidJWKSURL
}

/// Builds a `JWTKeyCollection` by fetching the JWKS from the OIDC discovery document.
///
/// Fetches `{issuerURL}/.well-known/openid-configuration` to locate the JWKS endpoint,
/// then downloads and parses the key set. Works with any standards-compliant OIDC provider
/// — Cognito, Auth0, Dex, or LocalStack's Cognito emulation.
///
/// Returns an empty collection if `issuerURL` is empty, allowing startup without OIDC configured.
///
/// - Parameters:
///   - issuerURL: The OIDC issuer URL (e.g. a Cognito User Pool URL or LocalStack endpoint).
public func buildJWTKeyCollection(
    issuerURL: String
) async throws -> JWTKeyCollection {
    guard !issuerURL.isEmpty else { return JWTKeyCollection() }

    let httpClient = HTTPClient.shared
    let discoveryURLString = "\(issuerURL)/.well-known/openid-configuration"
    guard URL(string: discoveryURLString) != nil else {
        throw OIDCConfigError.invalidIssuerURL
    }
    let discoveryResponse = try await httpClient.get(url: discoveryURLString).get()
    guard let discoveryBody = discoveryResponse.body else {
        throw OIDCConfigError.invalidIssuerURL
    }
    let discoveryData = Data(buffer: discoveryBody)
    let discovery = try JSONDecoder().decode(OIDCDiscoveryDocument.self, from: discoveryData)

    guard URL(string: discovery.jwksURI) != nil else {
        throw OIDCConfigError.invalidJWKSURL
    }
    let jwksResponse = try await httpClient.get(url: discovery.jwksURI).get()
    guard let jwksBody = jwksResponse.body else {
        throw OIDCConfigError.invalidJWKSURL
    }
    let jwksData = Data(buffer: jwksBody)
    let jwks = try JSONDecoder().decode(JWKS.self, from: jwksData)

    let keyCollection = JWTKeyCollection()
    try await keyCollection.add(jwks: jwks)
    return keyCollection
}
